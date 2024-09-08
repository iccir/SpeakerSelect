// (c) 2014-2024 Ricci Adams
// MIT License / 1-clause BSD License

@import Foundation;
@import CoreAudio;

extern NSString * const AudioDevicesDidRefreshNotification;
extern NSString * const DefaultOutputDeviceDidChangeNotification;
extern NSString * const VolumeOrMuteDidChangeNotification;


@class Preset;

@interface AudioDevice : NSObject

+ (NSArray<AudioDevice *> *) allDevices;

@property (nonatomic, class) AudioDevice *defaultOutputDevice;

@property (nonatomic, readonly) AudioObjectID objectID;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *deviceUID;
@property (nonatomic, readonly) NSString *manufacturer;
@property (nonatomic, readonly) NSString *modelUID;

@property (nonatomic) double sampleRate;

@property (nonatomic) float volume;
@property (nonatomic, getter=isMuted) BOOL muted;

@end

