//
//  SpdySession.m
//  This class is the only one that deals with both SSL and spdylay.
//  To replace the base spdy library, this is the only class that should
//  be change.
//
//  Created by Jim Morrison on 2/8/12.
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

#import "SpdySession.h"

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#include <fcntl.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>


#import "SPDY.h"
#import "SpdyStream.h"

#include "openssl/ssl.h"
#include "openssl/err.h"
#include "spdylay/spdylay.h"

static const int priority = 1;

@interface SpdySession ()

@property (assign) uint16_t spdyVersion;

- (void)_cancelStream:(SpdyStream *)stream;
- (NSError *)connectTo:(NSURL *)url;
- (void)connectionFailed:(int)error domain:(CFStringRef)domain;
- (void)invalidateSocket;
- (void)removeStream:(SpdyStream *)stream;
- (int)send_data:(const uint8_t *)data len:(size_t)len flags:(int)flags;
- (void)setup_ssl_ctx;
- (BOOL)sslConnect;
- (BOOL)sslHandshake;  // Returns true if the handshake completed.
- (void)sslError;
- (BOOL)submitRequest:(SpdyStream *)stream;
- (BOOL)wouldBlock:(int)r;
@end


@implementation SpdySession {
    NSMutableSet *streams;
    
    CFSocketRef socket;
    SSL *ssl;
    SSL_CTX *ssl_ctx;
    spdylay_session_callbacks *callbacks;
}

@synthesize spdyNegotiated;
@synthesize spdyVersion;
@synthesize session;
@synthesize host;
@synthesize connectState;
@synthesize networkStatus;

static void sessionCallBack(CFSocketRef s,
                            CFSocketCallBackType callbackType,
                            CFDataRef address,
                            const void *data,
                            void *info);

static int select_next_proto_cb(SSL *ssl,
                                unsigned char **out, unsigned char *outlen,
                                const unsigned char *in, unsigned int inlen,
                                void *arg) {
    SpdySession *sc = (SpdySession *)arg;
    int spdyVersion = spdylay_select_next_protocol(out, outlen, in, inlen);
    if (spdyVersion > 0) {
        sc.spdyVersion = spdyVersion;
        sc.spdyNegotiated = YES;
    }
    
    return SSL_TLSEXT_ERR_OK;
}

- (void)invalidateSocket {
  if (socket == nil)
    return;

  CFSocketInvalidate(socket);
  CFRelease(socket);
  socket = nil;
}

- (void)setup_ssl_ctx {
    /* Disable SSLv2 and enable all workarounds for buggy servers */
    SSL_CTX_set_options(ssl_ctx, SSL_OP_ALL|SSL_OP_NO_SSLv2);
    SSL_CTX_set_mode(ssl_ctx, SSL_MODE_AUTO_RETRY);
    SSL_CTX_set_mode(ssl_ctx, SSL_MODE_RELEASE_BUFFERS);
    SSL_CTX_set_next_proto_select_cb(ssl_ctx, select_next_proto_cb, self);
}

- (void)sslError {
    NSLog(@"%s", ERR_error_string(ERR_get_error(), 0));
    [self invalidateSocket];
}

static int make_non_block(int fd) {
    int flags, r;
    while ((flags = fcntl(fd, F_GETFL, 0)) == -1 && errno == EINTR);
    if (flags == -1)
        return -1;
    while ((r = fcntl(fd, F_SETFL, flags | O_NONBLOCK)) == -1 && errno == EINTR);
    if (r == -1)
        return -1;
    return 0;
}

static ssize_t read_from_data_callback(spdylay_session *session, int32_t stream_id, uint8_t *buf, size_t length, int *eof, spdylay_data_source *source, void *user_data) {
    NSInputStream* stream = (NSInputStream*)source->ptr;
    NSInteger bytesRead = [stream read:buf maxLength:length];
    if (![stream hasBytesAvailable]) {
        *eof = 1;
        [stream close];
    }
    SpdyStream *spdyStream = spdylay_session_get_stream_user_data(session, stream_id);
    if (bytesRead > 0) {
        [[spdyStream delegate]onRequestBytesSent:bytesRead];
    }
    return bytesRead;
}

- (NSError *)connectTo:(NSURL *)url {
    struct addrinfo hints;
    
    char service[10];
    NSNumber *port = [url port];
    if (port != nil)
        snprintf(service, sizeof(service), "%u", [port intValue]);
    else
        snprintf(service, sizeof(service), "443");
    
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    
    struct addrinfo *res;
    int err = getaddrinfo([[url host] UTF8String], service, &hints, &res);
    if (err != 0) {
        NSError *error;
        if (err == EAI_SYSTEM) {
            NSLog(@"Die here.");
            error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        } else {
            NSLog(@"Die other.");
            error = [NSError errorWithDomain:@"kCFStreamErrorDomainNetDB" code:err userInfo:nil];
        }
        self.connectState = ERROR;
        return error;
    }

    struct addrinfo* rp = res;
    if (rp != NULL) {
        CFSocketContext ctx = {0, self, NULL, NULL, NULL};
        CFDataRef address = CFDataCreate(NULL, (const uint8_t*)rp->ai_addr, rp->ai_addrlen);
        socket = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketConnectCallBack | kCFSocketReadCallBack | kCFSocketWriteCallBack,
                                &sessionCallBack, &ctx);
        CFSocketConnectToAddress(socket, address, -1);
        CFRelease(address);
        self.connectState = CONNECTING;
        freeaddrinfo(res);
        return nil;
    }
    self.connectState = ERROR;
    return [NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork code:kCFHostErrorHostNotFound userInfo:nil];
}

- (void)notSpdyError {
    self.connectState = ERROR;
    
    for (SpdyStream *stream in streams) {
        [stream notSpdyError];
    }
}

- (void)connectionFailed:(int)error domain:(CFStringRef)domain {
    self.connectState = ERROR;
    [self invalidateSocket];
    CFErrorRef cfError = CFErrorCreate(kCFAllocatorDefault, domain, error, NULL);
    for (SpdyStream *value in streams) {
        [value.delegate onError:cfError];
    }
    CFRelease(cfError);
}

- (void)_cancelStream:(SpdyStream *)stream {
    [stream cancelStream];
    if (stream.streamId > 0) {
        spdylay_submit_rst_stream([self session], stream.streamId, SPDYLAY_CANCEL);
    }
}

- (void)cancelStream:(SpdyStream *)stream {
    [self _cancelStream:stream];
    [streams removeObject:stream];
}

- (NSInteger)resetStreamsAndGoAway {
    NSInteger cancelledStreams = [streams count];
    for (SpdyStream *stream in streams) {
        [self _cancelStream:stream];
    }
    [streams removeAllObjects];
    spdylay_submit_goaway(session, SPDYLAY_GOAWAY_OK);
    spdylay_session_send(self.session);
    return cancelledStreams;
}

- (BOOL)isInvalid {
    return socket == nil;
}

- (BOOL)submitRequest:(SpdyStream *)stream {
    if (!self.spdyNegotiated) {
        [stream notSpdyError];
        return NO;
    }

    spdylay_data_provider data_prd = {-1, NULL};
    if (stream.body != nil) {
        [stream.body open];
        data_prd.source.ptr = stream.body;
        data_prd.read_callback = read_from_data_callback;
    }
    if (spdylay_submit_request(session, priority, [stream nameValues], &data_prd, stream) < 0) {
        NSLog(@"Failed to submit request.");
        [stream connectionError];
        return NO;
    }
    return YES;
}

- (BOOL)sslHandshake {
    int r = SSL_connect(ssl);
    if (r == 1) {
        self.connectState = CONNECTED;
        if (!self.spdyNegotiated) {
            [self notSpdyError];
            [self invalidateSocket];
            return NO;
        }

        spdylay_session_client_new(&session, self.spdyVersion, callbacks, self);

        NSEnumerator *enumerator = [streams objectEnumerator];
        id stream;
        
        while ((stream = [enumerator nextObject])) {
            if (![self submitRequest:stream]) {
                [streams removeObject:stream];
            }
        }
        return YES;
    }
    if (r == 0) {
        self.connectState = ERROR;
        [self notSpdyError];
        [self invalidateSocket];
    }
    return NO;
}

- (void)setUpSSL {
    // Create SSL context.
    int sock = CFSocketGetNative(socket);
    make_non_block(sock);  // Ensure the SSL methods will not block.
    ssl_ctx = SSL_CTX_new(SSLv23_client_method());
    if (ssl_ctx == NULL) {
        [self sslError];
        return;
    }
    [self setup_ssl_ctx];
    ssl = SSL_new(ssl_ctx);
    if (ssl == NULL) {
        [self sslError];
        return;
    }
    if (SSL_set_fd(ssl, sock) == 0) {
        [self sslError];
        return;
    }
}

- (BOOL)sslConnect {
    [self setUpSSL];
    return [self sslHandshake];
}



- (NSError *)connect:(NSURL *)h {
    [self setHost:h];
    return [self connectTo:h];
}

- (void)addStream:(SpdyStream *)stream {
    stream.parentSession = self;
    [streams addObject:stream];
    if (self.connectState == CONNECTED) {
        if (![self submitRequest:stream]) {
            return;
        }
        spdylay_session_send(self.session);
    }
}
    
- (void)fetch:(NSURL *)u delegate:(RequestCallback *)delegate {
    SpdyStream *stream = [[SpdyStream newFromNSURL:u delegate:delegate] autorelease];
    [self addStream:stream];
}


- (void)fetchFromMessage:(CFHTTPMessageRef)request delegate:(RequestCallback *)delegate body:(NSInputStream *)body {
    SpdyStream *stream = [[SpdyStream newFromCFHTTPMessage:request delegate:delegate body:body] autorelease];
    [self addStream:stream];
}

- (void)addToLoop {
    CFRunLoopSourceRef loop_ref = CFSocketCreateRunLoopSource (NULL, socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), loop_ref, kCFRunLoopCommonModes);
    CFRelease(loop_ref);
}

- (int)recv_data:(uint8_t *)data len:(size_t)len flags:(int)flags {
    int r;
    r = SSL_read(ssl, data, (int)len);
    if (r == 0) {
        NSLog(@"Closing connection from read = 0");
        [self connectionFailed:ECONNRESET domain:kCFErrorDomainPOSIX];
        [self invalidateSocket];
    }
    return r;
}

- (BOOL)wouldBlock:(int)r {
    int e = SSL_get_error(ssl, r);
    return e == SSL_ERROR_WANT_READ || e == SSL_ERROR_WANT_WRITE;
}

static ssize_t fixUpCallbackValue(SpdySession *ss, int r) {
    if (r < 0) {
        if ([ss wouldBlock:r]) {
            r = SPDYLAY_ERR_WOULDBLOCK;
        } else {
            r = SPDYLAY_ERR_CALLBACK_FAILURE;
        }
    } else if(r == 0) {
        r = SPDYLAY_ERR_CALLBACK_FAILURE;
    }
    return r;
}

static ssize_t recv_callback(spdylay_session *session, uint8_t *data, size_t len, int flags, void *user_data) {
    SpdySession *ss = (SpdySession *)user_data;
    int r = [ss recv_data:data len:len flags:flags];
    return fixUpCallbackValue(ss, r);
}

- (int)send_data:(const uint8_t *)data len:(size_t)len flags:(int)flags {
    int r = SSL_write(ssl, data, (int)len);
    if (r == 0) {
        NSLog(@"Closing connection from write = 0");
        [self connectionFailed:ECONNRESET domain:kCFErrorDomainPOSIX];
        [self invalidateSocket];
    }
    return r;
}

static ssize_t send_callback(spdylay_session *session, const uint8_t *data, size_t len, int flags, void *user_data) {
    SpdySession *ss = (SpdySession*)user_data;
    int r = [ss send_data:data len:len flags:flags];
    return fixUpCallbackValue(ss, r);
}

static void on_data_chunk_recv_callback(spdylay_session *session, uint8_t flags, int32_t stream_id,
                                        const uint8_t *data, size_t len, void *user_data) {
    SpdyStream *stream = spdylay_session_get_stream_user_data(session, stream_id);
    [stream writeBytes:data len:len];
}

static void on_stream_close_callback(spdylay_session *session, int32_t stream_id, spdylay_status_code status_code, void *user_data) {
    SpdyStream *stream = spdylay_session_get_stream_user_data(session, stream_id);
    [stream closeStream];
    SpdySession *ss = (SpdySession *)user_data;
    [ss removeStream:stream];
}

static void on_ctrl_recv_callback(spdylay_session *session, spdylay_frame_type type, spdylay_frame *frame, void *user_data) {
    if (type == SPDYLAY_SYN_REPLY) {
        spdylay_syn_reply *reply = &frame->syn_reply;
        SpdyStream *stream = spdylay_session_get_stream_user_data(session, reply->stream_id);
        [stream parseHeaders:(const char **)reply->nv];
    }
}

static void before_ctrl_send_callback(spdylay_session *session, spdylay_frame_type type, spdylay_frame *frame, void *user_data) {
    if (type == SPDYLAY_SYN_STREAM) {
        spdylay_syn_stream *syn = &frame->syn_stream;
        SpdyStream *stream = spdylay_session_get_stream_user_data(session, syn->stream_id);
        [stream setStreamId:syn->stream_id];
        [stream.delegate onConnect:stream];
    }
}

- (void)removeStream:(SpdyStream *)stream {
    [streams removeObject:stream];
}

- (SpdySession *)init {
    self = [super init];

    callbacks = malloc(sizeof(*callbacks));
    memset(callbacks, 0, sizeof(*callbacks));
    callbacks->send_callback = send_callback;
    callbacks->recv_callback = recv_callback;
    callbacks->on_stream_close_callback = on_stream_close_callback;
    callbacks->on_ctrl_recv_callback = on_ctrl_recv_callback;
    callbacks->before_ctrl_send_callback = before_ctrl_send_callback;
    callbacks->on_data_chunk_recv_callback = on_data_chunk_recv_callback;

    session = NULL;
    self.spdyNegotiated = NO;
    self.spdyVersion = -1;
    self.connectState = NOT_CONNECTED;
    
    streams = [[NSMutableSet alloc] init];
    
    return self;
}

- (void)dealloc {
    if (session != NULL) {
        spdylay_submit_goaway(session, SPDYLAY_GOAWAY_OK);
        spdylay_session_del(session);
        session = NULL;
    }
    [streams release];
    if (ssl != NULL) {
        SSL_shutdown(ssl);
        SSL_free(ssl);
        SSL_CTX_free(ssl_ctx);
    }
    [self invalidateSocket];
    free(callbacks);
    [super dealloc];
}
@end

static void sessionCallBack(CFSocketRef s,
                            CFSocketCallBackType callbackType,
                            CFDataRef address,
                            const void *data,
                            void *info) {
    if (info == NULL) {
        return;
    }
    SpdySession *session = (SpdySession *)info;
    if (session.connectState == CONNECTING) {
        if (data != NULL) {
            int e = *(int *)data;
            [session connectionFailed:e domain:kCFErrorDomainPOSIX];
            return;
        }
        session.connectState = SSL_HANDSHAKE;
        if (![session sslConnect]) {
            return;
        }
        callbackType |= kCFSocketWriteCallBack;
    }
    if (session.connectState == SSL_HANDSHAKE) {
        if (![session sslHandshake]) {
            return;
        }
        callbackType |= kCFSocketWriteCallBack;
    }

    spdylay_session *laySession = [session session];
    if (callbackType & kCFSocketWriteCallBack) {
        spdylay_session_send(laySession);
    }
    if (callbackType & kCFSocketReadCallBack) {
        spdylay_session_recv(laySession);
    }
}


