//
//  FileFetcher.h
//  finlinks
//
//  Created by Cezary Kułakowski on 23/03/2021.
//

#import <Cocoa/Cocoa.h>

@interface FileFetcher : NSObject <NSURLSessionDelegate>

typedef void(^FetchFileCompletionHandler)(NSData*);

- (void)fetchRuntime:(NSString*)version
            fromHost:(NSString*)host
         usingWindow:(NSWindow*)window
    andCallCompletionHandler:(FetchFileCompletionHandler)handler;
@end
