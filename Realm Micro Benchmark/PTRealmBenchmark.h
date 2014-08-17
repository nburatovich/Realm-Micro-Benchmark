//  Created by Nick Buratovich on 8/15/14.
//  Copyright (c) 2014 Nick Buratovich. All rights reserved.


#import <Foundation/Foundation.h>


typedef NS_OPTIONS(NSUInteger, PTBenchmark) {
    PTBenchmarkAdd           = 1 << 0,
    PTBenchmarkModify        = 1 << 1,
    PTBenchmarkRemove        = 1 << 2,
    PTBenchmarkQuery         = 1 << 3,
    PTBenchmarkQueryComplex  = 1 << 4
};


@interface PTRealmBenchmark : NSObject

@property (assign) BOOL useInMemoryStore;
@property (assign) BOOL autorefresh;
@property (assign) BOOL clearAllDataBeforeBenchmark;

- (NSString *)logBenchmark:(PTBenchmark)benchmark forIterations:(NSUInteger)count;

@end
