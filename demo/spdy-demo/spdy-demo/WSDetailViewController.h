//
//  WSDetailViewController.h
//  spdy-demo
//
//  Created by Jim Morrison on 2/10/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FetchedUrl;

@interface WSDetailViewController : UIViewController
@property (retain, nonatomic) IBOutlet UINavigationItem *navTitle;
@property (retain, nonatomic) IBOutlet UIWebView *webView;
@property (retain) FetchedUrl* url;


@end
