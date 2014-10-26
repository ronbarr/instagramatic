//
//  InstagramAPIController.m
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import "InstagramAPIController.h"

@interface InstagramAPIController ()

//Set these in the init to change parameters
//Search tag
@property (strong,nonatomic) NSString * tag;
//Authentication tokens from the Instagram console
@property (strong,nonatomic) NSString * accessToken;
@property (strong,nonatomic) NSString * secret;

//Time in seconds to wait between retrievals
@property NSTimeInterval delayBetweenRetrievals;

//Maximum number of photos to cache
@property NSInteger photoCacheSize;

//Connection state variables
@property (strong,nonatomic) NSURLConnection * connection;

@end

@implementation InstagramAPIController

#pragma mark init
-(instancetype) init {
    if (self = [super init]) {
        //Set parameters
        self.tag = @"selfie";
        self.accessToken = @"87b8196ae610451b98d8c0816634cd0e";
        self.secret = @"6f17e1ac069a4abdad2f131fbb0bfa2f";
        self.delayBetweenRetrievals = 300;
        self.photoCacheSize = 100;
        [self retrievePhotos:self.tag sinceID:0];
     }
    return self;
}

#pragma mark - initiate retrieval
-(void) retrievePhotos:(NSString *) tag sinceID:(long long) sinceID {
    //Set connection variables
    NSString * requestString = [NSString stringWithFormat:@"https://api.instagram.com/v1/tags/%@/media/recent/?access_token=%@", self.tag, self.accessToken];
    if (sinceID) {  //Only get new photos
        NSString * sinceIDString = [NSString stringWithFormat:@"&MAX_TAG_ID=%lld",sinceID];
        requestString = [requestString stringByAppendingString:sinceIDString];
    }
    NSURL * requestURL = [NSURL URLWithString:requestString];
    NSURLRequest * request = [NSURLRequest requestWithURL:requestURL];
    
    //Start connection
    self.connection = nil;

    if (self.connection) {  //Current connection? Cancel it...
        [self.connection cancel];
        self.connection = nil;
    }
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

#pragma mark - NSURL Delegate Methods
-(void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
}

-(void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
}

-(void) connectionDidFinishLoading:(NSURLConnection *)connection {
    
}


@end
