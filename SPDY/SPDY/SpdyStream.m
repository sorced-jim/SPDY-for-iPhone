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

#import "SpdySession.h"

static NSSet *headersNotToCopy = nil;

@interface SpdyStream ()
- (void)fixArena:(NSInteger)length;
- (const char *)copyString:(NSString *)str;
- (const char *)getStringFromCFHTTPMessage:(CFHTTPMessageRef)msg func:(CFStringRef(*)(CFHTTPMessageRef))func;
- (const char *)copyCFString:(CFStringRef)str;
- (NSMutableData *)createArena:(NSInteger)capacity;
- (int)serializeUrl:(NSURL *)url withMethod:(NSString *)method;
- (int)serializeHeadersDict:(NSDictionary *)headers fromIndex:(int)index;

@property (retain) NSMutableData *stringArena;
@property (retain) NSURL *url;

@end

@implementation SpdyStream {
    CFHTTPMessageRef response;
    NSMutableArray *arenas;
    NSInteger arenaCapacity;
}

@synthesize nameValues;
@synthesize url = _url;
@synthesize body;
@synthesize delegate;
@synthesize parentSession;
@synthesize streamId;
@synthesize stringArena;

+ (void)staticInit {
    if (headersNotToCopy == nil) {
        headersNotToCopy = [[NSSet alloc] initWithObjects:@"host", @"connection", nil];
    }
}

- (id)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    response = CFHTTPMessageCreateEmpty(NULL, NO);
    streamClosed = NO;
    self.body = nil;
    self.streamId = -1;
    arenas = nil;
    arenaCapacity = -1;
    self.stringArena = nil;
    return self;
}

- (void)dealloc {
    self.body = nil;
    self.stringArena = nil;
    self.parentSession = nil;
    if (arenas != nil) {
        [arenas release];
    }
    free(nameValues);
    [super dealloc];
}

- (void)parseHeaders:(const char **)nameValuePairs {
    while (*nameValuePairs != NULL && *(nameValuePairs+1) != NULL) {
        CFStringRef key = CFStringCreateWithCString(NULL, nameValuePairs[0], kCFStringEncodingUTF8);
        CFStringRef value = CFStringCreateWithCString(NULL, nameValuePairs[1], kCFStringEncodingUTF8);
        nameValuePairs += 2;
        if (key != NULL) {
            if (value != NULL) {
                CFHTTPMessageSetHeaderFieldValue(response, key, value);
                CFRelease(value);
            }
            CFRelease(key);
        } else if (value != NULL) {
            CFRelease(value);            
        }
    }
    assert(CFHTTPMessageAppendBytes(response, (const UInt8 *)"\r\n", 2));
    [delegate onResponseHeaders:response];
}

- (size_t)writeBytes:(const uint8_t *)bytes len:(size_t)length {
    return [delegate onResponseData:bytes length:length];
}

- (void)closeStream {
    if (streamClosed != YES) {
        streamClosed = YES;
        [delegate onStreamClose];
    }
}

- (void)cancelStream {
    streamClosed = YES;
    CFErrorRef error = CFErrorCreate(kCFAllocatorDefault, kSpdyErrorDomain, kSpdyRequestCancelled, NULL);
    [delegate onError:error];
    CFRelease(error);
}

- (void)close {
    [self.parentSession cancelStream:self];
}

- (void)notSpdyError {
    [delegate onNotSpdyError];
}

- (void)connectionError {
    CFErrorRef error = CFErrorCreate(kCFAllocatorDefault, kSpdyErrorDomain, kSpdyConnectionFailed, NULL);
    [delegate onError:error];
    CFRelease(error);
}

- (NSMutableData *)createArena:(NSInteger)capacity {
    arenaCapacity = capacity;
    return [NSMutableData dataWithCapacity:capacity];
}

- (void)fixArena:(NSInteger)length {
    if ([self.stringArena length] + length > arenaCapacity) {
        NSLog(@"Adding an arena. %d > %d", [self.stringArena length] + length, arenaCapacity);
        if (arenas == nil) {
            arenas = [[NSMutableArray alloc]initWithCapacity:2];
        }
        [arenas addObject:self.stringArena];

        NSInteger newCapacity = length > arenaCapacity ? length : arenaCapacity;
        self.stringArena = [self createArena:newCapacity];
    }
}

- (const char *)copyString:(NSString *)str {
    const char *utf8 = [str UTF8String];
    unsigned long length = strlen(utf8) + 1;
    [self fixArena:length];
    NSInteger arenaLength = [self.stringArena length];
    [self.stringArena appendBytes:utf8 length:length];
    return (const char*)[self.stringArena mutableBytes] + arenaLength;
}

- (const char *)copyCFString:(CFStringRef)str {
    const char *utf8 = CFStringGetCStringPtr(str, CFStringGetFastestEncoding(str));
    if (utf8 == NULL) {
        NSLog(@"Can't get raw version of %@: %@", str, CFStringGetFastestEncoding(str));
        return "";
    }
    
    unsigned long length = strlen(utf8) + 1;
    [self fixArena:length];
    NSInteger arenaLength = [self.stringArena length];
    [self.stringArena appendBytes:utf8 length:length];
    return (const char *)[self.stringArena mutableBytes] + arenaLength;
}

- (const char *)getStringFromCFHTTPMessage:(CFHTTPMessageRef)msg func:(CFStringRef(*)(CFHTTPMessageRef))func {
    CFStringRef str = func(msg);
    const char *utf8 = [self copyCFString:str];
    CFRelease(str);
    return utf8;
}

- (const char *)getStringFromCFURL:(CFURLRef)u func:(CFStringRef(*)(CFURLRef))func {
    CFStringRef str = func(u);
    const char *utf8 = [self copyCFString:str];
    CFRelease(str);
    return utf8;
}

- (void)serializeHeaders:(CFHTTPMessageRef)msg {
    CFDictionaryRef d = CFHTTPMessageCopyAllHeaderFields(msg);
    CFURLRef url = CFHTTPMessageCopyRequestURL(msg);
    CFStringRef method = CFHTTPMessageCopyRequestMethod(msg);
    CFIndex count = CFDictionaryGetCount(d);

    self.nameValues = malloc((count * 2 + 6*2 + 1) * sizeof(const char *));
    
        CFStringRef *keys = CFAllocatorAllocate(NULL, sizeof(CFStringRef)*count*2, 0);
    CFTypeRef *values = (CFTypeRef *)(keys + count);
    CFIndex index;
    const char **nv = self.nameValues;
    CFDictionaryGetKeysAndValues(d, (const void **)keys, (const void **)values);
    nv[0] = ":method";
    nv[1] = [self getStringFromCFHTTPMessage:msg func:CFHTTPMessageCopyRequestMethod];
    nv[2] = "user-agent";
    nv[3] = "SPDY objc-0.0.3";
    nv[4] = ":version";
    nv[5] = [self getStringFromCFHTTPMessage:msg func:CFHTTPMessageCopyVersion];
    nv[6] = ":scheme";
    nv[7] = [self getStringFromCFURL:url func:CFURLCopyScheme];
    nv[8] = ":host";
    nv[9] = [self getStringFromCFURL:url func:CFURLCopyHostName];
    nv[10] = ":path";
    CFStringRef resourceSpecifier = CFURLCopyResourceSpecifier(url);
    CFStringRef path = CFURLCopyPath(url);
    if (resourceSpecifier != NULL) {
        NSMutableString *nsPath = [[[NSMutableString alloc]init] autorelease];
        [nsPath appendFormat:@"%@%@", (NSString *)path, (NSString *)resourceSpecifier];
        nv[11] = [self copyString:nsPath];
        CFRelease(resourceSpecifier);
    } else {
        nv[11] = [self copyCFString:path];
    }
    CFRelease(path);
    for (index = 0; index < count; ++index) {
        nv[index*2 + 12] = [self copyCFString:keys[index]];
        nv[index*2 + 13] = [self copyCFString:values[index]];
    }
    nv[count*2+6*2] = NULL;

    CFAllocatorDeallocate(NULL, keys);
    CFRelease(url);
    CFRelease(method);
    CFRelease(d);
}

// Assumes self.nameValues is at least 12 elements long.
- (int)serializeUrl:(NSURL *)url withMethod:(NSString *)method {
    self.url = url;
    const char** nv = self.nameValues;
    nv[0] = ":method";
    nv[1] = [self copyString:method];
    nv[2] = ":scheme";
    nv[3] = [self copyString:[url scheme]];
    nv[4] = ":path";
    const char* pathPlus = [self copyString:[url resourceSpecifier]];
    const char* host = [self copyString:[url host]];
    nv[5] = pathPlus + strlen(host) + 2;
    nv[6] = ":host";
    nv[7] = host;
    nv[8] = "user-agent";
    nv[9] = "SPDY obj-c/0.0.0";
    nv[10] = ":version";
    nv[11] = "HTTP/1.1";
    return 12;
}

// Returns the next index.
- (int)serializeHeadersDict:(NSDictionary *)headers fromIndex:(int)index {
    if (headers == nil) {
        return index;
    }

    int nameValueIndex = index;
    const char **nv = self.nameValues;
    for (NSString *k in headers) {
        NSString *key = [k lowercaseString];
        if (![headersNotToCopy containsObject:key]) {
            NSString *value = [headers objectForKey:k];
            nv[nameValueIndex] = [self copyString:key];
            nv[nameValueIndex + 1] = [self copyString:value];
            nameValueIndex += 2;
        }
    }
    return nameValueIndex;
}

#pragma mark Creation methods.

+ (SpdyStream *)newFromCFHTTPMessage:(CFHTTPMessageRef)msg delegate:(RequestCallback *)delegate body:(NSInputStream *)body {
    SpdyStream *stream = [[SpdyStream alloc] init];
    CFURLRef u = CFHTTPMessageCopyRequestURL(msg);
    stream.url = (NSURL *)u;
    if (body != nil) {
        stream.body = body;
    } else {
        CFDataRef bodyData = CFHTTPMessageCopyBody(msg);
        if (bodyData != NULL) {
            stream.body = [NSInputStream inputStreamWithData:(NSData *)bodyData];
            CFRelease(bodyData);
        }
    }
    stream.delegate = delegate;
    stream.stringArena = [stream createArena:1024];
    [stream serializeHeaders:msg];
    CFRelease(u);
    return stream;
}

+ (SpdyStream *)newFromNSURL:(NSURL *)url delegate:(RequestCallback *)delegate {
    SpdyStream *stream = [[SpdyStream alloc] init];
    stream.nameValues = malloc(sizeof(const char *) * (6*2 + 1));
    stream.delegate = delegate;
    stream.stringArena = [stream createArena:512];
    [stream serializeUrl:url withMethod:@"GET"];
    stream.nameValues[12] = NULL;
    return stream;
}

+ (SpdyStream *)newFromRequest:(NSURLRequest *)request delegate:(RequestCallback *)delegate {
    SpdyStream *stream = [[SpdyStream alloc] init];
    NSDictionary *headers = [request allHTTPHeaderFields];
    NSLog(@"headers: %@, stream: %@", headers, stream);
    stream.delegate = delegate;
    stream.stringArena = [stream createArena:2048];
    int maxElements = [headers count]*2 + 6*2 + 1;
    stream.nameValues = malloc(sizeof(const char *) * maxElements);
    int nameValueIndex = [stream serializeUrl:[request URL] withMethod:[request HTTPMethod]];
    NSLog(@"index is: %d, max elements: %d", nameValueIndex, maxElements);
    nameValueIndex = [stream serializeHeadersDict:headers fromIndex:nameValueIndex];
    stream.nameValues[nameValueIndex] = NULL;
    return stream;
}

@end
