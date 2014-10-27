  //
//  HomeViewController.m
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import "InstaViewController.h"
#import "InstaViewModelController.h"
#import "InstagramAPIController.h"
#import "DetailViewController.h"

@interface InstaViewController ()

@property (strong,nonatomic) InstaViewModelController * modelController;
@property (strong, nonatomic) UIImage * image;

@end

@implementation InstaViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.modelController = [[InstaViewModelController alloc] init];
    self.modelController.collectionView = self.collectionView;
    self.modelController.delegate = self;
    
    self.collectionView.delegate = self.modelController;
    self.collectionView.dataSource = self.modelController;
    
 }

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"detailView"]) {
        DetailViewController * controller = (DetailViewController *) segue.destinationViewController;
         controller.imageToShow = self.image;
    }
}

-(void) displayDetailImage:(UIImage *) image; {
    
    self.image = image;
    [self performSegueWithIdentifier:@"detailView" sender:self];
}

- (BOOL)prefersStatusBarHidden
/** tell the system to hide the status bar */
{
    return YES;
}

@end
