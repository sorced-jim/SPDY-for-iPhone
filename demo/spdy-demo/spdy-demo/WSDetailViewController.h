//
//  WSDetailViewController.h
//  spdy-demo
//
//  Created by Jim Morrison on 2/10/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WSDetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;

@property (strong, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end
