//
//  SpdyUrlConnection.m
//  NOTE: iOS makes a copy of the return value of responseWithURL:withResponse:withRequestBytes, so the original type is
//  lost.
//
//  Created by Jim Morrison on 4/2/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SpdyUrlConnection.h"
#import "SPDY.h"

// This is actually a dictionary of sets.  The first set is the host names, the second is a set of ports.
static NSMutableDictionary *disabledHosts;


@implementation SpdyUrlResponse
@synthesize statusCode = _statusCode;
@synthesize allHeaderFields = _allHeaderFields;
@synthesize requestBytes = _requestBytes;

+ (NSURLResponse *)responseWithURL:(NSURL *)url withResponse:(CFHTTPMessageRef)headers withRequestBytes:(NSInteger)requestBytesSent {
    NSMutableDictionary *headersDict = [[[NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(headers)) autorelease] mutableCopy] autorelease];
    [headersDict setObject:@"YES" forKey:@"protocol-was: spdy"];
    NSNumberFormatter *f = [[[NSNumberFormatter alloc] init] autorelease];
    NSString *contentType = [headersDict objectForKey:@"content-type"];
    NSString *contentLength = [headersDict objectForKey:@"content-length"];
    NSNumber *length = [f numberFromString:contentLength];
    NSInteger statusCode = CFHTTPMessageGetResponseStatusCode(headers);
    NSString *version = [NSMakeCollectable(CFHTTPMessageCopyVersion(headers)) autorelease];
    if ([[NSHTTPURLResponse class] instancesRespondToSelector:@selector(initWithURL:statusCode:HTTPVersion:headerFields:)]) {
        return [[[NSHTTPURLResponse alloc] initWithURL:url statusCode:statusCode  HTTPVersion:version headerFields:headersDict] autorelease];
    }
    
    SpdyUrlResponse *response = [[SpdyUrlResponse alloc] autorelease];
    [response initWithURL:url MIMEType:contentType expectedContentLength:[length intValue] textEncodingName:nil];
    response.statusCode = statusCode;
    response.allHeaderFields = headersDict;
    response.requestBytes = requestBytesSent;
    return response;
}

@end

@interface SpdyUrlCallback : RequestCallback
- (id)initWithConnection:(SpdyUrlConnection *)protocol;
@property (retain) SpdyUrlConnection *protocol;
@property (assign) NSInteger requestBytesSent;
@end

@implementation SpdyUrlCallback
@synthesize protocol = _protocol;
@synthesize requestBytesSent = _requestBytesSent;

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

- (void)onError:(NSError *)error {
    if (!self.protocol.cancelled) {
        [[self.protocol client] URLProtocol:self.protocol didFailWithError:error];
    }
}

- (void)onNotSpdyError:(id<SpdyRequestIdentifier>)identifier {
    NSURL *url = [identifier url];
    [SpdyUrlConnection disableUrl:url];
    NSError *error = [NSError errorWithDomain:kSpdyErrorDomain code:kSpdyConnectionNotSpdy userInfo:nil];
    [[self.protocol client] URLProtocol:self.protocol didFailWithError:error];    
}

- (void)onRequestBytesSent:(NSInteger)bytesSend {
    // The updated byte count should be sent, but the URLProtocolClient doesn't have a method to do that.
    //[[self.protocol client] URLProtocol:self.protocol didSendBodyData:bytesSend];
    self.requestBytesSent += bytesSend;
}

- (void)onResponseHeaders:(CFHTTPMessageRef)headers {
    NSURLResponse *response = [SpdyUrlResponse responseWithURL:[self.protocol.spdyIdentifier url] withResponse:headers withRequestBytes:self.requestBytesSent];
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

+ (void)registerSpdy {
    disabledHosts = [[NSMutableDictionary alloc] init];
    [NSURLProtocol registerClass:[SpdyUrlConnection class]];
}

+ (BOOL)isRegistered {
    return disabledHosts != nil;
}

+ (void)unregister {
    [NSURLProtocol unregisterClass:[SpdyUrlConnection class]];
    [disabledHosts release];
    disabledHosts = nil;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return [SpdyUrlConnection canInitWithUrl:[request URL]];
}

+ (BOOL)canInitWithUrl:(NSURL *)url {
    BOOL isHttps = [[[url scheme] lowercaseString] isEqualToString:@"https"];
    if (isHttps) {
        NSSet *ports = [disabledHosts objectForKey:[url host]];
        if (ports != nil) {
            NSNumber *port = [url port];
            if (port == nil)
                port = [NSNumber numberWithInt:443];
            if ([ports containsObject:port])
                return NO;
        }
        return YES;
    }
    return NO;
}

+ (void)disableUrl:(NSURL *)url {
    NSMutableSet *ports = [disabledHosts objectForKey:[url host]];
    if (ports == nil) {
        ports = [NSMutableSet set];
        [disabledHosts setObject:ports forKey:[url host]];
    }
    if ([url port] == nil) {
        [ports addObject:[NSNumber numberWithInt:80]];
        [ports addObject:[NSNumber numberWithInt:443]];
    } else {
        [ports addObject:[url port]];
    }
}

// This could be a good place to remove the connection headers.
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *spdyRequest = [request mutableCopy];
    [NSURLProtocol setProperty:[NSNumber numberWithBool:YES] forKey:@"spdy" inRequest:spdyRequest];
    return spdyRequest;
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
