//
//  HomeViewController.m
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import "InstaViewController.h"
#import "InstaViewModelController.h"

@interface InstaViewController ()

@property (strong,nonatomic) InstaViewModelController * modelController;

@end

@implementation InstaViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.modelController = [[InstaViewModelController alloc] init];
    self.modelController.collectionView = self.collectionView;
    self.collectionView.delegate = self.modelController;
    self.collectionView.dataSource = self.modelController;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
