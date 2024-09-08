/*
    TitleAndSymbolView
    Mimic Control Center's menu item views

    (c) 2024 Ricci Adams
    MIT License / 1-clause BSD License
*/

#import "TitleAndSymbolView.h"


@implementation TitleAndSymbolView {
    BOOL _isHighlighted;
    NSImage *_symbolImage;
    NSTextField *_titleLabel;
}


- (instancetype) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingAssumeInside;
        NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:NULL];
        [self addTrackingArea:trackingArea];
        
        _titleLabel = [NSTextField labelWithString:@""];
        [self addSubview:_titleLabel];
    }
    
    return self;
}


- (void) layout
{
    [super layout];
    
    NSRect bounds = [self bounds];
    
    NSRect titleLabelFrame = bounds;
    
    CGFloat titleX = 46.0;
    titleLabelFrame.origin.x += titleX;
    titleLabelFrame.size.width -= titleX;

    [_titleLabel setFrame:titleLabelFrame];

    [_titleLabel sizeToFit];
    
    titleLabelFrame = [_titleLabel frame];
    titleLabelFrame.origin.y = (bounds.size.height - titleLabelFrame.size.height) / 2.0;
    [_titleLabel setFrame:titleLabelFrame];
}


- (void) mouseEntered:(NSEvent *)event
{
    _isHighlighted = YES;
    [self setNeedsDisplay:YES];
}


- (void) mouseExited:(NSEvent *)event
{
    _isHighlighted = NO;
    [self setNeedsDisplay:YES];
}


- (void) mouseUp:(NSEvent *)event
{
    if (_isHighlighted) {
        [self sendAction:[self action] to:[self target]];
    }
}


- (void) drawRect:(NSRect)dirtyRect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];

    NSRect bounds = [self bounds];

    BOOL isHighlighted = _isHighlighted;
    BOOL isSelected = [self isSelected];
    BOOL mouseDown = [NSEvent pressedMouseButtons] & 1;

    // Draw highlight
    if (isHighlighted) {
        NSRect highlightRect = NSInsetRect(bounds, 5.0, 0);

        [[NSColor colorNamed:@"HighlightColor"] set];
        [[NSBezierPath bezierPathWithRoundedRect:highlightRect xRadius:4 yRadius:4] fill];
    }
    
    // Draw circle
    {
        CGFloat diameter = 26.0;

        NSRect circleRect = NSMakeRect(
            5.0 + 9.0,
            (bounds.size.height - diameter) / 2,
            diameter, diameter
        );

        NSColor *circleBackgroundColor;
        NSColor *circleForegroundColor;

        if (isSelected) {
            circleBackgroundColor = [NSColor colorNamed:@"CircleBackgroundSelected"];
            circleForegroundColor = [NSColor colorNamed:@"CircleForegroundSelected"];
        } else {
            circleBackgroundColor = [NSColor colorNamed:@"CircleBackground"];
            circleForegroundColor = [NSColor colorNamed:@"CircleForeground"];
        }

        CGContextSaveGState(context);
        
        [circleBackgroundColor set];
        [[NSBezierPath bezierPathWithOvalInRect:circleRect] addClip];

        CGContextFillRect(context, circleRect);

        if (isHighlighted && mouseDown) {
            [[NSColor colorNamed:@"CircleActivationBlend"] set];
            CGContextFillRect(context, circleRect);
        }

        CGContextRestoreGState(context);
        
        [circleForegroundColor set];
        
        CGContextBeginTransparencyLayer(context, NULL);
        
        [[NSColor blackColor] set];
        [[self _symbolImage] drawInRect:[self _symbolRectWithCircleRect:circleRect]];
        
        [circleForegroundColor set];
        NSRectFillUsingOperation(circleRect, NSCompositingOperationSourceIn);

        CGContextEndTransparencyLayer(context);
    }
}


- (NSRect) _symbolRectWithCircleRect:(NSRect)circleRect
{
    NSImage *symbolImage = [self _symbolImage];
    if (!symbolImage) return NSZeroRect;

    NSSize size = [symbolImage size];
    
    return NSMakeRect(
        circleRect.origin.x + ((circleRect.size.width  - size.width)   / 2.0),
        circleRect.origin.y + ((circleRect.size.height - size.height ) / 2.0),
        size.width,
        size.height
    );
}


- (NSImage *) _symbolImage
{
    if (!_symbolImage && _symbol) {
        NSString *overrideName = [NSString stringWithFormat:@"SymbolOverride_%@", _symbol];
        NSImage *overrideImage = [NSImage imageNamed:overrideName];
        
        if (overrideImage) {
            _symbolImage = overrideImage;

        } else {
            NSImage *image = [NSImage imageWithSystemSymbolName:_symbol accessibilityDescription:nil];
            
            NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
            image = [image imageWithSymbolConfiguration:configuration]; 
            
            [image setTemplate:YES];

            _symbolImage = image;
        }
    }
    
    return _symbolImage;
}


#pragma mark - Accessors

- (void) setTitle:(NSString *)title
{
    if (_title != title) {
        _title = title;
        [_titleLabel setStringValue:(title ? title : @"")];
        [self setNeedsLayout:YES];
        [self setNeedsDisplay:YES];
    }
}


- (void) setSymbol:(NSString *)symbol
{
    if (_symbol != symbol) {
        _symbol = symbol;
        _symbolImage = nil;
        [self setNeedsDisplay:YES];
    }
}


- (void) setSelected:(BOOL)selected
{
    if (_selected != selected) {
        _selected = selected;
        [self setNeedsDisplay:YES];
    }
}

@end
