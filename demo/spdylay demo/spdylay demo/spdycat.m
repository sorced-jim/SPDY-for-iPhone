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

#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h>


#import "WSSpdySession.h"
#import "WSSpdyStream.h"

#include "openssl/ssl.h"
#include "openssl/err.h"
#include "spdylay/spdylay.h"

@interface ExitLoop : RequestCallback {
    spdycat* _sc;
    RequestCallback* delegate;
}

@property (retain) RequestCallback* delegate;

@end


@implementation ExitLoop

@synthesize delegate;

- (id)init:(spdycat*) sc delegate:(RequestCallback*)d {
    self = [super init];
    _sc = sc;
    [self setDelegate:d];
    return self;
}

- (void)onResponseBody:(NSInputStream *)readStream {
    [delegate onResponseBody:readStream];
    if ([_sc decrementRequestCount]) {
        NSLog(@"Stopping run loop since all streams done.");
        CFRunLoopStop(CFRunLoopGetMain());
    }
}

@end

@implementation spdycat {
}

- (BOOL)decrementRequestCount {
    --requestCount;
    return requestCount == 0;
}

- (void)fetch:(NSString *)url delegate:(RequestCallback *)delegate {
    NSURL* u = [[NSURL URLWithString:url] autorelease];
    if (u == nil) {
        [self decrementRequestCount];
        return;
    }
    
    WSSpdySession* session = [sessions objectForKey:[u host]];
    if (session == nil) {
        session = [[[WSSpdySession alloc]init] autorelease];
        if (![session connect:u]) {
            [self decrementRequestCount];
            return;
        }
        [sessions setObject:session forKey:[u host]];
        [session addToLoop];
    }
    ExitLoop* el = [[[ExitLoop alloc]init:self delegate:delegate] autorelease];
    [delegates addObject:el];
    [session fetch:u delegate:el];
}

- (spdycat*) init:(NSInteger)count {
    self = [super init];
    sessions = [[[NSMutableDictionary alloc]init] retain];
    delegates = [[[NSMutableArray alloc]initWithCapacity:count] retain];
    requestCount = count;
    return self;
}

- (void)dealloc {
    [sessions release];
    [delegates release];
}
@end

@implementation RequestCallback

- (void)onResponseBody:(NSInputStream *)readStream {
    
}

- (void)onResponseHeaders {
    
}
@end
