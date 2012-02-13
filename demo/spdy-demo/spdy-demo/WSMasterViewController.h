//
//  WSMasterViewController.h
//  spdy-demo
//
//  Created by Jim Morrison on 2/10/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SPDY;

@interface WSMasterViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

- (IBAction)fetchUrl:(id)sender;

@property (weak, nonatomic) IBOutlet UITableView *urlTable;
@property (weak, nonatomic) IBOutlet UITextField *urlInput;
@property (retain) NSMutableArray *urlsFetched;
@property (retain) SPDY *spdy;

@end
