//
//  Watchdog.h
//  watchdog
//
//  Created by aaron on 2017/8/16.
//  Copyright © 2017年 aaron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Watchdog : NSObject
+(void)start;
+(void)stop;
@end


typedef void(^PingThreadHandle)(void);
@interface PingThread: NSThread
-(instancetype)initWithThreshold:(NSTimeInterval)threshold handle:(PingThreadHandle)handle;
@end
