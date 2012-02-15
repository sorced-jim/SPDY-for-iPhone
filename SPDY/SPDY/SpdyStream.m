//
//  SpdyStream.m
//  A class representing a SPDY stream.  This class is responsible for converting to a CFHTTPMessage.
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

#import "SpdyStream.h"
#import "SPDY.h"

@implementation SpdyStream {
    CFHTTPMessageRef response;
}

@synthesize nameValues;
@synthesize url;
@synthesize delegate;
@synthesize stringArena;

- (id)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    response = CFHTTPMessageCreateEmpty(NULL, NO);
    streamClosed = NO;
    return self;
}

- (void)dealloc {
    free(nameValues);
}

- (void)parseHeaders:(const char **)nameValuePairs {
    while (*nameValuePairs != NULL) {
        CFStringRef key = CFStringCreateWithCString(NULL, nameValuePairs[0], kCFStringEncodingUTF8);
        CFStringRef value = CFStringCreateWithCString(NULL, nameValuePairs[1], kCFStringEncodingUTF8);
        nameValuePairs += 2;
        CFHTTPMessageSetHeaderFieldValue(response, key, value);
        CFRelease(key);
        CFRelease(value);
    }
    [delegate onResponseHeaders:response];
}

- (size_t)writeBytes:(const uint8_t *)bytes len:(size_t)length {
    return [delegate onResponseData:bytes length:length];
}

- (void) printStream {
    printf("Calling printStream\n");
    NSLog(@"%@\n", url);
}

- (void) closeStream {
    streamClosed = YES;
    [delegate onStreamClose];
}

static const char* copyString(NSMutableData* arena, NSString* str) {
    const char* utf8 = [str UTF8String];
    unsigned long length = strlen(utf8) + 1;
    NSInteger arenaLength = [arena length];
    [arena appendBytes:utf8 length:length];
    return (const char*)[arena mutableBytes] + arenaLength;
}

- (const char*) copyCFString:(CFStringRef) str {
    const char* utf8 = CFStringGetCStringPtr(str, kCFStringEncodingUTF8);
    unsigned long length = strlen(utf8) + 1;
    NSInteger arenaLength = [stringArena length];
    [stringArena appendBytes:utf8 length:length];
    CFRelease(str);
    return (const char*)[stringArena mutableBytes] + arenaLength;
}

- (void)serializeHeaders:(CFHTTPMessageRef) msg {
    CFDictionaryRef d = CFHTTPMessageCopyAllHeaderFields(msg);
    CFIndex count = CFDictionaryGetCount(d);
    
    CFStringRef *keys = CFAllocatorAllocate(NULL, sizeof(CFStringRef)*count*2, 0);
    CFTypeRef *values = (CFTypeRef *)(keys + count);
    CFIndex index;
    nameValues = malloc((count * 2 + 6*2 + 1) * sizeof(const char*));
    const char** nv = nameValues;
    CFDictionaryGetKeysAndValues(d, (const void **)keys, (const void **)values);
    nv[0] = "method";
    nv[1] = [self copyCFString:CFHTTPMessageCopyRequestMethod(msg)];
    nv[2] = "user-agent";
    nv[3] = "SPDY objc-0.0.1";
    nv[4] = "version";
    nv[5] = "HTTP/1.";
    CFURLRef u = CFHTTPMessageCopyRequestURL(msg);
    nv[6] = "scheme";
    nv[7] = [self copyCFString:CFURLCopyScheme(u)];
    nv[8] = "host";
    nv[9] = [self copyCFString:CFURLCopyHostName(u)];
    nv[10] = "url";
    // This is wrong since the query parameters are missing.
    nv[11] = [self copyCFString:CFURLCopyPath(u)];
    for (index = 12; index < count+12; ++index) {
        nv[index*2] = [self copyCFString:keys[index]];
        nv[index*2 + 1] = [self copyCFString:values[index]];
    }
    nv[count*2+6*2] = NULL;
    CFRelease(u);
    CFAllocatorDeallocate(NULL, keys);
    CFRelease(d);
}

#pragma mark Creation methods.

+ (SpdyStream*)createFromCFHTTPMessage:(CFHTTPMessageRef)msg delegate:(RequestCallback*) delegate {
    SpdyStream *stream = [[SpdyStream alloc]init];
    stream.nameValues = malloc(sizeof(const char*)* (6*2 + 1));
    stream.url = (NSURL*)CFHTTPMessageCopyRequestURL(msg);
    stream.delegate = delegate;
    [stream setStringArena:[NSMutableData dataWithCapacity:100]];
    [stream serializeHeaders:msg];
    return nil;
}

+ (SpdyStream*)createFromNSURL:(NSURL *)url delegate:(RequestCallback *)delegate {
    SpdyStream *stream = [[SpdyStream alloc]init];
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
