//
//  FileFetcher.m
//  finlinks
//
//  Created by Cezary Kułakowski on 23/03/2021.
//

#import <Foundation/Foundation.h>

#import "FileFetcher.h"

@interface ProgressIndicator : NSView
@property (nonatomic) NSProgressIndicator* progress_indicator;
@end

@implementation ProgressIndicator

- (void)initWithMaxValue:(NSInteger)max_value {
  NSWindow* window = [NSApp mainWindow];
  NSRect window_rect = [window frame];
  NSRect indicator_frame = NSMakeRect(0.0f, 0.0f, window_rect.size.width, 15.0);
  NSRect text_frame = NSMakeRect(0.0f, 0.0, window_rect.size.width, 50.0);
  _progress_indicator = [[NSProgressIndicator alloc] initWithFrame:indicator_frame];
  //NSTextField* text_field = [[NSTextField alloc] initWithFrame:text_frame];
  NSTextField* text_field = [NSTextField textFieldWithString:@"Fetching runtime"];
  [text_field setFrame:text_frame];
  [_progress_indicator setStyle:NSProgressIndicatorStyleBar];
  [_progress_indicator setHidden:NO];
  [_progress_indicator setIndeterminate:NO];
  [_progress_indicator setBezeled:YES];
  window.styleMask &= ~NSWindowStyleMaskResizable;
  [_progress_indicator setMaxValue:max_value];
  [[window contentView] addSubview:text_field];
  [[window contentView] addSubview:_progress_indicator];
}

- (void)incrementBy:(NSInteger)value {
  [_progress_indicator incrementBy:value];
}

@end

@interface FileFetcher ()

@property (nonatomic, retain) NSMutableData* data_to_download;
@property (nonatomic) float download_size;
@property (nonatomic) FetchFileCompletionHandler completion_handler;
@property (nonatomic) ProgressIndicator* progress_indicator;

@end

@implementation FileFetcher

- (void)displayAlertWithMessage:(NSString*)message {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:message];
  [alert addButtonWithTitle:@"Ok"];
  [alert runModal];
}

- (void)fetchFile:(NSURL*)url
andCallCompletionHandler:(FetchFileCompletionHandler)handler {
  _completion_handler = handler;
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

- (void)setProgressIndicatorWithMaxValue:(NSInteger)max_value {
  _progress_indicator = [ProgressIndicator alloc];
  [_progress_indicator initWithMaxValue:max_value];
}

- (void)URLSession:(NSURLSession*)session
          dataTask:(NSURLSessionDataTask*)dataTask
didReceiveResponse:(NSURLResponse*)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
  completionHandler(NSURLSessionResponseAllow);
  //completionHandler(NSURLSessionResponseCancel);
  _download_size = [response expectedContentLength];
  [self setProgressIndicatorWithMaxValue:_download_size];
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
