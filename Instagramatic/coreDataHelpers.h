//
//  coreDataHelpers.h
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface coreDataHelpers : NSObject

//Root saving context used for consistency
@property (readonly, strong, nonatomic) NSManagedObjectContext *rootObjectContext;
//Context for main thread; child of root
@property (readonly, strong, nonatomic) NSManagedObjectContext *mainObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (strong,nonatomic) NSOperationQueue * backgroundSavingQueue;
@property (strong,nonatomic) NSOperationQueue * backgroundReadingQueue;

- (void)saveContext;

@end
