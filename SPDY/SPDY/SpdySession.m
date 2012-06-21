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
- (void)connectionFailed:(NSInteger)error domain:(NSString *)domain;
- (void)invalidateSocket;
- (void)removeStream:(SpdyStream *)stream;
- (int)send_data:(const uint8_t *)data len:(size_t)len flags:(int)flags;
- (void)setUpSslCtx;
- (BOOL)sslConnect;
- (BOOL)sslHandshake;  // Returns true if the handshake completed.
- (void)sslError;
- (BOOL)submitRequest:(SpdyStream *)stream;
- (BOOL)wouldBlock:(int)r;
- (ssize_t)fixUpCallbackValue:(int)r;
- (void)enableWriteCallback;
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

- (void)setUpSslCtx {
    /* Disable SSLv2 and enable all workarounds for buggy servers */
    SSL_CTX_set_options(ssl_ctx, SSL_OP_ALL|SSL_OP_NO_SSLv2);
    SSL_CTX_set_mode(ssl_ctx, SSL_MODE_AUTO_RETRY);
    SSL_CTX_set_mode(ssl_ctx, SSL_MODE_RELEASE_BUFFERS);
    SSL_CTX_set_mode(ssl_ctx, SSL_MODE_ENABLE_PARTIAL_WRITE);
    SSL_CTX_set_next_proto_select_cb(ssl_ctx, select_next_proto_cb, self);
}

- (void)sslError {
    SPDY_LOG(@"%s", ERR_error_string(ERR_get_error(), 0));
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
        [[spdyStream delegate] onRequestBytesSent:bytesRead];
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
    SPDY_LOG(@"Looking up hostname for %@", [url host]);
    int err = getaddrinfo([[url host] UTF8String], service, &hints, &res);
    if (err != 0) {
        NSError *error;
        if (err == EAI_SYSTEM) {
            error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        } else {
            error = [NSError errorWithDomain:@"kCFStreamErrorDomainNetDB" code:err userInfo:nil];
        }
        SPDY_LOG(@"Error getting IP address for %@ (%@)", url, error);
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
        
        // Ignore write failures, and deal with then on write.
        int set = 1;
        int sock = CFSocketGetNative(socket);
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
        
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

- (void)connectionFailed:(NSInteger)err domain:(NSString *)domain {
    self.connectState = ERROR;
    [self invalidateSocket];
    NSError *error = [NSError errorWithDomain:domain code:err userInfo:nil];
    for (SpdyStream *value in streams) {
        [value.delegate onError:error];
    }
}

- (void)_cancelStream:(SpdyStream *)stream {
    [stream cancelStream];
    if (stream.streamId > 0) {
        spdylay_submit_rst_stream([self session], stream.streamId, SPDYLAY_CANCEL);
    }
}

- (void)cancelStream:(SpdyStream *)stream {
    // Do not remove the stream here as it will be removed on the close callback when spdylay is done with the object.
    [self _cancelStream:stream];
}

- (NSInteger)resetStreamsAndGoAway {
    NSInteger cancelledStreams = [streams count];
    for (SpdyStream *stream in streams) {
        [self _cancelStream:stream];
    }
    if (session != nil) {
        spdylay_submit_goaway(session, SPDYLAY_GOAWAY_OK);
        spdylay_session_send(session);
    }
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
        SPDY_LOG(@"Failed to submit request for %@", stream);
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
        NSInteger oldErrno = errno;
        NSInteger err = SSL_get_error(ssl, r);
        if (err == SSL_ERROR_SYSCALL)
            [self connectionFailed:oldErrno domain:(NSString *)kCFErrorDomainPOSIX];
        else
            [self connectionFailed:err domain:kOpenSSLErrorDomain];
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
    [self setUpSslCtx];
    ssl = SSL_new(ssl_ctx);
    if (ssl == NULL) {
        [self sslError];
        return;
    }
    SSL_set_tlsext_host_name(ssl, [[self.host host] UTF8String]);
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
    self.host = h;
    return [self connectTo:h];
}

- (void)addStream:(SpdyStream *)stream {
    stream.parentSession = self;
    [streams addObject:stream];
    if (self.connectState == CONNECTED) {
        if (![self submitRequest:stream]) {
            return;
        }
        int err = spdylay_session_send(self.session);
        if (err != 0) {
            SPDY_LOG(@"Error (%d) sending data for %@", err, stream);
        }
    } else {
        SPDY_LOG(@"Post-poning %@ until a connection has been established, current state %d", stream, self.connectState);
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

- (void)fetchFromRequest:(NSURLRequest *)request delegate:(RequestCallback *)delegate {
    SpdyStream *stream = [[SpdyStream newFromRequest:(NSURLRequest *)request delegate:delegate] autorelease];
    [self addStream:stream];
}

- (void)addToLoop {
    CFRunLoopSourceRef loop_ref = CFSocketCreateRunLoopSource (NULL, socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), loop_ref, kCFRunLoopCommonModes);
    CFRelease(loop_ref);
}

- (int)recv_data:(uint8_t *)data len:(size_t)len flags:(int)flags {
    return SSL_read(ssl, data, (int)len);
}

- (BOOL)wouldBlock:(int)sslError {
    return sslError == SSL_ERROR_WANT_READ || sslError == SSL_ERROR_WANT_WRITE;
}

- (ssize_t)fixUpCallbackValue:(int)r {
    [self enableWriteCallback];

    if (r > 0)
        return r;

    int sslError = SSL_get_error(ssl, r);
    if (r < 0 && [self wouldBlock:sslError]) {
        r = SPDYLAY_ERR_WOULDBLOCK;
    } else {
        int sysError = sslError;
        if (sslError == SSL_ERROR_SYSCALL) {
            sysError = ERR_get_error();
            if (sysError == 0) {
                if (r == 0)
                    sysError = -1;
                else
                    sysError = errno;
            }
        }
        SPDY_LOG(@"SSL Error %d, System error %d, retValue %d, closing connection", sslError, sysError, r);
        r = SPDYLAY_ERR_CALLBACK_FAILURE;
        [self connectionFailed:ECONNRESET domain:(NSString *)kCFErrorDomainPOSIX];
        [self invalidateSocket];
    }

    // Clear any errors that we could have encountered.
    ERR_clear_error();
    return r;
}

static ssize_t recv_callback(spdylay_session *session, uint8_t *data, size_t len, int flags, void *user_data) {
    SpdySession *ss = (SpdySession *)user_data;
    int r = [ss recv_data:data len:len flags:flags];
    return [ss fixUpCallbackValue:r];
}

- (int)send_data:(const uint8_t *)data len:(size_t)len flags:(int)flags {
    return SSL_write(ssl, data, (int)len);
}

- (void)enableWriteCallback {
    if (socket != NULL)
        CFSocketEnableCallBacks(socket, kCFSocketWriteCallBack | kCFSocketReadCallBack);    
}

static ssize_t send_callback(spdylay_session *session, const uint8_t *data, size_t len, int flags, void *user_data) {
    SpdySession *ss = (SpdySession*)user_data;
    int r = [ss send_data:data len:len flags:flags];
    return [ss fixUpCallbackValue:r];
}

static void on_data_chunk_recv_callback(spdylay_session *session, uint8_t flags, int32_t stream_id,
                                        const uint8_t *data, size_t len, void *user_data) {
    SpdyStream *stream = spdylay_session_get_stream_user_data(session, stream_id);
    [stream writeBytes:data len:len];
}

static void on_stream_close_callback(spdylay_session *session, int32_t stream_id, spdylay_status_code status_code, void *user_data) {
    SpdyStream *stream = spdylay_session_get_stream_user_data(session, stream_id);
    SPDY_LOG(@"Stream closed %@, because spdylay_status_code=%d", stream, status_code);
    [stream closeStream];
    SpdySession *ss = (SpdySession *)user_data;
    [ss removeStream:stream];
}

static void on_ctrl_recv_callback(spdylay_session *session, spdylay_frame_type type, spdylay_frame *frame, void *user_data) {
    if (type == SPDYLAY_SYN_REPLY) {
        spdylay_syn_reply *reply = &frame->syn_reply;
        SpdyStream *stream = spdylay_session_get_stream_user_data(session, reply->stream_id);
        SPDY_LOG(@"Received headers for %@", stream)
        [stream parseHeaders:(const char **)reply->nv];
    }
}

static void before_ctrl_send_callback(spdylay_session *session, spdylay_frame_type type, spdylay_frame *frame, void *user_data) {
    if (type == SPDYLAY_SYN_STREAM) {
        spdylay_syn_stream *syn = &frame->syn_stream;
        SpdyStream *stream = spdylay_session_get_stream_user_data(session, syn->stream_id);
        [stream setStreamId:syn->stream_id];
        SPDY_LOG(@"Sending SYN_STREAM for %@", stream);
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

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ host: %@, spdyVersion=%d, state=%d, networkStatus: %d", [super description], host, self.spdyVersion, self.connectState, self.networkStatus];
}
@end

static void sessionCallBack(CFSocketRef s,
                            CFSocketCallBackType callbackType,
                            CFDataRef address,
                            const void *data,
                            void *info) {
    //SPDY_DEBUG_LOG(@"Calling session callback: %p", info);
    if (info == NULL) {
        return;
    }
    SpdySession *session = (SpdySession *)info;
    if (session.connectState == CONNECTING) {
        if (data != NULL) {
            int e = *(int *)data;
            [session connectionFailed:e domain:(NSString *)kCFErrorDomainPOSIX];
            return;
        }
        SPDY_LOG(@"Connected to %@", info);
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
        int err = spdylay_session_send(laySession);
        if (err != 0) {
            SPDY_LOG(@"Error writing data in write callback for session %@", session);
        }
    }
    if (callbackType & kCFSocketReadCallBack) {
        spdylay_session_recv(laySession);
    }
}


