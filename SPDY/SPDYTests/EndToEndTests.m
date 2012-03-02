//
//  EndToEndTests.m
//  SPDY end to end tests using spdyd from spdylay.
//
//  Created by Jim Morrison on 3/1/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "EndToEndTests.h"
#import "SPDY.h"

static const int port = 9783;

@interface E2ECallback : RequestCallback {
    BOOL closeCalled;
    BOOL skipTests;
}
@property (assign) BOOL closeCalled;
@property (assign) CFHTTPMessageRef responseHeaders;
@property (assign) BOOL skipTests;
@end


@implementation E2ECallback

- (void)dealloc {
    CFRelease(self.responseHeaders);
}

- (void)onStreamClose {
    self.closeCalled = YES;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)onConnect:(NSURL *)url {
    NSLog(@"Connected to %@", url);
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    self.responseHeaders = (CFHTTPMessageRef)CFRetain(headers);
}

- (void)onError:(CFErrorRef)error {
    if (CFEqual(CFErrorGetDomain(error), kCFErrorDomainPOSIX) && CFErrorGetCode(error) == ECONNREFUSED) {
        // Running the tests through xcode doesn't actually use the run script, so ignore failures where the server can't be contacted.
        self.skipTests = YES;
    }
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)onNotSpdyError {
    CFRunLoopStop(CFRunLoopGetCurrent());
    NSLog(@"Not connecting to a spdy server.");
}

@synthesize closeCalled;
@synthesize responseHeaders;
@synthesize skipTests;

@end


@implementation EndToEndTests


// All code under test must be linked into the Unit Test bundle
- (void)testSimpleFetch {
    E2ECallback *delegate = [[[E2ECallback alloc]init] autorelease];
    [[SPDY sharedSPDY]fetch:@"http://localhost:9793/" delegate:delegate];
    CFRunLoopRun();
    if (delegate.skipTests) {
        return;
    }
    STAssertTrue(delegate.closeCalled, @"Run loop finished as expected.");
}

@end
