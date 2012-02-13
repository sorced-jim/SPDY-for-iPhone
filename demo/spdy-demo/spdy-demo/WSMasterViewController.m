//
//  WSMasterViewController.m
//  spdy-demo
//
//  Created by Jim Morrison on 2/10/12.
//  Copyright (c) 2012 Twist Inc. All rights reserved.
//

#import "WSMasterViewController.h"
#import "FetchedUrl.h"
#import "SPDY/SPDY.h"

@implementation WSMasterViewController {
    NSMutableArray *_urlsFetched;
    SPDY *_spdy;
}
@synthesize urlTable;
@synthesize urlInput;
@synthesize urlsFetched = _urlsFetched;
@synthesize spdy = _spdy;


- (void)awakeFromNib
{
    [super awakeFromNib];
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

    self.urlsFetched = [NSMutableArray arrayWithCapacity:4];
    self.spdy = [[SPDY alloc]init];
    self.urlTable.dataSource = self;
    self.urlTable.delegate = self;
}

- (void)viewDidUnload
{
    [self setUrlInput:nil];
    [self setUrlTable:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
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


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source.
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }   
}

- (IBAction)fetchUrl:(id)sender {
    NSString *url = self.urlInput.text;
    if (url == nil) {
        return;
    }
    FetchedUrl *u = [[FetchedUrl alloc]init:url spdy:self.spdy];
    [self.urlsFetched addObject:u];
    NSArray* insertPath = [NSArray arrayWithObjects: [NSIndexPath indexPathForRow:[self.urlsFetched count]-1 inSection:0], nil];
    
    [self.urlTable beginUpdates];
    [self.urlTable insertRowsAtIndexPaths:insertPath withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.urlTable endUpdates];
    self.urlInput.text = nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *urlsId = @"webUrlCell";
    
    // Get a cell to use.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:urlsId];
    
    // Set up the cell.
    FetchedUrl *url = [self.urlsFetched objectAtIndex:indexPath.row];
    cell.textLabel.text = url.url;
    cell.detailTextLabel.text = url.state;
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // There is only one section.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of urls.
    return [self.urlsFetched count];
}


@end
