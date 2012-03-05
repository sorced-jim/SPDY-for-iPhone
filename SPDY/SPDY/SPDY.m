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
#import "SpdyInputStream.h"

// The shared spdy instance.
static SPDY *spdy = NULL;
CFStringRef kSpdyErrorDomain = CFSTR("SpdyErrorDomain");

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
    if (session != nil && [session isInvalid]) {
        [sessions removeObjectForKey:[url host]];
        session = nil;
    }
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
        CFErrorRef error = CFErrorCreate(kCFAllocatorDefault, kCFErrorDomainCFNetwork, kCFHostErrorHostNotFound, NULL);
        [delegate onError:error];
        CFRelease(error);
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

- (NSInteger)closeAllSessions {
    NSInteger cancelledRequests = 0;
    NSEnumerator *enumerator = [sessions objectEnumerator];
    SpdySession *session;
    
    while ((session = (SpdySession *)[enumerator nextObject])) {
        cancelledRequests += [session resetStreamsAndGoAway];
    }
    [sessions removeAllObjects];
    return cancelledRequests;
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

- (void)onRequestBytesSent:(NSInteger)bytesSend {
    
}

- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length {
    return length;
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
}

- (void)onError:(CFErrorRef)error {
    
}

- (void)onNotSpdyError {
    
}

- (void)onStreamClose {
    
}

- (void)onConnect:(id<SpdyRequestIdentifier>)url {
    
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

- (void)onConnect:(id<SpdyRequestIdentifier>)u {
    self.url = u.url;
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

- (void)onError:(CFErrorRef)error {
    
}
@end

// Create a delegate derived class of RequestCallback.  Create a context struct.
// Convert this to an objective-C object that derives from RequestCallback.
@interface _SpdyCFStream : RequestCallback {
    CFReadStreamRef readStreamPair;
    CFWriteStreamRef writeStreamPair;  // read() will write into writeStreamPair.
    unsigned long long requestBytesWritten;
};

@property (assign) BOOL opened;
@property (assign) int error;
@property (assign) CFReadStreamRef readStreamPair;
@end


@implementation _SpdyCFStream

@synthesize opened;
@synthesize error;
@synthesize readStreamPair;

- (_SpdyCFStream *)init:(CFAllocatorRef)a {
    self = [super init];
    
    CFReadStreamRef baseReadStream;
    CFStreamCreateBoundPair(a, &baseReadStream, &writeStreamPair, 16 * 1024);
    readStreamPair = (CFReadStreamRef)[[SpdyInputStream alloc]init:(NSInputStream *)baseReadStream];
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
}

// Methods that implementors should override.
- (void)onConnect:(id<SpdyRequestIdentifier>)url {
    CFWriteStreamOpen(writeStreamPair);
    self.opened = YES;
}

- (void)onRequestBytesSent:(NSInteger)bytesSend {
    requestBytesWritten += bytesSend;
    CFNumberRef totalBytes = CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &requestBytesWritten);
    CFReadStreamSetProperty(readStreamPair, kCFStreamPropertyHTTPRequestBytesWrittenCount, totalBytes);
    CFRelease(totalBytes);
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    CFReadStreamSetProperty(readStreamPair, kCFStreamPropertyHTTPResponseHeader, headers);
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

- (void)onError:(CFErrorRef)error_code {
    self.error = CFErrorGetCode(error_code);
    self.opened = NO;
}

@end

CFReadStreamRef SpdyCreateSpdyReadStream(CFAllocatorRef alloc, CFHTTPMessageRef requestHeaders, CFReadStreamRef requestBody) {
    _SpdyCFStream *ctx = [[_SpdyCFStream alloc]init:alloc];
    if (ctx) {
        SPDY *spdy = [SPDY sharedSPDY];
        [spdy fetchFromMessage:requestHeaders delegate:ctx];
        return [ctx readStreamPair];
     }
     return NULL;
}
                         

