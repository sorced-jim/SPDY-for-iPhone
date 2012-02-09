//
//  spdycat.m
//  spdylay demo
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

#import "spdycat.h"

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <CoreFoundation/CoreFoundation.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h>


#import "WSSpdySession.h"
#import "WSSpdyStream.h"

#include "openssl/ssl.h"
#include "openssl/err.h"
#include "spdylay/spdylay.h"

@implementation spdycat {
    NSMutableDictionary* sessions;
}

- (void)fetch:(NSString *)url delegate:(RequestCallback *)delegate {
    NSURL* u = [[NSURL URLWithString:url] autorelease];
    if (u == nil) {
        [delegate onError];
        return;
    }
    
    WSSpdySession* session = [sessions objectForKey:[u host]];
    if (session == nil) {
        session = [[[WSSpdySession alloc]init] autorelease];
        if (![session connect:u]) {
            [delegate onError];
            return;
        }
        [sessions setObject:session forKey:[u host]];
        [session addToLoop];
    }
    [session fetch:u delegate:delegate];
}

- (spdycat*) init {
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

- (void)onStreamClose {
    
}
@end

@implementation BufferedCallback {
    CFMutableDataRef body;
    CFHTTPMessageRef headers;
}

- (id)init {
    self = [super init];
    body = CFDataCreateMutable(NULL, 0);
    return self;
}

- (void)dealloc {
    CFRelease(body);
    CFRelease(headers);
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
