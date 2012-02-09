//
//  WSSpdyStream.m
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

#import "WSSpdyStream.h"
#import "spdycat.h"

@implementation WSSpdyStream

@synthesize nameValues;
@synthesize url;
@synthesize delegate;
@synthesize stringArena;

- (id)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    streamClosed = NO;
    data = [NSMutableData dataWithCapacity:4096];
    return self;
}

- (void)dealloc {
    [data release];
    data = nil;
    
    free(nameValues);
}

- (size_t)writeBytes:(const uint8_t *)bytes len:(size_t)length {
    [data appendBytes:bytes length:length];
    return length;
}

- (void) printStream {
    printf("Calling printStream\n");
    NSLog(@"%@:\n%@", url, data);
}

- (void) closeStream {
    streamClosed = YES;
    [delegate onResponseBody:self];
}

#pragma mark NSInputStream subclass methods.

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
    // I hope to use an array of buffers, to avoid buffering a whole stream in memory.
    return NO;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    NSUInteger rangeLength = len;
    NSUInteger length = [data length];
    if (baseOffset == length)
    {
        if (streamClosed) {
            return 0;
        }
        return -1;
    }
    if (baseOffset + rangeLength > length) {
        rangeLength = [data length] - baseOffset;
    }
    NSRange range = NSMakeRange(baseOffset, rangeLength);
    [data getBytes:buffer range:range];
    baseOffset += rangeLength;
    return rangeLength;
}

- (BOOL) hasBytesAvailable {
    return baseOffset < [data length];
}

#pragma mark CFReadStream bridge methods

- (void)_scheduleInCFRunLoop:(CFRunLoopRef)runLoop forMode:(CFStringRef)mode {
    // Don't do anything here.
}

- (BOOL)_setCFClientFlags:(CFOptionFlags)inFlags callback:(CFReadStreamClientCallBack)callback context:(CFStreamClientContext *)context {
    return YES;
}

#pragma mark Creation methods.

// This is all wrong since the String refs get aren't kept from the CFURL.
#if 0
static const char** SerializeHeaders(CFHTTPMessageRef msg) {
    CFDictionaryRef d = CFHTTPMessageCopyAllHeaderFields(msg);
    CFIndex count = CFDictionaryGetCount(d);
    
    CFStringRef *keys = CFAllocatorAllocate(NULL, sizeof(CFStringRef)*count*2, 0);
    CFTypeRef *values = (CFTypeRef *)(keys + count);
    CFIndex index;
    const char** nv = malloc((count * 2 + 6*2 + 1) * sizeof(const char*));
    CFDictionaryGetKeysAndValues(d, (const void **)keys, (const void **)values);
    nv[0] = "method";
    nv[1] = CFStringGetCStringPtr(CFHTTPMessageCopyRequestMethod(msg), kCFStringEncodingUTF8);
    nv[2] = "user-agent";
    nv[3] = "SPDY objc-0.0.1";
    nv[4] = "version";
    nv[5] = "HTTP/1.";
    CFURLRef url = CFHTTPMessageCopyRequestURL(msg);
    nv[6] = "scheme";
    nv[7] = CFStringGetCStringPtr(CFURLCopyScheme(url), kCFStringEncodingUTF8);
    nv[8] = "host";
    nv[9] = CFStringGetCStringPtr(CFURLCopyHostName(url), kCFStringEncodingUTF8);
    nv[10] = "url";
    // This is wrong since the query parameters are missing.
    nv[11] = CFStringGetCStringPtr(CFURLCopyPath(url), kCFStringEncodingUTF8);
    for (index = 0; index < count; index ++) {
        nv[index*2] = CFStringGetCStringPtr(keys[index], kCFStringEncodingUTF8);
        nv[index*2 + 1] = CFStringGetCStringPtr(values[index], kCFStringEncodingUTF8);
    }
    nv[count*2+6*2] = NULL;
    CFAllocatorDeallocate(NULL, keys);
    return nv;        
}
#endif

static const char* copyString(NSMutableData* arena, NSString* str) {
    const char* utf8 = [str UTF8String];
    unsigned long length = strlen(utf8) + 1;
    NSInteger arenaLength = [arena length];
    [arena appendBytes:utf8 length:length];
    return (const char*)[arena mutableBytes] + arenaLength;
}

+ (WSSpdyStream*)createFromNSURL:(NSURL *)url delegate:(RequestCallback *)delegate {
    WSSpdyStream *stream = [[WSSpdyStream alloc]init];
    stream.nameValues = malloc(sizeof(const char*)* (6*2 + 1));
    stream.url = url;
    stream.delegate = delegate;
    [stream setStringArena:[NSMutableData dataWithCapacity:100]];
    const char** nv = [stream nameValues];
    nv[0] = "method";
    nv[1] = "GET";
    nv[2] = "scheme";
    nv[3] = copyString([stream stringArena], [url scheme]);
    nv[4] = "url";
    nv[5] = copyString([stream stringArena], [url path]);
    nv[6] = "host";
    nv[7] = copyString([stream stringArena], [url host]);
    nv[8] = "user-agent";
    nv[9] = "SPDY obj-c/0.0.0";
    nv[10] = "version";
    nv[11] = "HTTP/1.1";
    nv[12] = NULL;
    return stream;
}

@end
