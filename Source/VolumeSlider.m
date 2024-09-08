/*
    VolumeSlider / VolumeSliderCell
    Hastily-constructed class to mimic Control Center's sliders

    (c) 2024 Ricci Adams
    MIT License / 1-clause BSD License
*/

#import "VolumeSlider.h"
#import "Utils.h"


@interface VolumeSliderCell : NSSliderCell
@property (nonatomic, readonly, getter=isTracking) BOOL tracking;
@end


@implementation VolumeSliderCell 

- (BOOL) startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
    _tracking = YES;
    return [super startTrackingAt:startPoint inView:controlView];
}


- (void) stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
    _tracking = NO;
    return [super stopTracking:lastPoint at:stopPoint inView:controlView mouseIsUp:flag];
}


- (CGRect) barRectFlipped:(BOOL)flipped
{
    NSRect barRect  = [super barRectFlipped:flipped];
    NSRect knobRect = [super knobRectFlipped:flipped];

    NSRect result = NSMakeRect(
        barRect.origin.x,
        knobRect.origin.y,
        barRect.size.width,
        knobRect.size.height
    );
    
    return NSInsetRect(result, 0, 3);
}


- (void) drawKnob:(NSRect)knobRect
{
    // No implementation
}


- (void) drawBarInside:(NSRect)inRect flipped:(BOOL)flipped
{
    NSColor *sliderBorderColor   = [NSColor colorNamed:@"SliderBorderColor"];
    NSColor *sliderFilledColor   = [NSColor colorNamed:@"SliderFilledColor"];
    NSColor *sliderUnfilledColor = [NSColor colorNamed:@"SliderUnfilledColor"];
    
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    CGFloat scaleFactor = [[[self controlView] window] backingScaleFactor];
    
    CGContextSaveGState(context);

    float floatValue = [self floatValue];

    CGFloat borderRadius = inRect.size.height * 0.5;

    [sliderBorderColor set];
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRoundedRect:inRect xRadius:borderRadius yRadius:borderRadius];
    [borderPath fill];
    
    inRect = CGRectInset(inRect, 1, 1);
    CGFloat barRadius = inRect.size.height * 0.5;

    NSBezierPath *bar = [NSBezierPath bezierPathWithRoundedRect:inRect xRadius:barRadius yRadius:barRadius];
    [bar addClip];

    [sliderUnfilledColor set];
    [[NSBezierPath bezierPathWithRect:inRect] fill];

    CGFloat knobWidth = inRect.size.height;
    CGFloat halfKnobWidth = knobWidth / 2.0;
    
    CGFloat valueX = round(inRect.origin.x + ((inRect.size.width - knobWidth) * floatValue));

    CGRect fillRect = inRect;
    CGRect knobRect = inRect;
    fillRect.size.width = (valueX - fillRect.origin.x) + halfKnobWidth;
    
    [sliderFilledColor set];
    [[NSBezierPath bezierPathWithRect:fillRect] fill];

    CGContextRestoreGState(context);

    knobRect.origin.x = valueX;
    knobRect.size.width = knobWidth;

    // Draw knob
    {
        NSBezierPath *knobPath = [NSBezierPath bezierPathWithOvalInRect:knobRect];
        
        CGFloat knobAlpha = ((knobRect.origin.x - inRect.origin.x) - knobRect.size.width) / knobRect.size.width;
        if (knobAlpha > 1.0) knobAlpha = 1.0;
        
        [[NSColor colorWithWhite:0 alpha:(0.1 * knobAlpha)] set];
        [knobPath setLineWidth:2];
        [knobPath stroke];

        NSShadow *shadow = [[NSShadow alloc] init];
        [shadow setShadowBlurRadius:4];
        [shadow setShadowColor:[NSColor colorWithWhite:0 alpha:(0.2 * knobAlpha)]];
        [shadow set];

        NSColor *color = _tracking ?
            [NSColor colorNamed:@"SliderKnobTrackingColor"] :
            [NSColor colorNamed:@"SliderKnobColor"];
            
        if (knobAlpha != 1.0) {
            color = [color blendedColorWithFraction:(1.0 - knobAlpha) ofColor:sliderFilledColor];
        }
        
        [color set];
        [knobPath fill];
    }

    CGContextBeginTransparencyLayer(context, NULL);
    {
        NSImage *image = [(VolumeSlider *)[self controlView] image];
        NSRect imageRect = knobRect;
        imageRect.origin.x = inRect.origin.x;
        imageRect = GetCenteredRect(imageRect, [image size], 12, scaleFactor);
        
        [image drawInRect:imageRect];

        [sliderUnfilledColor set];
        NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceIn);
    }
    CGContextEndTransparencyLayer(context);
}


@end


@implementation VolumeSlider

- (BOOL) isTracking
{
    VolumeSliderCell *cell = [self cell];
    return [cell isTracking];
}


- (void) setImage:(NSImage *)image
{
    if (_image != image) {
        _image = image;
        [self setNeedsDisplay:YES];
    }
}

@end

