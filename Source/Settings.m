// (c) 2024 Ricci Adams
// MIT License / 1-clause BSD License

#import "Settings.h"
#import "JSONTypechecker.h"
#import "Preset.h"
#import "Biquad.h"


@interface SettingsDevice ()
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *symbol;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic) SettingsDeviceMatch *match;
@property (nonatomic) NSArray<Preset *> *presets;
@end


@implementation SettingsDevice
@end


@interface SettingsDeviceMatch ()
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *deviceUID;
@property (nonatomic) NSString *manufacturer;
@property (nonatomic) NSString *modelUID;
@end


@implementation SettingsDeviceMatch
@end


JSONTypechecker *sTypechecker = nil;

static JSONTypechecker *sGetTypechecker(void)
{
    if (!sTypechecker) {
        sTypechecker = [[JSONTypechecker alloc] initWithTypeMap:@{
            @"$": JSONTypeDictionary,

            @"$.devices": JSONTypeArray,
            @"$.devices[]": JSONTypeDictionary,
            @"$.devices[].name": JSONTypeString,
            @"$.devices[].symbol": JSONTypeString,
            @"$.devices[].hidden": JSONTypeNumber,
            @"$.devices[].presets": JSONTypeArray,
            @"$.devices[].presets[]": JSONTypeString,

            @"$.devices[].match": JSONTypeDictionary,
            @"$.devices[].match.name": JSONTypeString,
            @"$.devices[].match.deviceUID": JSONTypeString,
            @"$.devices[].match.manufacturer": JSONTypeString,
            @"$.devices[].match.modelUID": JSONTypeString,
            
            @"$.presets": JSONTypeDictionary,
            @"$.presets.*": JSONTypeDictionary,
            @"$.presets.*.name": JSONTypeString,

            @"$.presets.*.multiplier": JSONTypeNumber,

            @"$.presets.*.biquads": JSONTypeArray,
            @"$.presets.*.biquads[]": JSONTypeDictionary,
            @"$.presets.*.biquads[].type": JSONTypeString,
            @"$.presets.*.biquads[].frequency": JSONTypeNumber,
            @"$.presets.*.biquads[].Q": JSONTypeNumber,
            @"$.presets.*.biquads[].gain": JSONTypeNumber
        }];
    }
    
    return sTypechecker;
}


@implementation SettingsFile {
    NSDictionary<NSString *, Preset *> *_presetMap;
}


#pragma mark - Init

- (instancetype) initWithFileURL:(NSURL *)fileURL
{
    if ((self = [super init])) {
        _fileURL = fileURL;
        [self _readFile];
    }

    return self;
}


#pragma mark - Private Methods

- (Biquad *) _biquadWithDictionary:(NSDictionary *)dictionary
{
    NSString *typeString = [dictionary objectForKey:@"type"];

    BiquadType type;
    if ([typeString isEqualToString:@"peaking"]) {
        type = BiquadTypePeaking;
    } else if ([typeString isEqualToString:@"lowpass"]) {
        type = BiquadTypeLowpass;
    } else if ([typeString isEqualToString:@"highpass"]) {
        type = BiquadTypeHighpass;
    } else if ([typeString isEqualToString:@"bandpass"]) {
        type = BiquadTypeBandpass;
    } else if ([typeString isEqualToString:@"lowshelf"]) {
        type = BiquadTypeLowshelf;
    } else if ([typeString isEqualToString:@"highshelf"]) {
        type = BiquadTypeHighshelf;
    } else {
        return nil;
    }
    
    double frequency = [[dictionary objectForKey:@"frequency"] doubleValue];
    double Q         = [[dictionary objectForKey:@"Q"]         doubleValue];
    double gain      = [[dictionary objectForKey:@"gain"]      doubleValue];

    return [[Biquad alloc] initWithType:type frequency:frequency Q:Q gain:gain];
}


- (Preset *) _presetWithDictionary:(NSDictionary *)dictionary
{
    NSString *name = [dictionary objectForKey:@"name"];
    
    NSNumber *multiplierNumber = [dictionary objectForKey:@"multiplier"];
    double multiplier = multiplierNumber ? [multiplierNumber doubleValue] : 1.0;
    
    NSArray *inBiquads = [dictionary objectForKey:@"biquads"];
    NSMutableArray *outBiquads = [NSMutableArray array];
    
    for (NSDictionary *inBiquad in inBiquads) {
        Biquad *biquad = [self _biquadWithDictionary:inBiquad];
        if (biquad) [outBiquads addObject:biquad];
    }

    return [[Preset alloc] initWithName:name biquads:outBiquads multiplier:multiplier];
}


- (SettingsDevice *) _deviceWithDictionary:(NSDictionary *)dictionary
{
    SettingsDevice *device = [[SettingsDevice alloc] init];
    
    [device setName:    [dictionary objectForKey:@"name"]];
    [device setSymbol:  [dictionary objectForKey:@"symbol"]];
    [device setHidden: [[dictionary objectForKey:@"hidden"] boolValue]];

    NSDictionary *matchDictionary = [dictionary objectForKey:@"match"];
    SettingsDeviceMatch *match = [self _matchWithDictionary:matchDictionary];
    [device setMatch:match];

    NSMutableArray *presets = [NSMutableArray array];
    for (NSString *presetName in [dictionary objectForKey:@"presets"]) {
        Preset *preset = [_presetMap objectForKey:presetName];
        if (preset) [presets addObject:preset];
    }

    [device setPresets:presets];
    
    return device;
}


- (SettingsDeviceMatch *) _matchWithDictionary:(NSDictionary *)dictionary
{
    SettingsDeviceMatch *match = [[SettingsDeviceMatch alloc] init];
    
    [match setName:         [dictionary objectForKey:@"name"]];
    [match setDeviceUID:    [dictionary objectForKey:@"deviceUID"]];
    [match setManufacturer: [dictionary objectForKey:@"manufacturer"]];
    [match setModelUID:     [dictionary objectForKey:@"modelUID"]];
    
    return match;
}


- (void) _readFile
{
    _error = nil;
    NSError *error;

    NSData *data = [NSData dataWithContentsOfURL:_fileURL options:0 error:&error];
    if (error) { _error = error; return; }
    
    id settingsDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) { _error = error; return; }

    [sGetTypechecker() typecheckObject:settingsDictionary error:&error];
    if (error) { _error = error; return; }

    NSDictionary *inPresets = [settingsDictionary objectForKey:@"presets"];
    NSMutableDictionary *presetMap = [NSMutableDictionary dictionary];

    for (NSString *key in [inPresets keyEnumerator]) {
        NSDictionary *inPreset = [inPresets objectForKey:key];
        [presetMap setObject:[self _presetWithDictionary:inPreset] forKey:key];
    }
    
    _presetMap = presetMap;
    
    NSMutableArray *devices = [NSMutableArray array];
    for (NSDictionary *deviceDictionary in [settingsDictionary objectForKey:@"devices"]) {
        SettingsDevice *device = [self _deviceWithDictionary:deviceDictionary];
        if (device) {
            [devices addObject:device];
        }
    }
    
    _devices = devices;
}


@end

