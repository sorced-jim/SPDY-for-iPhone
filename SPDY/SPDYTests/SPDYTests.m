//
//  SPDYTests.m
//  SPDYTests
//
//  Created by Jim Morrison on 2/9/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SPDYTests.h"
#import "SPDY.h"

@interface CountError : RequestCallback {
    CFErrorRef error;
}
@property BOOL onErrorCalled;
@property (assign) CFErrorRef error;
@end

@implementation CountError
@synthesize onErrorCalled;
@synthesize error;

-(void)onError:(CFErrorRef)e {
    error = e;
    CFRetain(error);
    self.onErrorCalled = YES;
}

- (void)dealloc {
    CFRelease(error);
    [super dealloc];
}
@end

@implementation SPDYTests

- (void)testFetchNoHost {
    CountError *count = [[[CountError alloc]init]autorelease];
    SPDY *spdy = [[[SPDY alloc]init] autorelease];
    [spdy fetch:@"go" delegate:count];
    STAssertTrue(count.onErrorCalled, @"onError was called.");
    STAssertEquals(kCFErrorDomainCFNetwork, CFErrorGetDomain(count.error), @"CFNetwork error domain");
    STAssertEquals((CFIndex)kCFHostErrorHostNotFound, CFErrorGetCode(count.error), @"Host not found error.");
}

@end
