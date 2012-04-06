//
//  EndToEndTests.m
//  SPDY end to end tests using spdyd from spdylay.
//
//  Created by Jim Morrison on 3/1/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "EndToEndTests.h"
#import "SPDY.h"
#import "SpdyUrlConnection.h"

#include <netdb.h>

static const int port = 9783;

@interface E2ECallback : RequestCallback {
    BOOL closeCalled;
    BOOL skipTests;
    CFHTTPMessageRef responseHeaders;
}
@property (assign) BOOL closeCalled;
@property (assign) CFHTTPMessageRef responseHeaders;
@property (assign) BOOL skipTests;
@property (retain) NSError *error;
@end


@implementation E2ECallback

@synthesize error = _error;
@synthesize closeCalled;
@synthesize responseHeaders;
@synthesize skipTests;

- (void)dealloc {
    [_error release];
    if (responseHeaders != NULL) {
        CFRelease(responseHeaders);
    }
    [super dealloc];
}

- (void)onStreamClose {
    NSLog(@"Closing stream.");
    self.closeCalled = YES;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)onConnect:(id<SpdyRequestIdentifier>)u {
    NSLog(@"Connected to %@", u.url);
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    NSLog(@"Got response headers.");
    self.responseHeaders = (CFHTTPMessageRef)CFRetain(headers);
}

- (void)onError:(NSError *)error {
    NSLog(@"Got error %@, will exit loop.", error);
    if (self.error == nil) {
        self.error = error;
        CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopCommonModes, ^{ CFRunLoopStop(CFRunLoopGetCurrent()); });
    }
}

- (void)onNotSpdyError:(id<SpdyRequestIdentifier>)identifier {
    NSLog(@"Not connecting to a spdy server.");
    CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopCommonModes, ^{ CFRunLoopStop(CFRunLoopGetCurrent()); });
}

@end

@interface CloseOnConnectCallback : E2ECallback
@property (assign) NSInteger closedStreams;
@end

@implementation CloseOnConnectCallback

@synthesize closedStreams;

- (void)onConnect:(id<SpdyRequestIdentifier>)stream {
    self.closedStreams = [[SPDY sharedSPDY] closeAllSessions];
}

@end

@interface SpdyTestConnectionDelegate : NSObject // NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;

@property (retain) NSURLConnection *connection;
@property (retain) NSError *error;
@property (retain) NSURLResponse *response;
@property (assign) NSInteger bytesSent;
@end

@implementation SpdyTestConnectionDelegate
@synthesize bytesSent = _bytesSent;
@synthesize connection = _connection;
@synthesize error = _error;
@synthesize response = _response;

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    NSLog(@"bytesWritten: %d", bytesWritten);
    self.bytesSent = totalBytesWritten;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.connection = connection;
    self.response = response;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.connection = connection;
    self.error = error;
    CFRunLoopStop(CFRunLoopGetCurrent());
}
@end

@interface EndToEndTests ()
@property (retain) E2ECallback *delegate;
@property (assign) BOOL exitNeeded;
@end

@implementation EndToEndTests

@synthesize delegate = _delegate;
@synthesize exitNeeded;

- (void)setUp {
    self.exitNeeded = YES;
    self.delegate = [[[E2ECallback alloc] init] autorelease];
    
    // Run the run loop and perform any pending loop exits.
    CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopCommonModes, ^{ if (self.exitNeeded) { CFRunLoopStop(CFRunLoopGetCurrent()); } });
    CFRunLoopRun();
    self.exitNeeded = NO;
    [SpdyUrlConnection registerSpdy];
}

- (void)tearDown {
    self.delegate = nil;
    [SpdyUrlConnection unregister];
}

// All code under test must be linked into the Unit Test bundle
- (void)testSimpleFetch {
    [[SPDY sharedSPDY] fetch:@"http://localhost:9793/" delegate:self.delegate];
    CFRunLoopRun();
    STAssertTrue(self.delegate.closeCalled, @"Run loop finished as expected.");
}

// All code under test must be linked into the Unit Test bundle
- (void)testFetchOnTwoPorts {
    [[SPDY sharedSPDY]fetch:@"http://localhost:9793/" delegate:self.delegate];
    CFRunLoopRun();
    STAssertTrue(self.delegate.closeCalled, @"Run loop finished as expected.");

    self.delegate = [[[E2ECallback alloc] init] autorelease];
    [[SPDY sharedSPDY] fetch:@"http://localhost:9794/" delegate:self.delegate];
    CFRunLoopRun();
    STAssertNotNil(self.delegate.error, @"Got an error");
}

static const unsigned char smallBody[] =
    "Hello, my name is simon.  And I like to do drawings.  I like to draw, all day long, so come do drawings with me."
    "Hello, my name is simon.  And I like to do drawings.  I like to draw, all day long, so come do drawings with me."
    "I'm not good at new content :) 12345";

- (void)testSimpleMessageBody {
    CFDataRef body = CFDataCreate(kCFAllocatorDefault, smallBody, sizeof(smallBody));
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("https://localhost:9793/"), NULL);
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), url, kCFHTTPVersion1_1);
    CFHTTPMessageSetBody(request, body);
    [[SPDY sharedSPDY] fetchFromMessage:request delegate:self.delegate];
    CFRunLoopRun();
    CFRelease(request);
    CFRelease(url);
    CFRelease(body);
    STAssertTrue(self.delegate.closeCalled, @"Run loop finished as expected.");    
}

- (void)testCancelOnConnect {
    self.delegate = [[CloseOnConnectCallback alloc] init];
    [[SPDY sharedSPDY]fetch:@"http://localhost:9793/index.html" delegate:self.delegate];
    CFRunLoopRun();
    STAssertEquals([(CloseOnConnectCallback *)self.delegate closedStreams], 1, @"One stream closed.");
    STAssertNotNil(self.delegate.error, @"An error was set.");
}

- (void)Disabled_testConnectToNonSSL {
    self.delegate = [[CloseOnConnectCallback alloc] init];
    [[SPDY sharedSPDY] fetch:@"http://localhost:9795/index.html" delegate:self.delegate];
    CFRunLoopRun();
    STAssertNotNil(self.delegate.error, @"Error for bad host.");
    STAssertEquals(self.delegate.error.code, 2, @"");
    STAssertTrue([self.delegate.error.domain isEqualToString:@"kOpenSSLErrorDomain"], @"OpenSSL error, but is %@", self.delegate.error.domain);
}


// A bad host name should be equivalent to the network being down.
- (void)testBadHostName {
    [[SPDY sharedSPDY] fetch:@"http://bad.localhost:9793/" delegate:self.delegate];
    CFRunLoopRun();
    STAssertNotNil(self.delegate.error, @"Error for bad host.");
    STAssertEquals(self.delegate.error.code, EAI_NONAME, @"");
    STAssertTrue([self.delegate.error.domain isEqualToString:@"kCFStreamErrorDomainNetDB"], @"NetDb domain, but is %@", self.delegate.error.domain);
}

static void ReadStreamClientCallBack(CFReadStreamRef readStream, CFStreamEventType type, void *info) {
    if (type & kCFStreamEventHasBytesAvailable) {
        char *bytes = malloc(1024);
        CFIndex bytesRead = 1;
        while (CFReadStreamHasBytesAvailable(readStream) && bytesRead > 0) {
            bytesRead = CFReadStreamRead(readStream, (UInt8 *)bytes, 1024);
        }
        free(bytes);
    }
    if (type & (kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred)) {
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}


- (void)testCFStream {
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("https://localhost:9793/"), NULL);
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), url, kCFHTTPVersion1_1);

    CFReadStreamRef readStream = SpdyCreateSpdyReadStream(kCFAllocatorDefault, request, NULL);
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

    CFStreamClientContext ctxt = {0, NULL, NULL, NULL, NULL};
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, ReadStreamClientCallBack, &ctxt);
    CFReadStreamOpen(readStream);
    CFRunLoopRun();
    CFRelease(request);
    CFRelease(url);

    CFErrorRef errors = CFReadStreamCopyError(readStream);
    STAssertTrue(errors == NULL, @"No errors: %@.", errors);
    if (errors != NULL) {
        CFRelease(errors);
    }
    CFReadStreamClose(readStream);
    CFRelease(readStream);
}

static void CloseReadStreamClientCallBack(CFReadStreamRef readStream, CFStreamEventType type, void *info) {
    if (type & kCFStreamEventHasBytesAvailable) {
        char *bytes = malloc(1024);
        CFIndex bytesRead = 1;
        while (CFReadStreamHasBytesAvailable(readStream) && bytesRead > 0) {
            bytesRead = CFReadStreamRead(readStream, (UInt8 *)bytes, 1024);
        }
        free(bytes);
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
    if (type & (kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred)) {
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}


- (void)testCFStreamCancelStream {
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("https://localhost:9793/"), NULL);
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), url, kCFHTTPVersion1_1);
    
    CFReadStreamRef readStream = SpdyCreateSpdyReadStream(kCFAllocatorDefault, request, NULL);
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
    CFStreamClientContext ctxt = {0, NULL, NULL, NULL, NULL};
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, CloseReadStreamClientCallBack, &ctxt);
    CFReadStreamOpen(readStream);

    CFRunLoopRun();
    CFReadStreamClose(readStream);
    CFRunLoopRun();
    
    CFRelease(request);
    CFRelease(url);
    
    CFErrorRef error = CFReadStreamCopyError(readStream);
    STAssertTrue(error != NULL, @"Cancelled stream error.");
    STAssertEquals(CFErrorGetCode(error), (CFIndex)kSpdyRequestCancelled, @"Cancelled request.");
    if (error != NULL) {
        CFRelease(error);
    }
    CFRelease(readStream);
}


- (void)testCFStreamUploadBytes {
    CFDataRef body = CFDataCreate(kCFAllocatorDefault, smallBody, sizeof(smallBody));
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("https://localhost:9793/"), NULL);
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), url, kCFHTTPVersion1_1);
    CFHTTPMessageSetBody(request, body);
    
    CFReadStreamRef readStream = SpdyCreateSpdyReadStream(kCFAllocatorDefault, request, NULL);
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
    CFStreamClientContext ctxt = {0, NULL, NULL, NULL, NULL};
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, ReadStreamClientCallBack, &ctxt);
    CFReadStreamOpen(readStream);
    CFRunLoopRun();
    CFRelease(request);
    CFRelease(url);
    CFRelease(body);
    
    CFErrorRef errors = CFReadStreamCopyError(readStream);
    STAssertTrue(errors == NULL, @"No errors.");
    unsigned long long bytesSent = [[NSMakeCollectable(CFReadStreamCopyProperty((CFReadStreamRef)readStream, kCFStreamPropertyHTTPRequestBytesWrittenCount)) autorelease] unsignedLongLongValue];
    STAssertEquals((unsigned long long)sizeof(smallBody), bytesSent, @"The whole body was sent.");
    
    CFReadStreamClose(readStream);
    CFRelease(readStream);
}

- (void)testCFStreamUploadFromStream {
    NSInputStream *body = [NSInputStream inputStreamWithData:[NSData dataWithBytes:smallBody length:sizeof(smallBody) - 20]];
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("https://localhost:9793/"), NULL);
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), url, kCFHTTPVersion1_1);
    
    CFReadStreamRef readStream = SpdyCreateSpdyReadStream(kCFAllocatorDefault, request, (CFReadStreamRef)body);
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
    CFStreamClientContext ctxt = {0, NULL, NULL, NULL, NULL};
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, ReadStreamClientCallBack, &ctxt);
    CFReadStreamOpen(readStream);
    CFRunLoopRun();
    CFRelease(request);
    CFRelease(url);
    
    CFErrorRef errors = CFReadStreamCopyError(readStream);
    STAssertTrue(errors == NULL, @"No errors.");
    unsigned long long bytesSent = [[NSMakeCollectable(CFReadStreamCopyProperty((CFReadStreamRef)readStream, kCFStreamPropertyHTTPRequestBytesWrittenCount)) autorelease] unsignedLongLongValue];
    STAssertEquals((unsigned long long)sizeof(smallBody) - 20, bytesSent, @"The whole body was sent.");
    
    CFReadStreamClose(readStream);
    CFRelease(readStream);
}

- (void)testCFStreamUploadFromStreamInsteadOfBody {
    NSInputStream *body = [NSInputStream inputStreamWithData:[NSData dataWithBytes:smallBody length:sizeof(smallBody) - 19]];
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("https://localhost:9793/"), NULL);
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), url, kCFHTTPVersion1_1);

    CFDataRef requestBody = CFDataCreate(kCFAllocatorDefault, smallBody, sizeof(smallBody));
    CFHTTPMessageSetBody(request, requestBody);
    
    CFReadStreamRef readStream = SpdyCreateSpdyReadStream(kCFAllocatorDefault, request, (CFReadStreamRef)body);
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
    CFStreamClientContext ctxt = {0, NULL, NULL, NULL, NULL};
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered, ReadStreamClientCallBack, &ctxt);
    CFReadStreamOpen(readStream);
    CFRunLoopRun();
    CFRelease(request);
    CFRelease(url);
    CFRelease(requestBody);
    
    CFErrorRef errors = CFReadStreamCopyError(readStream);
    STAssertTrue(errors == NULL, @"No errors.");
    unsigned long long bytesSent = [[NSMakeCollectable(CFReadStreamCopyProperty((CFReadStreamRef)readStream, kCFStreamPropertyHTTPRequestBytesWrittenCount)) autorelease] unsignedLongLongValue];
    STAssertEquals((unsigned long long)sizeof(smallBody) - 19, bytesSent, @"The whole body was sent.");
    
    CFReadStreamClose(readStream);
    CFRelease(readStream);
}

- (void)testNSURLRequest {
    SpdyTestConnectionDelegate *delegate = [[[SpdyTestConnectionDelegate alloc] init] retain];
    NSURL *url = [NSURL URLWithString:@"https://localhost:9793/"];
    [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:url]
                                  delegate:delegate];
    CFRunLoopRun();
    STAssertNil(delegate.error, @"Error: %@", delegate.error);
    if ([delegate.response class] == [NSHTTPURLResponse class]) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)delegate.response;
        STAssertEquals([delegate.response class], [NSHTTPURLResponse class], @"The response should be an http response with 5.0+ response: %@", delegate.response);
        STAssertEquals(response.statusCode, 200, @"Good reply");
        STAssertEquals([response.allHeaderFields objectForKey:@"protocol-was: spdy"], @"YES", @"Headers are: %@", response.allHeaderFields);
    }
    [delegate release];
}

- (void)testNSURLRequestTimeout {
    SpdyTestConnectionDelegate *delegate = [[[SpdyTestConnectionDelegate alloc] init] retain];
    NSURL *url = [NSURL URLWithString:@"https://localhost:9793/?spdyd_do_not_respond_to_req=yes"];
    [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:0.1]
                                  delegate:delegate];
    CFRunLoopRun();
    STAssertNotNil(delegate.error, @"Error: %@", delegate.error);
    //STAssertEquals([delegate.connection class], [SpdyUrlConnection class], @"The response should be a spdy response: %@", delegate.connection);
    [delegate release];
}

- (void)testNSURLRequestWithBodyStream {
    SpdyTestConnectionDelegate *delegate = [[[SpdyTestConnectionDelegate alloc] init] retain];
    NSURL *url = [NSURL URLWithString:@"https://localhost:9793/"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPBodyStream = [NSInputStream inputStreamWithData:[NSData dataWithBytes:"1234" length:4]];
    [NSURLConnection connectionWithRequest:request delegate:delegate];
    CFRunLoopRun();
    STAssertNil(delegate.error, @"Error: %@", delegate.error);
    //STAssertEquals([delegate.response class], [SpdyUrlResponse class], @"The response should be a spdy response: %@", delegate.response);
    [delegate release];
}

- (void)testNSURLRequestWithBody {
    SpdyTestConnectionDelegate *delegate = [[[SpdyTestConnectionDelegate alloc] init] retain];
    NSURL *url = [NSURL URLWithString:@"https://localhost:9793/"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPBody = [NSData dataWithBytes:"12345" length:5];
    [NSURLConnection connectionWithRequest:request delegate:delegate];
    CFRunLoopRun();
    STAssertNil(delegate.error, @"Error: %@", delegate.error);
    //STAssertEquals([delegate.response class], [SpdyUrlResponse class], @"The response should be a spdy response: %@", delegate.response);
    [delegate release];
}

- (void)testRegisteredForSpdy {
    STAssertTrue([[SPDY sharedSPDY] isSpdyRegistered], @"Spdy should be registered");
    [[SPDY sharedSPDY] unregisterForNSURLConnection];
    STAssertFalse([[SPDY sharedSPDY] isSpdyRegistered], @"Spdy should no longer be registered");
}

@end
