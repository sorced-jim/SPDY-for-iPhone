//
//  SpdyUrlConnectionTest.m
//  Tests for SpdyUrlConnectionTest.
//
//  Created by Jim Morrison on 4/4/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SpdyUrlConnectionTest.h"
#import "SpdyUrlConnection.h"

@implementation SpdyUrlConnectionTest

- (void)setUp {
    [SpdyUrlConnection registerSpdy];
}

- (void)tearDown {
    [SpdyUrlConnection unregister];
}

- (void)testDisableUrl {
    NSURL *url = [NSURL URLWithString:@"https://ww.g.ca/"];
    NSURL *url443 = [NSURL URLWithString:@"https://ww.g.ca:443/"];
    NSURL *url444 = [NSURL URLWithString:@"https://ww.g.ca:444/"];
    STAssertTrue([SpdyUrlConnection canInitWithUrl:url], @"%@", url);
    STAssertTrue([SpdyUrlConnection canInitWithUrl:url443], @"%@", url443);
    STAssertTrue([SpdyUrlConnection canInitWithUrl:url444], @"%@", url444);
    
    [SpdyUrlConnection disableUrl:url];
    STAssertFalse([SpdyUrlConnection canInitWithUrl:url], @"%@", url);
    STAssertFalse([SpdyUrlConnection canInitWithUrl:url443], @"%@", url443);    
    STAssertTrue([SpdyUrlConnection canInitWithUrl:url444], @"%@", url444);

    [SpdyUrlConnection disableUrl:url444];
    STAssertFalse([SpdyUrlConnection canInitWithUrl:url444], @"%@", url444);
}
@end
