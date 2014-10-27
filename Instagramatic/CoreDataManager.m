//
//  coreDataHelpers.m
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import "CoreDataManager.h"
#import "AppDelegate.h"

@implementation CoreDataManager
#pragma mark - Core Data stack

@synthesize rootObjectContext = _rootObjectContext;
@synthesize mainObjectContext = _mainObjectContext;

@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

+ (instancetype)sharedManager
{
    static CoreDataManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[CoreDataManager alloc] init];
    });
    return sharedManager;
}

-(instancetype) init {
    {
        if (self = [super init])
        {
            
          }
        return self;
    }
}

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Instagramatic" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it.
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    // Create the coordinator and store
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    AppDelegate * appDelegate = [UIApplication sharedApplication].delegate;
    NSURL *storeURL = [[appDelegate applicationDocumentsDirectory] URLByAppendingPathComponent:@"Instagramatic.sqlite"];
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        // Replace this with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);

    }
    
    return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)mainObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_mainObjectContext != nil) {
        return _mainObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _mainObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_mainObjectContext setParentContext:[self rootObjectContext]];
    if (!_mainObjectContext.persistentStoreCoordinator) {
        [_mainObjectContext setPersistentStoreCoordinator:coordinator];
    }
    [_mainObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
     return _mainObjectContext;
}

- (NSManagedObjectContext *)rootObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_rootObjectContext != nil) {
        return _rootObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _rootObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    if (!_rootObjectContext.persistentStoreCoordinator) {
        [_rootObjectContext setPersistentStoreCoordinator:coordinator];
    }
    [_rootObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
    return _rootObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext:(NSManagedObjectContext *) context {
    /** recursively save contexts through to the root **/
    BOOL success = YES;
    if (context == self.rootObjectContext) {
        NSLog(@"will save root");
    } else
        if (context == self.mainObjectContext) {
            NSLog(@"will save main");
        } else {
            NSLog(@"will save context %@", context);
        }
    if (context != nil) {
        NSError *error = nil;
         if ([context hasChanges]) {
            if ([context save:&error]) {
                NSLog(@"saved %@", context);
                if (context.parentContext) {
                    [self saveContext:context.parentContext];
                }
             }
            else {
                success = NO;
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
             }
        }
    
    }
 }


#pragma mark - Create new local context for use in background threads
    - (NSManagedObjectContext *)localContext {
        NSManagedObjectContext *temporaryContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [temporaryContext setParentContext:[self mainObjectContext]];
        if (!temporaryContext.persistentStoreCoordinator) {
            [temporaryContext setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
        }
        [temporaryContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        return temporaryContext;
    }
    
@end
