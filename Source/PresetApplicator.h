// (c) 2024 Ricci Adams
// MIT License / 1-clause BSD License

#import <Foundation/Foundation.h>

@class Preset;
@class AudioDevice;

@interface PresetApplicator : NSObject

- (void) applyPreset:(Preset *)preset toAudioDevice:(AudioDevice *)audioDevice;

@end
