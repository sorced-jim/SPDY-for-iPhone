//
//      File: FetchedUrl.m
//  Abstract: 
//
//  Created by Jim Morrison on 2/13/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "FetchedUrl.h"
#import "SPDY/SPDY.h"

@interface Callback : BufferedCallback {
    FetchedUrl *url;
}
- (id)init:(FetchedUrl*) url;
@end

@implementation Callback {
    
}

- (id)init:(FetchedUrl*) u {
    self = [super init];
    url = u;
    return self;
}

- (void)onNotSpdyError {
    url.state = @"Host does not support SPDY";
}

- (void)onError {
    url.state = @"Error";
}

- (void)onResponse:(CFHTTPMessageRef)response {
    url.state = @"loaded";
}

- (void)onConnect {
    url.state = @"connected";
}

@end

@implementation FetchedUrl {
    NSString *_url;
    NSString *_state;
    NSData *_body;
    Callback *delegate;
}

@synthesize url = _url;
@synthesize state = _state;
@synthesize body = _body;

- (id)init:(NSString*)u spdy:(SPDY*)spdy {
    self = [super init];
    delegate = [[Callback alloc]init:self];
    self.url = u;
    self.state = @"connecting";
    [spdy fetch:u delegate:delegate];
    return self;
}

- (void)dealloc {
    [delegate release];
}
@end
