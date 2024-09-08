// (c) 2024 Ricci Adams
// MIT License / 1-clause BSD License


#import "AppDelegate.h"
#import "AudioDevice.h"
#import "Utils.h"
#import "JSONTypechecker.h"
#import "Settings.h"
#import "TitleAndSymbolView.h"
#import "PresetApplicator.h"
#import "Preset.h"
#import "VolumeSlider.h"


@import CoreAudio;

@interface DeviceEntry : NSObject
@property (nonatomic) AudioDevice *audioDevice;
@property (nonatomic) SettingsDevice *settingsDevice;
@property (nonatomic) TitleAndSymbolView *view;
@end

@implementation DeviceEntry
@end


@interface PresetEntry : NSObject
@property (nonatomic) AudioDevice *audioDevice;
@property (nonatomic) Preset *preset;
@property (nonatomic) TitleAndSymbolView *view;
@end

@implementation PresetEntry
@end


@interface AppDelegate () <NSMenuItemValidation>
@property (weak) IBOutlet VolumeSlider *volumeSlider; 
@property (weak) IBOutlet NSMenu *statusMenu;

@property (strong) IBOutlet NSMenuItem *volumeMenuItem;

@property (strong) IBOutlet NSMenuItem *devicesSeparator;
@property (strong) IBOutlet NSMenuItem *devicesHeader;
@property (strong) IBOutlet NSMenuItem *devicesGroupItem;

@property (strong) IBOutlet NSMenuItem *presetsSeparator;
@property (strong) IBOutlet NSMenuItem *presetsHeader;
@property (strong) IBOutlet NSMenuItem *presetsGroupItem;

@property (strong) IBOutlet NSMenuItem *revealMenuItem;
@property (strong) IBOutlet NSMenuItem *reloadMenuItem;
@property (strong) IBOutlet NSMenuItem *soundSettingsItem;

@end

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    SettingsFile *_settingsFile;
    BOOL _wasOptionHeldOnMenuOpen;
    
    Preset *_activePreset;
    PresetApplicator *_presetApplicator;

    NSDictionary<NSValue *, DeviceEntry *> *_deviceEntryMap;
    NSArray<DeviceEntry *> *_deviceEntryArray;
    NSArray<PresetEntry *> *_presetEntryArray;
}


#pragma mark - Private Methods

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    __auto_type makeSectionHeader = ^(NSMenuItem *item) {
        NSString *title = [item title];

        NSAttributedString *as = [[NSAttributedString alloc] initWithString:title attributes:@{
            NSForegroundColorAttributeName: [NSColor labelColor],
            NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold]
        }];
    
        [item setAttributedTitle:as];
    };

    __auto_type observe = ^(NSString *name, void (^block)(NSNotification *notification)) {
        [[NSNotificationCenter defaultCenter] addObserverForName: name
                                                          object: nil
                                                           queue: nil
                                                      usingBlock: block];
    };

    NSStatusItem *statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusItem setVisible:YES];
    [statusItem setBehavior:NSStatusItemBehaviorTerminationOnRemoval];
    [statusItem setMenu:[self statusMenu]];

    _statusItem = statusItem;

    makeSectionHeader([self devicesHeader]);
    makeSectionHeader([self presetsHeader]);

    observe(AudioDevicesDidRefreshNotification, ^(NSNotification *notification) {
        [self _rebuildDeviceEntries];
        [self _rebuildMenu];
        [self _updateActivePreset];
    });

    observe(DefaultOutputDeviceDidChangeNotification, ^(NSNotification *notification) {
        [self _rebuildPresetEntries];
        [self _rebuildMenu];
        [self _updateActivePreset];
        [self _updateSliderAndIcons];
        [self _updateSelectedMenuItems];
    });

    observe(VolumeOrMuteDidChangeNotification, ^(NSNotification *notification) {
        [self _updateSliderAndIcons];
    });

    [self reloadSettings:self];
    [self _updateSliderAndIcons];
}


#pragma mark - Settings

- (NSURL *) _settingsURL
{
    NSString *appSupport = GetApplicationSupportDirectory();
    NSString *settingsJson = [appSupport stringByAppendingPathComponent:@"settings.json"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:settingsJson]) {
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"settings" ofType:@"json"];
        [[NSFileManager defaultManager] copyItemAtPath:bundlePath toPath:settingsJson error:NULL];
    }

    return [NSURL fileURLWithPath:settingsJson];
}


- (IBAction) reloadSettings:(id)sender
{
    _settingsFile = [[SettingsFile alloc] initWithFileURL:[self _settingsURL]];
    
    NSError *error = [_settingsFile error];
    if (error) {
        [[NSAlert alertWithError:error] runModal];
    }

    [self _rebuildDeviceEntries];
    [self _rebuildPresetEntries];
    [self _rebuildMenu];
    [self _updateActivePreset];
}


#pragma mark - Active Preset / Tap

- (NSString *) _lastUsedPresetKeyWithDeviceUID:(NSString *)deviceUID
{
    return [NSString stringWithFormat:@"LastUsedPreset-%@", deviceUID];
}

- (Preset *) _lastUsedPresetWithDeviceUID:(NSString *)deviceUID presets:(NSArray<Preset *> *)presets
{
    NSString *presetName = [[NSUserDefaults standardUserDefaults] stringForKey:[self _lastUsedPresetKeyWithDeviceUID:deviceUID]];

    if (presetName) {
        for (Preset *preset in presets) {
            if ([[preset name] isEqualToString:presetName]) {
                return preset;
            }
        }
    }
    
    return [presets firstObject];
}


- (void) _updateActivePreset
{
    AudioDevice    *selectedAudioDevice    = [AudioDevice defaultOutputDevice];
    SettingsDevice *selectedSettingsDevice = nil;
       
    // Find our SettingsDevice for the 
    for (DeviceEntry *entry in _deviceEntryArray) {
        if ([[entry audioDevice] isEqual:selectedAudioDevice]) {
            selectedSettingsDevice = [entry settingsDevice];
            break;
        }
    }
    
    NSString *deviceUID = [selectedAudioDevice deviceUID];
    NSArray *presets = [selectedSettingsDevice presets];
    Preset *presetToUse = nil;

    if ([presets count] > 1) {
        presetToUse = [self _lastUsedPresetWithDeviceUID:deviceUID presets:presets];
    } else if ([presets count] == 1) {
        presetToUse = [presets lastObject];
    }
    
    [_presetApplicator applyPreset:presetToUse toAudioDevice:selectedAudioDevice];
    _activePreset = presetToUse;
}


- (IBAction) selectPreset:(id)sender
{
    PresetEntry *entry = [sender representedObject];
 
    NSString *deviceUID = [[entry audioDevice] deviceUID];
    
    NSString *key = [self _lastUsedPresetKeyWithDeviceUID:deviceUID];
    [[NSUserDefaults standardUserDefaults] setObject:[[entry preset] name] forKey:key];
    
    [self _updateActivePreset];
    [self _updateSelectedMenuItems];
}


#pragma mark - UI Updates

- (void) menuNeedsUpdate:(NSMenu*)menu
{
    _wasOptionHeldOnMenuOpen = ([NSEvent modifierFlags] & NSEventModifierFlagOption) > 0;
    [self _rebuildMenu];
}


- (void) _rebuildDeviceEntries
{
    NSMutableArray *remainingAudioDevices = [[AudioDevice allDevices] mutableCopy];

    NSMutableArray *deviceEntryArray = [NSMutableArray array];

    NSDictionary        *oldDeviceEntryMap = _deviceEntryMap;
    NSMutableDictionary *newDeviceEntryMap = [NSMutableDictionary dictionary];

    __auto_type makeEntry = ^(AudioDevice *audioDevice, SettingsDevice *settingsDevice) {
        NSValue *key = [NSValue valueWithNonretainedObject:audioDevice];

        DeviceEntry *entry = [oldDeviceEntryMap objectForKey:key];
        if (!entry) entry = [[DeviceEntry alloc] init];
            
        [entry setAudioDevice:audioDevice];
        [entry setSettingsDevice:settingsDevice];
        
        [deviceEntryArray addObject:entry];
        [newDeviceEntryMap setObject:entry forKey:key];
    };

    __auto_type contains = ^(NSString *haystack, NSString *needle) {
        return needle && [haystack containsString:needle];
    };
    
    for (SettingsDevice *settingsDevice in [_settingsFile devices]) {
        AudioDevice *foundAudioDevice = nil;
        SettingsDeviceMatch *match = [settingsDevice match];

        for (AudioDevice *audioDevice in remainingAudioDevices) {
            if (
                contains([audioDevice name],         [match name]) ||
                contains([audioDevice deviceUID],    [match deviceUID]) ||
                contains([audioDevice manufacturer], [match manufacturer]) ||
                contains([audioDevice modelUID],     [match modelUID])
            ) {
                foundAudioDevice = audioDevice;
                break;
            }
        }
    
        if (foundAudioDevice) {
            makeEntry(foundAudioDevice, settingsDevice);
            [remainingAudioDevices removeObject:foundAudioDevice];
        }
    }
    
    for (AudioDevice *audioDevice in remainingAudioDevices) {
        makeEntry(audioDevice, nil);
    }

    _deviceEntryArray = deviceEntryArray;
    _deviceEntryMap   = newDeviceEntryMap;
}


- (void) _rebuildPresetEntries
{
    // Find DeviceEntry for current output device
    AudioDevice *defaultOutputDevice = [AudioDevice defaultOutputDevice];
    NSValue *key = [NSValue valueWithNonretainedObject:defaultOutputDevice];
    DeviceEntry *deviceEntry = [_deviceEntryMap objectForKey:key];
    
    NSMutableArray *presetEntryArray = [NSMutableArray array];

    if (deviceEntry) {
        for (Preset *preset in [[deviceEntry settingsDevice] presets]) {
            PresetEntry *presetEntry = [[PresetEntry alloc] init];
            
            [presetEntry setPreset:preset];
            [presetEntry setAudioDevice:defaultOutputDevice];
            
            [presetEntryArray addObject:presetEntry];
        }
    }

    _presetEntryArray = presetEntryArray;
}


- (void) _rebuildMenu
{
    NSMenu *menu = [self statusMenu];
    CGFloat menuWidth = 298;

    [menu setMinimumWidth:menuWidth];
    
    NSMenuItem *devicesGroupItem = [self devicesGroupItem];
    NSMenuItem *presetsGroupItem = [self presetsGroupItem];

    NSView *devicesContainer = [devicesGroupItem view];
    if (!devicesContainer) {
        devicesContainer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, menuWidth, 0)];
        [devicesGroupItem setView:devicesContainer];
    }

    NSView *presetsContainer = [presetsGroupItem view];
    if (!presetsContainer) {
        presetsContainer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, menuWidth, 0)];
        [presetsGroupItem setView:presetsContainer];
    }

    __auto_type stackViews = ^(NSView *container, NSArray<NSView *> *views) {
        if (![[container subviews] isEqualToArray:views]) {
            [[container subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

            NSRect containerFrame = [container bounds];
            NSRect subviewFrame   = containerFrame;

            for (NSView *view in [views reverseObjectEnumerator]) {
                subviewFrame.size.height = [view frame].size.height;
                [view setFrame:subviewFrame];
                subviewFrame.origin.y = NSMaxY(subviewFrame);
            }

            for (NSView *view in views) {
                [container addSubview:view];
            }
            
            containerFrame.size.height = subviewFrame.origin.y;
            [container setFrame:containerFrame];
        }
    };

    __auto_type makeTitleAndSymbolView = ^(id entry, SEL action) {
        TitleAndSymbolView *view = [[TitleAndSymbolView alloc] initWithFrame:NSMakeRect(0, 0, menuWidth, 32)];

        [view setTarget:self];
        [view setAction:action];
        [view setRepresentedObject:entry];

        [entry setView:view];

        return view;
    };

    __auto_type addViewForDeviceEntry = ^(NSMutableArray *array, DeviceEntry *deviceEntry) {
        AudioDevice    *audioDevice    = [deviceEntry audioDevice];
        SettingsDevice *settingsDevice = [deviceEntry settingsDevice];
        TitleAndSymbolView *view = [deviceEntry view];
    
        if (!view) {
            view = makeTitleAndSymbolView(deviceEntry, @selector(selectDevice:));
        }
    
        NSString *title = [settingsDevice name];
        if (!title) title = [audioDevice name];

        NSString *symbol = [settingsDevice symbol];
        if (!symbol) symbol = @"speaker.wave.2.fill";

        [view setTitle:title];
        [view setSymbol:symbol];

        [array addObject:view];
    };
    
    __auto_type addViewForPresetEntry = ^(NSMutableArray *array, PresetEntry *presetEntry) {
        Preset *preset = [presetEntry preset];
        TitleAndSymbolView *view = [presetEntry view];

        if (!view) {
            view = makeTitleAndSymbolView(presetEntry, @selector(selectPreset:));
        }

        [view setTitle:[preset name]];
        
        [array addObject:view];
    };
    
    // Resize/hide devices view
    {
        NSMutableArray *subviews = [NSMutableArray array];

        for (DeviceEntry *entry in _deviceEntryArray) {
            addViewForDeviceEntry(subviews, entry);
        }

        stackViews(devicesContainer, subviews);

        BOOL sectionHidden = ([subviews count] == 0);
        [[self devicesSeparator] setHidden:sectionHidden];
        [[self devicesHeader]    setHidden:sectionHidden];
        [[self devicesGroupItem] setHidden:sectionHidden];
    }

    // Resize/hide presets view
    {
        NSMutableArray *subviews = [NSMutableArray array];

        for (PresetEntry *entry in _presetEntryArray) {
            addViewForPresetEntry(subviews, entry);
        }
        
        stackViews(presetsContainer, subviews);

        BOOL sectionHidden = ([subviews count] == 0);
        [[self presetsSeparator] setHidden:sectionHidden];
        [[self presetsHeader]    setHidden:sectionHidden];
        [[self presetsGroupItem] setHidden:sectionHidden];
    }
        
    [[self reloadMenuItem] setHidden:!_wasOptionHeldOnMenuOpen];
    [[self revealMenuItem] setHidden:!_wasOptionHeldOnMenuOpen];
    [[self soundSettingsItem] setHidden:_wasOptionHeldOnMenuOpen];

    [self _updateSliderAndIcons];
    [self _updateSelectedMenuItems];
}


- (void) _updateSliderAndIcons
{
    AudioDevice  *audioDevice  = [AudioDevice defaultOutputDevice];
    VolumeSlider *volumeSlider = [self volumeSlider];

    float volume = [audioDevice volume];
    BOOL isMuted = [audioDevice isMuted];

    if (volume == 0.0) isMuted = YES;
    if (isMuted) volume = 0.0;

    if (![volumeSlider isTracking]) {
        [volumeSlider setFloatValue:volume];
    }
    
    NSImage *image = isMuted ?
        [NSImage imageWithSystemSymbolName:@"speaker.slash.fill" accessibilityDescription:nil] :
        [NSImage imageWithSystemSymbolName:@"speaker.wave.3.fill" variableValue:volume accessibilityDescription:nil];

    [[self volumeSlider] setImage:image];

    NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium scale:NSImageSymbolScaleMedium];
    [[_statusItem button] setImage:[image imageWithSymbolConfiguration:configuration]];
}


- (void) _updateSelectedMenuItems
{
    AudioDevice *defaultOutputDevice = [AudioDevice defaultOutputDevice];
    
    for (DeviceEntry *entry in _deviceEntryArray) {
        AudioDevice *audioDevice = [entry audioDevice];
        TitleAndSymbolView *view = [entry view];
    
        [view setSelected:[audioDevice isEqual:defaultOutputDevice]];
    }
    
    for (PresetEntry *entry in _presetEntryArray) {
        Preset *preset = [entry preset];
        if (!preset) continue;

        [[entry view] setSelected:[_activePreset isEqual:preset]];
    }
}


#pragma mark - IBActions

- (IBAction) revealSettings:(id)sender
{
    NSString *directory = GetApplicationSupportDirectory();
    NSString *file = [[self _settingsURL] path];

    [[NSWorkspace sharedWorkspace] selectFile:file inFileViewerRootedAtPath:directory];
}


- (IBAction) handleSlider:(id)sender
{
    float value = [[self volumeSlider] floatValue];
    
    if (value == 0.0) {
        [[AudioDevice defaultOutputDevice] setMuted:YES];
    } else {
        [[AudioDevice defaultOutputDevice] setMuted:NO];
        [[AudioDevice defaultOutputDevice] setVolume:value];
    }
}


- (IBAction) selectDevice:(id)sender
{
    DeviceEntry *entry = [sender representedObject];
    [AudioDevice setDefaultOutputDevice:[entry audioDevice]];
}


- (IBAction) showSoundSettings:(id)sender
{
    NSURL *URL = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.Sound-Settings.extension"];
    [[NSWorkspace sharedWorkspace] openURL:URL];
}


@end
