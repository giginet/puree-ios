#import "PURDeserializer.h"

@implementation PURDeserializer

+ (YapDatabaseDeserializer)failableYapDeserializer
{
    return ^id _Nonnull(NSString * _Nonnull collection, NSString * _Nonnull key, NSData * _Nonnull data) {
        if (data && data.length > 0) {
            @try {
                [NSKeyedUnarchiver unarchiveObjectWithData:data];
            }
            @catch (NSException *exception) {
                return nil;
            }
        }
        return nil;
    };
}

+ (instancetype)defaultDeserializer
{
    return [[self alloc] initWithObjectDeserializer:[YapDatabase defaultDeserializer]
                               metadataDeserializer:[YapDatabase defaultDeserializer]];
}

+ (instancetype)failableDeserializer
{
    return [[self alloc] initWithObjectDeserializer:self.failableYapDeserializer
                               metadataDeserializer:self.failableYapDeserializer];
}

- (instancetype)initWithObjectDeserializer:(YapDatabaseDeserializer)objectDeserializer
                      metadataDeserializer:(YapDatabaseDeserializer)metadataDeserializer
{
    self = [super init];
    _objectDeserializer = objectDeserializer;
    _metadataDeserializer = metadataDeserializer;
    return self;
}

@end
