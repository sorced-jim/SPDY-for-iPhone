//
//  SpdySessionTests.m
//  Tests for spdy session code.
//
//  Created by Jim Morrison on 2/20/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SpdySessionTests.h"
#import "SpdySession.h"
#import "SPDY.h"

@interface SpdySessionTestDelegate : RequestCallback
@property (retain) NSError *error;
@end

@implementation SpdySessionTestDelegate
@synthesize error = _error;

- (void)dealloc {
    [_error release];
    [super dealloc];
}

- (void)onConnect:(id<SpdyRequestIdentifier>)identifier {
    NSLog(@"connected");
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)onError:(NSError *)error {
    NSLog(@"Got error: %@", error);
    self.error = error;
    CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopCommonModes, ^{ CFRunLoopStop(CFRunLoopGetCurrent()); });
}
@end

@implementation SpdySessionTests

- (void)testReleaseWithNoConnection {
    SpdySession *session = [[SpdySession alloc] init];
    [session release];
}

- (void)testRetainCount {
    SpdySession *session = [[SpdySession alloc] init];
    NSError *error = [session connect:[NSURL URLWithString:@"https://localhost:9793/123-123"]];
    STAssertNil(error, @"Error: %@", error);
    [session addToLoop];
    SpdySessionTestDelegate *delegate = [[[SpdySessionTestDelegate alloc] init] autorelease];
    @autoreleasepool {
        [session fetch:[NSURL URLWithString:@"https://localhost:9793/"] delegate:delegate];
    }
    NSLog(@"running loop");
    CFRunLoopRun();
    STAssertEquals([session retainCount], 2U, @"The one stream has a reference.");
    [session resetStreamsAndGoAway];
    NSLog(@"Runing lop.");
    CFRunLoopRun();
    STAssertNotNil(delegate.error, @"");
    STAssertEquals(delegate.error.domain, kSpdyErrorDomain, @"");
    STAssertEquals(delegate.error.code, kSpdyRequestCancelled, @"");
    STAssertEquals([session retainCount], 1U, @"Session would be closed if we didn't have a reference.");
    [session release];
}

@end
