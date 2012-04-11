//
//      File: SpdySessionKey.h
//  Abstract: An object that uniquely identifies host/port pairs.
//
//  Created by Erik Chen on 4/11/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SpdySessionKey : NSObject <NSCopying>
- (SpdySessionKey *)initFromUrl:(NSURL *)url;
- (BOOL)isEqualToKey:(SpdySessionKey *)other;

// host is guaranteed to be not nil.
@property (nonatomic, retain, readonly) NSString *host;
// port is optional.
@property (nonatomic, retain, readonly) NSNumber *port;
@end