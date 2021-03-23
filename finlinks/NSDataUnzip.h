//
//  NSDataUnzip.h
//  finlinks
//
//  Created by Cezary Kułakowski on 23/03/2021.
//
//
//  NSData+Compression.h
//  CocoaGit
//
//  Created by Geoffrey Garside on 29/06/2008.
//  Copyright 2008 ManicPanda.com. All rights reserved.
//
//  Methods extracted from source given at
//  http://www.cocoadev.com/index.pl?NSDataCategory
//

#import <Foundation/NSData.h>

/*! Adds  decompression message to NSData.
 * Method extracted from source given at
 * http://www.cocoadev.com/index.pl?NSDataCategory
 */
@interface NSData (Compression)

/*! Returns a data object containing a Zlib compressed copy of the receivers contents.
 * \returns A data object containing a Zlib compressed copy of the receivers contents.
 */
- (NSData *) unzip;

@end
