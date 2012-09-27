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

extern NSString *kSpdyErrorDomain;
extern NSString *kOpenSSLErrorDomain;

enum SpdyErrors {
    kSpdyConnectionOk = 0,
    kSpdyConnectionFailed = 1,
    kSpdyRequestCancelled = 2,
    kSpdyConnectionNotSpdy = 3,
    kSpdyInvalidResponseHeaders = 4,
};

@protocol SpdyRequestIdentifier <NSObject>
- (NSURL *)url;
- (void)close;
@end

@protocol SpdyUrlConnectionCallback <NSObject>

- (BOOL)shouldUseSpdyForUrl:(NSURL *)url;

@end

// The SpdyLogger protocol is used to log from the spdy library.  The default SpdyLogger prints out ugly logs with NSLog.  You'll probably
// want to override the default.
@protocol SpdyLogger
- (void)writeSpdyLog:(NSString *)format file:(const char *)file line:(int)line, ...;
@end

@interface SPDY : NSObject

+ (SPDY *)sharedSPDY;

// Call registerForNSURLConnection to enable spdy when using NSURLConnection.  SPDY responses can be identified (in iOS 5.0+) by looking for
// the @"protocol-was: spdy" header with the value @"YES".  "protocol-was: spdy" is not a valid http header, thus it is safe to add it.
// WARNING: Using NSURLConnection means that upload progress can not be monitored.  This is because of a lack of an API in URLProtocolClient.
- (void)registerForNSURLConnection;

// Like registerForNSURLConnection but callback is called for each request.  Callback is retained.
- (void)registerForNSURLConnectionWithCallback:(id <SpdyUrlConnectionCallback>)callback;
- (BOOL)isSpdyRegistered;
- (BOOL)isSpdyRegisteredForUrl:(NSURL *)url;
- (void)unregisterForNSURLConnection;

// A reference to delegate is kept until the stream is closed.  The caller will get an onError or onStreamClose before the stream is closed.
- (void)fetch:(NSString *)path delegate:(RequestCallback *)delegate;
- (void)fetchFromMessage:(CFHTTPMessageRef)request delegate:(RequestCallback *)delegate;
- (void)fetchFromRequest:(NSURLRequest *)request delegate:(RequestCallback *)delegate;

// Cancels all active requests and closes all connections.  Returns the number of requests that were cancelled.  Ideally this should be called when all requests have already been canceled.
- (NSInteger)closeAllSessions;

@property (retain) NSObject<SpdyLogger> *logger;
@end

@interface RequestCallback : NSObject {
}

// Methods that implementors should override.
- (void)onConnect:(id<SpdyRequestIdentifier>)identifier;
- (void)onRequestBytesSent:(NSInteger)bytesSend;
- (void)onResponseHeaders:(CFHTTPMessageRef)headers;
- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length;
- (void)onStreamClose;
- (void)onNotSpdyError:(id<SpdyRequestIdentifier>)identifier;

- (void)onError:(NSError *)error;

@end

@interface BufferedCallback : RequestCallback {
}

// Derived classses should override these methods since BufferedCallback overrides the rest of the callbacks from RequestCallback.
- (void)onResponse:(CFHTTPMessageRef)response;
- (void)onError:(NSError *)error;

@property (nonatomic, retain) NSURL *url;

@end

#define SPDY_LOG(fmt, ...) do { \
  [[SPDY sharedSPDY].logger writeSpdyLog:fmt file:__FILE__ line:__LINE__, ##__VA_ARGS__];\
  if (0) NSLog(fmt, ## __VA_ARGS__); \
} while (0);

#define SPDY_DEBUG_LOG(fmt, ...) do { \
    [[SPDY sharedSPDY].logger writeSpdyLog:fmt file:__FILE__ line:__LINE__, ##__VA_ARGS__];\
    if (0) NSLog(fmt, ## __VA_ARGS__); \
} while (0);
