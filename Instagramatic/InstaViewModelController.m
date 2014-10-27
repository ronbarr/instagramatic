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

//Required for Apple's change management boilerplate
@property (strong, nonatomic) NSMutableArray *objectChanges;
@property (strong, nonatomic) NSMutableArray *sectionChanges;

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
        _sectionChanges = [NSMutableArray arrayWithCapacity:100];
        
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
    
    NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"updated"
                                                                      ascending:NO];
    
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

#pragma mark - Apple boilerplate to handle changes (with bug workaround)
- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    
    NSMutableDictionary *change = [NSMutableDictionary new];
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            change[@(type)] = @(sectionIndex);
            break;
        case NSFetchedResultsChangeDelete:
            change[@(type)] = @(sectionIndex);
            break;
        case NSFetchedResultsChangeUpdate:
        case NSFetchedResultsChangeMove:
            break;
    }
    
    [_sectionChanges addObject:change];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    NSLog(@"change is incoming... %i",type);
    
    NSMutableDictionary *change = [NSMutableDictionary new];
    switch(type)
    {
        case NSFetchedResultsChangeInsert:
            change[@(type)] = newIndexPath;
            break;
        case NSFetchedResultsChangeDelete:
            change[@(type)] = indexPath;
            break;
        case NSFetchedResultsChangeUpdate:
            change[@(type)] = indexPath;
            break;
        case NSFetchedResultsChangeMove:
            change[@(type)] = @[indexPath, newIndexPath];
            break;
    }
    
     [_objectChanges addObject:change];
    if (_objectChanges.count >= 10) {
        [_objectChanges removeAllObjects];
        self.fetchedResultsController = nil;
        [self.collectionView reloadData];
        NSLog(@"reloading...");
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    
    if ([_sectionChanges count] > 0 )
    {
        //UI operations - switch back to main thread
        
          [[NSOperationQueue mainQueue] addOperationWithBlock:^{
              
            [self.collectionView performBatchUpdates:^{
                
                for (NSDictionary *change in _sectionChanges)
                {
                    [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {
                        
                        NSFetchedResultsChangeType type = [key unsignedIntegerValue];
                        switch (type)
                        {
                            case NSFetchedResultsChangeInsert:
                                [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                                break;
                            case NSFetchedResultsChangeDelete:
                                [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                                break;
                            case NSFetchedResultsChangeUpdate:
                                [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                                break;
                                
                            case NSFetchedResultsChangeMove:
                                break;
                                
                        }
                    }];
                }
            } completion:nil];
            
            
            if ([_objectChanges count] > 0 && [_sectionChanges count] == 0)
            {
                
                if ([self shouldReloadCollectionViewToPreventKnownIssue] || self.collectionView.window == nil) {
                    // This is to prevent a bug in UICollectionView from occurring.
                    // The bug presents itself when inserting the first object or deleting the last object in a collection view.
                    // http://stackoverflow.com/questions/12611292/uicollectionview-assertion-failure
                    // This code should be removed once the bug has been fixed, it is tracked in OpenRadar
                    // http://openradar.appspot.com/12954582
                    [self.collectionView reloadData];
                    
                } else {
                    
                    [self.collectionView performBatchUpdates:^{
                        
                        for (NSDictionary *change in _objectChanges)
                        {
                            [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {
                                
                                NSFetchedResultsChangeType type = [key unsignedIntegerValue];
                                switch (type)
                                {
                                    case NSFetchedResultsChangeInsert:
                                        [self.collectionView insertItemsAtIndexPaths:@[obj]];
                                        break;
                                    case NSFetchedResultsChangeDelete:
                                        [self.collectionView deleteItemsAtIndexPaths:@[obj]];
                                        break;
                                    case NSFetchedResultsChangeUpdate:
                                        [self.collectionView reloadItemsAtIndexPaths:@[obj]];
                                        break;
                                    case NSFetchedResultsChangeMove:
                                        [self.collectionView moveItemAtIndexPath:obj[0] toIndexPath:obj[1]];
                                        break;
                                }
                            }];
                        }
                    } completion:nil];
                }
            }
            [_sectionChanges removeAllObjects];
            [_objectChanges removeAllObjects];
        }];
        
        //Back in the background...
     }
}

- (BOOL)shouldReloadCollectionViewToPreventKnownIssue {
    __block BOOL shouldReload = NO;
    for (NSDictionary *change in self.objectChanges) {
        [change enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSFetchedResultsChangeType type = [key unsignedIntegerValue];
            NSIndexPath *indexPath = obj;
            switch (type) {
                case NSFetchedResultsChangeInsert:
                    if ([self.collectionView numberOfItemsInSection:indexPath.section] == 0) {
                        shouldReload = YES;
                    } else {
                        shouldReload = NO;
                    }
                    break;
                case NSFetchedResultsChangeDelete:
                    if ([self.collectionView numberOfItemsInSection:indexPath.section] == 1) {
                        shouldReload = YES;
                    } else {
                        shouldReload = NO;
                    }
                    break;
                case NSFetchedResultsChangeUpdate:
                    shouldReload = NO;
                    break;
                case NSFetchedResultsChangeMove:
                    shouldReload = NO;
                    break;
            }
        }];
    }
    
    return shouldReload;
}

#pragma mark - Collection View Data Source & delegate
-(NSInteger) collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    NSUInteger objectCount = self.fetchedResultsController.fetchedObjects.count;
    
    NSLog(@"%lu objects in section", objectCount);
    return objectCount;
}

-(UICollectionViewCell *) collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    //Should this be a large image?
    imageSize size = [self shouldBeLargeImage:indexPath] ? standard : loRes;
    
    CollectionViewCell * cell =
    [self.collectionView dequeueReusableCellWithReuseIdentifier:[self cellIdentifierForSize:size]
                                                   forIndexPath:indexPath];
    
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
    imageSize size = [self shouldBeLargeImage:indexPath] ? standard : loRes;
    
    CollectionViewCell * cell =
    [self.collectionView dequeueReusableCellWithReuseIdentifier:[self cellIdentifierForSize:size]
                                                   forIndexPath:indexPath];
  
  
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

@end
