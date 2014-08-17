//  Created by Nick Buratovich on 8/15/14.
//  Copyright (c) 2014 Nick Buratovich. All rights reserved.


#import "AppDelegate.h"
#import "PTRealmBenchmark.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSButton *inMemoryStoreButton;
@property (weak) IBOutlet NSButton *autorefreshButton;
@property (weak) IBOutlet NSTextField *iterationsField;
@property (strong) IBOutlet NSTextView *logTextView;

@property (strong) PTRealmBenchmark *benchmark;


- (IBAction)benchmarkAdd:(id)sender;
- (IBAction)benchmarkModify:(id)sender;
- (IBAction)benchmarkRemove:(id)sender;
- (IBAction)benchmarkAll:(id)sender;

- (IBAction)benchmarkQuery:(id)sender;
- (IBAction)benchmarkQueryComplex:(id)sender;

- (void)_logText:(NSString *)string;

@end


@implementation AppDelegate

+ (void)initialize
{
    if (self == [AppDelegate self]) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"objectCount" : @"10000"}];
    }
}

- (void)awakeFromNib
{
    self.benchmark = [PTRealmBenchmark new];
}

- (IBAction)benchmarkAdd:(id)sender
{
    [self _benchmarkFlags:PTBenchmarkAdd];
}
- (IBAction)benchmarkModify:(id)sender
{
    [self _benchmarkFlags:PTBenchmarkModify];
}
- (IBAction)benchmarkRemove:(id)sender
{
    [self _benchmarkFlags:PTBenchmarkRemove];
}
- (IBAction)benchmarkAll:(id)sender
{
    [self _benchmarkFlags:(PTBenchmarkAdd | PTBenchmarkModify | PTBenchmarkRemove)];
}

- (IBAction)benchmarkQuery:(id)sender
{
    [self _benchmarkFlags:PTBenchmarkQuery];
}
- (IBAction)benchmarkQueryComplex:(id)sender
{
    [self _benchmarkFlags:PTBenchmarkQueryComplex];
}


- (void)_benchmarkFlags:(PTBenchmark)benchmarkFlags
{
    // set configuration
    BOOL useInMemoryStore = (self.inMemoryStoreButton.state == NSOnState);
    self.benchmark.useInMemoryStore = useInMemoryStore;
    
    BOOL autorefresh = (self.autorefreshButton.state == NSOnState);
    self.benchmark.autorefresh = autorefresh;
    
    BOOL isOptionKeyDown = (([NSApp currentEvent].modifierFlags & NSAlternateKeyMask) == NSAlternateKeyMask);
    self.benchmark.clearAllDataBeforeBenchmark = isOptionKeyDown;
    
    // perform benchmarks
    NSUInteger iterations = (NSUInteger)self.iterationsField.integerValue;
    NSString *logString = [self.benchmark logBenchmark:benchmarkFlags forIterations:iterations];
    
    [self _logText:logString];
}

- (void)_logText:(NSString *)string
{
    NSString *returnSeparatedString = [NSString stringWithFormat:@"%@\n", string ?: @"Error"];
    NSDictionary *attributes = @{NSFontAttributeName : [NSFont fontWithName:@"Menlo" size:10.0]};
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:returnSeparatedString attributes:attributes];
    [self.logTextView.textStorage appendAttributedString:attributedString];
    
    [self.logTextView scrollRangeToVisible: NSMakeRange(self.logTextView.string.length, 0)];
}

@end
