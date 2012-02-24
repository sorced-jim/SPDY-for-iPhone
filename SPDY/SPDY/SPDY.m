//
//  SPDY.m
//  SPDY library implementation.
//
//  Created by Jim Morrison on 1/31/12.
//  Copyright 2012 Twist Inc.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "SPDY.h"

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h>

#include "openssl/ssl.h"
#import "SpdySession.h"

// The shared spdy instance.
static SPDY *spdy = NULL;


typedef struct {
    CFIndex version; /* == 0 */
    Boolean (*open)(CFReadStreamRef stream, CFStreamError *error, Boolean *openComplete, void *info);
    Boolean (*openCompleted)(CFReadStreamRef stream, CFStreamError *error, void *info);
    CFIndex (*read)(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength, CFStreamError *error, Boolean *atEOF, void *info);
    const UInt8 *(*getBuffer)(CFReadStreamRef stream, CFIndex maxBytesToRead, CFIndex *numBytesRead, CFStreamError *error, Boolean *atEOF, void *info);
    Boolean (*canRead)(CFReadStreamRef stream, void *info);
    void (*close)(CFReadStreamRef stream, void *info);
    CFTypeRef (*copyProperty)(CFReadStreamRef stream, CFStringRef propertyName, void *info);
    void (*schedule)(CFReadStreamRef stream, CFRunLoopRef runLoop, CFStringRef runLoopMode, void *info);
    void (*unschedule)(CFReadStreamRef stream, CFRunLoopRef runLoop, CFStringRef runLoopMode, void *info);
} _CFReadStreamCallBacksV0Copy;

CFReadStreamRef CFReadStreamCreate(CFAllocatorRef alloc, const _CFReadStreamCallBacksV0Copy *callbacks, void *info);

@implementation SPDY {
    NSMutableDictionary *sessions;
}

- (SpdySession *)getSession:(NSURL *)url {
    SpdySession *session = [sessions objectForKey:[url host]];
    if (session == nil) {
        session = [[[SpdySession alloc]init] autorelease];
        if (![session connect:url]) {
            NSLog(@"Could not connect to %@", url);
            return nil;
        }
        [sessions setObject:session forKey:[url host]];
        [session addToLoop];
    }
    return session;
}

- (void)fetch:(NSString *)url delegate:(RequestCallback *)delegate {
    NSURL *u = [NSURL URLWithString:url];
    if (u == nil || u.host == nil) {
        [delegate onError];
        return;
    }
    SpdySession *session = [self getSession:u];
    if (session == nil) {
        [delegate onNotSpdyError];
        return;
    }
    [session fetch:u delegate:delegate];
}

- (void)fetchFromMessage:(CFHTTPMessageRef)request delegate:(RequestCallback *)delegate {
    CFURLRef url = CFHTTPMessageCopyRequestURL(request);
    SpdySession *session = [self getSession:(NSURL *)url];
    if (session == nil) {
        [delegate onNotSpdyError];
    } else {
        [session fetchFromMessage:request delegate:delegate];
    }
    CFRelease(url);
}

- (SPDY *)init {
    self = [super init];
    sessions = [[NSMutableDictionary alloc]init];
    return self;
}

- (void)dealloc {
    [sessions release];
}

+ (SPDY *)sharedSPDY {
    if (spdy == NULL) {
        SSL_library_init();
        spdy = [[SPDY alloc]init];
    }
    return spdy;
}
@end

@implementation RequestCallback

- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length {
    return length;
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
}

- (void)onError {
    
}

- (void)onNotSpdyError {
    
}

- (void)onStreamClose {
    
}

- (void)onConnect:(NSURL *)url {
    
}
@end

@interface BufferedCallback ()

@property (assign) CFHTTPMessageRef headers;
@end

@implementation BufferedCallback {
    CFMutableDataRef body;
    CFHTTPMessageRef _headers;
    NSURL *_url;
}

@synthesize url = _url;

- (id)init {
    self = [super init];
    self.url = nil;
    body = CFDataCreateMutable(NULL, 0);
    return self;
}

- (void)dealloc {
    self.url = nil;
    CFRelease(body);
    CFRelease(_headers);
}

- (void)setHeaders:(CFHTTPMessageRef)h {
    _headers = CFHTTPMessageCreateCopy(NULL, h);
    CFRetain(_headers);
}

- (CFHTTPMessageRef)headers {
    return _headers;
}

- (void)onConnect:(NSURL *)u {
    self.url = u;
}

-(void)onResponseHeaders:(CFHTTPMessageRef)h {
    self.headers = h;
}

- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length {
    CFDataAppendBytes(body, bytes, length);
    return length;
}

- (void)onStreamClose {
    CFHTTPMessageSetBody(_headers, body);
    [self onResponse:_headers];
}

- (void)onResponse:(CFHTTPMessageRef)response {
    
}

- (void)onError {
    
}
@end

// Create a delegate derived class of RequestCallback.  Create a context struct.
// Convert this to an objective-C object that derives from RequestCallback.
@interface _SpdyCFStream : RequestCallback {
    CFReadStreamRef readStreamPair;
    CFWriteStreamRef writeStreamPair;  // read() will write into writeStreamPair.
    SpdyStream *stream;
    SpdySession *session;
    CFHTTPMessageRef _responseHeaders;
};

@property (assign) BOOL opened;
@property (assign) int error;
@property (assign) CFHTTPMessageRef responseHeaders;
@property (assign) CFReadStreamRef readStreamPair;
@end

static void ReadStreamClientCallBack(CFReadStreamRef readStream, CFStreamEventType type, void *info) {
    _SpdyCFStream *ctx = (_SpdyCFStream *)info;
    // Trigger the actual client callback.  How?  Damn?
}

@implementation _SpdyCFStream

@synthesize opened;
@synthesize error;
@synthesize readStreamPair;

- (_SpdyCFStream *)init:(CFAllocatorRef)a {
    self = [super init];
    CFStreamCreateBoundPair(a, &readStreamPair, &writeStreamPair, 16 * 1024);
    
    CFStreamClientContext ctxt = {0, self, NULL, NULL, NULL};
    CFReadStreamSetClient(readStreamPair, kCFStreamEventHasBytesAvailable, ReadStreamClientCallBack, &ctxt);

    self.error = 0;
    self.opened = NO;
    return self;
}

- (void)dealloc {
    if (CFReadStreamGetStatus(readStreamPair) != kCFStreamStatusClosed) {
        CFReadStreamClose(readStreamPair);
    }
    if (CFWriteStreamGetStatus(writeStreamPair) != kCFStreamStatusClosed) {
        CFWriteStreamClose(writeStreamPair);
    }
    CFRelease(readStreamPair);
    CFRelease(writeStreamPair);
}

- (void)setResponseHeaders:(CFHTTPMessageRef)h {
    _responseHeaders = h;
    CFRetain(h);
}

- (CFHTTPMessageRef)responseHeaders {
    return _responseHeaders;
}

// Methods that implementors should override.
- (void)onConnect:(NSURL *)url {
    self.opened = YES;
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    self.responseHeaders = headers;
}

- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length {
    // TODO(jim): Ensure that any errors from write() get transfered to the SpdyStream.
    return CFWriteStreamWrite(writeStreamPair, bytes, length);
}

- (void)onStreamClose {
    CFWriteStreamClose(writeStreamPair);
}

- (void)onNotSpdyError {
    self.error = 2;
}

- (void)onError {
    self.error = 1;
    self.opened = NO;
}

- (BOOL)assignCFStreamError:(CFStreamError*)e {
    if (self.error != 0) {
        e->domain = kCFStreamErrorDomainCustom;
        e->error = self.error;
        return NO;
    }
    return YES;
}

@end

static CFTypeRef copyProperty(CFReadStreamRef readStream, CFStringRef property, void *data) {
    _SpdyCFStream *ctx = (_SpdyCFStream *)data;
    if (CFEqual(property, kCFStreamPropertyHTTPResponseHeader)) {
        if (ctx.responseHeaders != NULL) {
            return CFRetain(ctx.responseHeaders);
        }
    }
    if (CFEqual(property, kCFStreamPropertyHTTPRequestBytesWrittenCount)) {
        //return CFDataGetLength([ctx->delegate body]);  // Oops, this is the response bytes.
    }
    return NULL;
}

static Boolean openStream(CFReadStreamRef readStream, CFStreamError *error, Boolean *openCompleted, void *data) {
    _SpdyCFStream *ctx = (_SpdyCFStream *)data;
    *openCompleted = ctx.opened;
    // TODO(jim): The request should be submitted now instead of at create time.
    return [ctx assignCFStreamError:error];
}

static Boolean openStreamCompleted(CFReadStreamRef readStream, CFStreamError *error, void *data) {
    _SpdyCFStream *ctx = (_SpdyCFStream *)data;
    [ctx assignCFStreamError:error];
    return ctx.opened;
}

static CFIndex readFromStream(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength, CFStreamError *error, Boolean *atEOF, void *data) {
    _SpdyCFStream *ctx = (_SpdyCFStream *)data;
    [ctx assignCFStreamError:error];
    CFIndex r = CFReadStreamRead(ctx.readStreamPair, buffer, bufferLength);
    *atEOF = (r == 0);
    return r;
}

static Boolean canRead(CFReadStreamRef stream, void *data) {
    _SpdyCFStream *ctx = (_SpdyCFStream *)data;
    return ctx.opened;
}

static void scheduleStream(CFReadStreamRef stream, CFRunLoopRef runLoop, CFStringRef runLoopMode, void *data) {
    _SpdyCFStream *ctx = (_SpdyCFStream *)data;

    // The streams are handled by SpdySession.  Flow control may require scheduling and unscheduling.
    // Schedule the readStream pair here.
    CFReadStreamScheduleWithRunLoop(ctx.readStreamPair, runLoop, runLoopMode);
}

static void UnscheduleStream(CFReadStreamRef stream, CFRunLoopRef runLoop, CFStringRef runLoopMode, void *data) {
    _SpdyCFStream *ctx = (_SpdyCFStream *)data;

    // Unschedule the readStream pair here.
    CFReadStreamUnscheduleFromRunLoop(ctx.readStreamPair, runLoop, runLoopMode);
}

static void closeStream(CFReadStreamRef stream, void *data) {
    _SpdyCFStream *ctx = (_SpdyCFStream *)data;
    CFReadStreamClose(ctx.readStreamPair);
}

CFReadStreamRef SpdyCreateSpdyReadStream(CFAllocatorRef alloc, CFHTTPMessageRef requestHeaders, CFReadStreamRef requestBody) {
    _SpdyCFStream *ctx = [[_SpdyCFStream alloc]init:alloc];
    if (ctx) {
        _CFReadStreamCallBacksV0Copy callbacks;        
        memset(&callbacks, 0, sizeof(callbacks));

        // version = 1 supports setProperty, v0 does not.
        callbacks.version = 0;
        callbacks.open = openStream;;
        callbacks.openCompleted = openStreamCompleted;
        callbacks.read = readFromStream;
        callbacks.canRead = canRead;
        callbacks.close = closeStream;
        callbacks.copyProperty = copyProperty;
        callbacks.schedule = scheduleStream;
        callbacks.unschedule = UnscheduleStream;
                         
        CFReadStreamRef result = CFReadStreamCreate(alloc, &callbacks, ctx);
        SPDY *spdy = [SPDY sharedSPDY];
        [spdy fetchFromMessage:requestHeaders delegate:ctx];
        return result;
     }
     return NULL;
}
                         

