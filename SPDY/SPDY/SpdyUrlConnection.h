//
//  SpdyUrlConnection.h
//  An implementation of NSURLProtocol for Spdy.
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

#import "SPDY.h"

// This class exists because NSHTTPURLResponse does not have a useful constructor in iOS 4.3 and below.
@interface SpdyUrlResponse : NSHTTPURLResponse
@property (assign) NSInteger statusCode;
@property (retain) NSDictionary *allHeaderFields;
@property (assign) NSInteger requestBytes;

+ (NSHTTPURLResponse *)responseWithURL:(NSURL *)url withResponse:(CFHTTPMessageRef)headers withRequestBytes:(NSInteger)requestBytesSent;
@end

@interface SpdyUrlConnection : NSURLProtocol

// Registers and unregisters the SpdyUrlConnection with NSURLProtocol.  Any hosts found not to support spdy after register is called
// are cleared when unregister is called.
+ (void)registerSpdy;
+ (BOOL)isRegistered;
+ (void)unregister;

+ (void)disableUrl:(NSURL *)url;
+ (BOOL)canInitWithUrl:(NSURL *)url;

@property (assign) id<SpdyRequestIdentifier> spdyIdentifier;
@property (assign, readonly) BOOL cancelled;
@property (assign) BOOL closed;

@end
