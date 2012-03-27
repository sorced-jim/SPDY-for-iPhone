//
//  WSAppDelegate.m
//  spdycat
//
//  Created by Jim Morrison on 2/20/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "WSAppDelegate.h"
#import "SPDY.h"

// Create CFHTTPMessage.
static CFHTTPMessageRef createHttpMessage() {
    CFHTTPMessageRef msg = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"),
                                                      CFURLCreateWithString(kCFAllocatorDefault, CFSTR("https://www.google.com/"), NULL),
                                                      kCFHTTPVersion1_0);
    CFHTTPMessageSetHeaderFieldValue(msg, CFSTR("X-Try-Spdy"), CFSTR("Jim was phython, are you looking at the logs?"));
    return msg;
}

@interface ShowBody : BufferedCallback {
}

@end

@implementation ShowBody

- (void)onError:(CFErrorRef)error {
    NSLog(@"Got an error!");
}

- (void)onNotSpdyError {
    NSLog(@"Not spdy!");
}

- (void)onResponse:(CFHTTPMessageRef)response {
    CFDataRef body = CFHTTPMessageCopyBody(response);
    printf("%.*s", (int)CFDataGetLength(body), CFDataGetBytePtr(body));
    CFRelease(body);
}

@end


@implementation WSAppDelegate {
    SPDY *spdy;
}

@synthesize window = _window;

static void ReadStreamClientCallBack(CFReadStreamRef readStream, CFStreamEventType type, void *info) {
    CFHTTPMessageRef msg = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    if (msg == NULL) {
        NSLog(@"No response header.");
        return;
    }
    if (!CFHTTPMessageIsHeaderComplete(msg)) {
        NSLog(@"Incomplete headers.");
        CFRelease(msg);
        return;
    }
    CFRelease(msg);
    UInt8* bytes = malloc(16*1024);
    CFIndex bytesRead = CFReadStreamRead(readStream, bytes, 16*1024);
    printf("%.*s", (int)bytesRead, bytes);
    free(bytes);
}

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //spdy = [SPDY sharedSPDY];
    //[spdy fetch:@"https://images.google.com/" delegate:[[[ShowBody alloc] init] autorelease]];
    //[spdy fetch:@"https://images.google.com/imghp" delegate:[[[ShowBody alloc] init] autorelease]];
    //[spdy fetchFromMessage:createHttpMessage() delegate:[[[ShowBody alloc] init] autorelease]];
    
    CFReadStreamRef readStream = SpdyCreateSpdyReadStream(kCFAllocatorDefault, createHttpMessage(), NULL);
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

    CFStreamClientContext ctxt = {0, self, NULL, NULL, NULL};
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable, ReadStreamClientCallBack, &ctxt);
    CFReadStreamOpen(readStream);
    
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

@end
