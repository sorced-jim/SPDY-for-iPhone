//
//      File: SpdyInputStream.h
//  Abstract: An input stream that wraps another input stream
//  and allows any property to be set.  No verification is
//  done on the properties that are set.
//
//  Created by Jim Morrison on 2/29/12.
//  Copyright (c) 2012 Twist Inc.

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
#import "SPDY.h"

@interface SpdyInputStream : NSInputStream<NSStreamDelegate>
- (SpdyInputStream *)init:(NSInputStream *)parent;

@property (retain) NSError *error;
@property (retain) id<SpdyRequestIdentifier> requestId;

@end
