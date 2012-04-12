//
//      File: SpdySessionKey.h
//  Abstract: An object that uniquely identifies host/port pairs.
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

#import <Foundation/Foundation.h>

@interface SpdySessionKey : NSObject <NSCopying>
- (SpdySessionKey *)initFromUrl:(NSURL *)url;
- (BOOL)isEqualToKey:(SpdySessionKey *)other;

// host is guaranteed to be not nil.
@property (nonatomic, retain, readonly) NSString *host;
// port is optional.
@property (nonatomic, retain, readonly) NSNumber *port;
@end
