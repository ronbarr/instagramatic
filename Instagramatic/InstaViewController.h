//
//  InstaViewController.h
//  Instagramatic
//
//  Created by Ron Barr on 10/25/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "InstaViewModelControllerDelegate.h"

@interface InstaViewController : UICollectionViewController <InstaViewModelControllerDelegate,
                                                            UIScrollViewDelegate>

@end
