//
//      File: SpdyInputStream.m
//  Abstract: Implementation of a wrapping input stream.
//
//  Created by Jim Morrison on 2/29/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "SpdyInputStream.h"

@implementation SpdyInputStream {
    NSMutableDictionary *properties;

    // Fields that any wrapper input stream will need to have.
    NSInputStream *parentStream;
    id <NSStreamDelegate> delegate;
    
    CFReadStreamClientCallBack copiedCallback;
    CFStreamClientContext copiedContext;
    CFOptionFlags requestedEvents;
}

@synthesize error;
@synthesize requestId;

- (SpdyInputStream *)init:(NSInputStream *)parent {
    self = [super init];
    [self setDelegate:self];
    if (self) {
        self.requestId = nil;
        self.error = nil;
        parentStream = [parent retain];
        [parentStream setDelegate:self];
        properties = [[NSMutableDictionary alloc]initWithCapacity:4];
    }
    
    return self;
}

- (void)dealloc {
    [parentStream release];
    [properties removeAllObjects];
    [properties release];
    self.requestId = nil;
    self.error = nil;
}

- (void)open {
    [parentStream open];
}

- (void)close {
    if (self.requestId != nil) {
        [self.requestId close];
    }
    [parentStream close];
}

- (id <NSStreamDelegate>)delegate {
    return delegate;
}

- (void)setDelegate:(id<NSStreamDelegate>)aDelegate {
    if (aDelegate == nil) {
        delegate = self;
    } else {
        delegate = aDelegate;
    }
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    [parentStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    [parentStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (id)propertyForKey:(NSString *)key {
    id value = [parentStream propertyForKey:key];
    if (value != nil) {
        return value;
    }
    return [properties objectForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key {
    if (![parentStream setProperty:property forKey:key]) {
        [properties setObject:property forKey:key];
    }
    return YES;
}

- (NSStreamStatus)streamStatus {
    return [parentStream streamStatus];
}

- (NSError *)streamError {
    if (self.error != nil) {
        return self.error;
    }
    return [parentStream streamError];
}

#pragma mark NSInputStream subclass methods

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    return [parentStream read:buffer maxLength:len];
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
    return [parentStream getBuffer:buffer length:len];
}

- (BOOL)hasBytesAvailable {
    return [parentStream hasBytesAvailable];
}

#pragma mark Undocumented CFReadStream bridged methods

- (void)_scheduleInCFRunLoop:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)aMode {
    CFReadStreamScheduleWithRunLoop((CFReadStreamRef)parentStream, aRunLoop, aMode);
}

- (BOOL)_setCFClientFlags:(CFOptionFlags)inFlags
                    callback:(CFReadStreamClientCallBack)inCallback
                    context:(CFStreamClientContext *)inContext {
    if (inCallback != NULL) {
        requestedEvents = inFlags;
        copiedCallback = inCallback;
        memcpy(&copiedContext, inContext, sizeof(CFStreamClientContext));
        
        if (copiedContext.info && copiedContext.retain) {
            copiedContext.retain(copiedContext.info);
        }
    } else {
        requestedEvents = kCFStreamEventNone;
        copiedCallback = NULL;
        if (copiedContext.info && copiedContext.release) {
            copiedContext.release(copiedContext.info);
        }
        
        memset(&copiedContext, 0, sizeof(CFStreamClientContext));
    }
    
    return YES;	
}

- (void)_unscheduleFromCFRunLoop:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)aMode {
    CFReadStreamUnscheduleFromRunLoop((CFReadStreamRef)parentStream, aRunLoop, aMode);
}

#pragma mark NSStreamDelegate methods

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    assert(aStream == parentStream);

    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            if (requestedEvents & kCFStreamEventOpenCompleted) {
                copiedCallback((CFReadStreamRef)self,
                               kCFStreamEventOpenCompleted,
							   copiedContext.info);
            }
            break;
            
        case NSStreamEventHasBytesAvailable:
            if (requestedEvents & kCFStreamEventHasBytesAvailable) {
                copiedCallback((CFReadStreamRef)self,
                               kCFStreamEventHasBytesAvailable,
                               copiedContext.info);
            }
            break;
            
        case NSStreamEventErrorOccurred:
            if (requestedEvents & kCFStreamEventErrorOccurred) {
                copiedCallback((CFReadStreamRef)self,
                               kCFStreamEventErrorOccurred,
                               copiedContext.info);
            }
            break;
            
        case NSStreamEventEndEncountered:
            if (requestedEvents & kCFStreamEventEndEncountered) {
                copiedCallback((CFReadStreamRef)self,
                               kCFStreamEventEndEncountered,
                               copiedContext.info);
            }
            break;
            
        case NSStreamEventHasSpaceAvailable:
            // This doesn't make sense for a read stream
            break;
            
        default:
            break;
    }
}

@end
