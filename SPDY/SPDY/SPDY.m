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

#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h>

#include "openssl/ssl.h"
#import "SpdySession.h"


@implementation SPDY {
    NSMutableDictionary* sessions;
}

- (SpdySession*)getSession:(NSURL*) url {
    SpdySession* session = [sessions objectForKey:[url host]];
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
    NSURL* u = [[NSURL URLWithString:url] autorelease];
    if (u == nil) {
        [delegate onError];
        return;
    }
    SpdySession *session = [self getSession:u];
    if (session == nil) {
        [delegate onNotSpdyError];
        return;
    }
    [delegate onConnect:u];
    [session fetch:u delegate:delegate];
}

- (void)fetchFromMessage:(CFHTTPMessageRef)request delegate:(RequestCallback *)delegate {
    CFURLRef url = CFHTTPMessageCopyRequestURL(request);
    SpdySession* session = [self getSession:(NSURL*)url];
    if (session == nil) {
        [delegate onNotSpdyError];
    } else {
        [delegate onConnect:(NSURL*)url];
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

- (size_t)onResponseData:(const uint8_t*)bytes length:(size_t)length {
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

- (void)onConnect:(NSURL*)url {
    
}
@end

@implementation BufferedCallback {
    CFMutableDataRef body;
    CFHTTPMessageRef headers;
    NSURL* _url;
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
    CFRelease(headers);
}

- (void)onConnect:(NSURL*)u {
    self.url = u;
}

-(void)onResponseHeaders:(CFHTTPMessageRef)h {
    headers = CFHTTPMessageCreateCopy(NULL, h);
    CFRetain(headers);
}

- (size_t)onResponseData:(const uint8_t*)bytes length:(size_t)length {
    CFDataAppendBytes(body, bytes, length);
    return length;
}

- (void)onStreamClose {
    CFHTTPMessageSetBody(headers, body);
    [self onResponse:headers];
}

- (void)onResponse:(CFHTTPMessageRef)response {
    
}

- (void)onError {
    
}
@end
