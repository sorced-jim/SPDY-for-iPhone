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

@interface SpdyStreamCallback : RequestCallback {
    BOOL closeCalled;
    CFHTTPMessageRef responseHeaders;
}
@property BOOL closeCalled;
@property (retain) NSError *error;
@property (assign) CFHTTPMessageRef responseHeaders;
@end


@implementation SpdyStreamCallback

- (void)dealloc {
    if (responseHeaders != NULL) {
        CFRelease(responseHeaders);
    }
    self.error = nil;
    [super dealloc];
}

- (void)onStreamClose {
    self.closeCalled = YES;
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    self.responseHeaders = (CFHTTPMessageRef)CFRetain(headers);
}

- (void)onError:(CFErrorRef)e {
    self.error = (NSError *)e;
}

@synthesize closeCalled;
@synthesize error;
@synthesize responseHeaders;

@end

static int countItems(const char **nv) {
    int count;
    for (count = 0; nv[count]; ++count) {
    }
    return count;
}

@implementation SpdyStreamTests {
    SpdyStreamCallback *delegate;
    NSURL *url;
    SpdyStream *stream;
}

- (void)setUp {
    url = [[NSURL URLWithString:@"http://example.com/bar;foo?q=123&q=bar&j=3"] retain];
    delegate = [[SpdyStreamCallback alloc]init];
}

- (void)tearDown {
    [stream release];
    [delegate release];
    [url release];
}

- (void)testNameValuePairs {
    stream = [SpdyStream newFromNSURL:url delegate:delegate];
    const char **nv = [stream nameValues];
    int items = countItems(nv);
    STAssertEquals(12, items, @"There should only be 6 pairs");
    STAssertEquals(0, items % 2, @"There must be an even number of pairs.");
    STAssertEquals(0, strcmp(nv[0], ":method"), @"First value is not method");
    STAssertEquals(0, strcmp(nv[1], "GET"), @"A NSURL uses get");
    STAssertEquals(0, strcmp(nv[2], ":scheme"), @"The scheme exists");
    STAssertEquals(0, strcmp(nv[3], "http"), @"It's pulled from the url.");
    STAssertEquals(0, strcmp(nv[4], ":path"), @"");
    STAssertEquals(0, strcmp(nv[5], "/bar;foo?q=123&q=bar&j=3"), @"The path and query parameters must be in the url.");
    STAssertEquals(0, strcmp(nv[6], ":host"), @"The host is separate.");
    STAssertEquals(0, strcmp(nv[7], "example.com"), @"No www here.");
    STAssertEquals(0, strcmp(nv[8], "user-agent"), @"The user-agent value doesn't matter.");
    STAssertEquals(0, strcmp(nv[10], ":version"), @"We'll send http/1.1");
    STAssertEquals(0, strcmp(nv[11], "HTTP/1.1"), @"Yup, 1.1 for the proxies.");
    
    STAssertNil(stream.body, @"No body for NSURL.");
}

- (void)testCloseStream {
    stream = [SpdyStream newFromNSURL:url delegate:delegate];
    [stream closeStream];
    STAssertTrue(delegate.closeCalled, @"Delegate not called on stream closed.");
}

- (void)testSerializeHeaders {
    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(NULL, CFSTR("OPTIONS"), (CFURLRef)url, CFSTR("HTTP/1.0"));
    CFHTTPMessageSetHeaderFieldValue(msg, CFSTR("Boy"), CFSTR("Bad"));
    stream = [SpdyStream newFromCFHTTPMessage:msg delegate:delegate body:nil];
    const char **nv = [stream nameValues];
    STAssertTrue(nv != NULL, @"nameValues should be allocated");
    if (nv == NULL) {
        return;
    }
    int items = countItems(nv);
    STAssertEquals(14, items, @"At least 7 pairs.");
    if (items < 14) {
        return;
    }
    STAssertEquals(0, items % 2, @"There must be an even number of pairs.");
    STAssertEquals(0, strcmp(nv[0], ":method"), @"First value is not method");
    STAssertEquals(0, strcmp(nv[1], "OPTIONS"), @"Pull the method from the message '%s'.", nv[1]);
    STAssertEquals(0, strcmp(nv[2], "user-agent"), @"The user-agent value doesn't matter.");
    
    STAssertEquals(0, strcmp(nv[4], ":version"), @"We'll send http/1.1");
    STAssertEquals(0, strcmp(nv[5], "HTTP/1.0"), @"Yup, 1.0 is in the request: '%s'", nv[5]);
    
    STAssertEquals(0, strcmp(nv[6], ":scheme"), @"The scheme exists: '%s'", nv[4]);
    STAssertEquals(0, strcmp(nv[7], "http"), @"It's pulled from the url.");
    STAssertEquals(0, strcmp(nv[8], ":host"), @"The host is separate.");
    STAssertEquals(0, strcmp(nv[9], "example.com"), @"No www here: %s", nv[9]);

    STAssertEquals(0, strcmp(nv[10], ":path"), @"");
    STAssertEquals(0, strcmp(nv[11], "/bar;foo?q=123&q=bar&j=3"), @"The path and query parameters must be in the url: '%s'", nv[11]);
    STAssertEquals(0, strcmp(nv[12], "Boy"), @"Boy is a header.");
    STAssertEquals(0, strcmp(nv[13], "Bad"), @"The boy was bad.");
    STAssertNil(stream.body, @"No Body.");
    CFRelease(msg);
}

- (void)testSerializeHeadersNoResourceSpecifier {
    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(NULL, CFSTR("OPTIONS"), CFURLCreateWithString(kCFAllocatorDefault, CFSTR("http://bar/"), NULL), kCFHTTPVersion1_0);
    stream = [SpdyStream newFromCFHTTPMessage:msg delegate:delegate body:nil];
    const char **nv = [stream nameValues];
    STAssertTrue(nv != NULL, @"nameValues should be allocated");
    if (nv == NULL) {
        return;
    }
    int items = countItems(nv);
    STAssertEquals(12, items, @"At least 6 pairs.");
    if (items < 12) {
        return;
    }
    STAssertEquals(0, strcmp(nv[5], "HTTP/1.0"), @"Yup, 1.0 is in the request: '%s'", nv[5]);
    STAssertEquals(0, strcmp(nv[11], "/"), @"The path and query parameters must be in the url: '%s'", nv[11]);
    CFRelease(msg);
}

- (void)testHugeQueryPath {
    CFMutableStringRef longUrl = CFStringCreateMutable(kCFAllocatorDefault, 1200);
    CFStringAppend(longUrl, CFSTR("http://bar/path?"));
    CFStringPad(longUrl, CFSTR("q=1234&"), 1100, 0);
    CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, longUrl, NULL);

    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(NULL, CFSTR("OPTIONS"), urlRef, kCFHTTPVersion1_0);
    stream = [SpdyStream newFromCFHTTPMessage:msg delegate:delegate body:nil];
    const char **nv = [stream nameValues];
    STAssertTrue(nv != NULL, @"nameValues should be allocated");
    if (nv == NULL) {
        return;
    }
    int items = countItems(nv);
    STAssertEquals(12, items, @"At least 6 pairs.");
    if (items < 12) {
        return;
    }
    STAssertEquals(0, strcmp(nv[5], "HTTP/1.0"), @"Yup, 1.0 is in the request: '%s'", nv[5]);
    STAssertEquals(0, strncmp(nv[11], "/path?q=1234&q=1234&", 20), @"The path and query parameters must be in the url: '%.*s'", 30, nv[11]);
    
    CFRelease(msg);
    CFRelease(urlRef);
    CFRelease(longUrl);
}

- (void)testSetBody {
    NSData *data = [NSData dataWithBytes:"hi=bye" length:6]; // autoreleased.
    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), (CFURLRef)url, CFSTR("HTTP/1.2"));
    CFHTTPMessageSetBody(msg, (CFDataRef)data);
    stream = [SpdyStream newFromCFHTTPMessage:msg delegate:delegate body:nil];
    STAssertNotNil(stream.body, @"Stream has a body.");
    CFRelease(msg);
}

- (void)testParseHeaders {
    stream = [SpdyStream newFromNSURL:url delegate:delegate];
    static const char* nameValues[] = {
        "Content-Type", "text/plain",
        NULL,
    };
    [stream parseHeaders:nameValues];
    STAssertTrue(delegate.responseHeaders != NULL, @"Have headers");
    STAssertTrue(CFHTTPMessageIsHeaderComplete(delegate.responseHeaders), @"Full headers.");
}

- (void)testParseHeadersBadValues {
    stream = [SpdyStream newFromNSURL:url delegate:delegate];
    static const char* nameValues[] = {
        "Content-Type", "text/plain",
        "bad\xc3\x28key", "good value",
        "dropped-key", "bad\xc3\x28value",
        "bad\xc3\x28key", "bad\xc3\x28value",
        "Used-Key", "good value",
        NULL,
    };
    [stream parseHeaders:nameValues];
    STAssertTrue(delegate.responseHeaders != NULL, @"Have headers");
    STAssertTrue(CFHTTPMessageIsHeaderComplete(delegate.responseHeaders), @"Full headers.");
    NSDictionary *headers = [(NSDictionary *)CFHTTPMessageCopyAllHeaderFields(delegate.responseHeaders) autorelease];
    STAssertEquals([headers count], 2U, @"Two headers kept %@", headers);
}

- (void)testParseHeadersOddHeaders {
    stream = [SpdyStream newFromNSURL:url delegate:delegate];
    static const char* nameValues[] = {
        "Content-Type", "text/plain",
        "Used-Key", "good value",
        "Unmatched.",
        NULL,
    };
    [stream parseHeaders:nameValues];
    STAssertTrue(delegate.responseHeaders != NULL, @"Have headers");
    STAssertTrue(CFHTTPMessageIsHeaderComplete(delegate.responseHeaders), @"Full headers.");
    NSDictionary *headers = [(NSDictionary *)CFHTTPMessageCopyAllHeaderFields(delegate.responseHeaders) autorelease];
    STAssertEquals([headers count], 2U, @"Two headers kept %@", headers);
}


- (void)testCancelStream {
    stream = [SpdyStream newFromNSURL:url delegate:delegate];
    [stream cancelStream];
    STAssertEquals([delegate.error domain], (NSString *)kSpdyErrorDomain, @"Spdy domain.");
    STAssertEquals([delegate.error code], kSpdyRequestCancelled, @"Cancelled request.");
}
@end
