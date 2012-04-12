//
//      File: SpdySessionKeyTests.m
//
//  Created by Erik Chen on 4/11/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SpdySessionKeyTests.h"
#import "SpdySessionKey.h"

@implementation SpdySessionKeyTests

- (void)testAssertOnInvalidURL {
    STAssertThrows([[SpdySessionKey alloc] initFromUrl:nil], @"It is not valid to try to create a key from a nil url");
}

- (void)testIsEqualDifferentHostName {
    NSURL *url1 = [NSURL URLWithString:@"http://google.com"];
    SpdySessionKey *key1 = [[[SpdySessionKey alloc] initFromUrl:url1] autorelease];
    
    NSURL *url2 = [NSURL URLWithString:@"http://yahoo.com"];
    SpdySessionKey *key2 = [[[SpdySessionKey alloc] initFromUrl:url2] autorelease];    
    
    STAssertFalse([key1 isEqualToKey:key2], @"key1 and key2 have different hostnames");
}

- (void)testIsEqualSameHostName {
    NSURL *url1 = [NSURL URLWithString:@"http://google.com"];
    SpdySessionKey *key1 = [[[SpdySessionKey alloc] initFromUrl:url1] autorelease];
    
    NSURL *url2 = [NSURL URLWithString:@"http://google.com"];
    SpdySessionKey *key2 = [[[SpdySessionKey alloc] initFromUrl:url2] autorelease];    
    
    STAssertNil(key1.port, @"No port was passed in");
    STAssertNil(key2.port, @"No port was passed in");
    STAssertTrue([key1 isEqualToKey:key2], @"key1 and key2 have the same hostname");    
}

- (void)testIsEqualDifferentPort {
    NSURL *url1 = [NSURL URLWithString:@"http://google.com:8080"];
    SpdySessionKey *key1 = [[[SpdySessionKey alloc] initFromUrl:url1] autorelease];
    
    NSURL *url2 = [NSURL URLWithString:@"http://google.com:333"];
    SpdySessionKey *key2 = [[[SpdySessionKey alloc] initFromUrl:url2] autorelease];    
    
    STAssertFalse([key1 isEqualToKey:key2], @"key1 and key2 have different ports");        
}

- (void)testIsEqualSamePort {
    NSURL *url1 = [NSURL URLWithString:@"http://google.com:8080"];
    SpdySessionKey *key1 = [[[SpdySessionKey alloc] initFromUrl:url1] autorelease];
    
    NSURL *url2 = [NSURL URLWithString:@"http://google.com:8080"];
    SpdySessionKey *key2 = [[[SpdySessionKey alloc] initFromUrl:url2] autorelease];    
    
    STAssertTrue([key1 isEqualToKey:key2], @"key1 and key2 have the same port");            
}

- (void)testIsEqualNilPort {
    NSURL *url1 = [NSURL URLWithString:@"http://google.com"];
    SpdySessionKey *key1 = [[[SpdySessionKey alloc] initFromUrl:url1] autorelease];
    
    NSURL *url2 = [NSURL URLWithString:@"http://google.com:800"];
    SpdySessionKey *key2 = [[[SpdySessionKey alloc] initFromUrl:url2] autorelease];    
    
    STAssertFalse([key1 isEqualToKey:key2], @"key1 and key2 have different ports");            
}

@end
