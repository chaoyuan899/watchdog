//
//  Watchdog.m
//  watchdog
//
//  Created by aaron on 2017/8/16.
//  Copyright © 2017年 aaron. All rights reserved.
//

#import "Watchdog.h"
#import "BSBacktraceLogger.h"
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <objc/runtime.h>


#define defaultThreshold 0.04
#define DEPTH 10

typedef NS_ENUM(NSUInteger,WATCH_LEVEL) {
    WATCH_LEVEL_LOG,
    WATCH_LEVEL_FILE
};

@interface Watchdog()
@property(nonatomic,strong)PingThread *pingThread;
@property(nonatomic,assign)WATCH_LEVEL level;
@property(nonatomic,strong)NSConditionLock *logFileLock;
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
    watchdog.level = WATCH_LEVEL_LOG;
    watchdog.logFileLock = [[NSConditionLock alloc] init];
    
    watchdog.pingThread = [[PingThread alloc] initWithThreshold:defaultThreshold handle:^{
        if (watchdog.level == WATCH_LEVEL_LOG) {
            [watchdog log];
        }else if (watchdog.level == WATCH_LEVEL_FILE) {
            [watchdog logToFile];
        }
    }];
    [watchdog.pingThread start];
}

+(void)stop {
    Watchdog *watchdog = [Watchdog sharedInstance];
    [watchdog.pingThread cancel];
}

-(void)log {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"cpu:%f",[self cpu]);
        NSLog(@"memory:%f",[self memory]);
        BSLOG_MAIN
    });
}

-(void)logToFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *logDir = [NSString stringWithFormat:@"%@/watchdog",[paths firstObject]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:logDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *currentDateStr = [dateFormatter stringFromDate:[NSDate date]];
    
    NSString *logFilePath = [NSString stringWithFormat:@"%@/%@",logDir,currentDateStr];
    NSLog(@"%@",logFilePath);
    
    NSError *error = nil;
    NSString *stackStr = [BSBacktraceLogger bs_backtraceOfAllThread];
    [[Watchdog sharedInstance].logFileLock lock];
    [stackStr writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"👮error happen:%@ 👮",error.description);
    }
    [[Watchdog sharedInstance].logFileLock unlock];
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





#pragma mark -- CPU
@implementation Watchdog(CPU)
#pragma mark -- CPU
//此算法是获取当前APP的CPU，数值与Instrument、GT接近
//https://github.com/TianJIANG/ios_monitor
- (float)cpu {
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    
    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;
    
    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;
    
    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads
    
    basic_info = (task_basic_info_t)tinfo;
    
    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;
    
    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    int j;
    
    for (j = 0; j < thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->system_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }
        
    } // for each thread
    
    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);
    
//    NSLog(@"CPU Usage: %f \n", tot_cpu);
    return tot_cpu;
}
@end





#pragma mark -- Memory
@implementation Watchdog(Memory)
//此算法是获取当前APP的内存，数值与GT的一致，与Instrument不一致
- (float)memory {
    task_basic_info_data_t taskInfo;
    mach_msg_type_number_t infoCount = TASK_BASIC_INFO_COUNT;
    kern_return_t kernReturn = task_info(mach_task_self(),
                                         TASK_BASIC_INFO, (task_info_t)&taskInfo, &infoCount);
    
    if(kernReturn != KERN_SUCCESS) {
        return -1;
    }
    
    float useMemory = taskInfo.resident_size / 1024.0 / 1024.0;
//    NSLog(@"Memory Usage: %f", useMemory);
    return useMemory;
}
@end




#pragma mark -- FPS
@implementation Watchdog(FPS)

- (CADisplayLink *)displayLink {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setDisplayLink:(CADisplayLink *)displayLink {
    objc_setAssociatedObject(self, @selector(displayLink), displayLink, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CFTimeInterval)lastTime {
    id time = objc_getAssociatedObject(self, _cmd);
    return [time doubleValue];
}

- (void)setLastTime:(CFTimeInterval)lastTime {
    objc_setAssociatedObject(self, @selector(lastTime), @(lastTime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(NSInteger)count {
    id count = objc_getAssociatedObject(self, _cmd);
    return [count integerValue];
}


-(void)setCount:(NSInteger)count {
    objc_setAssociatedObject(self, @selector(count), @(count), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (TickOutput)output {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setOutput:(TickOutput)output {
    objc_setAssociatedObject(self, @selector(output), output, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)linkTicks:(CADisplayLink *)link
{
    if (self.lastTime == 0) {
        self.lastTime = link.timestamp;
        return;
    }
    
    self.count++;
    NSTimeInterval delta = link.timestamp - self.lastTime;
    if (delta < 1) return;
    self.lastTime = link.timestamp;
    float fps = self.count / delta;
    self.count = 0;
    
    self.output(fps);
    
//    NSLog(@"fps:%f",fps);
}

- (void)fps:(TickOutput)output {
    self.output = output;
    
    self.count = 10;
    self.lastTime = 10.0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(linkTicks:)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)dealloc {
    [self.displayLink invalidate];
}
@end

