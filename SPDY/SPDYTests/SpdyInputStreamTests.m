//
//  SpdyInputStreamTests.m
//  Tests the CFReadStream wrapper that allows setting any property.
//
//  Created by Jim Morrison on 3/1/12.
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

#import "SpdyInputStreamTests.h"
#import "SpdyInputStream.h"

@implementation SpdyInputStreamTests {
    CFWriteStreamRef writeStream;
    CFReadStreamRef readStream;
    SpdyInputStream *testStream;
}

- (void)setUp {
    CFStreamCreateBoundPair(kCFAllocatorDefault, &readStream, &writeStream, 1024);
    testStream = [[SpdyInputStream alloc]init:(NSInputStream *)readStream];
}
- (void)tearDown {
    [testStream release];
    CFRelease(writeStream);
    CFRelease(readStream);
}

- (void)testSetProperty {
    STAssertTrue([testStream setProperty:@"hi" forKey:@"Any-Key"], @"Set any property.");
    STAssertEquals([testStream propertyForKey:@"Any-Key"], @"hi", @"Get the property");    
}

- (void)testDelegate {
    STAssertEquals(testStream, [testStream delegate], @"Delegate starts as nil.");
    [testStream setDelegate:nil];
    STAssertEquals(testStream, [testStream delegate], @"Delegate should still be the same");
}

@end
