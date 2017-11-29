#import <Foundation/Foundation.h>
#import <YapDatabase/YapDatabase.h>

NS_ASSUME_NONNULL_BEGIN

@interface PURDeserializer : NSObject

@property (nonatomic) YapDatabaseDeserializer objectDeserializer;
@property (nonatomic) YapDatabaseDeserializer metadataDeserializer;

+ (instancetype)defaultDeserializer;
+ (instancetype)failableDeserializer;

- (instancetype)initWithObjectDeserializer:(YapDatabaseDeserializer)objectDeserializer
                      metadataDeserializer:(YapDatabaseDeserializer)metadataDeserializer;

@end

NS_ASSUME_NONNULL_END
