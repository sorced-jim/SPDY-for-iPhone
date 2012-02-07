//
//  WSSpdyStream.m
//  spdylay demo
//
//  Created by Jim Morrison on 2/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WSSpdyStream.h"

@implementation WSSpdyStream

@synthesize name_values;
@synthesize url;

- (id)init
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    
    data = [NSMutableData dataWithCapacity:4096];
    return self;
}

- (void)dealloc
{
    [data release];
    data = nil;
    free(name_values);
}

- (size_t)writeBytes:(const uint8_t *)bytes len:(size_t)length
{
    [data appendBytes:bytes length:length];
    return length;
}

- (void) printStream
{
    printf("Calling printStream\n");
    NSLog(@"%@:\n%@", url, data);
}

static const char** SerializeHeaders(CFHTTPMessageRef msg)
{
    CFDictionaryRef d = CFHTTPMessageCopyAllHeaderFields(msg);
    CFIndex count = CFDictionaryGetCount(d);
    
    CFStringRef *keys = CFAllocatorAllocate(NULL, sizeof(CFStringRef)*count*2 + 6 + 1, 0);
    CFTypeRef *values = (CFTypeRef *)(keys + count);
    CFIndex index;
    const char** nv = malloc(count * 2 * sizeof(const char*));
    CFDictionaryGetKeysAndValues(d, (const void **)keys, (const void **)values);
    for (index = 0; index < count; index ++) {
        nv[index*2] = CFStringGetCStringPtr(keys[index], kCFStringEncodingUTF8);
        nv[index*2 + 1] = CFStringGetCStringPtr(values[index], kCFStringEncodingUTF8);
    }
    nv[-1] = NULL;
    CFAllocatorDeallocate(NULL, keys);
    return nv;        
}

+ (WSSpdyStream*)createFromNSURL:(NSURL *)url
{
    WSSpdyStream *stream = [[WSSpdyStream alloc]init];
    stream.name_values = malloc(6*2 + 1);
    stream.url = url;
    const char** nv = [stream name_values];
    nv[0] = "method";
    nv[1] = "GET";
    nv[2] = "scheme";
    nv[3] = "https";
    nv[4] = "url";
    nv[5] = [[url path] UTF8String];
    nv[6] = "host";
    nv[7] = [[url host] UTF8String];
    nv[8] = "user-agent";
    nv[9] = "SPDY obj-c/0.0.0";
    nv[10] = "version";
    nv[11] = "HTTP/1.1";
    nv[12] = NULL;
    return stream;
}

@end
