//
//  NSTimer+Control.m
//  AFSpritz-Demo
//
//  Created by Alvaro Franco on 3/18/14.
//  Copyright (c) 2014 AlvaroFranco. All rights reserved.
//

#import "NSTimer+Control.h"
#import <objc/runtime.h>

@implementation NSTimer (Control)

static NSString * const NSTimerPauseDate = @"NSTimerPauseDate";
static NSString *const NSTimerPreviousFireDate = @"NSTimerPreviousFireDate";

- (void)pauseTimer {
	objc_setAssociatedObject(self, (__bridge const void *)(NSTimerPauseDate), [NSDate date], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(self, (__bridge const void *)(NSTimerPreviousFireDate), self.fireDate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	self.fireDate = [NSDate distantFuture];
}

- (void)resumeTimer {
	NSDate *pauseDate = objc_getAssociatedObject(self, (__bridge const void *)NSTimerPauseDate);
	NSDate *previousFireDate = objc_getAssociatedObject(self, (__bridge const void *)NSTimerPreviousFireDate);

	const NSTimeInterval pauseTime = -[pauseDate timeIntervalSinceNow];
	self.fireDate = [NSDate dateWithTimeInterval:pauseTime sinceDate:previousFireDate];
}

@end
