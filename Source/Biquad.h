// (c) 2019-2024 Ricci Adams
// MIT License / 1-clause BSD License

@import Foundation;
@import Accelerate;

typedef NS_ENUM(NSInteger, BiquadType) {
    BiquadTypePeaking,
    BiquadTypeLowpass,
    BiquadTypeHighpass,
    BiquadTypeBandpass,
    BiquadTypeLowshelf,
    BiquadTypeHighshelf
};

@interface Biquad : NSObject

+ (void) fillCoefficients: (double *) coefficients
              biquadArray: (NSArray<Biquad *> *) biquadArray
               sampleRate: (double) sampleRate
             channelCount: (NSUInteger) channelCount;

- (instancetype) initWithType: (BiquadType) type
                    frequency: (double) frequency
                            Q: (double) Q
                         gain: (double) gain;

@property (nonatomic, readonly) BiquadType type;
@property (nonatomic, readonly) double frequency;
@property (nonatomic, readonly) double Q;
@property (nonatomic, readonly) double gain;

@end

