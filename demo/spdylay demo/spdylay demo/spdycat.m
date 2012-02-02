//
//  spdycat.m
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

#import "spdycat.h"

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h>

#include "openssl/ssl.h"
#include "openssl/err.h"
#include "spdylay/spdylay.h"

@implementation spdycat

@synthesize show_headers;
@synthesize output_file;
@synthesize session;

static void MyCallBack (CFSocketRef s,
                        CFSocketCallBackType callbackType,
                        CFDataRef address,
                        const void *data,
                        void *info) {
    spdycat *cat = (spdycat*)info;
    if (callbackType == kCFSocketWriteCallBack) {
        const char *nv[] = {
            "method", "GET",
            "scheme", "https",
            "url", "/",
            "host", "www.google.com",
            "user-agent", "SPDY obj-c/0.0.0",
            "version", "HTTP/1.1",
            NULL
        };
        spdylay_submit_request([cat session], 1, nv, NULL);
        NSLog(@"I can write data!");
    }
    return;
}

static int select_next_proto_cb(SSL* ssl,
                                unsigned char **out, unsigned char *outlen,
                                const unsigned char *in, unsigned int inlen,
                                void *arg)
{
    *out = (unsigned char*)in+1;
    *outlen = in[0];
    for(unsigned int i = 0; i < inlen; i += in[i]+1) {
        if(in[i] == 6 && memcmp(&in[i+1], "spdy/2", in[i]) == 0) {
            *out = (unsigned char*)in+i+1;
            *outlen = in[i];
        }
    }
    return SSL_TLSEXT_ERR_OK;
}

static void setup_ssl_ctx(SSL_CTX *ssl_ctx)
{
    /* Disable SSLv2 and enable all workarounds for buggy servers */
    SSL_CTX_set_options(ssl_ctx, SSL_OP_ALL|SSL_OP_NO_SSLv2);
    SSL_CTX_set_mode(ssl_ctx, SSL_MODE_AUTO_RETRY);
    SSL_CTX_set_mode(ssl_ctx, SSL_MODE_RELEASE_BUFFERS);
    SSL_CTX_set_next_proto_select_cb(ssl_ctx, select_next_proto_cb, 0);
}

static CFSocketRef ssl_error() {
    NSLog(@"%s\n", ERR_error_string(ERR_get_error(), 0));
    return nil;
}

static int connect_to(NSURL* url)
{
    int fd = -1;
    struct addrinfo hints;

    char service[10];
    NSNumber* port = [url port];
    if (port != nil) {
        snprintf(service, sizeof(service), "%u", [port intValue]);
    } else {
        snprintf(service, sizeof(service), "443");
    }
    
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    struct addrinfo *res;
    int err = getaddrinfo([[url host] UTF8String], service, &hints, &res);
    if (err != 0) {
        NSLog(@"%s\n", gai_strerror(err));
        return -1;
    }
        
    for(struct addrinfo *rp = res; rp; rp = rp->ai_next) {
        int r = 0;
        fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if(fd == -1) {
            continue;
        }
        while((r = connect(fd, rp->ai_addr, rp->ai_addrlen)) == -1 && errno == EINTR);
        if(r == 0) {
            break;
        }
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);
    return fd;
}

- (CFSocketRef) create_socket:(NSURL*) url
{
    // Create SSL Stream
    int sock = connect_to(url);
    if (sock < 0) {
        return nil;
    }
    ssl_ctx = SSL_CTX_new(SSLv23_client_method());
    if(ssl_ctx == NULL) {
        return ssl_error();
    }
    setup_ssl_ctx(ssl_ctx);
    ssl = SSL_new(ssl_ctx);
    if (ssl == NULL) {
        return ssl_error();
    }
    if (SSL_set_fd(ssl, sock) == 0) {
        return ssl_error();
    }
    if (SSL_connect(ssl) < 0) {
        return ssl_error();
    }
    CFSocketContext ctx = {0, self, NULL, NULL, NULL};
    CFSocketRef s = CFSocketCreateWithNative(NULL, sock, kCFSocketReadCallBack | kCFSocketWriteCallBack, (CFSocketCallBack)&MyCallBack, &ctx);
    if (s == nil) {
        return nil;
    }
    NSLog(@"Created a connection to %@\n", url);
    return s;
}

- (void)fetch:(NSString *)url
{
    NSURL* u = [NSURL URLWithString:url];
    if (u == nil) {
        NSLog(@"Invalid url: %@", url);        
    }
    
    socket = [self create_socket:u];
    if (socket != nil) {
        CFRunLoopSourceRef loop_ref = CFSocketCreateRunLoopSource (NULL, socket, 0);
        CFRunLoopRef loop = CFRunLoopGetCurrent();
        CFRunLoopAddSource(loop, loop_ref, kCFRunLoopCommonModes);
    }
}

- (spdycat*) init
{
    self = [super init];
    spdylay_session_client_new(&session, NULL, self);
    return self;
}

- (void)dealloc
{
    spdylay_session_del(session);
    SSL_shutdown(ssl);
    SSL_free(ssl);
    SSL_CTX_free(ssl_ctx);
    CFSocketInvalidate(socket);
    socket = nil;
    self.output_file = nil;
    [super dealloc];
}
@end
