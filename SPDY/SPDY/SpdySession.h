//
//  SpdySession.h
//  SPDY library.  This file contains a class for a spdy session (a network connection).
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

@class RequestCallback;
@class SpdyStream;

struct spdylay_session;
enum ConnectState {
    NOT_CONNECTED,
    CONNECTING,
    SSL_HANDSHAKE,
    CONNECTED,
    ERROR,
};

typedef enum {
    kSpdyNotReachable = 0,
    kSpdyReachableViaWWAN,
    kSpdyReachableViaWiFi	
} SpdyNetworkStatus;

@interface SpdySession : NSObject {
    struct spdylay_session *session;
    
    BOOL spdyNegotiated;
    enum ConnectState connectState;
    SpdyNetworkStatus networkStatus;
}

@property BOOL spdyNegotiated;
@property struct spdylay_session *session;
@property (retain) NSURL *host;
@property enum ConnectState connectState;
@property SpdyNetworkStatus networkStatus;

// Returns nil if the session is able to start a connection to host.
- (NSError *)connect:(NSURL *)host;
- (void)fetch:(NSURL *)path delegate:(RequestCallback *)delegate;
- (void)fetchFromMessage:(CFHTTPMessageRef)request delegate:(RequestCallback *)delegate body:(NSInputStream *)body;
- (void)fetchFromRequest:(NSURLRequest *)request delegate:(RequestCallback *)delegate;
- (void)addToLoop;

- (NSInteger)resetStreamsAndGoAway;

// Indicates if the session has entered an invalid state.
- (BOOL)isInvalid;

// Used by the SpdyStream
- (void)cancelStream:(SpdyStream *)stream;

@end
