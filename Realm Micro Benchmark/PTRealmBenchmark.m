//  Created by Nick Buratovich on 8/15/14.
//  Copyright (c) 2014 Nick Buratovich. All rights reserved.


#import "PTRealmBenchmark.h"
#import <Realm/Realm.h>


// realm.autorefresh = NO on the defaultRealm, as of 0.83, seems to just turn itself back on every run.  set IS_AUTOREFRESH_BUG_FIXED to 1 when fixed.
#define IS_AUTOREFRESH_BUG_FIXED 0


@interface PTRealmBenchmark ()

- (NSTimeInterval)_logTimeForBlock:(void (^)(void))block;

@end


@interface MicroObject : RLMObject

@property NSInteger identifier;
@property double x;
@property double y;
@property NSString *title;

+ (NSArray *)locationArrayWithCount:(NSUInteger)count;

@end

@implementation MicroObject

+ (NSArray *)locationArrayWithCount:(NSUInteger)count
{
    NSMutableArray *array = [NSMutableArray new];
    for (NSUInteger i = 0; i < count; i++) {
        MicroObject *location = [MicroObject new];
        location.identifier = i;
        location.x = drand48();
        location.y = drand48();
        location.title = @"My Title"; // [NSUUID UUID].UUIDString;
        
        [array addObject:location];
    }
    return (array.count > 0) ? array : nil;
}

@end


@implementation PTRealmBenchmark

- (NSString *)logBenchmark:(PTBenchmark)benchmark forIterations:(NSUInteger)count
{
    if ((benchmark == 0)  ||  (count == 0)) {
        return nil;
    }
    
    
    __block NSMutableString *result = [NSMutableString new];
    
    // perform first-time configurations and logs
    __block BOOL firstTimeRun = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        firstTimeRun = YES;
        
        srand48(time(0));
        
        if (self.useInMemoryStore) {
            [RLMRealm useInMemoryDefaultRealm];
        }
        
        [result appendFormat:@"Realm path:  %@\n", [RLMRealm defaultRealmPath]];
        [result appendFormat:@"useInMemoryStore:  %@\n", self.useInMemoryStore ? @"YES" : @"NO"];
        #if !IS_AUTOREFRESH_BUG_FIXED
        [result appendFormat:@"autorefresh:  %@\n", [RLMRealm defaultRealm].autorefresh ? @"YES" : @"NO"];
        #endif
    });
    
    RLMRealm *realm = [RLMRealm defaultRealm];
    
    #if IS_AUTOREFRESH_BUG_FIXED
    // log configuration changes.  setting realm.autorefresh = NO doesn't matter.  it apparently always re-turns itself on when we go again.  see above.
    if ((realm.autorefresh != self.autorefresh)  ||  firstTimeRun) {
        realm.autorefresh = self.autorefresh;
        [result appendFormat:@"autorefresh:  %@\n", realm.autorefresh ? @"YES" : @"NO"];
    }
    #endif
    if (firstTimeRun) {
        [result appendFormat:@"\n"];
    }
    
    
    if (self.clearAllDataBeforeBenchmark) {
        [realm transactionWithBlock:^{
            [realm deleteObjects:[MicroObject allObjectsInRealm:realm]];
        }];
    }
    
    
    BOOL willModifyLocationCount = ((benchmark & PTBenchmarkAdd) || (benchmark & PTBenchmarkModify)  ||  (benchmark & PTBenchmarkRemove));
    
    if (willModifyLocationCount) {
        [result appendFormat:@"Before item count:  %lu\n", (unsigned long)[MicroObject allObjectsInRealm:realm].count];
    }
    
    if (benchmark & PTBenchmarkAdd) {
        NSArray *array = [MicroObject locationArrayWithCount:count];
        NSTimeInterval time = [self _logTimeForBlock:^{
            [realm transactionWithBlock:^{
                [realm addObjectsFromArray:array];
            }];
        }];
        [result appendFormat:@"  Time to add %lu items:  %f\n", (unsigned long)count, time];
    }
    
    RLMArray *locations = [MicroObject allObjectsInRealm:realm];
    NSUInteger locationCount = locations.count;
    
    if ((benchmark & PTBenchmarkModify)  ||  (benchmark & PTBenchmarkRemove)) {
        NSUInteger possibleObjectCount = MIN(locationCount, count);
        
        if (benchmark & PTBenchmarkModify) {
            NSTimeInterval time = [self _logTimeForBlock:^{
                [realm transactionWithBlock:^{
                    for (NSUInteger index = 0; index < possibleObjectCount; index++) {
                        MicroObject *location = locations[index];
                        location.identifier = location.identifier + 1;
                    }
                }];
            }];
            [result appendFormat:@"  Time to modify %lu items:  %f\n", (unsigned long)possibleObjectCount, time];
        }
        
        if (benchmark & PTBenchmarkRemove) {
            NSMutableArray *itemsToRemove = [NSMutableArray new];
            for (NSUInteger index = 0; index < possibleObjectCount; index++) {
                MicroObject *location = locations[index];
                [itemsToRemove addObject:location];
            }
            NSTimeInterval time = [self _logTimeForBlock:^{
                [realm transactionWithBlock:^{
                    [realm deleteObjects:itemsToRemove];
                }];
            }];
            [result appendFormat:@"  Time to remove %lu items:  %f\n", (unsigned long)possibleObjectCount, time];
        }
    }
    
    if (benchmark & PTBenchmarkQuery) {
        __block RLMArray *queryArray;
        NSTimeInterval time = [self _logTimeForBlock:^{
            queryArray = [MicroObject objectsInRealm:realm where:@"identifier <= %ld", arc4random_uniform((u_int32_t)locationCount)];
        }];
        [result appendFormat:@"  Time to run query returning %lu of %lu items:  %f\n", (unsigned long)queryArray.count, locationCount, time];
    }
    
    if (benchmark & PTBenchmarkQueryComplex) {
        __block RLMArray *queryArray;
        NSTimeInterval time = [self _logTimeForBlock:^{
            queryArray = [MicroObject objectsInRealm:realm where:@"((x <= %f) OR (y >= %f)) AND (title == %@)", 0.2, 0.8, @"My Title"];
        }];
        [result appendFormat:@"  Time to run complex query returning %lu of %lu items:  %f\n", (unsigned long)queryArray.count, locationCount, time];
    }
    
    if (willModifyLocationCount) {
        [result appendFormat:@" After item count:  %lu\n", (unsigned long)[MicroObject allObjectsInRealm:realm].count];
    }
    
    
    NSCharacterSet *charSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    result = [[result stringByTrimmingCharactersInSet:charSet] mutableCopy];
    
    if (!firstTimeRun) {
        [result insertString:@"\n" atIndex:0];
    }
    
    return result;
}

- (NSTimeInterval)_logTimeForBlock:(void (^)(void))block
{
    NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
    block();
    return [NSDate timeIntervalSinceReferenceDate] - time;
}

@end
