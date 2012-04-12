//
//      File: SpdySessionKey.m
//
//  Created by Erik Chen on 4/11/12.
//  Copyright 2012 Twist Inc.
//

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "SpdySessionKey.h"

@interface SpdySessionKey ()
@property (nonatomic, retain) NSString *host;
@property (nonatomic, retain) NSNumber *port;
@end

@implementation SpdySessionKey
@synthesize host = _host;
@synthesize port = _port;

- (SpdySessionKey *)initFromUrl:(NSURL *)url {
    NSAssert([url host] != nil, @"Cannot make a key if url does not have a valid host");
    self.host = url.host;
    self.port = url.port;
    return self;
}

- (void)dealloc {
    [_host release];
    [_port release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@:%@ (%u)", [super description], self.host, self.port, [self hash]];
}

- (NSUInteger)hash {
    return [self.host hash] + [self.port hash];
}

- (BOOL)isEqual:(id)other {
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
    return [self isEqualToKey:other];
}

- (BOOL)isEqualToKey:(SpdySessionKey *)other {
    if (![self.host isEqualToString:other.host])
        return NO;
    
    // If neither self nor other have a port, then they are equal.
    if (!self.port && !other.port)
        return YES;
    
    // If either has a port, then the ports must be equal.
    return [self.port isEqualToNumber:other.port];
}

- (id)copyWithZone:(NSZone *)zone {
    SpdySessionKey *other = [[SpdySessionKey allocWithZone:zone] init];
    other.host = [[self.host copyWithZone:zone] autorelease];
    other.port = [[self.port copyWithZone:zone] autorelease];
    return other;
}

@end
