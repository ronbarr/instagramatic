//
//  InstagramAPIController.h
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface InstagramAPIController : NSObject < NSURLConnectionDelegate, NSURLConnectionDataDelegate>

typedef NS_ENUM(NSInteger, imageSize) {
    standard,
    loRes,
    thumbnail
};

+ (instancetype)sharedController;

-(void)downloadImageAtURL:(NSString *)imageURLString
               forImageID:(NSString *)imageID
                     size:(imageSize)size
                  onqueue:(NSOperationQueue *) optionalQueue
              returnImage:(UIImageView *) optionalReturnImageView;

-(NSManagedObject *) imageFromID:(NSString *) imageID
                       inContext:(NSManagedObjectContext *) context;

@end
