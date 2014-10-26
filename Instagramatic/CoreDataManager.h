//
//  coreDataHelpers.h
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import <Foundation/Foundation.h>

/* Core data functions global to app. Singleton. */

@interface CoreDataManager : NSObject

//Root saving context used for consistency
@property (readonly, strong, nonatomic) NSManagedObjectContext *rootObjectContext;
//Context for main thread; child of root
@property (readonly, strong, nonatomic) NSManagedObjectContext *mainObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (strong,nonatomic) NSOperationQueue * backgroundSavingQueue;

//Returns address of singleton
+ (instancetype)sharedManager;
//Save the context through to the persistent store
- (void)saveContext:(NSManagedObjectContext *) context;
//Return a new child context of the main thread context suitable for use in a background thread
- (NSManagedObjectContext *)localContext;
@end
