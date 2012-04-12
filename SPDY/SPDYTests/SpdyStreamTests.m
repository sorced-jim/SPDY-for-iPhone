//
//  SpdyStreamTests.m
//  SPDY
//
//  Created by Jim Morrison on 2/15/12.
//  Copyright (c) 2012 Twist Inc.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

@synthesize closeCalled;
@synthesize error = _error;
@synthesize responseHeaders;

- (void)dealloc {
    if (responseHeaders != NULL) {
        CFRelease(responseHeaders);
    }
    [_error release];
    [super dealloc];
}

- (void)onStreamClose {
    self.closeCalled = YES;
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    self.responseHeaders = (CFHTTPMessageRef)CFRetain(headers);
}

- (void)onError:(NSError *)e {
    self.error = e;
}

@end

static int countItems(const char **nv) {
    int count;
    for (count = 0; nv[count]; ++count) {
    }
    return count;
}

@interface SpdyStreamTests ()
@property (retain) NSURL *url;
@property (retain) SpdyStreamCallback *delegate;
@end

@implementation SpdyStreamTests {
    SpdyStream *stream;
}

@synthesize delegate = _delegate;
@synthesize url = _url;

- (void)setUp {
    [SpdyStream staticInit];
    self.url = [NSURL URLWithString:@"http://example.com/bar;foo?q=123&q=bar&j=3"];
    self.delegate = [[[SpdyStreamCallback alloc] init] autorelease];
}

- (void)tearDown {
    [stream release];
    self.delegate = nil;
    self.url = nil;
}

- (void)testNameValuePairs {
    stream = [SpdyStream newFromNSURL:self.url delegate:self.delegate];
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
    STAssertEquals(0, strcmp(nv[8], ":version"), @"We'll send http/1.1");
    STAssertEquals(0, strcmp(nv[9], "HTTP/1.1"), @"Yup, 1.1 for the proxies.");
    STAssertEquals(0, strcmp(nv[10], "user-agent"), @"The user-agent value doesn't matter.");
    
    STAssertNil(stream.body, @"No body for NSURL.");
}
- (void)testNameValuePairsWithPort {
    stream = [SpdyStream newFromNSURL:[NSURL URLWithString:@"ftp://bar:27/asd;212?12=3"] delegate:self.delegate];
    const char **nv = [stream nameValues];
    int items = countItems(nv);
    STAssertEquals(12, items, @"There should only be 6 pairs");
    STAssertEquals(0, items % 2, @"There must be an even number of pairs.");
    STAssertEquals(0, strcmp(nv[0], ":method"), @"First value is not method");
    STAssertEquals(0, strcmp(nv[1], "GET"), @"A NSURL uses get");
    STAssertEquals(0, strcmp(nv[2], ":scheme"), @"The scheme exists");
    STAssertEquals(0, strcmp(nv[3], "ftp"), @"It's pulled from the url.");
    STAssertEquals(0, strcmp(nv[4], ":path"), @"");
    STAssertEquals(0, strcmp(nv[5], "/asd;212?12=3"), @"The path and query parameters must be in the url.");
    STAssertEquals(0, strcmp(nv[6], ":host"), @"The host is separate.");
    STAssertEquals(0, strcmp(nv[7], "bar"), @"No www here.");
}
    
- (void)testCloseStream {
    stream = [SpdyStream newFromNSURL:self.url delegate:self.delegate];
    [stream closeStream];
    STAssertTrue(self.delegate.closeCalled, @"Delegate not called on stream closed.");
}

- (void)testSerializeHeaders {
    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(NULL, CFSTR("OPTIONS"), (CFURLRef)self.url, CFSTR("HTTP/1.0"));
    CFHTTPMessageSetHeaderFieldValue(msg, CFSTR("Boy"), CFSTR("Bad"));
    stream = [SpdyStream newFromCFHTTPMessage:msg delegate:self.delegate body:nil];
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
    STAssertEquals(0, items % 2, @"There must be an even number of pairs.");
    STAssertEquals(0, strcmp(nv[0], ":method"), @"First value is not method");
    STAssertEquals(0, strcmp(nv[1], "OPTIONS"), @"Pull the method from the message '%s'.", nv[1]);
    STAssertEquals(0, strcmp(nv[2], ":scheme"), @"The scheme exists: '%s'", nv[2]);
    STAssertEquals(0, strcmp(nv[3], "http"), @"It's pulled from the url.");
    STAssertEquals(0, strcmp(nv[4], ":path"), @"");
    STAssertEquals(0, strcmp(nv[5], "/bar;foo?q=123&q=bar&j=3"), @"The path and query parameters must be in the url: '%s'", nv[5]);
    STAssertEquals(0, strcmp(nv[6], ":host"), @"The host is separate.");
    STAssertEquals(0, strcmp(nv[7], "example.com"), @"No www here: %s", nv[7]);
    STAssertEquals(0, strcmp(nv[8], ":version"), @"We'll send http/1.1, %s", nv[10]);
    STAssertEquals(0, strcmp(nv[9], "HTTP/1.0"), @"Yup, 1.0 is in the request: '%s'", nv[11]);

    STAssertEquals(0, strcmp(nv[10], "boy"), @"Boy is a header.");
    STAssertEquals(0, strcmp(nv[11], "Bad"), @"The boy was bad.");
    STAssertNil(stream.body, @"No Body.");
    CFRelease(msg);
}

- (void)testSerializeHeadersNoResourceSpecifier {
    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(NULL, CFSTR("OPTIONS"), CFURLCreateWithString(kCFAllocatorDefault, CFSTR("http://bar/"), NULL), kCFHTTPVersion1_0);
    stream = [SpdyStream newFromCFHTTPMessage:msg delegate:self.delegate body:nil];
    const char **nv = [stream nameValues];
    STAssertTrue(nv != NULL, @"nameValues should be allocated");
    if (nv == NULL) {
        return;
    }
    int items = countItems(nv);
    STAssertEquals(10, items, @"At least 5 pairs.");
    if (items < 10) {
        return;
    }
    STAssertEquals(0, strcmp(nv[5], "/"), @"The path and query parameters must be in the url: '%s'", nv[5]);
    STAssertEquals(0, strcmp(nv[9], "HTTP/1.0"), @"Yup, 1.0 is in the request: '%s'", nv[11]);
    CFRelease(msg);
}

- (void)testHugeQueryPath {
    CFMutableStringRef longUrl = CFStringCreateMutable(kCFAllocatorDefault, 1200);
    CFStringAppend(longUrl, CFSTR("http://bar/path?"));
    CFStringPad(longUrl, CFSTR("q=1234&"), 1100, 0);
    CFURLRef urlRef = CFURLCreateWithString(kCFAllocatorDefault, longUrl, NULL);

    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(NULL, CFSTR("OPTIONS"), urlRef, kCFHTTPVersion1_0);
    stream = [SpdyStream newFromCFHTTPMessage:msg delegate:self.delegate body:nil];
    const char **nv = [stream nameValues];
    STAssertTrue(nv != NULL, @"nameValues should be allocated");
    if (nv == NULL) {
        return;
    }
    int items = countItems(nv);
    STAssertEquals(10, items, @"At least 5 pairs.");
    if (items < 10) {
        return;
    }
    STAssertEquals(0, strncmp(nv[5], "/path?q=1234&q=1234&", 20), @"The path and query parameters must be in the url: '%.*s'", 30, nv[5]);
    STAssertEquals(0, strcmp(nv[9], "HTTP/1.0"), @"Yup, 1.0 is in the request: '%s'", nv[11]);
    
    CFRelease(msg);
    CFRelease(urlRef);
    CFRelease(longUrl);
}

- (void)testSetBody {
    NSData *data = [NSData dataWithBytes:"hi=bye" length:6]; // autoreleased.
    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), (CFURLRef)self.url, CFSTR("HTTP/1.2"));
    CFHTTPMessageSetBody(msg, (CFDataRef)data);
    stream = [SpdyStream newFromCFHTTPMessage:msg delegate:self.delegate body:nil];
    STAssertNotNil(stream.body, @"Stream has a body.");
    CFRelease(msg);
}

- (void)testParseHeaders {
    stream = [SpdyStream newFromNSURL:self.url delegate:self.delegate];
    static const char* nameValues[] = {
        ":status", "452 hi",
        ":version", "spdy/8",
        "Content-Type", "text/plain",
        NULL,
    };
    [stream parseHeaders:nameValues];
    STAssertTrue(self.delegate.responseHeaders != NULL, @"Have headers");
    STAssertTrue(CFHTTPMessageIsHeaderComplete(self.delegate.responseHeaders), @"Full headers.");
}

- (void)testParseHeadersBadValues {
    stream = [SpdyStream newFromNSURL:self.url delegate:self.delegate];
    static const char* nameValues[] = {
        ":status", "111",
        ":version", "http/1.2",
        "Content-Type", "text/plain",
        "bad\xc3\x28key", "good value",
        "dropped-key", "bad\xc3\x28value",
        "bad\xc3\x28key", "bad\xc3\x28value",
        "Used-Key", "good value",
        NULL,
    };
    [stream parseHeaders:nameValues];
    STAssertTrue(self.delegate.responseHeaders != NULL, @"Have headers");
    STAssertTrue(CFHTTPMessageIsHeaderComplete(self.delegate.responseHeaders), @"Full headers.");
    NSDictionary *headers = [(NSDictionary *)CFHTTPMessageCopyAllHeaderFields(self.delegate.responseHeaders) autorelease];
    STAssertEquals([headers count], 4U, @"Four headers kept %@", headers);
}

- (void)testParseHeadersOddHeaders {
    stream = [SpdyStream newFromNSURL:self.url delegate:self.delegate];
    static const char* nameValues[] = {
        ":status", "124 Yup",
        ":version", "yup/yup",
        "Content-Type", "text/plain",
        "Used-Key", "good value",
        "Unmatched.",
        NULL,
    };
    [stream parseHeaders:nameValues];
    STAssertTrue(self.delegate.responseHeaders != NULL, @"Have headers");
    STAssertTrue(CFHTTPMessageIsHeaderComplete(self.delegate.responseHeaders), @"Full headers.");
    NSDictionary *headers = [(NSDictionary *)CFHTTPMessageCopyAllHeaderFields(self.delegate.responseHeaders) autorelease];
    STAssertEquals([headers count], 4U, @"Four headers kept %@", headers);
}

- (void)testParseHeadersNoStatus {
    stream = [SpdyStream newFromNSURL:self.url delegate:self.delegate];
    static const char* nameValues[] = {
        ":stats", "124 Yup",
        ":version", "yup/yup",
        "Content-Type", "text/plain",
        NULL,
    };
    [stream parseHeaders:nameValues];
    STAssertTrue(self.delegate.responseHeaders == NULL, @"Have headers");
    STAssertNotNil(self.delegate.error, @"Error");
    STAssertEquals(self.delegate.error.domain, kSpdyErrorDomain, @"Error %@", self.delegate.error);
    STAssertEquals(self.delegate.error.code, kSpdyInvalidResponseHeaders, @"Error %@", self.delegate.error);
}

- (void)testCancelStream {
    stream = [SpdyStream newFromNSURL:self.url delegate:self.delegate];
    [stream cancelStream];
    STAssertEquals([self.delegate.error domain], (NSString *)kSpdyErrorDomain, @"Spdy domain.");
    STAssertEquals([self.delegate.error code], kSpdyRequestCancelled, @"Cancelled request.");
}

- (void)testSerializeRequestHeaders {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    [request setHTTPMethod:@"OPTIONS"];
    [request addValue:@"Bar" forHTTPHeaderField:@"Connection"];
    [request addValue:@"Baz" forHTTPHeaderField:@"X-Jim"];
    stream = [SpdyStream newFromRequest:request delegate:self.delegate];
    int items = countItems(stream.nameValues);
    const char **nv = stream.nameValues;
    STAssertEquals(items, 12, @"The connection header is dropped.");
    STAssertEquals(0, strcmp(nv[0], ":method"), @"First value is not method, it is: %s", nv[0]);
    STAssertEquals(0, strcmp(nv[1], "OPTIONS"), @"Request method from request: %s", nv[1]);
    STAssertEquals(0, strcmp(nv[2], ":scheme"), @"The scheme exists");
    STAssertEquals(0, strcmp(nv[3], "http"), @"It's pulled from the url.");
    STAssertEquals(0, strcmp(nv[4], ":path"), @"");
    STAssertEquals(0, strcmp(nv[5], "/bar;foo?q=123&q=bar&j=3"), @"The path and query parameters must be in the url.");
    STAssertEquals(0, strcmp(nv[6], ":host"), @"The host is separate.");
    STAssertEquals(0, strcmp(nv[7], "example.com"), @"No www here.");
    STAssertEquals(0, strcmp(nv[8], ":version"), @"We'll send http/1.1");
    STAssertEquals(0, strcmp(nv[9], "HTTP/1.1"), @"Yup, 1.1 for the proxies.");
    STAssertEquals(0, strcmp(nv[10], "x-jim"), @"Extra header: %s", nv[12]);
    STAssertEquals(0, strcmp(nv[11], "Baz"), @"The header is %s", nv[13]);

    STAssertNil(stream.body, @"No body for NSURL.");
}

@end
