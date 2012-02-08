//
//  WSSpdySession.h
//  spdylay demo
//
//  Created by Jim Morrison on 2/8/12.
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

#import <Foundation/Foundation.h>
#include "openssl/ssl.h"
#include "spdylay/spdylay.h"

@class RequestCallback;

@interface WSSpdySession : NSObject {
    NSURL* host;
    CFSocketRef socket;
    SSL* ssl;
    SSL_CTX* ssl_ctx;
    spdylay_session *session;
    spdylay_session_callbacks *callbacks;
    
    BOOL spdy_negotiated;
    NSInteger streamCount;
    NSInteger nextStreamId;
}

@property BOOL spdy_negotiated;
@property NSInteger streamCount;
@property spdylay_session *session;
@property (retain) NSURL* host;

- (BOOL)connect:(NSURL*) host;
- (void)fetch:(NSURL*) path delegate:(RequestCallback*)delegate;
- (void)addToLoop;

@end
