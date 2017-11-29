#import <YapDatabase/YapDatabase.h>
#import "PURDeserializer.h"
#import "PURLogStore.h"
#import "PURLog.h"
#import "PUROutput.h"

static NSString * const LogDatabaseDirectory = @"com.cookpad.PureeData.default";
static NSString * const LogDatabaseFileName = @"logs.db";
static NSString * const LogDataCollectionNamePrefix = @"log_";

static NSMutableDictionary<NSString *, YapDatabase *> *__databases;

NS_ASSUME_NONNULL_BEGIN

@interface PURLogStore ()

@property (nonatomic) NSString *databasePath;
@property (nonatomic) YapDatabaseConnection *databaseConnection;

@end

NS_ASSUME_NONNULL_END

static NSString *PURLogStoreCollectionNameForPattern(NSString *pattern)
{
    return [LogDataCollectionNamePrefix stringByAppendingString:pattern];
}

static NSString *PURLogKey(PUROutput *output, PURLog *log)
{
    return [[NSStringFromClass([output class]) stringByAppendingString:@"_"] stringByAppendingString:log.identifier];
}

@implementation PURLogStore

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __databases = [NSMutableDictionary new];
    });
}

+ (instancetype)defaultLogStore
{
    return [[self alloc] initWithDatabasePath:[self defaultDatabasePath]];
}

- (instancetype)initWithDatabasePath:(NSString *)databasePath
{
    return [self initWithDatabasePath:databasePath deserializer:[PURDeserializer defaultDeserializer]];
}

- (instancetype)initWithDatabasePath:(NSString *)databasePath deserializer:(PURDeserializer *)deserializer
{
    self = [super init];
    if (self) {
        _databasePath = databasePath;
        _deserializer = deserializer;
    }
    return self;

}

- (BOOL)prepare
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *databaseDirectory = [self.databasePath stringByDeletingLastPathComponent];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:databaseDirectory isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:databaseDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
        if (error) {
            return NO;
        }
    } else if (!isDirectory) {
        return NO;
    }

    YapDatabase *database = __databases[self.databasePath];
    if (!database) {
        database = [[YapDatabase alloc] initWithPath:self.databasePath
                                    objectSerializer:nil
                                  objectDeserializer:self.deserializer.objectDeserializer
                                  metadataSerializer:nil
                                metadataDeserializer:self.deserializer.metadataDeserializer
                                             options:nil];
        __databases[self.databasePath] = database;
    }
    if (self.databaseConnection.database != database) {
        self.databaseConnection = [database newConnection];
    }
    return YES;
}

+ (NSString *)defaultDatabasePath
{
    NSArray *libraryCachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *libraryCacheDirectoryPath = libraryCachePaths.firstObject;
    NSString *filePath = [LogDatabaseDirectory stringByAppendingPathComponent:LogDatabaseFileName];
    NSString *databasePath = [libraryCacheDirectoryPath stringByAppendingPathComponent:filePath];

    return databasePath;
}

- (void)retrieveLogsForOutput:(PUROutput *)output completion:(PURLogStoreRetrieveCompletionBlock)completion;
{
    NSAssert(self.databaseConnection, @"Database connection is not available");

    NSMutableArray<PURLog *> *logs = [NSMutableArray new];
    [self.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction){
        NSString *keyPrefix = [NSStringFromClass([output class]) stringByAppendingString:@"_"];
        [transaction enumerateRowsInCollection:PURLogStoreCollectionNameForPattern(output.tagPattern)
                                    usingBlock:^(NSString *key, PURLog *log, id metadata, BOOL *stop){
                                        if (log != nil) {
                                            [logs addObject:log];
                                        }
                                    }
                                    withFilter:^BOOL(NSString *key){
                                        return [key hasPrefix:keyPrefix];
                                    }];
    }
                                completionBlock:^{
                                    completion(logs);
                                }];
}

- (void)addLog:(PURLog *)log forOutput:(PUROutput *)output completion:(nullable dispatch_block_t)completion
{
    NSAssert(self.databaseConnection, @"Database connection is not available");

    [self addLogs:@[ log ] forOutput:output completion:completion];
}

- (void)addLogs:(NSArray<PURLog *> *)logs forOutput:(PUROutput *)output completion:(nullable dispatch_block_t)completion
{
    NSAssert(self.databaseConnection, @"Database connection is not available");

    [self.databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
        NSString *collectionName = PURLogStoreCollectionNameForPattern(output.tagPattern);
        for (PURLog *log in logs) {
            [transaction setObject:log forKey:PURLogKey(output, log) inCollection:collectionName];
        }
    }
                                     completionBlock:completion];
}

- (void)removeLogs:(NSArray<PURLog *> *)logs forOutput:(PUROutput *)output completion:(nullable dispatch_block_t)completion
{
    NSAssert(self.databaseConnection, @"Database connection is not available");

    [self.databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
        NSString *collectionName = PURLogStoreCollectionNameForPattern(output.tagPattern);
        for (PURLog *log in logs) {
            [transaction removeObjectForKey:PURLogKey(output, log) inCollection:collectionName];
        }
    }
                                     completionBlock:completion];
}

- (void)clearAll
{
    NSAssert(self.databaseConnection, @"Database connection is not available");

    [self.databaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
        [transaction removeAllObjectsInAllCollections];
    }];
}

@end
