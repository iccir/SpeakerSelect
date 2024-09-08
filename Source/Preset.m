// (c) 2024 Ricci Adams
// MIT License / 1-clause BSD License

#import "Preset.h"
#import "Biquad.h"

@implementation Preset

- (instancetype) initWithName: (NSString *) name
                      biquads: (NSArray<Biquad *> *) biquads
                   multiplier: (double) multiplier
{
    if ((self = [super init])) {
        _name = name;
        _biquads = biquads;
        _multiplier = multiplier;
    }

    return self;
}


@end
