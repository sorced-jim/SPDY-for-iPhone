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

- (id)init:(NSString*)url spdy:(SPDY*)spdy table:(UITableView*)table;

@property (retain) NSString* url;
@property (retain) NSString* state;
@property (retain) NSURL* baseUrl;
@property (retain) NSData* body;
@property (retain) UITableView* parent;
@end
