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
    CFHTTPMessageRef responseHeaders;
}
@property (assign) BOOL closeCalled;
@property (assign) CFHTTPMessageRef responseHeaders;
@property (assign) BOOL skipTests;
@property (retain) NSError *error;
@end


@implementation E2ECallback

- (void)dealloc {
    if (responseHeaders != NULL) {
        CFRelease(responseHeaders);
    }
}

- (void)onStreamClose {
    self.closeCalled = YES;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)onConnect:(id<SpdyRequestIdentifier>)u {
    NSLog(@"Connected to %@", u.url);
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    self.responseHeaders = (CFHTTPMessageRef)CFRetain(headers);
}

- (void)onError:(CFErrorRef)error {
    if (CFEqual(CFErrorGetDomain(error), kCFErrorDomainPOSIX) && CFErrorGetCode(error) == ECONNREFUSED) {
        // Running the tests through xcode doesn't actually use the run script, so ignore failures where the server can't be contacted.
        self.skipTests = YES;
    }
    self.error = (NSError *)error;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)onNotSpdyError {
    CFRunLoopStop(CFRunLoopGetCurrent());
    NSLog(@"Not connecting to a spdy server.");
}

@synthesize error;
@synthesize closeCalled;
@synthesize responseHeaders;
@synthesize skipTests;

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

@interface EndToEndTests ()
@property (retain) E2ECallback *delegate;
@end

@implementation EndToEndTests

@synthesize delegate;

- (void)setUp {
    self.delegate = [[E2ECallback alloc]init];
}

- (void)tearDown {
    self.delegate = nil;
}

// All code under test must be linked into the Unit Test bundle
- (void)testSimpleFetch {
    [[SPDY sharedSPDY]fetch:@"http://localhost:9793/" delegate:self.delegate];
    CFRunLoopRun();
    if (self.delegate.skipTests) {
        NSLog(@"Skipping tests since the server isn't up.");
        return;
    }
    STAssertTrue(self.delegate.closeCalled, @"Run loop finished as expected.");
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
    [[SPDY sharedSPDY]fetchFromMessage:request delegate:self.delegate];
    CFRunLoopRun();
    CFRelease(request);
    CFRelease(url);
    CFRelease(body);
    if (self.delegate.skipTests) {
        return;
    }
    STAssertTrue(self.delegate.closeCalled, @"Run loop finished as expected.");    
}

- (void)disable_testCancelOnConnect {
    self.delegate = [[CloseOnConnectCallback alloc]init];
    [[SPDY sharedSPDY]fetch:@"http://localhost:9793/index.html" delegate:self.delegate];
    CFRunLoopRun();
    if (self.delegate.skipTests) {
        return;
    }
    STAssertEquals([(CloseOnConnectCallback *)self.delegate closedStreams], 1, @"One stream closed.");
    STAssertNotNil(self.delegate.error, @"An error was set.");
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

    CFErrorRef skipTests = CFReadStreamCopyError(readStream);
    if (skipTests != NULL) {
        CFRelease(skipTests);
        NSLog(@"Skipping tests.");
    }
}

- (void)testCFStreamUploadBytes {
    CFDataRef body = CFDataCreate(kCFAllocatorDefault, smallBody, sizeof(smallBody));
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("https://localhost:9793/"), NULL);
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), url, kCFHTTPVersion1_1);
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
    
    CFErrorRef skipTests = CFReadStreamCopyError(readStream);
    if (skipTests != NULL) {
        CFRelease(skipTests);
        NSLog(@"Skipping tests.");
    }
    unsigned long long bytesSent = [[NSMakeCollectable(CFReadStreamCopyProperty((CFReadStreamRef)readStream, kCFStreamPropertyHTTPRequestBytesWrittenCount)) autorelease] unsignedLongLongValue];
    STAssertEquals((unsigned long long)sizeof(smallBody), bytesSent, @"The whole body was sent.");
}

@end
