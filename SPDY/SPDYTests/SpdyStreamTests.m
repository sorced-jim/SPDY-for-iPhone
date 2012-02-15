//
//  SpdyStreamTests.m
//  SPDY
//
//  Created by Jim Morrison on 2/15/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SpdyStreamTests.h"

#import "SpdyStream.h"
#import "SPDY.h"

@interface Callback : RequestCallback {
    BOOL closeCalled;
}
@property BOOL closeCalled;
@end


@implementation Callback

- (void)onStreamClose {
    self.closeCalled = YES;
}
@synthesize closeCalled;

@end

@implementation SpdyStreamTests {
    Callback* delegate;
    NSURL* url;
    SpdyStream* stream;
}

- (void)setUp {
    url = [NSURL URLWithString:@"http://example.com/bar;foo?q=123&q=bar&j=3"];
    delegate = [[Callback alloc]init];
    stream = [SpdyStream createFromNSURL:url delegate:delegate];
}

- (void)tearDown {
    [stream release];
    [delegate release];
    [url release];
}

// All code under test must be linked into the Unit Test bundle
- (void)testCloseStream
{
    [stream closeStream];
    STAssertTrue(delegate.closeCalled, @"Compiler isn't feeling well today :-(");
}

@end
