//
//  WSSpdyStream.h
//  spdylay demo
//
//  Created by Jim Morrison on 2/7/12.
//  Copyright 2012 Twist Inc.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


#import <Foundation/Foundation.h>

@interface WSSpdyStream : NSInputStream {
    NSMutableData* data;
    const char** nameValues;
    NSURL* url;
    NSUInteger baseOffset;
    BOOL streamClosed;
}

// To be used by the SPDY session.
- (size_t) writeBytes:(const uint8_t*) data len:(size_t) length;
- (void) closeStream;

+ (WSSpdyStream*)createFromCFHTTPMessage:(CFHTTPMessageRef) msg;
+ (WSSpdyStream*)createFromNSURL:(NSURL*) url;

@property const char** nameValues;
@property (retain) NSURL* url;

@end


