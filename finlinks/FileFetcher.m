//
//  FileFetcher.m
//  finlinks
//
//  Created by Cezary Kułakowski on 23/03/2021.
//

#import <Foundation/Foundation.h>

#import "FileFetcher.h"


@interface FileFetcher ()

@property (nonatomic, retain) NSMutableData* data_to_download;
@property (nonatomic) float download_size;
@property (nonatomic) FetchFileCompletionHandler completion_handler;
@property (nonatomic) NSProgressIndicator* progress_indicator;

@end

@implementation FileFetcher

- (void)displayAlertWithMessage:(NSString*)message {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:message];
  [alert addButtonWithTitle:@"Ok"];
  [alert runModal];
}

- (void)setWindowAndProgressBar:(NSWindow*)window
              forRuntimeVersion:(NSString*)version{
  NSRect window_rect = NSMakeRect(0.0, 0.0, 500.0, 75.0);
  [window setFrame:window_rect
            display:YES];
  [window center];
  window.styleMask &= ~NSWindowStyleMaskResizable;
  window.styleMask |= NSWindowStyleMaskFullSizeContentView;
  [window setTitleVisibility:NSWindowTitleHidden];
  [window setTitlebarAppearsTransparent:YES];
  [[window standardWindowButton:NSWindowCloseButton] setHidden:YES];
  [[window standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
  [[window standardWindowButton:NSWindowZoomButton] setHidden:YES];
  [window setIsVisible:YES];
  NSRect indicator_frame = NSMakeRect(0.0f, 0.0f, window_rect.size.width, 15.0);
  NSRect text_frame = NSMakeRect(0.0f, 0.0f, window_rect.size.width, 50.0);
  _progress_indicator = [[NSProgressIndicator alloc] initWithFrame:indicator_frame];
  NSString* textToDisplay = [NSString stringWithFormat:@"Fetching runtime %@", version];
  NSTextField* text_field = [NSTextField textFieldWithString:textToDisplay];
  [text_field setFrame:text_frame];
  [text_field setAlignment:NSTextAlignmentCenter];
  [_progress_indicator setStyle:NSProgressIndicatorStyleBar];
  [_progress_indicator setHidden:NO];
  [_progress_indicator setIndeterminate:NO];
  [_progress_indicator setBezeled:YES];
  [[window contentView] addSubview:text_field];
  [[window contentView] addSubview:_progress_indicator];
}

- (void)fetchRuntime:(NSString*)version
            fromHost:(NSString*)host
         usingWindow:(NSWindow*)window
andCallCompletionHandler:(FetchFileCompletionHandler)handler {
  [self setWindowAndProgressBar:window
              forRuntimeVersion:version];
  _completion_handler = handler;
  NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", host, version]];
  NSURLSession* url_session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                            delegate:self
                                                       delegateQueue:[NSOperationQueue mainQueue]];
  NSURLSessionDataTask* download_task = [url_session dataTaskWithURL:url];
  [download_task resume];
}

- (void)URLSession:(NSURLSession*)session didBecomeInvalidWithError:(NSError*)error {
  [self displayAlertWithMessage:@"got error"];
  _completion_handler(nil);
}

- (void)URLSession:(NSURLSession*)session
          dataTask:(NSURLSessionDataTask*)dataTask
didReceiveResponse:(NSURLResponse*)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
  completionHandler(NSURLSessionResponseAllow);
  //completionHandler(NSURLSessionResponseCancel);
  _download_size = [response expectedContentLength];
  [_progress_indicator setMaxValue:_download_size];
  _data_to_download = [[NSMutableData alloc] init];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask*)dataTask
    didReceiveData:(NSData *)data {
  [_data_to_download appendData:data];
  //NSLog(@"%@", [NSString stringWithFormat:@"Progress: %lu", (unsigned long)[_data_to_download length]]);
  [_progress_indicator incrementBy:[data length]];
  if ([_data_to_download length] == _download_size) {
    _completion_handler(_data_to_download);
  }
}

@end
