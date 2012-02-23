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

- (SPDY*) init {
    SSL_library_init();
    self = [super init];
    sessions = [[NSMutableDictionary alloc]init];
    return self;
}

- (void)dealloc {
    [sessions release];
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
struct _SpdyContext {
    BufferedCallback *delegate;
    CFAllocatorRef alloc;
    CFReadStreamRef readStreamPair;
    CFWriteStreamRef writeStreamPair;  // read() will write into writeStreamPair.
    SpdyStream *stream;
    SpdySession *session;
};

static void deallocContext(struct _SpdyContext *ctx) {
    CFRelease(ctx->alloc);
    CFRelease(ctx->readStreamPair);
    CFRelease(ctx->writeStreamPair);
    [ctx->delegate release];
}

static CFTypeRef copyProperty(CFReadStreamRef readStream, CFStringRef property, void *data) {
    struct _SpdyContext *ctx = (struct _SpdyContext *)data;
    if (CFEqual(property, kCFStreamPropertyHTTPResponseHeader)) {
        if (ctx->delegate.headers != NULL) {
            return CFRetain(ctx->delegate.headers);
        }
    }
    if (CFEqual(property, kCFStreamPropertyHTTPRequestBytesWrittenCount)) {
        //return CFDataGetLength([ctx->delegate body]);  // Oops, this is the response bytes.
    }
    return NULL;
}

static Boolean openStream(CFReadStreamRef readStream, CFStreamError *error, Boolean *openCompleted, void *data) {
    struct _SpdyContext *ctx = (struct _SpdyContext *)data;
    // submit the request.
    return NO;
}

static Boolean openStreamCompleted(CFReadStreamRef readStream, CFStreamError *error, void *data) {
    struct _SpdyContext *ctx = (struct _SpdyContext *)data;
    // Check if stream has been submitted.
    return NO;    
}

static CFIndex readFromStream(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength, CFStreamError *error, Boolean *atEOF, void *data) {
    struct _SpdyContext *ctx = (struct _SpdyContext *)data;
    // Get stream body and read from that.
    return -1;
}

static Boolean canRead(CFReadStreamRef stream, void *data) {
    struct _SpdyContext *ctx = (struct _SpdyContext *)data;
    // Check that the ctx->stream body exists.
    return NO;
}

static void scheduleStream(CFReadStreamRef stream, CFRunLoopRef runLoop, CFStringRef runLoopMode, void *data) {
    struct _SpdyContext *ctx = (struct _SpdyContext *)data;

    // The streams are handled by SpdySession.  Flow control may require scheduling and unscheduling.
    // Schedule the readStream pair here.
    CFReadStreamScheduleWithRunLoop(ctx->readStreamPair, runLoop, runLoopMode);
}

static void UnscheduleStream(CFReadStreamRef stream, CFRunLoopRef runLoop, CFStringRef runLoopMode, void *data) {
    struct _SpdyContext *ctx = (struct _SpdyContext *)data;

    // Unschedule the readStream pair here.
    CFReadStreamUnscheduleFromRunLoop(ctx->readStreamPair, runLoop, runLoopMode);
}

static void closeStream(CFReadStreamRef stream, void *data) {
    
}

CFReadStreamRef SpdyCreateSpdyReadStream(CFAllocatorRef alloc, CFHTTPMessageRef requestHeaders, CFReadStreamRef requestBody) {
    struct _SpdyContext *ctx = (struct _SpdyContext *)CFAllocatorAllocate(alloc, sizeof(*ctx), 0);
    if (ctx) {
        memset(ctx, 0, sizeof(*ctx));
        ctx->alloc = CFRetain(alloc);
        ctx->delegate = [[BufferedCallback alloc]init];
        _CFReadStreamCallBacksV0Copy callbacks;
        
        CFReadStreamRef readStreamPair;
        CFWriteStreamRef writeStreamPair;
        
        CFStreamCreateBoundPair(alloc, &readStreamPair, &writeStreamPair, 16 * 1024);
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
        return result;
                         
     }
     return NULL;
}
                         

