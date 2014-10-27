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
    UITapGestureRecognizer * tapRecognizer = [[UITapGestureRecognizer alloc]
                                              initWithTarget:self.imageView
                                              action:@selector(imageTapped)];
    [tapRecognizer setNumberOfTapsRequired:1];
    [self.imageView addGestureRecognizer:tapRecognizer];
}

-(void) imageTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
