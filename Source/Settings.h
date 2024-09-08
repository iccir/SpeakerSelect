// (c) 2024 Ricci Adams
// MIT License / 1-clause BSD License

@import Foundation;

@class Preset;

@interface SettingsDeviceMatch : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *deviceUID;
@property (nonatomic, readonly) NSString *manufacturer;
@property (nonatomic, readonly) NSString *modelUID;
@end


@interface SettingsDevice : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *symbol;
@property (nonatomic, readonly, getter=isHidden) BOOL hidden;
@property (nonatomic, readonly) SettingsDeviceMatch *match;
@property (nonatomic, readonly) NSArray<Preset *> *presets;
@end


@interface SettingsFile : NSObject

- (instancetype) initWithFileURL:(NSURL *)fileURL;

@property (nonatomic, readonly) NSURL *fileURL;

@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) NSArray<SettingsDevice *> *devices;

@end


