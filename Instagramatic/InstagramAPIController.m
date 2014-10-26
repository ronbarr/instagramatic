//
//  InstagramAPIController.m
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import "InstagramAPIController.h"
#import "CoreDataManager.h"

@interface InstagramAPIController ()


//Set these in the init to change parameters
//Search tag
@property (strong,nonatomic) NSString * tag;
//Authentication tokens from the Instagram console
@property (strong,nonatomic) NSString * accessToken;
@property (strong,nonatomic) NSString * secret;

//Time in seconds to wait between retrievals
@property NSTimeInterval delayBetweenRetrievals;

//Timer that fetches
@property NSTimer * fetchTimer;

//Last ID received
@property NSString * lastID;

//Maximum number of photos to cache
@property NSInteger photoCacheSize;

//Connection state variables
@property (strong,nonatomic) NSURLConnection * imageInfoConnection;
@property (strong,nonatomic) NSURLConnection * imageDownloadConnection;

@property (strong,nonatomic) NSOperationQueue * backgroundReadingQueue;

//Incoming data
@property (strong,nonatomic) NSMutableData * incomingData;

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
        
        //Update frequently
        self.fetchTimer = [NSTimer timerWithTimeInterval:self.delayBetweenRetrievals
                                                  target:self
                                                selector:@selector(fetchMorePhotos)
                                                userInfo:nil
                                                 repeats:YES];
        
        self.backgroundReadingQueue = [[NSOperationQueue alloc] init];
        self.backgroundReadingQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

#pragma mark - initiate retrieval
-(void) retrievePhotos:(NSString *) tag
               sinceID:(long long) sinceID {
    //Set connection variables
    NSString * requestString = [NSString stringWithFormat:@"https://api.instagram.com/v1/tags/%@/media/recent/?client_id=%@", self.tag, self.accessToken];
    if (sinceID) {  //Only get new photos
        NSString * sinceIDString = [NSString stringWithFormat:@"&MAX_TAG_ID=%lld",sinceID];
        requestString = [requestString stringByAppendingString:sinceIDString];
    }
    NSURL * requestURL = [NSURL URLWithString:requestString];
    NSURLRequest * request = [NSURLRequest requestWithURL:requestURL];
    NSLog(@"request %@", request);
    
    //Start connection
    self.imageInfoConnection = nil;
    
    if (self.imageInfoConnection) {  //Current connection? Cancel it...
        [self.imageInfoConnection cancel];
        self.imageInfoConnection = nil;
    }
    self.imageInfoConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    self.incomingData = [NSMutableData data];
}

-(void) fetchMorePhotos {
    [self retrievePhotos:self.tag sinceID:[self.lastID longLongValue]];
}
#pragma mark - parse and store incoming data
-(void) parseIncomingData:(NSData *) data {
    /** Parses incoming data asynchronously **/
    CoreDataManager * coreDataManager = [CoreDataManager sharedManager];
    NSManagedObjectContext * localContext = [coreDataManager localContext];
    
    //Perform the block in the background;
    [localContext performBlock:^{
        NSError * error;
        NSDictionary * JSONData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            NSLog(@"fatal error %@ %lu", error, error.code);
        }
        else {
            [self storeJSONRecords:JSONData inContext:localContext];
            [coreDataManager saveContext:localContext];
        }
        
    }];
}

#pragma mark get array of JSON record from blob
-(void) storeJSONRecords:(NSDictionary *) JSONData
               inContext:(NSManagedObjectContext *) context {
    NSArray * data = [JSONData objectForKey:@"data"];
    for (NSDictionary * imageValues in data) {
        [self storeRecord:imageValues inContext:context];
    }
    
}

#pragma mark fetch an image data object with an ID
-(NSManagedObject *) imageFromID:(NSString *) imageID
                       inContext:(NSManagedObjectContext *) context {
    NSManagedObject * fetchedObject = nil;
    
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:@"Image" inManagedObjectContext:context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    //Valid record?
         NSPredicate *predicate = [NSPredicate predicateWithFormat:@"instaID = %@", imageID];
        [request setPredicate:predicate];
        
        NSError *error;
        NSArray *array = [context executeFetchRequest:request error:&error];
        if (array.count) {
            fetchedObject = [array firstObject];
        }
    return fetchedObject;
}

#pragma mark add or update each record in array
-(void) storeRecord:(NSDictionary *) imageValues
          inContext:(NSManagedObjectContext *) context {
    
    NSString * imageID = [imageValues valueForKey:@"id"];
    NSString * imageType = [imageValues valueForKey:@"type"];
    if (imageID &&
        [imageType isEqualToString:@"image"]) {          // is it an image?
        
        // Does this image already exist?
        NSManagedObject * existingRecord = [self imageFromID:imageID
                                                   inContext:context];
        if (!existingRecord) {
            [self createRecord:imageValues //No, create it
                     inContext:context];
        }
        else {
            [self updateRecord:existingRecord
                    withValues:imageValues
                     inContext:context];
        }
        
    }
}

#pragma mark create a new image record
-(void) createRecord:(NSDictionary *) imageValues
           inContext:(NSManagedObjectContext *) context {
    NSManagedObject * newRecord = [NSEntityDescription insertNewObjectForEntityForName:@"Image"
                                                                inManagedObjectContext:context];
    [newRecord setValue:[NSDate date] forKey:@"created"];
    [self updateRecord:newRecord
            withValues:imageValues
             inContext:context];
}

#pragma mark update record with new values
-(void) updateRecord:(NSManagedObject *)image
          withValues: (NSDictionary *) imageValues
           inContext:(NSManagedObjectContext *) context {
    
    [image setValue:[NSDate date] forKey:@"updated"];
    
    //First get standard info
    [self updateAttribute:@"instaID" ofImage:image withValue:[imageValues objectForKey:@"id"]];
    [self updateAttribute:@"type" ofImage:image withValue:[imageValues objectForKey:@"type"]];
    [self updateAttribute:@"link" ofImage:image withValue:[imageValues objectForKey:@"link"]];
    
    //Extract the image URLS
    NSDictionary * images = [imageValues objectForKey:@"images"];
    NSDictionary * stdImage = [images objectForKey:@"standard_resolution"];
    NSDictionary * loResImage = [images objectForKey:@"low_resolution"];
    NSDictionary * thumbNail = [images objectForKey:@"thumbnail"];
    
    NSString * stdImageURL = [stdImage valueForKey:@"url"];
    NSString * loResURL = [loResImage valueForKey:@"url"];
    NSString * thumbURL = [thumbNail valueForKey:@"url"];
    
    [self updateAttribute:@"standardURL" ofImage:image withValue:stdImageURL];
    [self updateAttribute:@"loResURL" ofImage:image withValue:loResURL];
    [self updateAttribute:@"thumbURL" ofImage:image withValue:thumbURL];
    
    //Start the downloading of the images themselves
    NSString * imageID = [imageValues objectForKey:@"id"];
    [self downloadImageAtURL:stdImageURL forImageID:imageID size:standard];
    [self downloadImageAtURL:loResURL forImageID:imageID size:loRes];
    [self downloadImageAtURL:thumbURL forImageID:imageID size:thumbnail];
    
    //Get the user info
    NSDictionary * userInfo = [imageValues objectForKey:@"user"];
    [self updateAttribute:@"userName" ofImage:image withValue:[userInfo objectForKey:@"username"]];
    [self updateAttribute:@"fullName" ofImage:image withValue:[userInfo objectForKey:@"full)name"]];
    [self updateAttribute:@"userID" ofImage:image withValue:[userInfo objectForKey:@"id"]];
    
}


-(void)downloadImageAtURL:(NSString *)imageURLString
               forImageID:(NSString *)imageID
                     size:(imageSize)size {
    
    if (imageURLString.length) {
    
    NSURL * imageURL = [NSURL URLWithString:imageURLString];
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:imageURL]
                                       queue:self.backgroundReadingQueue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               if (!error) {
                                   CoreDataManager * coreDataManager = [CoreDataManager sharedManager];
                                   NSManagedObjectContext * localContext = [coreDataManager localContext];
                                   [localContext performBlock:^{
                                       /*Got the image data. Fetch the original image info, create a new record
                                        with the image data, and point to it from the original info record */
                                       NSManagedObject * imageInfo = [self imageFromID:imageID
                                                                             inContext:localContext];
                                       
                                       NSManagedObject * newRecord = [NSEntityDescription insertNewObjectForEntityForName:@"ImageData"
                                                    inManagedObjectContext:localContext];
                                       [newRecord setValue:data forKey:@"imageBinaryData"];
                                       
                                       NSString * key = @"stdImage";
                                       if (size == loRes) {
                                           key = @"smallImage";
                                       }
                                       else if (size == thumbnail) {
                                           key = @"thumbImage";
                                       }
                                       [imageInfo setValue:newRecord forKey:key];
                                       
                                   }];
                                   [coreDataManager saveContext:localContext];
                               }
                           }];
    }
}

-(void) updateAttribute:(NSString *) attribute
                ofImage:(NSManagedObject *)image
              withValue:(id) value {
    if (value) {
        [image setValue:value forKey:attribute];
    }
    
}

#pragma mark - NSURL Delegate Methods
-(void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse * restResponse = (NSHTTPURLResponse *) response;
        NSInteger statusCode = restResponse.statusCode;
        if (statusCode >= 200 && statusCode < 300) {
            NSLog(@"successful request %li", (long)statusCode);
            
            [self.incomingData setLength:0];
        }
        else {
            NSLog(@"bad request %li", (long)statusCode);
        }
    }
}

-(void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    [self.incomingData appendData:data];
    
}

-(void) connectionDidFinishLoading:(NSURLConnection *)connection {
    self.imageInfoConnection = nil;
    [self parseIncomingData:self.incomingData];
}

-(void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"fatal error %@ %lu", error, error.code);
}
@end
