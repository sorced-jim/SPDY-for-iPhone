//
//  SPDYTests.m
//  SPDYTests
//
//  Created by Jim Morrison on 2/9/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SPDYTests.h"
#import "SPDY.h"

@interface CountError : RequestCallback
@property BOOL onErrorCalled;
@property (retain) NSError *error;
@end

@implementation CountError
@synthesize onErrorCalled;
@synthesize error = _error;

-(void)onError:(NSError *)error {
    self.error = error;
    self.onErrorCalled = YES;
}

- (void)dealloc {
    [_error release];
    [super dealloc];
}
@end

@implementation SPDYTests

- (void)testFetchNoHost {
    CountError *count = [[[CountError alloc] init] autorelease];
    SPDY *spdy = [[[SPDY alloc] init] autorelease];
    [spdy fetch:@"go" delegate:count];
    STAssertTrue(count.onErrorCalled, @"onError was called.");
    STAssertEquals((NSString *)kCFErrorDomainCFNetwork, count.error.domain, @"CFNetwork error domain");
    STAssertEquals((NSInteger)kCFHostErrorHostNotFound, count.error.code, @"Host not found error.");
}

@end
