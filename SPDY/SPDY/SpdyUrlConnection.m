//
//  SpdyUrlConnection.m
//  SPDY
//
//  Created by Jim Morrison on 4/2/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SpdyUrlConnection.h"
#import "SPDY.h"

// This is actually a dictionary of sets.  The first set is the host names, the second is a set of ports.
static NSMutableDictionary *disabledHosts;


// This class exists because NSHTTPURLResponse does not have a useful constructor in iOS 4.3 and below.
@interface SpdyUrlResponse : NSURLResponse
@property (assign) NSInteger statusCode;
@property (retain) NSDictionary *allHeaderFields;

- (id)initWithURL:(NSURL *)url withResponse:(CFHTTPMessageRef)headers;
@end

@implementation SpdyUrlResponse
@synthesize statusCode = _statusCode;
@synthesize allHeaderFields = _allHeaderFields;

- (id)initWithURL:(NSURL *)url withResponse:(CFHTTPMessageRef)headers {
    NSDictionary *headersDict = [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(headers)) autorelease];
    NSNumberFormatter *f = [[[NSNumberFormatter alloc] init] autorelease];
    NSString *contentType = [headersDict objectForKey:@"content-type"];
    NSString *contentLength = [headersDict objectForKey:@"content-length"];
    NSNumber *length = [f numberFromString:contentLength];
    self = [super initWithURL:url MIMEType:contentType expectedContentLength:[length intValue] textEncodingName:nil];
    self.statusCode = CFHTTPMessageGetResponseStatusCode(headers);
    self.allHeaderFields = headersDict;
    return self;
}
@end

@interface SpdyUrlCallback : RequestCallback
- (id)initWithConnection:(SpdyUrlConnection *)protocol;
@property (retain) SpdyUrlConnection *protocol;
@end

@implementation SpdyUrlCallback
@synthesize protocol = _protocol;

- (id)initWithConnection:(SpdyUrlConnection *)protocol {
    self = [super init];
    if (self != nil) {
        self.protocol = protocol;
    }
    return self;
}

- (void)onConnect:(id<SpdyRequestIdentifier>)spdyId {
    self.protocol.spdyIdentifier = spdyId;
    if (self.protocol.cancelled) {
        [spdyId close];
    }
}

- (void)onError:(CFErrorRef)error {
    [[self.protocol client] URLProtocol:self.protocol didFailWithError:(NSError *)error];
}

- (void)onNotSpdyError:(id<SpdyRequestIdentifier>)identifier {
    NSURL *url = [identifier url];
    NSMutableSet *ports = [disabledHosts objectForKey:[url host]];
    if (ports == nil) {
        ports = [NSMutableSet set];
        [disabledHosts setObject:ports forKey:[url host]];
    }
    [ports addObject:[url port]];
    NSError *error = [NSError errorWithDomain:(NSString *)kSpdyErrorDomain code:kSpdyConnectionNotSpdy userInfo:nil];
    [[self.protocol client] URLProtocol:self.protocol didFailWithError:error];    
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    SpdyUrlResponse *response = [[[SpdyUrlResponse alloc] initWithURL:[self.protocol.spdyIdentifier url] withResponse:headers] autorelease];
    [[self.protocol client] URLProtocol:self.protocol didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (size_t)onResponseData:(const uint8_t *)bytes length:(size_t)length {
    NSData *data = [NSData dataWithBytes:bytes length:length];
    [[self.protocol client] URLProtocol:self.protocol didLoadData:data];
    return length;
}

- (void)onStreamClose {
    self.protocol.closed = YES;
    [[self.protocol client] URLProtocolDidFinishLoading:self.protocol];
}

@end

@interface SpdyUrlConnection ()
@property (assign) BOOL cancelled;
@end

@implementation SpdyUrlConnection
@synthesize spdyIdentifier = _spdyIdentifier;
@synthesize cancelled = _cancelled;
@synthesize closed = _closed;

+ (void)register {
    disabledHosts = [[NSMutableDictionary alloc] init];
    [NSURLProtocol registerClass:[SpdyUrlConnection class]];
}

+ (void)unregister {
    [disabledHosts release];
    [NSURLProtocol unregisterClass:[SpdyUrlConnection class]];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    BOOL isHttps = [[[[request URL] scheme] lowercaseString] isEqualToString:@"https"];
    if (isHttps) {
        NSSet *ports = [disabledHosts objectForKey:[[request URL] host]];
        if (ports == nil || ![ports containsObject:[[request URL] port]])
            return YES;
    }
    return NO;
}

// This could be a good place to remove the connection headers.
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    SpdyUrlCallback *delegate = [[[SpdyUrlCallback alloc] initWithConnection:self] autorelease];
    [[SPDY sharedSPDY] fetchFromRequest:[self request] delegate:delegate];
}

- (void)stopLoading {
    if (self.closed)
        return;
    self.cancelled = YES;
    if (self.spdyIdentifier != nil)
        [self.spdyIdentifier close];
}

@end
