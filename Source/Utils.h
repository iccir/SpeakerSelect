// (c) 2024 Ricci Adams
// MIT License / 1-clause BSD License

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#ifdef __cplusplus
extern "C" {
#endif

extern NSString *GetStringForFourCharCode(OSStatus fcc);

extern void Log(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

extern BOOL CheckError(OSStatus error, NSString *operation);

extern NSString *FindOrCreateDirectory(
    NSSearchPathDirectory searchPathDirectory,
    NSSearchPathDomainMask domainMask,
    NSString *appendComponent,
    NSError **outError
);

extern NSString *GetApplicationSupportDirectory(void);

NSRect GetCenteredRect(NSRect containerRect, NSSize inSize, CGFloat targetHeight, CGFloat scale);


#ifdef __cplusplus
}
#endif

