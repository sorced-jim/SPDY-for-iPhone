//
//  SpdyUrlConnection.h
//  SPDY
//
//  Created by Jim Morrison on 4/2/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SPDY.h"

@interface SpdyUrlConnection : NSURLProtocol

// Registers and unregisters the SpdyUrlConnection with NSURLProtocol.  Any hosts found not to support spdy after register is called
// are cleared when unregister is called.
+ (void)registerSpdy;
+ (void)unregister;

@property (assign) id<SpdyRequestIdentifier> spdyIdentifier;
@property (assign, readonly) BOOL cancelled;
@property (assign) BOOL closed;

@end
