//
//      File: FetchedUrl.m
//  Abstract: 
//
//  Created by Jim Morrison on 2/13/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "FetchedUrl.h"
#import "SPDY.h"

@interface Callback : BufferedCallback {
    FetchedUrl *fetchedUrl;
}
- (id)init:(FetchedUrl *) fetchedUrl;
@end

@implementation Callback {
    
}

- (id)init:(FetchedUrl *) u {
    self = [super init];
    fetchedUrl = u;

    return self;
}

- (void)onNotSpdyError:(id<SpdyRequestIdentifier>)identifier {
    fetchedUrl.state = @"Host does not support SPDY";
    [fetchedUrl.parent reloadData];
}

- (void)onError:(CFErrorRef)error {
    fetchedUrl.state = @"Error";
    [fetchedUrl.parent reloadData];
}

- (void)onConnect:(id<SpdyRequestIdentifier>)u {
    [super onConnect:u];
    fetchedUrl.state = @"connected";
    fetchedUrl.baseUrl = u.url;
    [fetchedUrl.parent reloadData];

}

- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length {
    fetchedUrl.state = @"Loading";
    [fetchedUrl.parent reloadData];
    return [super onResponseData:bytes length:length];
}

- (void)onResponse:(CFHTTPMessageRef)response {
    CFDataRef b = CFHTTPMessageCopyBody(response);
    fetchedUrl.body = (NSData *)b;
    CFRelease(b);

    fetchedUrl.state = @"loaded";
    [fetchedUrl.parent reloadData];
}

@end

@implementation FetchedUrl {
    NSString *_url;
    NSString *_state;
    NSData *_body;
    NSURL* _baseUrl;
    Callback *delegate;
    UITableView *_parent;
}

@synthesize url = _url;
@synthesize state = _state;
@synthesize body = _body;
@synthesize baseUrl = _baseUrl;
@synthesize parent = _parent;

- (id)init:(NSString *)u spdy:(SPDY *)spdy table:(UITableView *)table {
    self = [super init];
    delegate = [[Callback alloc]init:self];
    self.url = u;
    self.parent = table;
    self.state = @"connecting";
    [spdy fetch:u delegate:delegate];
    return self;
}

- (void)dealloc {
    self.url = nil;
    self.baseUrl = nil;
    self.body = nil;
    self.state = nil;
    [delegate release];
    [super dealloc];
}
@end
