//
//  InstagramAPIController.h
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface InstagramAPIController : NSObject < NSURLConnectionDelegate, NSURLConnectionDataDelegate>
/* All things Instagram API. Downloads and saves image info and images to Core Data store */
typedef NS_ENUM(NSInteger, imageSize) {
    standard,
    loRes,
    thumbnail
};

//Returns the singleton. Creates and inits if necessary
+ (instancetype)sharedController;

/*Download an image @ URL. Saves it to Core Data Image object using imageID as key.
 Optionally updates obtional return imageview. Uses optional queue for higher priority tasks */
-(void)downloadImageAtURL:(NSString *)imageURLString
               forImageID:(NSString *)imageID
                     size:(imageSize)size
                  onqueue:(NSOperationQueue *) optionalQueue
              returnImage:(UIImageView *) optionalReturnImageView;

//Returns a Core Data Image object from an ID
-(NSManagedObject *) imageFromID:(NSString *) imageID
                       inContext:(NSManagedObjectContext *) context;

@end
