// (c) 2014-2024 Ricci Adams
// MIT License / 1-clause BSD License

#import "AudioDevice.h"
#import "Utils.h"

static NSArray *sAllDevices = nil;
static AudioObjectID sDefaultOutputDeviceID = 0;
static AudioDevice *sDefaultOutputDevice = nil;

NSString * const AudioDevicesDidRefreshNotification = @"AudioDevicesDidRefresh";
NSString * const DefaultOutputDeviceDidChangeNotification = @"DefaultOutputDeviceDidChangeNotification";
NSString * const VolumeOrMuteDidChangeNotification = @"VolumeOrMuteDidChangeNotification";

static const AudioObjectPropertyAddress sAddressDevices = { 
    kAudioHardwarePropertyDevices, 
    kAudioObjectPropertyScopeGlobal, 0
};

static const AudioObjectPropertyAddress sAddressDefaultOutputDevice = {
    kAudioHardwarePropertyDefaultOutputDevice,
    kAudioObjectPropertyScopeGlobal, 0
};

static const AudioObjectPropertyAddress sAddressStreams = {
    kAudioDevicePropertyStreams,
    kAudioObjectPropertyScopeOutput, 0
};

static const AudioObjectPropertyAddress sAddressVolume = {
    0x766d7663, // 'vmvc'
    kAudioObjectPropertyScopeOutput, 0
};

static const AudioObjectPropertyAddress sAddressMute = {
    kAudioDevicePropertyMute,
    kAudioObjectPropertyScopeOutput, 0
};


static OSStatus sDispatchVolumeNotification(
    AudioObjectID inObjectID,
    UInt32 inNumberAddresses,
    const AudioObjectPropertyAddress *inAddresses,
    void *inClientData
) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VolumeOrMuteDidChangeNotification object:nil];
    });

    return noErr;
}


static void *sCopyProperty(AudioObjectID objectID, const AudioObjectPropertyAddress *address, UInt32 *outDataSize)
{
    UInt32 dataSize = 0;
    
    if (AudioObjectGetPropertyDataSize(objectID, address, 0, NULL, &dataSize) != noErr) {
        return NULL;
    }
    
    void *result = malloc(dataSize);
    
    if (AudioObjectGetPropertyData(objectID, address, 0, NULL, &dataSize, result) != noErr) {
        free(result);
        return NULL;
    }

    if (outDataSize) *outDataSize = dataSize;
    
    return result;
}


static NSString *sGetString(AudioObjectID objectID, AudioObjectPropertySelector selector)
{
    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };

    if (objectID && AudioObjectHasProperty(objectID, &address)) {
        CFStringRef data = NULL;
        UInt32 dataSize = sizeof(data);
        
        if (AudioObjectGetPropertyData(objectID, &address, 0, NULL, &dataSize, &data) == noErr) {
            return CFBridgingRelease(data);
        }
    }
    
    return nil;
}


static BOOL sCheck(NSString *opName, OSStatus err)
{
    return CheckError(err, opName);
}


static void sLoadUInt32(NSString *opName, AudioObjectID objectID, AudioObjectPropertySelector selector, UInt32 *outValue)
{
    if (!objectID) return;

    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };

    UInt32 value = 0;
    UInt32 size  = sizeof(UInt32);

    if (sCheck(opName, AudioObjectGetPropertyData(objectID, &address, 0, NULL, &size, &value))) {
        *outValue = value;
    }
}


@implementation AudioDevice {
    AudioObjectID _objectID;
    NSString *_deviceUID;
    NSString *_name;
    UInt32 _transportType;
}


#pragma mark - Static

+ (void) _refreshAudioDevices
{
    __auto_type getConnectedDevices = ^{
        NSMutableArray *result = [NSMutableArray array];

        UInt32 dataSize = 0;
        AudioDeviceID *audioDevices = sCopyProperty(kAudioObjectSystemObject, &sAddressDevices, &dataSize);
        
        if (!audioDevices) {
            Log(@"Error when querying kAudioObjectSystemObject for devices");
            return result;
        }

        UInt32 deviceCount = dataSize / sizeof(AudioDeviceID);

        for (UInt32 i = 0; i < deviceCount; ++i) {
            AudioObjectID objectID = audioDevices[i];

            NSString *deviceUID = sGetString(objectID, kAudioDevicePropertyDeviceUID);
            if (!deviceUID) {
                continue;
            }

            if ([deviceUID hasPrefix:@"com.iccir.SpeakerSelect."]) {
                continue;
            }

            dataSize = 0;
            
            if (!sCheck(
                @"AudioObjectGetPropertyDataSize[kAudioDevicePropertyStreamConfiguration]",
                AudioObjectGetPropertyDataSize(objectID, &sAddressStreams, 0, NULL, &dataSize)
            )) continue;
            
            NSInteger streamCount = dataSize / sizeof(AudioStreamID);
            if (streamCount < 1) {
                continue;
            }

            AudioDevice *device = [[AudioDevice alloc] initWithDeviceUID:deviceUID name:nil];
            
            [device _updateObjectID:objectID];

            [result addObject:device];
        }

        free(audioDevices);

        return result;
    };

    __auto_type makeDeviceMap = ^(NSArray *inArray) {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];

        for (AudioDevice *device in inArray) {
            NSString *key = [device deviceUID];
            if (key) [result setObject:device forKey:key];
        }
        
        return result;
    };
    
    __auto_type mergeDevices = ^(NSMutableArray *oldArray, NSMutableArray *newArray, NSMutableArray *outArray) {
        NSMutableDictionary *oldMap = makeDeviceMap(oldArray);
        NSMutableDictionary *newMap = makeDeviceMap(newArray);
        
        for (NSString *key in [newMap allKeys]) {
            AudioDevice *oldDevice = [oldMap objectForKey:key];
            AudioDevice *newDevice = [newMap objectForKey:key];
            
            if (oldDevice) {
                [oldDevice _updateObjectID:[newDevice objectID]];

                [outArray addObject:oldDevice];
                
                [oldArray removeObject:oldDevice];
                [newArray removeObject:newDevice];
            }
        }
    };

    static BOOL isRefreshing = NO;
    
    if (isRefreshing) return;
    isRefreshing = YES;

    NSMutableArray *oldDevices = [sAllDevices mutableCopy];
    NSMutableArray *newDevices = [getConnectedDevices() mutableCopy];
    
    NSMutableArray *outDevices = [NSMutableArray array];
    
    mergeDevices(oldDevices, newDevices, outDevices);
   
    if (newDevices) [outDevices addObjectsFromArray:newDevices];

    NSArray *allDevices = [outDevices sortedArrayUsingComparator:^NSComparisonResult(id deviceA, id deviceB) {
        return [[deviceA name] caseInsensitiveCompare:[deviceB name]];
    }];
    
    if (![sAllDevices isEqual:allDevices]) {
        sAllDevices = allDevices;
        [[NSNotificationCenter defaultCenter] postNotificationName:AudioDevicesDidRefreshNotification object:nil];
    }
   
    isRefreshing = NO;

    [AudioDevice _refreshDefaultOutputDevice];
}


+ (void) _refreshDefaultOutputDevice
{
    AudioObjectID defaultOutputDeviceID = 0;
    UInt32 dataSize = sizeof(defaultOutputDeviceID);

    OSStatus err = AudioObjectGetPropertyData(
        kAudioObjectSystemObject, &sAddressDefaultOutputDevice,
        0, NULL,
        &dataSize, &defaultOutputDeviceID
    );

    if (err == noErr) {
        sDefaultOutputDevice = nil;

        for (AudioDevice *device in sAllDevices) {
            if (defaultOutputDeviceID == [device objectID]) {
                sDefaultOutputDevice = device;
                break;
            }
        }
    }
    
    if (sDefaultOutputDeviceID != defaultOutputDeviceID) {
        if (sDefaultOutputDeviceID) {
            AudioObjectRemovePropertyListener(sDefaultOutputDeviceID, &sAddressMute,   sDispatchVolumeNotification, NULL);
            AudioObjectRemovePropertyListener(sDefaultOutputDeviceID, &sAddressVolume, sDispatchVolumeNotification, NULL);
        }

        if (defaultOutputDeviceID) {
            AudioObjectAddPropertyListener(defaultOutputDeviceID, &sAddressMute,   sDispatchVolumeNotification, NULL);
            AudioObjectAddPropertyListener(defaultOutputDeviceID, &sAddressVolume, sDispatchVolumeNotification, NULL);
        }

        sDefaultOutputDeviceID = defaultOutputDeviceID;

        [[NSNotificationCenter defaultCenter] postNotificationName:DefaultOutputDeviceDidChangeNotification object:nil];
    }
}


+ (AudioDevice *) defaultOutputDevice
{
    return sDefaultOutputDevice;
}


+ (void) setDefaultOutputDevice:(AudioDevice *)defaultOutputDevice
{
    AudioObjectID objectID = [defaultOutputDevice objectID];
    
    OSStatus err = AudioObjectSetPropertyData(
        kAudioObjectSystemObject, &sAddressDefaultOutputDevice,
        0, NULL,
        sizeof(objectID), &objectID
    );
    
    if (err == noErr) {
        sDefaultOutputDevice = defaultOutputDevice;
        [[NSNotificationCenter defaultCenter] postNotificationName:DefaultOutputDeviceDidChangeNotification object:self];
    }
}


+ (void) initialize
{
    AudioObjectAddPropertyListenerBlock(
        kAudioObjectSystemObject,
        &sAddressDevices,
        dispatch_get_main_queue(),
        ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress inAddresses[]) {
            [AudioDevice _refreshAudioDevices];
        }
    );

    AudioObjectAddPropertyListenerBlock(
        kAudioObjectSystemObject,
        &sAddressDefaultOutputDevice,
        dispatch_get_main_queue(),
        ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress inAddresses[]) {
            [AudioDevice _refreshDefaultOutputDevice];
        }
    );
    
    [AudioDevice _refreshAudioDevices];
}


+ (NSArray<AudioDevice *> *) allDevices
{
    return sAllDevices;
}


#pragma mark - Lifecycle / Overrides

- (instancetype) initWithDeviceUID:(NSString *)deviceUID name:(NSString *)name
{
    if ((self = [super init])) {
        _deviceUID = deviceUID;
        _name = [name copy];
    }
    
    return self;
}


- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: %p '%@'>", NSStringFromClass([self class]), self, [self name]];
}


#pragma mark - Private Methods

- (UInt32) _transportType
{
    if (_transportType == kAudioDeviceTransportTypeUnknown) {
        UInt32 transportType = kAudioDeviceTransportTypeUnknown;
        sLoadUInt32(@"_transportType", _objectID, kAudioDevicePropertyTransportType, &transportType);
        _transportType = transportType;
    }
    
    return _transportType;
}


- (UInt32) _channelCount
{
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyStreamConfiguration,
        kAudioDevicePropertyScopeOutput, 0
    };

    UInt32 size = 0;
    AudioBufferList *bufferList = sCopyProperty(_objectID, &address, &size);
    if (!bufferList) return 0;

    UInt32 channelCount = 0;

    for (NSInteger i = 0; i < bufferList->mNumberBuffers; i++) {
        channelCount += bufferList->mBuffers[i].mNumberChannels;
    }
    
    free(bufferList);
    
    return channelCount;
}


- (void) _updateObjectID:(AudioObjectID)objectID
{
    if (_objectID != objectID) {
        [self willChangeValueForKey:@"objectID"];
        _objectID = objectID;
        [self didChangeValueForKey:@"objectID"];
    }
}


#pragma mark - Accessors

- (NSString *) name
{
    if (!_name && _objectID) {
        _name = sGetString(_objectID, kAudioObjectPropertyName);
    }

    return _name;
}


- (NSString *) deviceUID
{
    if (!_deviceUID && _objectID) {
        _deviceUID = sGetString(_objectID, kAudioDevicePropertyDeviceUID);
    }

    return _deviceUID;
}


- (NSString *) manufacturer
{
    return sGetString(_objectID, kAudioObjectPropertyManufacturer);
}


- (NSString *) modelUID
{
    return sGetString(_objectID, kAudioDevicePropertyModelUID);
}


#pragma mark - Accessors

- (BOOL) isBuiltIn
{
    return [self _transportType] == kAudioDeviceTransportTypeBuiltIn;
}

- (float) volume
{
    float volume = 0;
    UInt32 dataSize = sizeof(volume);

    AudioObjectGetPropertyData(_objectID, &sAddressVolume, 0, NULL, &dataSize, &volume);
    
    return volume;
}


- (void) setVolume:(float)volume
{
    AudioObjectSetPropertyData(_objectID, &sAddressVolume, 0, NULL, sizeof(volume), &volume);
}


- (BOOL) isMuted
{
    UInt32 value = 0;
    UInt32 dataSize = sizeof(value);

    AudioObjectGetPropertyData(_objectID, &sAddressMute, 0, NULL, &dataSize, &value);
    
    return value > 0;
}


- (void) setMuted:(BOOL)muted
{
    UInt32 value = muted ? 1 : 0;
    AudioObjectSetPropertyData(_objectID, &sAddressMute, 0, NULL, sizeof(value), &value);
}


@end

