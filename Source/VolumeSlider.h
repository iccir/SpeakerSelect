/*
    VolumeSlider / VolumeSliderCell
    Hastily-constructed class to mimic Control Center's sliders

    (c) 2024 Ricci Adams
    MIT License / 1-clause BSD License
*/

@import AppKit;

@interface VolumeSlider : NSSlider
@property (nonatomic, readonly, getter=isTracking) BOOL tracking;
@property (nonatomic) NSImage *image;
@end
