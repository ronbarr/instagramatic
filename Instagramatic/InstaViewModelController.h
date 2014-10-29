//
//  InstaViewModelController.h
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import "InstaViewModelControllerDelegate.h"
#import "CoreDataManager.h"

/* Manages the flow of Instagram data to the UICollection View.
 Delegate/Datasource for Collection View */


@interface InstaViewModelController : NSObject <UICollectionViewDelegate, UICollectionViewDataSource,NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) UICollectionView * collectionView;
@property (strong, nonatomic) UIView * hostView;
@property (strong, nonatomic) id <InstaViewModelControllerDelegate> delegate;

@end
