//
//  WSDetailViewController.m
//  spdy-demo
//
//  Created by Jim Morrison on 2/10/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "WSDetailViewController.h"
#import "FetchedUrl.h"

@interface WSDetailViewController ()
- (void)configureView;
@end

@implementation WSDetailViewController {
    FetchedUrl *_url;
    NSString* _state;
}
@synthesize navTitle = _navTitle;
@synthesize webView = _webView;


#pragma mark - Managing the url.

- (void)setUrl:(FetchedUrl*)u {
    if (_url != u) {
        _url = u;
        // Update the view.
        [self configureView];
    }
}

- (FetchedUrl*)url {
    return _url;
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self.url != nil) {
        self.navTitle.title = self.url.url;
        if (self.url.state == @"loaded") {
            [self.webView loadData:self.url.body MIMEType:@"text/html" textEncodingName:@"utf-8" baseURL:self.url.baseUrl];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.url = nil;
    [self configureView];
}

- (void)viewDidUnload
{
    [self setWebView:nil];
    [self setTitle:nil];
    [self setNavTitle:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    self.url = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)dealloc {
    self.url = nil;
    [_webView release];
    [_navTitle release];
    [super dealloc];
}
@end
