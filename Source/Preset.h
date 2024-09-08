// (c) 2024 Ricci Adams
// MIT License / 1-clause BSD License

#import <Foundation/Foundation.h>

@class Biquad;

@interface Preset : NSObject

- (instancetype) initWithName: (NSString *) name
                      biquads: (NSArray<Biquad *> *) biquads
                   multiplier: (double) multiplier;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSArray<Biquad *> *biquads;
@property (nonatomic, readonly) double multiplier;

@end
