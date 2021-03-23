//
//  FileFetcher.h
//  finlinks
//
//  Created by Cezary Kułakowski on 23/03/2021.
//

#import <Cocoa/Cocoa.h>

@interface FileFetcher : NSObject <NSURLSessionDelegate>

typedef void(^FetchFileCompletionHandler)(NSData*);

- (void)fetchFile:(NSURL*)url
   andCallCompletionHandler:(FetchFileCompletionHandler)handler;
@end
