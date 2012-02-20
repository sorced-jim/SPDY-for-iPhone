//
//  SpdySessionTests.m
//  SPDY
//
//  Created by Jim Morrison on 2/20/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SpdySessionTests.h"
#import "spdySession.h"

@implementation SpdySessionTests

- (void)testReleaseWithNoConnection {
    SpdySession *session = [[SpdySession alloc]init];
    [session release];
}

@end
