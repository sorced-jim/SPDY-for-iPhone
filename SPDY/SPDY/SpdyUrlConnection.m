//
//  SpdyUrlConnection.m
//  SPDY
//
//  Created by Jim Morrison on 4/2/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SpdyUrlConnection.h"
#import "SPDY.h"

@interface SpdyUrlCallback : RequestCallback
- (id)initWithConnection:(SpdyUrlConnection *)delegate;
@property (retain) SpdyUrlConnection *delegate;
@end

@implementation SpdyUrlCallback
@synthesize delegate = _delegate;

- (id)initWithConnection:(SpdyUrlConnection *)delegate {
    self = [super init];
    if (self != nil) {
        self.delegate = delegate;
    }
    return self;
}

- (void)onConnect:(id<SpdyRequestIdentifier>)spdyId {
    self.delegate.spdyIdentifier = spdyId;
}

@end

// This is actually a dictionary of sets.  The first set is the host names, the second is a set of ports.
static NSMutableDictionary *disabledHosts;

@interface SpdyUrlConnection ()
@end

@implementation SpdyUrlConnection
@synthesize spdyIdentifier;

+ (void)register {
    disabledHosts = [NSMutableSet set];
    [NSURLProtocol registerClass:[SpdyUrlConnection class]];
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
    SpdyUrlCallback *delegate = [[SpdyUrlCallback alloc] initWithConnection:self];
    [[SPDY sharedSPDY] fetchFromRequest:[self request] delegate:delegate];
}

- (void)stopLoading {
    
}


@end
