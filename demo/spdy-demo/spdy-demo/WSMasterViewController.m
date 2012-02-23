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
#import "WSDetailViewController.h"

@implementation WSMasterViewController {
    NSMutableArray *_urlsFetched;
    SPDY *spdy;
}
@synthesize urlTable;
@synthesize urlInput;
@synthesize urlsFetched = _urlsFetched;


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
    spdy = [SPDY sharedSPDY];
    self.urlTable.dataSource = self;
    self.urlTable.delegate = self;
}

- (void)viewDidUnload
{
    [self setUrlInput:nil];
    [self setUrlTable:nil];
    [super viewDidUnload];

    // Release any retained subviews of the main view.
    self.urlsFetched = nil;
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
    return NO;
}

- (IBAction)fetchUrl:(id)sender {
    NSString *url = self.urlInput.text;
    if (url == nil) {
        return;
    }
    FetchedUrl *u = [[[FetchedUrl alloc]init:url spdy:spdy table:self.urlTable] autorelease];
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
    [self.view endEditing:YES];
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSUInteger selectedIndex = [self.urlTable indexPathForSelectedRow].row;
	if ([segue.identifier isEqualToString:@"viewPageSeque"]) {
        WSDetailViewController *webViewController = segue.destinationViewController;
        webViewController.url = [self.urlsFetched objectAtIndex:selectedIndex];
	}
}

@end
