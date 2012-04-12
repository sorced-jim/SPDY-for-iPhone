//
//  SpdyUrlConnection.m
//  NOTE: iOS makes a copy of the return value of responseWithURL:withResponse:withRequestBytes, so the original type is
//  lost.
//
//  Created by Jim Morrison on 4/2/12.
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

#import "SpdyUrlConnection.h"
#import "SPDY.h"
#include "zlib.h"

// This is actually a dictionary of sets.  The first set is the host names, the second is a set of ports.
static NSMutableDictionary *disabledHosts;


@implementation SpdyUrlResponse
@synthesize statusCode = _statusCode;
@synthesize allHeaderFields = _allHeaderFields;
@synthesize requestBytes = _requestBytes;

+ (NSHTTPURLResponse *)responseWithURL:(NSURL *)url withResponse:(CFHTTPMessageRef)headers withRequestBytes:(NSInteger)requestBytesSent {
    NSMutableDictionary *headersDict = [[[NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(headers)) autorelease] mutableCopy] autorelease];
    [headersDict setObject:@"YES" forKey:@"protocol-was: spdy"];
    NSNumberFormatter *f = [[[NSNumberFormatter alloc] init] autorelease];
    NSString *contentType = [headersDict objectForKey:@"content-type"];
    NSString *contentLength = [headersDict objectForKey:@"content-length"];
    NSNumber *length = [f numberFromString:contentLength];
    NSInteger statusCode = CFHTTPMessageGetResponseStatusCode(headers);
    NSString *version = [NSMakeCollectable(CFHTTPMessageCopyVersion(headers)) autorelease];
    if ([[NSHTTPURLResponse class] instancesRespondToSelector:@selector(initWithURL:statusCode:HTTPVersion:headerFields:)]) {
        return [[[NSHTTPURLResponse alloc] initWithURL:url statusCode:statusCode  HTTPVersion:version headerFields:headersDict] autorelease];
    }
    
    SpdyUrlResponse *response = [[[SpdyUrlResponse alloc] initWithURL:url MIMEType:contentType expectedContentLength:[length intValue] textEncodingName:nil] autorelease];
    response.statusCode = statusCode;
    response.allHeaderFields = headersDict;
    response.requestBytes = requestBytesSent;
    return response;
}

@end

@interface SpdyUrlCallback : RequestCallback
- (id)initWithConnection:(SpdyUrlConnection *)protocol;
@property (retain) SpdyUrlConnection *protocol;
@property (assign) NSInteger requestBytesSent;
@end

@implementation SpdyUrlCallback
@synthesize protocol = _protocol;
@synthesize requestBytesSent = _requestBytesSent;

- (id)initWithConnection:(SpdyUrlConnection *)protocol {
    self = [super init];
    if (self != nil) {
        self.protocol = protocol;
    }
    return self;
}

- (void)onConnect:(id<SpdyRequestIdentifier>)spdyId {
    self.protocol.spdyIdentifier = spdyId;
    if (self.protocol.cancelled) {
        [spdyId close];
    }
}

- (void)onError:(NSError *)error {
    if (!self.protocol.cancelled) {
        [[self.protocol client] URLProtocol:self.protocol didFailWithError:error];
    }
}

- (void)onNotSpdyError:(id<SpdyRequestIdentifier>)identifier {
    NSURL *url = [identifier url];
    [SpdyUrlConnection disableUrl:url];
    NSError *error = [NSError errorWithDomain:kSpdyErrorDomain code:kSpdyConnectionNotSpdy userInfo:nil];
    [[self.protocol client] URLProtocol:self.protocol didFailWithError:error];    
}

- (void)onRequestBytesSent:(NSInteger)bytesSend {
    // The updated byte count should be sent, but the URLProtocolClient doesn't have a method to do that.
    //[[self.protocol client] URLProtocol:self.protocol didSendBodyData:bytesSend];
    self.requestBytesSent += bytesSend;
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    NSHTTPURLResponse *response = [SpdyUrlResponse responseWithURL:[self.protocol.spdyIdentifier url] withResponse:headers withRequestBytes:self.requestBytesSent];
    [[self.protocol client] URLProtocol:self.protocol didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length {
    NSData *data = [NSData dataWithBytes:bytes length:length];
    [[self.protocol client] URLProtocol:self.protocol didLoadData:data];
    return length;
}

- (void)onStreamClose {
    self.protocol.closed = YES;
    [[self.protocol client] URLProtocolDidFinishLoading:self.protocol];
}

@end

@interface SpdyUrlConnection ()
@property (assign) BOOL cancelled;
@end

@implementation SpdyUrlConnection
@synthesize spdyIdentifier = _spdyIdentifier;
@synthesize cancelled = _cancelled;
@synthesize closed = _closed;

+ (void)registerSpdy {
    disabledHosts = [[NSMutableDictionary alloc] init];
    [NSURLProtocol registerClass:[SpdyUrlConnection class]];
}

+ (BOOL)isRegistered {
    return disabledHosts != nil;
}

+ (void)unregister {
    [NSURLProtocol unregisterClass:[SpdyUrlConnection class]];
    [disabledHosts release];
    disabledHosts = nil;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return [SpdyUrlConnection canInitWithUrl:[request URL]];
}

+ (BOOL)canInitWithUrl:(NSURL *)url {
    BOOL isHttps = [[[url scheme] lowercaseString] isEqualToString:@"https"];
    if (isHttps) {
        NSSet *ports = [disabledHosts objectForKey:[url host]];
        if (ports != nil) {
            NSNumber *port = [url port];
            if (port == nil)
                port = [NSNumber numberWithInt:443];
            if ([ports containsObject:port])
                return NO;
        }
        SPDY_LOG(@"Can use spdy for: %@", url);
        return YES;
    }
    return NO;
}

+ (void)disableUrl:(NSURL *)url {
    NSMutableSet *ports = [disabledHosts objectForKey:[url host]];
    if (ports == nil) {
        ports = [NSMutableSet set];
        [disabledHosts setObject:ports forKey:[url host]];
    }
    SPDY_LOG(@"Disabling spdy for %@", url);
    if ([url port] == nil) {
        [ports addObject:[NSNumber numberWithInt:80]];
        [ports addObject:[NSNumber numberWithInt:443]];
    } else {
        [ports addObject:[url port]];
    }
}

// This could be a good place to remove the connection headers.
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    SpdyUrlCallback *delegate = [[[SpdyUrlCallback alloc] initWithConnection:self] autorelease];
    [[SPDY sharedSPDY] fetchFromRequest:[self request] delegate:delegate];
}

- (void)stopLoading {
    if (self.closed)
        return;
    self.cancelled = YES;
    if (self.spdyIdentifier != nil) {
        SPDY_LOG(@"Cancelling request for %@", self.spdyIdentifier);
        [self.spdyIdentifier close];
    }
}

@end
