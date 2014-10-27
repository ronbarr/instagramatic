//
//  CollectionViewCell.h
//  Instagramatic
//
//  Created by Ron Barr on 10/26/14.
//  Copyright (c) 2014 Ron Barr. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CollectionViewCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (strong, nonatomic) NSString * imageID;
@end
