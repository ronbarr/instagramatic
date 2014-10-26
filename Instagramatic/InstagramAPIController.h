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

-(void)downloadImageAtURL:(NSString *)imageURLString
               forImageID:(NSString *)imageID
                     size:(imageSize)size;

@end
