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

- (void)onError:(CFErrorRef)e {
    NSLog(@"Got error %@, will exit loop.", (NSError *)e);
    if (self.error == nil) {
        self.error = (NSError *)e;
        CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopCommonModes, ^{ CFRunLoopStop(CFRunLoopGetCurrent()); });
    }
}

- (void)onNotSpdyError {
    NSLog(@"Not connecting to a spdy server.");
    CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopCommonModes, ^{ CFRunLoopStop(CFRunLoopGetCurrent()); });
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
@property (assign) BOOL exitNeeded;
@end

@implementation EndToEndTests

@synthesize delegate;
@synthesize exitNeeded;

- (void)setUp {
    self.exitNeeded = YES;
    self.delegate = [[[E2ECallback alloc]init] autorelease];
    
    // Run the run loop and perform any pending loop exits.
    CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopCommonModes, ^{ if (self.exitNeeded) { CFRunLoopStop(CFRunLoopGetCurrent()); } });
    CFRunLoopRun();
    self.exitNeeded = NO;
}

- (void)tearDown {
    self.delegate = nil;
}

// All code under test must be linked into the Unit Test bundle
- (void)testSimpleFetch {
    [[SPDY sharedSPDY]fetch:@"http://localhost:9793/" delegate:self.delegate];
    CFRunLoopRun();
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
    STAssertTrue(self.delegate.closeCalled, @"Run loop finished as expected.");    
}

- (void)testCancelOnConnect {
    self.delegate = [[CloseOnConnectCallback alloc]init];
    [[SPDY sharedSPDY]fetch:@"http://localhost:9793/index.html" delegate:self.delegate];
    CFRunLoopRun();
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

    CFErrorRef errors = CFReadStreamCopyError(readStream);
    STAssertTrue(errors == NULL, @"No errors.");
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

@end
