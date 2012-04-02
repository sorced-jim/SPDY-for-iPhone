//
//  SpdyUrlConnection.h
//  SPDY
//
//  Created by Jim Morrison on 4/2/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SPDY.h"

@interface SpdyUrlConnection : NSURLProtocol

+ (void)register;

@property (assign) id<SpdyRequestIdentifier> spdyIdentifier;

@end
