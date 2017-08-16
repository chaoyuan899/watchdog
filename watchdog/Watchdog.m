//
//  Watchdog.m
//  watchdog
//
//  Created by aaron on 2017/8/16.
//  Copyright © 2017年 aaron. All rights reserved.
//

#import "Watchdog.h"
#import "BSBacktraceLogger.h"

#define defaultThreshold 0.4

@interface Watchdog()
@property(nonatomic,strong)PingThread *pingThread;
@end

@implementation Watchdog

+(void)load {
    [Watchdog start];
}

+ (instancetype)sharedInstance {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

+(void)start {
    Watchdog *watchdog = [Watchdog sharedInstance];
    watchdog.pingThread = [[PingThread alloc] initWithThreshold:defaultThreshold handle:^{
//        NSLog(@"👮 Main thread was blocked for %f s 👮",defaultThreshold);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            BSLOG_MAIN // 打印主线程调用栈， BSLOG 打印当前线程，BSLOG_ALL 打印所有线程
            // 调用 [BSBacktraceLogger bs_backtraceOfCurrentThread] 这一系列的方法可以获取字符串，然后选择上传服务器或者其他处理。
        });
    }];
    [watchdog.pingThread start];
}

+(void)stop {
    Watchdog *watchdog = [Watchdog sharedInstance];
    [watchdog.pingThread cancel];
}
@end



@interface PingThread()
@property(nonatomic,assign)BOOL pingTaskIsRunning;
@property(nonatomic,strong)dispatch_semaphore_t semaphore;
@property(nonatomic,assign)NSTimeInterval threshold;
@property(nonatomic,strong)PingThreadHandle handle;
@end
@implementation PingThread
-(instancetype)initWithThreshold:(double)threshold handle:(PingThreadHandle)handle {
    if (self == [super init]) {
        self.pingTaskIsRunning = false;
        self.semaphore = dispatch_semaphore_create(0);
        self.threshold = threshold;
        self.handle = handle;
    }
    return self;
}

-(void)main {
    while (!self.isCancelled) {
        self.pingTaskIsRunning = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.pingTaskIsRunning = false;
            dispatch_semaphore_signal(self.semaphore);
        });
        
        [NSThread sleepForTimeInterval:self.threshold];
        if (self.pingTaskIsRunning) {
            self.handle();
        }
        
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    }
}
@end
