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
#import <SystemConfiguration/SystemConfiguration.h>
#import <CFNetwork/CFNetwork.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h>

#include "openssl/ssl.h"
#import "SpdySession.h"
#import "SpdyInputStream.h"
#import "SpdyStream.h"
#import "SpdyUrlConnection.h"

// The shared spdy instance.
static SPDY *spdy = NULL;
NSString *kSpdyErrorDomain = @"SpdyErrorDomain";
NSString *kOpenSSLErrorDomain = @"OpenSSLErrorDomain";

@interface SessionKey : NSObject<NSCopying>
- (SessionKey *)initFromUrl:(NSURL *)url;
- (NSUInteger)hash;
- (BOOL)isEqual:(id)other;
- (BOOL)isEqualToKey:(SessionKey *)other;
- (id)copyWithZone:(NSZone *)zone;

@property (retain) NSString *host;
@property (retain) NSNumber *port;
@end

@implementation SessionKey
@synthesize host;
@synthesize port;

- (SessionKey *)initFromUrl:(NSURL *)url {
    self.host = url.host;
    self.port = url.port;
    return self;
}

- (void)dealloc {
    self.host = nil;
    self.port = nil;
    [super dealloc];
}

- (NSUInteger)hash {
    return [host hash] + [port hash];
}

- (BOOL)isEqual:(id)other {
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
    return [self isEqualToKey:other];
}

- (BOOL)isEqualToKey:(SessionKey *)other {
    return [host isEqualToString:other.host] && [port isEqualToNumber:other.port];
}

- (id)copyWithZone:(NSZone *)zone {
    SessionKey *other = [SessionKey allocWithZone:zone];
    other.host = [self.host copyWithZone:zone];
    other.port = [self.port copyWithZone:zone];
    return other;
}

@end

@interface SPDY ()
- (void)fetchFromMessage:(CFHTTPMessageRef)request delegate:(RequestCallback *)delegate body:(NSInputStream *)body;
+ (enum SpdyNetworkStatus)reachabilityStatusForHost:(NSString *)host;
@end

@implementation SPDY {
    NSMutableDictionary *sessions;
}

+ (enum SpdyNetworkStatus)reachabilityStatusForHost:(NSString *)host {	
	SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithName(NULL, [host UTF8String]);
	if (ref) {
        SCNetworkReachabilityFlags flags = 0;
        if (SCNetworkReachabilityGetFlags(ref, &flags)) {
            if (flags & kSCNetworkReachabilityFlagsReachable) {
                if (flags & kSCNetworkReachabilityFlagsIsWWAN)
                    return kSpdyReachableViaWWAN;
                return kSpdyReachableViaWiFi;
            }
        }
        
        CFRelease(ref);
    }
    return kSpdyNotReachable;
}


- (SpdySession *)getSession:(NSURL *)url withError:(NSError **)error {
    SessionKey *key = [[[SessionKey alloc] initFromUrl:url] autorelease];
    SpdySession *session = [sessions objectForKey:key];
    enum SpdyNetworkStatus currentStatus = [self.class reachabilityStatusForHost:key.host];
    if (session != nil && ([session isInvalid] || currentStatus != session.networkStatus)) {
        [session resetStreamsAndGoAway];
        [sessions removeObjectForKey:key];
        session = nil;
    }
    if (session == nil) {
        session = [[[SpdySession alloc] init] autorelease];
        *error = [session connect:url];
        if (*error != nil) {
            NSLog(@"Could not connect to %@ because %@", url, *error);
            return nil;
        }
        session.networkStatus = currentStatus;
        [sessions setObject:session forKey:key];
        [session addToLoop];
    }
    return session;
}

- (void)fetch:(NSString *)url delegate:(RequestCallback *)delegate {
    NSURL *u = [NSURL URLWithString:url];
    if (u == nil || u.host == nil) {
        NSError *error = [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork code:kCFHostErrorHostNotFound userInfo:nil];
        [delegate onError:error];
        return;
    }
    NSError *error;
    SpdySession *session = [self getSession:u withError:&error];
    if (session == nil) {
        [delegate onError:error];
        return;
    }
    [session fetch:u delegate:delegate];
}

- (void)fetchFromMessage:(CFHTTPMessageRef)request delegate:(RequestCallback *)delegate {
    [self fetchFromMessage:request delegate:delegate body:nil];
}

- (void)fetchFromMessage:(CFHTTPMessageRef)request delegate:(RequestCallback *)delegate body:(NSInputStream *)body {
    CFURLRef url = CFHTTPMessageCopyRequestURL(request);
    NSError *error;
    SpdySession *session = [self getSession:(NSURL *)url withError:&error];
    if (session == nil) {
        [delegate onError:error];
    } else {
        [session fetchFromMessage:request delegate:delegate body:body];
    }
    CFRelease(url);    
}

- (void)fetchFromRequest:(NSURLRequest *)request delegate:(RequestCallback *)delegate {
    NSURL *url = [request URL];
    NSError *error;
    SpdySession *session = [self getSession:(NSURL *)url withError:&error];
    if (session == nil) {
        [delegate onError:error];
    } else {
        [session fetchFromRequest:request delegate:delegate];
    }
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
    [super dealloc];
}

+ (SPDY *)sharedSPDY {
    if (spdy == NULL) {
        SSL_library_init();
        spdy = [[SPDY alloc] init];
        [SpdyStream staticInit];
    }
    return spdy;
}

// These methods are object methods so that sharedSpdy is called before registering SpdyUrlConnection with NSURLConnection.
- (void)registerForNSURLConnection {
    [SpdyUrlConnection registerSpdy];
}

- (BOOL)isSpdyRegistered {
    return [SpdyUrlConnection isRegistered];
}

- (void)unregisterForNSURLConnection {
    [SpdyUrlConnection unregister];
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

- (void)onError:(NSError *)error {
    
}

- (void)onNotSpdyError:(id<SpdyRequestIdentifier>)identifier {
    
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
    [super dealloc];
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

- (void)onError:(NSError *)error {
    
}
@end

// Create a delegate derived class of RequestCallback.  Create a context struct.
// Convert this to an objective-C object that derives from RequestCallback.
@interface _SpdyCFStream : RequestCallback {
    CFWriteStreamRef writeStreamPair;  // read() will write into writeStreamPair.
    unsigned long long requestBytesWritten;
};

@property (assign) BOOL opened;
@property (assign) int error;
@property (retain) SpdyInputStream *readStreamPair;
@end


@implementation _SpdyCFStream

@synthesize opened;
@synthesize error;
@synthesize readStreamPair;

- (_SpdyCFStream *)init:(CFAllocatorRef)a {
    self = [super init];
    
    CFReadStreamRef baseReadStream;
    CFStreamCreateBoundPair(a, &baseReadStream, &writeStreamPair, 16 * 1024);
    self.readStreamPair = [[[SpdyInputStream alloc] init:(NSInputStream *)baseReadStream] autorelease];
    self.opened = NO;
    requestBytesWritten = 0;
    return self;
}

- (void)dealloc {
    self.readStreamPair.requestId = nil;
    if ([self.readStreamPair streamStatus] != NSStreamStatusClosed) {
        [self.readStreamPair close];
    }
    if (CFWriteStreamGetStatus(writeStreamPair) != kCFStreamStatusClosed) {
        CFWriteStreamClose(writeStreamPair);
    }
    CFRelease(writeStreamPair);
    self.readStreamPair = nil;
    [super dealloc];
}

- (void)setResponseHeaders:(CFHTTPMessageRef)h {
}

// Methods that implementors should override.
- (void)onConnect:(id<SpdyRequestIdentifier>)requestId {
    [self.readStreamPair setRequestId:requestId];
    CFWriteStreamOpen(writeStreamPair);
    self.opened = YES;
}

- (void)onRequestBytesSent:(NSInteger)bytesSend {
    requestBytesWritten += bytesSend;
    CFNumberRef totalBytes = CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &requestBytesWritten);
    CFReadStreamSetProperty((CFReadStreamRef)readStreamPair, kCFStreamPropertyHTTPRequestBytesWrittenCount, totalBytes);
    CFRelease(totalBytes);
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    CFReadStreamSetProperty((CFReadStreamRef)readStreamPair, kCFStreamPropertyHTTPResponseHeader, headers);
}

- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length {
    // TODO(jim): Ensure that any errors from write() get transfered to the SpdyStream.
    return CFWriteStreamWrite(writeStreamPair, bytes, length);
}

- (void)onStreamClose {
    self.opened = NO;
    CFWriteStreamClose(writeStreamPair);
}

- (void)onNotSpdyError:(id<SpdyRequestIdentifier>)identifier {
    self.readStreamPair.error = [NSError errorWithDomain:kSpdyErrorDomain code:kSpdyConnectionNotSpdy userInfo:[NSDictionary dictionaryWithObject:[identifier url] forKey:@"url"]];
}

- (void)onError:(NSError *)error_code {
    self.readStreamPair.error = error_code;
    self.opened = NO;
}

@end

CFReadStreamRef SpdyCreateSpdyReadStream(CFAllocatorRef alloc, CFHTTPMessageRef requestHeaders, CFReadStreamRef requestBody) {
    _SpdyCFStream *ctx = [[[_SpdyCFStream alloc] init:alloc] autorelease];
    if (ctx) {
        SPDY *spdy = [SPDY sharedSPDY];
        [spdy fetchFromMessage:requestHeaders delegate:ctx body:(NSInputStream *)requestBody];
        return (CFReadStreamRef)[[ctx readStreamPair] retain];
     }
     return NULL;
}
                         

