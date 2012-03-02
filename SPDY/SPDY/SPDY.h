//
//  SPDY.h
//  SPDY library
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

#import <Foundation/Foundation.h>

@class RequestCallback;

// Returns a CFReadStream.  If requestBody is non-NULL the request method in requestHeaders must
// support a message body and the requestBody will override the body that may already be in requestHeaders.  If
// the request method in requestHeaders expects a body and requestBody is NULL then the body from requestHeaders
// will be used.
CFReadStreamRef SpdyCreateSpdyReadStream(CFAllocatorRef alloc, CFHTTPMessageRef requestHeaders, CFReadStreamRef requestBody);


@interface SPDY : NSObject {
}

+ (SPDY *)sharedSPDY;

// A reference to delegate is kept until the stream is closed.  The caller will get an onError or onResponseBody before the stream is closed.
- (void)fetch:(NSString *)path delegate:(RequestCallback *)delegate;
- (void)fetchFromMessage:(CFHTTPMessageRef)request delegate:(RequestCallback *)delegate;

@end

@interface RequestCallback : NSObject {
}

// Methods that implementors should override.
- (void)onConnect:(NSURL *)url;
- (void)onResponseHeaders:(CFHTTPMessageRef)headers;
- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length;
- (void)onStreamClose;
- (void)onNotSpdyError;
- (void)onError:(CFErrorRef)error;

@end

@interface BufferedCallback : RequestCallback {
}

// Derived classses should override these methods since BufferedCallback overrides the rest of the callbacks from RequestCallback.
- (void)onResponse:(CFHTTPMessageRef)response;
- (void)onError:(CFErrorRef)error;

@property (retain) NSURL *url;

@end
