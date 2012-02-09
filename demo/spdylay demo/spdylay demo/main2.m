//
//  main2.m
//  spdylay demo
//
//  Created by Jim Morrison on 1/31/12.
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

#import "main2.h"

#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>
#import <getopt.h>
#import <openssl/ssl.h>
#import <signal.h>
#import <stdlib.h>
#import <string.h>

#import "spdycat.h"

static struct option long_options[] = {
    {"show_headers", no_argument, 0, 'v' },
    {"output", 1, 0, 'O' },
    {"help", no_argument, 0, 'h' },
    {0, 0, 0, 0 }
};

@interface ShowBody : BufferedCallback {
    main2 *main;
}

@property (retain) main2 *main;

- (id)init:(main2*)main;

@end

@implementation ShowBody

@synthesize main;

- (id)init:(main2*)m {
    self = [super init];
    [self setMain:m];
    return self;
}

- (void)onError {
    NSLog(@"Got an error!");
    [[self main] decrementRequests];
}

- (void)onNotSpdyError {
    NSLog(@"Not spdy!");
    [[self main] decrementRequests];
}

- (void)onResponse:(CFHTTPMessageRef)response {
    CFDataRef body = CFHTTPMessageCopyBody(response);
    printf("%.*s", (int)CFDataGetLength(body), CFDataGetBytePtr(body));
    [[self main] decrementRequests];
    CFRelease(body);
}

@end

@implementation main2 {
    spdycat* cat;
    NSInteger requestCount;
}

static void print_help() {
    NSLog(@"\n--show_headers -v\tShow the response headers\n--output -O file\tOutput the response body to file");
    exit(0);    
}

+ (main2*)newMain2:(int)argc args:(char*[]) argv {
    main2* m = [main2 alloc];
    [m run:argc args:argv];
    return m;
}

- (void)decrementRequests {
    --requestCount;
    if (requestCount == 0) {
        NSLog(@"Stopping run loop since all streams done.");
        CFRunLoopStop(CFRunLoopGetMain());
    }
}

- (void)run:(int)argc args:(char*[])argv {
    //NSString* output_file;
    //BOOL verbose = YES;
    while(1) {
        int option_index = 0;
        int c = getopt_long(argc, argv, "Ohv", long_options, &option_index);
        if (c == -1) {
            break;
        }
        switch(c) {
            case 'O':
                //output_file = [NSString stringWithUTF8String: argv[optind-1]];
                break;
            case 'h':
                print_help();
            case 'v':
                //verbose = YES;
                break;
            case '?':
                exit(1);
            default:
                break;
        }
    }
    if (optind > argc) {
        print_help();
    }

    struct sigaction act;
    memset(&act, 0, sizeof(struct sigaction));
    act.sa_handler = SIG_IGN;
    sigaction(SIGPIPE, &act, 0);
    
    // Set up SSL.
    SSL_library_init();
    requestCount = 4;
    cat = [[spdycat alloc]init];
    [cat fetch:@"https://www.google.com/" delegate:[[[ShowBody alloc]init:self] autorelease]];
    [cat fetch:@"https://www.google.com/imghp" delegate:[[[ShowBody alloc]init:self] autorelease]];
    [cat fetch:@"https://images.google.com/imghp" delegate:[[[ShowBody alloc]init:self] autorelease]];
    [cat fetch:@"https://www.yahoo.com/" delegate:[[[ShowBody alloc]init:self] autorelease]];
}

-(void)dealloc {
    [cat release];
}

@end
