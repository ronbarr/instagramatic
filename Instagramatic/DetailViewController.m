//
//  DetailViewController.m
//  Instagramatic
//
//  Created by Ron Barr on 10/26/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import "DetailViewController.h"

@interface DetailViewController ()

@end

@implementation DetailViewController

-(void) viewDidLoad {
    [super viewDidLoad];
 
    self.imageView.image = self.imageToShow;
}

- (IBAction)dismiss:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];

}

- (BOOL)prefersStatusBarHidden
/** tell the system to hide the status bar */
{
    return YES;
}
@end
