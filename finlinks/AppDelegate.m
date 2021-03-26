//
//  AppDelegate.m
//  finlinks
//
//  Created by Cezary Kułakowski on 16/03/2021.
//

#import "AppDelegate.h"
#import "FileFetcher.h"
#import "NSDataUnzip.h"
#import "SSZipArchive.h"


@interface AppDelegate ()

typedef void(^ManifestParsedHandler)(NSString*);

@property (strong) IBOutlet NSWindow *window;
@property (nonatomic) NSString* manifest_url;
@property (nonatomic) NSString* runtime_args;
@property (nonatomic) NSString* runtime_version;
@end

@implementation AppDelegate

- (void)displayAlertWithMessage:(NSString*)message {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:message];
  [alert addButtonWithTitle:@"Ok"];
  [alert runModal];
}

- (void)displayAlertWithMessageAndTerminate:(NSString*)message {
  [self displayAlertWithMessage:message];
  [NSApp terminate:self];
}

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
  NSString* whole_link = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
  NSString* protocol = [whole_link substringWithRange:NSMakeRange(0, 4)];
  if ([protocol isEqualToString:@"fin:"]) {
    _manifest_url = [whole_link substringFromIndex:3];
    _manifest_url = [NSString stringWithFormat:@"http%@", _manifest_url];
  } else if ([protocol isEqualToString:@"fins"]) {
    _manifest_url = [whole_link substringFromIndex:4];
    _manifest_url = [NSString stringWithFormat:@"https%@", _manifest_url];
  } else {
    [self displayAlertWithMessageAndTerminate:[NSString stringWithFormat:@"Unknown fin link: %@", whole_link]];
  }
  [self fetchManifest];
}

- (void)parseManifestFile:(NSFileHandle*)file_handle
 andCallCompletionHandler:(ManifestParsedHandler)handler{
  NSData* file_content = [file_handle availableData];
  NSInputStream* stream = [NSInputStream inputStreamWithData:file_content];
  [stream open];
  NSError *error = nil;
  id object = [NSJSONSerialization
               JSONObjectWithStream:stream
                            options:0
                              error:&error];
  if (error || ![object isKindOfClass:[NSDictionary class]]) {
    [self displayAlertWithMessageAndTerminate:@"Invalid json file"];
  }
  NSDictionary* dict = object;
  id runtime_section = dict[@"runtime"];
  if (![runtime_section isKindOfClass:[NSDictionary class]]) {
    handler(@"no runtime section in manifest");
    return;
  }
  NSDictionary* runtime_dict = runtime_section;
  id version = runtime_dict[@"version"];
  if (![version isKindOfClass:[NSString class]]) {
    handler(@"no runtime version in manifest");
    return;
  }
  id args = runtime_dict[@"arguments"];
  _runtime_args = nil;
  if ([args isKindOfClass:[NSString class]]) {
    _runtime_args = args;
  }
  [self obtainExactVersionFromVersionString:version
                   andCallCompletionHandler:handler];
}

- (NSString*)getPathForRuntimesDirectory {
  return [NSString stringWithFormat:@"%@/OpenFin/runtime", NSHomeDirectory()];
}

- (NSString*)getLocalPathForRuntime {
  return [NSString stringWithFormat:@"%@/%@", [self getPathForRuntimesDirectory], _runtime_version];
}

- (void)fetchVersionForChannel:(NSString*)channel_name
      andCallCompletionHandler:(ManifestParsedHandler)handler {
  NSURL* url = [NSURL URLWithString:
                [NSString stringWithFormat:@"https://cdn.openfin.co/release/runtime/%@", channel_name]];
  NSURLSessionDownloadTask* download_task =
      [[NSURLSession sharedSession] downloadTaskWithURL:url
                                      completionHandler:^(NSURL* location, NSURLResponse* response, NSError* error) {
        if (error) {
          handler([NSString stringWithFormat: @"failed to get version for channel %@", channel_name]);
          return;
        }
        NSFileHandle* file_handle = [NSFileHandle fileHandleForReadingFromURL:location
                                                                        error:nil];
        NSData* file_content = [file_handle availableData];
        NSString* version = [[NSString alloc] initWithData:file_content encoding:NSASCIIStringEncoding];
        if (!version) {
          handler([NSString stringWithFormat:@"failed to parse version string for channel %@", channel_name]);
          return;
        }
        self->_runtime_version = version;
        handler(nil);
      }];
  [download_task resume];
}

- (void)obtainExactVersionFromVersionString:(NSString*)version
                   andCallCompletionHandler:(ManifestParsedHandler)handler {
  NSRegularExpression* exact_version_regexp =
      [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,2}\\.[0-9]{2}\\.[0-9]{2}\\.[0-9]{1,4}$"
                                                options:0
                                                  error:nil];
  NSUInteger number_of_matches =
      [exact_version_regexp numberOfMatchesInString:version
                                            options:0
                                              range:NSMakeRange(0, [version length])];
  if (number_of_matches) {
    _runtime_version = version;
    handler(nil);
    return;
  }
  NSArray* channels = @[@"stable", @"beta", @"canary", @"canary-next"];
  if ([channels containsObject:version]) {
    [self fetchVersionForChannel:version
        andCallCompletionHandler:handler];
    return;
  }
  handler([NSString stringWithFormat:@"runtime version not valid %@", version]);
}

- (void)onRuntimeFetched:(NSData*)data {
  if (!data) {
    [self displayAlertWithMessageAndTerminate:@"Failed to fetch runtime."];
  }
  NSString* runtime_path = [self getLocalPathForRuntime];
  if (![[NSFileManager defaultManager] createDirectoryAtPath:runtime_path
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil]) {
    [self displayAlertWithMessageAndTerminate:@"Failed to create runtime's directory"];
  }
  NSString* fetched_zip_location = [NSTemporaryDirectory() stringByAppendingPathComponent:@"runtime.zip"];
  if (![data writeToFile:fetched_zip_location atomically:NO]) {
    [self displayAlertWithMessageAndTerminate:
        [NSString stringWithFormat:@"Failed to write fetched runtime to temporary location"]];
  }
  NSError* unzip_error;
  [SSZipArchive unzipFileAtPath:fetched_zip_location
                  toDestination:runtime_path
                      overwrite:NO
                       password:nil
                          error:&unzip_error];
  if (unzip_error) {
    [self displayAlertWithMessageAndTerminate:
       [NSString stringWithFormat:@"Failed to unzip fetched runtime. Error code: %ld", [unzip_error code]]];
  }
  [self startRuntime];
}

- (BOOL)fetchRuntimeIfNeeded {
  NSString* local_runtime = [self getLocalPathForRuntime];
  if ([[NSFileManager defaultManager] fileExistsAtPath:local_runtime]) {
    return NO;
  }
  //[self displayAlertWithMessage:[NSString stringWithFormat:@"cdn url: %@", url]];
  [[FileFetcher alloc] fetchRuntime:_runtime_version
                           fromHost:@"https://cdn.openfin.co/release/runtime/mac/x64"
                     usingWindow:_window
        andCallCompletionHandler:^(NSData* received_data) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self onRuntimeFetched:received_data];
    });
  }];
  return YES;
}

- (void)startRuntime {
  NSString* runtimes_dir = [self getPathForRuntimesDirectory];
  NSURL* runtime_local_url = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@/%@/OpenFin.app/Contents/MacOS/OpenFin", runtimes_dir, _runtime_version]];
  NSMutableArray* args = [[_runtime_args componentsSeparatedByString:@" "] mutableCopy];
  [args addObject:[NSString stringWithFormat:@"--config=%@", _manifest_url]];
  NSError* error;
  [NSTask launchedTaskWithExecutableURL:runtime_local_url
                              arguments:args
                                  error:&error
                     terminationHandler:nil];
  if (error) {
    [self displayAlertWithMessageAndTerminate:
       [NSString stringWithFormat:@"Failed to launch runtime from path: %@/%@", runtimes_dir, _runtime_version]];
  } else {
    [NSApp terminate:self];
  }
}

- (void)onManifestParsedWithResult:(NSString*)error {
  if (error) {
    [self displayAlertWithMessageAndTerminate:
       [NSString stringWithFormat:@"Failed to parse manifest: %@", error]];
  }
  if (![self fetchRuntimeIfNeeded]) {
    [self startRuntime];
  }
}

- (void)onManifestFetchedAsFileHandle:(NSFileHandle*)file_handle {
[self parseManifestFile:file_handle
 andCallCompletionHandler:^(NSString* error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self onManifestParsedWithResult:error];
    });
  }];
}

- (void)fetchManifest {
  NSURLSessionDownloadTask* download_task =
      [[NSURLSession sharedSession] downloadTaskWithURL:[NSURL URLWithString:_manifest_url]
                                      completionHandler:^(NSURL* location, NSURLResponse* response, NSError* error) {
        NSFileHandle* file_handle = nil;
        if (!error) {
          file_handle = [NSFileHandle fileHandleForReadingFromURL:location
                                                            error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          if (error) {
            [self displayAlertWithMessageAndTerminate:
               [NSString stringWithFormat:@"Failed to fetch manifest from url: %@", self->_manifest_url]];
          } else {
            [self onManifestFetchedAsFileHandle:file_handle];
          }
        });
      }];
  [download_task resume];
}

- (void)registerProtocols {
  CFURLRef fins_url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("fin:"), NULL);
  CFURLRef current_handler_url = LSCopyDefaultApplicationURLForURL(fins_url, kLSRolesAll, nil);
  BOOL protocol_was_registered = current_handler_url != nil;
  CFStringRef fin_protocol = CFStringCreateWithCString(NULL, "fin", kCFStringEncodingUTF8);
  CFStringRef fins_protocol = CFStringCreateWithCString(NULL, "fins", kCFStringEncodingUTF8);
  NSString* handler_bundle_id = [[NSBundle mainBundle] bundleIdentifier];
  CFStringRef bundler_cf_string = (__bridge CFStringRef)handler_bundle_id;
  OSStatus status_fin = LSSetDefaultHandlerForURLScheme(fin_protocol, bundler_cf_string);
  OSStatus status_fins = LSSetDefaultHandlerForURLScheme(fins_protocol, bundler_cf_string);
  NSString* message;
  if ((int)status_fin == 0 && (int)status_fins == 0) {
    message = @"Handlers has been successfully installed";
  } else {
    message = [NSString stringWithFormat:@"Installing one of the handlers failed with errors code: %d, %d",
               (int)status_fin, (int)status_fins];
  }
  if (!protocol_was_registered) {
    [self displayAlertWithMessageAndTerminate:message];
    [NSApp terminate:self];
  }
}

- (void)launchOpenFinCliForManifestURL:(NSString*)manifestURL{
  NSURL* cmdURL = [NSURL URLWithString:@"file:///usr/local/bin/node"];
  NSArray* args = @[@"/usr/local/bin/openfin", @"--launch", [NSString stringWithFormat:@"--config=%@", manifestURL]];
  [NSTask launchedTaskWithExecutableURL:cmdURL
                              arguments:args
                                  error:NULL
                     terminationHandler:NULL];
}

-(void)applicationWillFinishLaunching:(NSNotification *)notification {
  [self registerProtocols];
  [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleAppleEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  //_manifest_url = @"http://localhost:9070/app.json";
  //_manifest_url = @"https://cdn.openfin.co/process-manager/app.json";
  //[self fetchManifest];
  //[NSApp terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
