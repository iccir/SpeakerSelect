// (c) 2011-2024 Ricci Adams
// MIT License / 1-clause BSD License

#import "JSONTypechecker.h"

NSString * const JSONTypeArray       = @"array";
NSString * const JSONTypeDictionary  = @"dictionary";
NSString * const JSONTypeNumber      = @"number";
NSString * const JSONTypeString      = @"string";
NSString * const JSONTypeNull        = @"null";

NSString *JSONTypecheckerErrorDomain = @"JSONTypecheckerErrorDomain";


@implementation JSONTypechecker {
    NSMutableString *_currentPath;
    NSDictionary *_typeMap;
    NSError *_error;
}

- (instancetype) initWithTypeMap:(NSDictionary<NSString *, NSString *> *)typeMap
{
    if ((self = [super init])) {
        _typeMap = typeMap;
    }
    
    return self;
}


- (NSError *) _visitArray:(NSArray *)array
{
    NSError *error = nil;
    NSRange range = NSMakeRange([_currentPath length], 2);

    [_currentPath appendString:@"[]"];
    
    NSString *expectedType = [_typeMap objectForKey:_currentPath];
    
    for (id inObject in array) {
        error = [self _visitObject:inObject expectedType:expectedType];
        if (error) break;
    }
    
    [_currentPath deleteCharactersInRange:range];
    
    return error;
}


- (NSError *) _visitDictionary:(NSDictionary *)dictionary
{
    NSError *error = nil;
    BOOL handledAsWildcard = NO;

    // Check for wildcard in type map
    {
        NSRange range = NSMakeRange([_currentPath length], 2);
        
        [_currentPath appendString:@".*"];
        NSString *expectedType = [_typeMap objectForKey:_currentPath];

        if (expectedType) {
            handledAsWildcard = YES;

            for (id object in [dictionary objectEnumerator]) {
                error = [self _visitObject:object expectedType:expectedType];
                if (error) break;
            }
        }
        
        [_currentPath deleteCharactersInRange:range];
    }
    
    if (!handledAsWildcard) {
        for (NSString *key in [dictionary keyEnumerator]) {
            id object = [dictionary objectForKey:key];
            
            NSRange range = NSMakeRange([_currentPath length], 1 + [key length]);
            [_currentPath appendFormat:@".%@", key];

            NSString *expectedType = [_typeMap objectForKey:_currentPath];

            error = [self _visitObject:object expectedType:expectedType];
            if (error) break;

            [_currentPath deleteCharactersInRange:range];
        }
    }
    
    return error;
}


- (NSError *) _visitObject:(id)inObject expectedType:(NSString *)expectedType
{
    NSString *actualType = nil;

    if      ([inObject isKindOfClass:[NSArray      class]]) actualType = JSONTypeArray;
    else if ([inObject isKindOfClass:[NSDictionary class]]) actualType = JSONTypeDictionary;
    else if ([inObject isKindOfClass:[NSString     class]]) actualType = JSONTypeString;
    else if ([inObject isKindOfClass:[NSNumber     class]]) actualType = JSONTypeNumber;
    else if ([inObject isKindOfClass:[NSNull       class]]) actualType = JSONTypeNull;

    if (!expectedType) {
        NSString *description = [NSString stringWithFormat:@"Unknown path: %@", _currentPath];

        return [NSError errorWithDomain:JSONTypecheckerErrorDomain code:JSONTypecheckerUnknownPathError userInfo:@{
            NSLocalizedDescriptionKey: description
        }];
        
    } else if (!actualType) {
        NSString *description = [NSString stringWithFormat:@"Unknown type %@. Path: %@", NSStringFromClass(inObject), _currentPath];

        return [NSError errorWithDomain:JSONTypecheckerErrorDomain code:JSONTypecheckerUnknownTypeError userInfo:@{
            NSLocalizedDescriptionKey: description
        }];

    } else if (![actualType isEqualToString:expectedType]) {
        NSString *description = [NSString stringWithFormat:@"Expected %@, found %@. Path: %@", expectedType, actualType, _currentPath];

        return [NSError errorWithDomain:JSONTypecheckerErrorDomain code:JSONTypecheckerWrongTypeError userInfo:@{
            NSLocalizedDescriptionKey: description
        }];

    } else if ([actualType isEqualToString:JSONTypeArray]) {
        return [self _visitArray:inObject];
    
    } else if ([actualType isEqualToString:JSONTypeDictionary]) {
        return [self _visitDictionary:inObject];

    } else {
        return nil;
    }
}


- (void) typecheckObject:(id)inObject error:(NSError **)outError
{
    _currentPath = [NSMutableString stringWithString:@"$"];

    NSError *error = [self _visitObject:inObject expectedType:[_typeMap objectForKey:_currentPath]];
    _currentPath = nil;

    if (outError) *outError = error;
}


@end

