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

@implementation spdycat {
    NSMutableDictionary* sessions;
}

@synthesize show_headers;

- (void)fetch:(NSString *)url delegate:(RequestCallback *)delegate {
    NSURL* u = [[NSURL URLWithString:url] autorelease];
    WSSpdySession* session = [sessions objectForKey:[u host]];
    if (session == nil) {
        session = [[[WSSpdySession alloc]init] autorelease];
        if (![session connect:u]) {
            return;
        }
        [sessions setObject:session forKey:[u host]];
        [session addToLoop];
    }
    [session fetch:u delegate:delegate];
}

- (spdycat*) init {
    self = [super init];
    sessions = [[[NSMutableDictionary alloc]init] autorelease];
    return self;
}

- (void)dealloc {
}
@end

@implementation RequestCallback

- (void)onResponseBody:(NSInputStream *)readStream {
    
}

- (void)onResponseHeaders {
    
}
@end
