//
//      File: FetchedUrl.h
//  Abstract: 
//
//  Created by Jim Morrison on 2/13/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SPDY;

@interface FetchedUrl : NSObject

- (id)init:(NSString*)url spdy:(SPDY*)spdy;

@property (retain) NSString* url;
@property (retain) NSString* state;
@property (retain) NSData* body;
@end
