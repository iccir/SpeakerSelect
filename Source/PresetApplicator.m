/*
    PresetApplicator
    Sends preset data to the AudioOptimizerPlugin kernel extension.
    (See https://github.com/iccir/AudioOptimizerPlugin)
    
    (c) 2024 Ricci Adams
    MIT License / 1-clause BSD License
*/

#import "PresetApplicator.h"

#import "AudioDevice.h"
#import "Preset.h"
#import "Biquad.h"

@import IOKit;


static io_registry_entry_t sFindDescendant(io_registry_entry_t entry, char *conformingTo)
{
    io_iterator_t iterator;

    if (IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator) == kIOReturnSuccess) {
        io_registry_entry_t child;

        while ((child = IOIteratorNext(iterator))) {
            if (IOObjectConformsTo(child, conformingTo)) {
                return child;
            }
            
            io_registry_entry_t foundChild = sFindDescendant(child, conformingTo);
            if (foundChild) return foundChild;
        }
    }

    return IO_OBJECT_NULL;
}


static io_registry_entry_t sFindOptimizer(NSString *deviceUID)
{
    CFDictionaryRef matching = IOServiceMatching("AppleUSBAudioEngine");
    io_iterator_t entryIterator;

    if (IOServiceGetMatchingServices(kIOMainPortDefault, matching, &entryIterator) == kIOReturnSuccess) {
        io_registry_entry_t device;

        while ((device = IOIteratorNext(entryIterator))) {
            CFMutableDictionaryRef serviceCFDictionary;

            if (IORegistryEntryCreateCFProperties(device, &serviceCFDictionary, kCFAllocatorDefault, kNilOptions) != kIOReturnSuccess) {
                IOObjectRelease(device);
                continue;
            }
            
            NSMutableDictionary *serviceDictionary = CFBridgingRelease(serviceCFDictionary);
            
            if (deviceUID && [[serviceDictionary objectForKey:@"IOAudioEngineGlobalUniqueID"] isEqual:deviceUID]) {
                io_registry_entry_t optimizer = sFindDescendant(device, "IccirAudioOptimizerPlugin");
                if (optimizer) return optimizer;
            }
        }
    }
    
    return IO_OBJECT_NULL;
}


static NSData *sGetDataForPreset(Preset *preset)
{
    typedef struct {
        UInt32 type;
        double frequency;
        double gain;
        double Q;
    } OutBiquad;

    NSArray *biquads = [preset biquads];
    NSInteger biquadCount = [biquads count];
    
    if (biquadCount == 0) return nil;

    if (biquadCount > UINT32_MAX) biquadCount = UINT32_MAX;

    size_t biquadsDataLength = (sizeof(OutBiquad) * biquadCount);

    OutBiquad *outBiquads = malloc(biquadsDataLength);

    double multiplier = [preset multiplier];

    for (NSInteger i = 0; i < biquadCount; i++) {
        Biquad *inBiquad = [biquads objectAtIndex:i];
        
        outBiquads[i].type = (UInt32)[inBiquad type];
        outBiquads[i].frequency = [inBiquad frequency];
        outBiquads[i].gain      = [inBiquad gain] * multiplier;
        outBiquads[i].Q         = [inBiquad Q];
    }
    
    return [[NSData alloc] initWithBytesNoCopy:outBiquads length:biquadsDataLength freeWhenDone:YES];
}


void sSendBiquadsToOptimizer(io_registry_entry_t optimizer, NSData *data)
{
    if ([data length] > 0) {
        IORegistryEntrySetCFProperty(optimizer, CFSTR("BiquadsData"), (__bridge CFDataRef)data);
        IORegistryEntrySetCFProperty(optimizer, CFSTR("BiquadsEnabled"), kCFBooleanTrue);
    } else {
        IORegistryEntrySetCFProperty(optimizer, CFSTR("BiquadsEnabled"), kCFBooleanFalse);
    }
}


@implementation PresetApplicator

- (void) applyPreset:(Preset *)preset toAudioDevice:(AudioDevice *)audioDevice
{
    io_registry_entry_t optimizer = sFindOptimizer([audioDevice deviceUID]);
    if (optimizer) {
        sSendBiquadsToOptimizer(optimizer, sGetDataForPreset(preset));
    }
}

@end
