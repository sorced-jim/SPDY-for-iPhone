//
//  WSSpdyStream.h
//  spdylay demo
//
//  Created by Jim Morrison on 2/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WSSpdyStream : NSInputStream {
    NSMutableData* data;
    const char** name_values;
    NSURL* url;
}

// To be used by the SPDY session.
- (size_t) writeBytes:(const uint8_t*) data
                  len:(size_t) length;
- (void) printStream;

+ (WSSpdyStream*)createFromCFHTTPMessage:(CFHTTPMessageRef) msg;
+ (WSSpdyStream*)createFromNSURL:(NSURL*) url;

@property const char** name_values;
@property (retain) NSURL* url;

@end


