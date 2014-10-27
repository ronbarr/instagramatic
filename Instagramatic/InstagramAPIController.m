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

//Queues for reading and processing
@property (strong,nonatomic) NSOperationQueue * backgroundReadingQueue;

//Incoming data
@property (strong,nonatomic) NSMutableData * incomingData;

@end

@implementation InstagramAPIController

#pragma mark init

+ (instancetype)sharedController
{
    static InstagramAPIController *sharedController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[InstagramAPIController alloc] init];
    });
    return sharedController;
}

-(instancetype) init {
    if (self = [super init]) {
        //Set parameters
        self.tag = @"selfie";
        self.accessToken = @"87b8196ae610451b98d8c0816634cd0e";
        self.secret = @"6f17e1ac069a4abdad2f131fbb0bfa2f";
        self.delayBetweenRetrievals = 20;
        self.photoCacheSize = 150;
        [self pruneDataBase:self.photoCacheSize];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(fetchMorePhotos)
                                                     name:@"fetchPhotos" object:nil ] ;
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
    NSLog(@"refreshing...");
}

-(void) pruneDataBase:(NSInteger) maxImages {
    NSManagedObjectContext * context = [[CoreDataManager sharedManager] localContext];
    
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:@"Image" inManagedObjectContext:context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSError *error;
    NSArray *array = [context executeFetchRequest:request error:&error];
    if (array.count > maxImages) {
        NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"likes" ascending:NO];
        array = [array sortedArrayUsingDescriptors:@[sortDescriptor]];
      array = [array subarrayWithRange:NSMakeRange(0, array.count - maxImages)];
        for (NSManagedObject * image in array) {
            [context deleteObject:image];
        }
        [[CoreDataManager sharedManager] saveContext:context];
    }
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
            NSLog(@"fatal error %@ %lu", error, (long)error.code);
        }
        else {
            [self storeJSONRecords:JSONData inContext:localContext];
            
            [coreDataManager saveContext:localContext];
        }
        
    }];
}

#pragma mark get array of JSON records from blob
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
    } else {
        [request setPredicate:nil];
        
        //If we over the max, pick a random image and replace instead...
        array = [context executeFetchRequest:request error:&error];
        if (array.count > self.photoCacheSize * 2) {
            NSInteger randomImage = arc4random_uniform(array.count-1);
            fetchedObject = array[randomImage];
        }
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

#pragma mark create a new image info record
-(void) createRecord:(NSDictionary *) imageValues
           inContext:(NSManagedObjectContext *) context {
    NSManagedObject * imageInfo = [NSEntityDescription insertNewObjectForEntityForName:@"Image"
                                                                inManagedObjectContext:context];
    [imageInfo setValue:[NSDate date] forKey:@"created"];
    [self updateRecord:imageInfo
            withValues:imageValues
             inContext:context];
}

#pragma mark update record with new values
-(void) updateRecord:(NSManagedObject *)imageInfo
          withValues: (NSDictionary *) imageValues
           inContext:(NSManagedObjectContext *) context {
    
    [imageInfo setValue:[NSDate date] forKey:@"updated"];
    
    //First get standard info
    [self updateAttribute:@"instaID" ofImage:imageInfo withValue:[imageValues objectForKey:@"id"]];
    [self updateAttribute:@"type" ofImage:imageInfo withValue:[imageValues objectForKey:@"type"]];
    [self updateAttribute:@"link" ofImage:imageInfo withValue:[imageValues objectForKey:@"link"]];
    
    //Extract the image URLS
    NSDictionary * images = [imageValues objectForKey:@"images"];
    NSDictionary * stdImage = [images objectForKey:@"standard_resolution"];
    NSDictionary * loResImage = [images objectForKey:@"low_resolution"];
    NSDictionary * thumbNail = [images objectForKey:@"thumbnail"];
    
    NSString * stdImageURL = [stdImage valueForKey:@"url"];
    NSString * loResURL = [loResImage valueForKey:@"url"];
    NSString * thumbURL = [thumbNail valueForKey:@"url"];
    
    [self updateAttribute:@"standardURL" ofImage:imageInfo withValue:stdImageURL];
    [self updateAttribute:@"loResURL" ofImage:imageInfo withValue:loResURL];
    [self updateAttribute:@"thumbURL" ofImage:imageInfo withValue:thumbURL];
    
    NSDictionary * userInfo = [imageValues objectForKey:@"user"];
    [self updateAttribute:@"userName" ofImage:imageInfo withValue:[userInfo objectForKey:@"username"]];
    [self updateAttribute:@"fullName" ofImage:imageInfo withValue:[userInfo objectForKey:@"full)name"]];
    [self updateAttribute:@"userID" ofImage:imageInfo withValue:[userInfo objectForKey:@"id"]];
    NSDictionary * likes = [imageValues objectForKey:@"likes"];
    NSNumber * likeCountNumber = [likes objectForKey:@"count"];
    
    if (likeCountNumber) {
        [self updateAttribute:@"likes" ofImage:imageInfo withValue:likeCountNumber];
    }
    
}


-(void)downloadImageAtURL:(NSString *)imageURLString
               forImageID:(NSString *)imageID
                     size:(imageSize)size
                  onqueue:(NSOperationQueue *) optionalQueue
              returnImage:(UIImageView *) optionalReturnImageView
{
    if (imageURLString.length) {
        
        NSURL * imageURL = [NSURL URLWithString:imageURLString];
        
        NSOperationQueue * queue = self.backgroundReadingQueue;
        if (optionalQueue) {
            queue = optionalQueue;
        }
        
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:imageURL]
                                           queue:queue
                               completionHandler: ^(NSURLResponse *response, NSData *data, NSError *error) {
                                   if (!error) {
                                       NSBlockOperation * transformImageOperation = [NSBlockOperation blockOperationWithBlock:^{
                                           /*Got the image data. Fetch the original image info, create a new record
                                            with the image data, and point to it from the original info record */
                                           CoreDataManager * coreDataManager = [CoreDataManager sharedManager];
                                           NSManagedObjectContext * localContext = [coreDataManager localContext];
                                           NSManagedObject * imageInfo = [self imageFromID:imageID
                                                                                 inContext:localContext];
                                           
                                           if ([imageID isEqualToString:[imageInfo valueForKey:@"instaID"]]) {
                                               NSManagedObject * imagedata = [NSEntityDescription insertNewObjectForEntityForName:@"ImageData"
                                                            inManagedObjectContext:localContext];
                                               [imagedata setValue:data forKey:@"imageBinaryData"];
                                               
                                               NSString * key = @"stdImage";
                                               if (size == loRes) {
                                                   key = @"smallImage";
                                               }
                                               else if (size == thumbnail) {
                                                   key = @"thumbImage";
                                               }
                                               [imageInfo setValue:[NSDate date] forKey:@"updated"];
                                               [imageInfo setValue:imagedata forKey:key];
                                               
                                               if (optionalReturnImageView) {
                                                   [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                                       optionalReturnImageView.image = [UIImage imageWithData:data];
                                                    }];
                                               }
                                               
                                               
                                               [coreDataManager saveContext:localContext];
                                           }
                                       }];
                                       
                                       //Fire it up
                                       [self.backgroundReadingQueue addOperation:transformImageOperation];
                                       
                                       
                                   }
                               }];
    }
}

-(void) transformIncomingImageFromID:(NSString *) imageID
                            withData:(NSData *) data
                                size:(imageSize) size {
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
    NSLog(@"fatal error %@ %lu", error, (long)error.code);
}
@end
