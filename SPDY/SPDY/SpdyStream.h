//
//  SpdyStream.h
//  A stream class the corresponds to an HTTP request and response.
//
//  Created by Jim Morrison on 2/7/12.
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
#import "SPDY.h"

@class RequestCallback;
@class SpdySession;

@interface SpdyStream : NSObject<SpdyRequestIdentifier> {
    const char **nameValues;
    NSURL *url;

    BOOL streamClosed;
    RequestCallback *delegate;
}

// To be used by the SPDY session.
- (void)parseHeaders:(const char **)nameValuePairs;
- (size_t)writeBytes:(const uint8_t *)data len:(size_t) length;
- (void)closeStream;
- (void)cancelStream;

// Close forwards back to the parent session.
- (void)close;

// Error case handlers used by the SPDY session.
- (void)notSpdyError;
- (void)connectionError;

+ (SpdyStream*)newFromCFHTTPMessage:(CFHTTPMessageRef)msg delegate:(RequestCallback*)delegate body:(NSInputStream *)body;
+ (SpdyStream*)newFromNSURL:(NSURL *)url delegate:(RequestCallback*)delegate;

@property const char **nameValues;
@property (retain) NSURL *url;
@property (retain) RequestCallback *delegate;
@property (retain) NSInputStream *body;
@property (assign) NSInteger streamId;
@property (retain) SpdySession *parentSession;

@end


