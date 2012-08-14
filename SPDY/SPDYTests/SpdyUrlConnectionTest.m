//
//  SpdyUrlConnectionTest.m
//  Tests for SpdyUrlConnectionTest.
//
//  Created by Jim Morrison on 4/4/12.
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

#import "SpdyUrlConnectionTest.h"
#import "SpdyUrlConnection.h"

@interface SpdyTestCallback <SpdyUrlConnectionCallback>
@property (nonatomic, assign) BOOL shouldUseSpdy;
@end

@implementation SpdyTestCallback
@synthesize shouldUseSpdy;

- (BOOL)shouldUseSpdyForUrl:(NSURL *)url {
    return shouldUseSpdy;
}

@end

@implementation SpdyUrlConnectionTest

- (void)setUp {
    [SpdyUrlConnection registerSpdy];
}

- (void)tearDown {
    [SpdyUrlConnection unregister];
}

- (void)testDisableUrl {
    NSURL *url = [NSURL URLWithString:@"https://ww.g.ca/"];
    NSURL *url443 = [NSURL URLWithString:@"https://ww.g.ca:443/"];
    NSURL *url444 = [NSURL URLWithString:@"https://ww.g.ca:444/"];
    STAssertTrue([SpdyUrlConnection canInitWithUrl:url], @"%@", url);
    STAssertTrue([SpdyUrlConnection canInitWithUrl:url443], @"%@", url443);
    STAssertTrue([SpdyUrlConnection canInitWithUrl:url444], @"%@", url444);
    
    [SpdyUrlConnection disableUrl:url];
    STAssertFalse([SpdyUrlConnection canInitWithUrl:url], @"%@", url);
    STAssertFalse([SpdyUrlConnection canInitWithUrl:url443], @"%@", url443);    
    STAssertTrue([SpdyUrlConnection canInitWithUrl:url444], @"%@", url444);

    [SpdyUrlConnection disableUrl:url444];
    STAssertFalse([SpdyUrlConnection canInitWithUrl:url444], @"%@", url444);
}

- (void)testGzipHeader {
    NSURL *url = [NSURL URLWithString:@"https://t.ca"];
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (CFURLRef)url, kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("content-EncodinG"), CFSTR("gzip"));
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("unKnown-heaDeR"), CFSTR("value"));
    
    NSHTTPURLResponse *response = [SpdyUrlResponse responseWithURL:url withResponse:request withRequestBytes:45];
    STAssertNotNil(response, @"Have response");
    STAssertNotNil([response allHeaderFields], @"Have headers");
    // In iOS 4.3 and below CFHTTPMessage uppercases the first letter of each word in the http header key.  In iOS 5 and up the headers
    // from CFHTTPMessage are case insenstive.
    STAssertEquals([[response allHeaderFields] objectForKey:@"Content-Encoding"], @"gzip", @"Has content-encoding %@", [response allHeaderFields]);
    STAssertEquals([[response allHeaderFields] objectForKey:@"Unknown-Header"], @"value", @"Case insensitive dictionary %@", [response allHeaderFields]);
}

- (void)testCheckCallbackCanInitWithUrl {
    [SpdyUrlConnection unregister];
    SpdyTestCallback *callback = [[[SpdyTestCallback alloc] init] autorelease];
    [SpdyUrlConnection registerSpdyWithCallback:callback];
    NSURL *url = [NSURL URLWithString:@"https://t.ca"];
    callback.shouldUseSpdy = YES;
    STAssertTrue([SpdyUrlConnection canInitWithUrl:url], @"%@", url);

    callback.shouldUseSpdy = NO;
    STAssertFalse([SpdyUrlConnection canInitWithUrl:url], @"%@", url);
}

@end
