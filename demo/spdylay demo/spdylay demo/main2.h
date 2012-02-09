
#import <Foundation/NSObject.h>

@interface main2 : NSObject {
    
}

+ (main2*)newMain2:(int)argc args:(char* [])argv;
- (void)run:(int)argc args:(char*[])argv;
- (void)decrementRequests;

@end

