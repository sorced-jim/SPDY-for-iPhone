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

static int countItems(const char** nv) {
    int count;
    for (count = 0; nv[count]; ++count) {
    }
    return count;
}

@implementation SpdyStreamTests {
    Callback* delegate;
    NSURL* url;
    SpdyStream* stream;
}

- (void)setUp {
    url = [NSURL URLWithString:@"http://example.com/bar;foo?q=123&q=bar&j=3"];
    delegate = [[Callback alloc]init];
}

- (void)tearDown {
    [stream release];
    [delegate release];
    [url release];
}

- (void)testNameValuePairs {
    stream = [SpdyStream createFromNSURL:url delegate:delegate];
    const char** nv = [stream nameValues];
    int items = countItems(nv);
    STAssertEquals(12, items, @"There should only be twelve pairs");
    STAssertEquals(0, items % 2, @"There must be an even number of pairs.");
    STAssertEquals(0, strcmp(nv[0], "method"), @"First value is not method");
    STAssertEquals(0, strcmp(nv[1], "GET"), @"A NSURL uses get");
    STAssertEquals(0, strcmp(nv[2], "scheme"), @"The scheme exists");
    STAssertEquals(0, strcmp(nv[3], "http"), @"It's pulled from the url.");
    STAssertEquals(0, strcmp(nv[4], "url"), @"");
    STAssertEquals(0, strcmp(nv[5], "/bar;foo?q=123&q=bar&j=3"), @"The path and query parameters must be in the url.");
    STAssertEquals(0, strcmp(nv[6], "host"), @"The host is separate.");
    STAssertEquals(0, strcmp(nv[7], "example.com"), @"No www here.");
    STAssertEquals(0, strcmp(nv[8], "user-agent"), @"The user-agent value doesn't matter.");
    STAssertEquals(0, strcmp(nv[10], "version"), @"We'll send http/1.1");
    STAssertEquals(0, strcmp(nv[11], "HTTP/1.1"), @"Yup, 1.1 for the proxies.");
}

- (void)testCloseStream
{
    stream = [SpdyStream createFromNSURL:url delegate:delegate];
    [stream closeStream];
    STAssertTrue(delegate.closeCalled, @"Delegate not called on stream closed.");
}

@end
