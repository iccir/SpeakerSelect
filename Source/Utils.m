// (c) 2024 Ricci Adams
// MIT License / 1-clause BSD License

#import "Utils.h"

static void (^sLogger)(NSString *);

void Log(NSString *format, ...)
{
    if (!sLogger) return;

    va_list v;

    va_start(v, format);

    NSString *contents = [[NSString alloc] initWithFormat:format arguments:v];
    if (sLogger) sLogger(contents);
    
    va_end(v);
}


static OSStatus sGroupError = noErr;



extern NSString *GetStringForFourCharCode(OSStatus fcc)
{
    char str[20] = {0};

    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(*(UInt32 *)&fcc);

    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else {
        return [NSString stringWithFormat:@"%ld", (long)fcc];
    }
    
    return [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
}


BOOL CheckError(OSStatus error, NSString *operation)
{
    if (error == noErr) {
        return YES;
    }

    if (sGroupError != noErr) {
        sGroupError = error;
    }

    if (sLogger) {
        sLogger([NSString stringWithFormat:@"Error: %@ (%@)",
            operation,
            GetStringForFourCharCode(error)
        ]);
    }

    return NO;
}


NSString *FindOrCreateDirectory(
    NSSearchPathDirectory searchPathDirectory,
    NSSearchPathDomainMask domainMask,
    NSString *appendComponent,
    NSError **outError
) {
    NSArray* paths = NSSearchPathForDirectoriesInDomains(searchPathDirectory, domainMask, YES);
    if (![paths count]) return nil;

    NSString *resolvedPath = [paths firstObject];
    if (appendComponent) {
        resolvedPath = [resolvedPath stringByAppendingPathComponent:appendComponent];
    }

    NSError *error;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:resolvedPath withIntermediateDirectories:YES attributes:nil error:&error];

    if (!success) {
        if (outError) *outError = error;
        return nil;
    }

    if (outError) *outError = nil;

    return resolvedPath;
}


NSString *GetApplicationSupportDirectory(void)
{
    NSString *name = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
    return FindOrCreateDirectory(NSApplicationSupportDirectory, NSUserDomainMask, name, NULL);
}


static inline CGFLOAT_TYPE ScaleRound(CGFLOAT_TYPE x, CGFLOAT_TYPE scaleFactor)
{
    return round(x * scaleFactor) / scaleFactor;
}


NSRect GetCenteredRect(NSRect containerRect, NSSize inSize, CGFloat targetHeight, CGFloat scaleFactor)
{
    CGFloat targetWidth = ScaleRound((inSize.width / inSize.height) * targetHeight, scaleFactor);

    CGFloat offsetX = ScaleRound((containerRect.size.width  - targetWidth)  / 2.0, scaleFactor);
    CGFloat offsetY = ScaleRound((containerRect.size.height - targetHeight) / 2.0, scaleFactor);

    return NSMakeRect(
        containerRect.origin.x + offsetX,
        containerRect.origin.y + offsetY,
        targetWidth,
        targetHeight
    );
}

