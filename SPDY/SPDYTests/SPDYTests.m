//
//  SPDYTests.m
//  SPDYTests
//
//  Created by Jim Morrison on 2/9/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SPDYTests.h"
#import "SPDY.h"

@interface CountError : RequestCallback;
    @property BOOL onErrorCalled;
@end

@implementation CountError
@synthesize onErrorCalled;

-(void)onError {
    self.onErrorCalled = YES;
}
@end

@implementation SPDYTests

- (void)testFetchNoHost {
    CountError* count = [[[CountError alloc]init]autorelease];
    SPDY* spdy = [[[SPDY alloc]init] autorelease];
    [spdy fetch:@"go" delegate:count];
    STAssertTrue(count.onErrorCalled, @"onError was called.");
}

@end
