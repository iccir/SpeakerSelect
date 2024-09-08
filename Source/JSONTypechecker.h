// (c) 2011-2024 Ricci Adams
// MIT License / 1-clause BSD License

@import Foundation;

extern NSString * const JSONTypeArray;
extern NSString * const JSONTypeDictionary;
extern NSString * const JSONTypeNumber; // Also includes 'true' and 'false'
extern NSString * const JSONTypeString;

extern NSString *JSONTypecheckerErrorDomain;

typedef NS_ENUM(NSInteger, JSONTypecheckerErrorCode) {
    JSONTypecheckerUnknownPathError = 1,
    JSONTypecheckerWrongTypeError   = 2,
    JSONTypecheckerUnknownTypeError = 3
};

@interface JSONTypechecker : NSObject

- (instancetype) initWithTypeMap:(NSDictionary<NSString *, NSString *> *)typeMap;

- (void) typecheckObject:(id)inObject error:(NSError **)outError;

@end

