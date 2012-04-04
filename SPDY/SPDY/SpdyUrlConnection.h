//
//  SpdyUrlConnection.h
//  SPDY
//
//  Created by Jim Morrison on 4/2/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SPDY.h"

// This class exists because NSHTTPURLResponse does not have a useful constructor in iOS 4.3 and below.
@interface SpdyUrlResponse : NSURLResponse
@property (assign) NSInteger statusCode;
@property (retain) NSDictionary *allHeaderFields;
@property (assign) NSInteger requestBytes;

- (id)initWithURL:(NSURL *)url withResponse:(CFHTTPMessageRef)headers;
@end

@interface SpdyUrlConnection : NSURLProtocol

// Registers and unregisters the SpdyUrlConnection with NSURLProtocol.  Any hosts found not to support spdy after register is called
// are cleared when unregister is called.
+ (void)registerSpdy;
+ (BOOL)isRegistered;
+ (void)unregister;

@property (assign) id<SpdyRequestIdentifier> spdyIdentifier;
@property (assign, readonly) BOOL cancelled;
@property (assign) BOOL closed;

@end
