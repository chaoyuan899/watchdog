//
//  Watchdog.h
//  watchdog
//
//  Created by aaron on 2017/8/16.
//  Copyright © 2017年 aaron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface Watchdog : NSObject
+ (instancetype)sharedInstance;
+(void)start;
+(void)stop;
@end


typedef void(^PingThreadHandle)(void);
@interface PingThread: NSThread
-(instancetype)initWithThreshold:(NSTimeInterval)threshold handle:(PingThreadHandle)handle;
@end



@interface Watchdog(CPU)
- (float)cpu;
@end



@interface Watchdog(Memory)
- (float)memory;
@end


typedef void (^TickOutput)(float value);
@interface Watchdog(FPS)
- (void)fps:(TickOutput)output;
@end
