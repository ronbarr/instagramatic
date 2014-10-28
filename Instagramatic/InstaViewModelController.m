//
//  InstaViewModelController.m
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import "InstaViewModelController.h"
#import "InstagramAPIController.h"
#import "CoreDataManager.h"
#import "CollectionViewCell.h"

@interface InstaViewModelController ()

//The class that loads the database with images from Instagram
@property (strong, nonatomic) InstagramAPIController * APIController;
//Manages reading the database to supply images to the UI
@property (strong, nonatomic) NSFetchedResultsController * fetchedResultsController;

//Changed objects
@property (strong, nonatomic) NSMutableArray *objectChanges;

//Default Image
@property (strong, nonatomic) UIImage *defaultImage;

@end

@implementation InstaViewModelController

-(instancetype) init {
    if (self = [super init]) {
        //Create the API controller and start connection
        self.APIController = [InstagramAPIController sharedController];
        
        //Initialize the fetched results controller
        [[[self fetchedResultsController] managedObjectContext] performBlock:^{
            NSError *error = nil;
            if (![[self fetchedResultsController] performFetch:&error]){
                NSLog(@"error fetching %@",error);
            } else {
                // Update the view from the main queue.
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [self.collectionView reloadData];
                }];
            }
        }];
        _objectChanges = [NSMutableArray arrayWithCapacity:100];
        _defaultImage = [UIImage imageNamed:@"grayFemale"];
        
    }
    return self;
}
#pragma mark Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    CoreDataManager * coreDataManager = [CoreDataManager sharedManager];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Image"
                                              inManagedObjectContext:[coreDataManager rootObjectContext]];
    [fetchRequest setEntity:entity];
    
    //We're getting all records; no need to set a predicate
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Set the sort key
    
    NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"created"
                                                                      ascending:YES];
    
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    
    NSString * sectionPath = nil;
    
    //Creating a new local context for the fetched results controller. Now all delegate functions will happen in background
    NSFetchedResultsController *aFetchedResultsController =
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:[coreDataManager rootObjectContext]
                                          sectionNameKeyPath:sectionPath
                                                   cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    return _fetchedResultsController;
}

#pragma mark - changes
- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    
    [_objectChanges addObject:anObject];
    if (_objectChanges.count >= 20) {
        [_objectChanges removeAllObjects];
        self.fetchedResultsController = nil;
        [self.collectionView reloadData];
        NSLog(@"reloading...");

    }
}


#pragma mark - Collection View Data Source & delegate
-(NSInteger) collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    NSUInteger objectCount = self.fetchedResultsController.fetchedObjects.count;
    
    return objectCount;
}

-(UICollectionViewCell *) collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    //Should this be a large image?
    imageSize size = [self shouldBeLargeImage:indexPath] ? standard : loRes;
    
    CollectionViewCell * cell =
    [self.collectionView dequeueReusableCellWithReuseIdentifier:[self cellIdentifierForSize:size]
                                                   forIndexPath:indexPath];
    
    cell.image.image = _defaultImage;
    
    if (cell) {
        NSManagedObject * imageInfo = [self.fetchedResultsController objectAtIndexPath:indexPath];
        
        NSString * imageID = [imageInfo valueForKey:@"instaID"];
        
        cell.imageID = imageID;
        
        NSManagedObject * rawImageDataObject = [imageInfo valueForKey:[self imageIdentifierForSize:size]];
        
        NSData * rawImageData = [rawImageDataObject valueForKey:@"imageBinaryData"];
        
        //Is picture in db?
        if ([rawImageData length] > 0) {  //Yes!
            cell.image.image = [UIImage imageWithData:rawImageData];
        } else {                          //No
            //Does it have an URL for this size?

            NSString * imageURLKey = [self imageURL:size];
            NSString * imageURL = nil;
            if (imageURLKey) {
                imageURL = [imageInfo valueForKey:imageURLKey];
            }
            if ([imageURL length]) {   //Yes - go get it
                if ([self.APIController respondsToSelector:@selector(downloadImageAtURL:forImageID:size:onqueue:returnImage:)] &&
                    [imageID length]) {
                    [self.APIController downloadImageAtURL:imageURL
                                                forImageID:imageID
                                                      size:size
                                                   onqueue:nil
                                               returnImage:cell.image];
                }
            }
        }
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    //Default - small size
    CGSize cellSize = CGSizeMake(65, 65);
    if ([self shouldBeLargeImage:indexPath]) {
        cellSize = CGSizeMake(120, 120);
    }
    return cellSize;
}

-(void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    //get the image info for this cell
    
    CollectionViewCell * cell = (CollectionViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    
    if ([self.delegate respondsToSelector:@selector(displayDetailImage:)]) {
        [self.delegate displayDetailImage: cell.image.image];
    }
}


#pragma mark - Utilities

-(BOOL) shouldBeLargeImage:(NSIndexPath *) indexPath {
    /* Every third item starting with the first should be large. */
    return indexPath.row % 3 == 0;
}

-(NSString *) cellIdentifierForSize:(imageSize) size {
    NSString * identifier = nil;
    switch (size) {
        case standard:
            identifier = @"largeImageCell";
            break;
        case loRes:
            identifier = @"smallImageCell";
            break;
        case thumbnail:
            identifier = @"";
            break;
    }
    return identifier;
}

-(NSString *) imageIdentifierForSize:(imageSize) size {
    NSString * identifier = nil;
    switch (size) {
        case standard:
            identifier = @"stdImage";
            break;
        case loRes:
            identifier = @"smallImage";
            break;
        case thumbnail:
            identifier = @"thumbImage";
            break;
    }
    return identifier;
}

-(NSString *) imageURL:(imageSize) size {
    NSString * identifier = nil;
    switch (size) {
        case standard:
            identifier = @"standardURL";
            break;
        case loRes:
            identifier = @"loResURL";
            break;
        case thumbnail:
            identifier = @"thumbURL";
            break;
    }
    return identifier;
}

#pragma mark - scrollview delegate
-(void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    
    if(self.collectionView.contentOffset.y >= self.collectionView.contentSize.height - CGRectGetHeight(self.hostView.bounds) - CGRectGetHeight(self.hostView.bounds)/2){
        [[NSNotificationCenter defaultCenter] postNotificationName:@"fetchPhotos" object:nil];    }
}


@end
