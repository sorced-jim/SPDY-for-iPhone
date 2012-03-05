//
//      File: SpdyInputStream.h
//  Abstract: An input stream that wraps another input stream
//  and allows any property to be set.  No verification is
//  done on the properties that are set.
//
//  Created by Jim Morrison on 2/29/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPDY.h"

@interface SpdyInputStream : NSInputStream<NSStreamDelegate>
- (SpdyInputStream *)init:(NSInputStream *)parent;

@property (retain) NSError *error;
@property (retain) id<SpdyRequestIdentifier> requestId;

@end
