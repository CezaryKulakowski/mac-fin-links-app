//
//  AppDelegate.m
//  finlinks
//
//  Created by Cezary Kułakowski on 16/03/2021.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
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
  if ([whole_link length] < 5) {
    [self displayAlertWithMessageAndTerminate:[NSString stringWithFormat:@"Unexpected link: %@", whole_link]];
    return;
  }
  NSString* url = [whole_link substringFromIndex:5];
  [self fetchManifestFromURL:url];
}

- (void)parseManifestFile:(NSFileHandle*)file_handle
    andReadRuntimeVersion:(NSString**)runtime_version
          andRuntimeArgs:(NSString**)runtime_args {
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
    [self displayAlertWithMessageAndTerminate:@"No runtime section in json file"];
  }
  NSDictionary* runtime_dict = runtime_section;
  id version = runtime_dict[@"version"];
  if (![version isKindOfClass:[NSString class]]) {
    [self displayAlertWithMessageAndTerminate:@"No valid version in runtime section"];
  }
  *runtime_version = version;
  id args = runtime_dict[@"arguments"];
  *runtime_args = nil;
  if ([args isKindOfClass:[NSString class]]) {
    *runtime_args = args;
  }
}

- (NSString*)getPathForRuntimeVersion:(NSString*)runtime_version {
  return [NSString stringWithFormat:@"%@/OpenFin/runtime/%@/OpenFin.app", NSHomeDirectory(), runtime_version];
}

- (NSString*)obtainExactVersionFromVersionString:(NSString*)runtime_version {
  NSRegularExpression* exact_version_regexp =
      [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,2}\\.[0-9]{2}\\.[0-9]{2}\\.[0-9]{1,4}$"
                                                options:0
                                                  error:nil];
  NSUInteger number_of_matches =
      [exact_version_regexp numberOfMatchesInString:runtime_version
                                            options:0
                                              range:NSMakeRange(0, [runtime_version length])];
  if (number_of_matches) {
    return runtime_version;
  }

  [self displayAlertWithMessageAndTerminate:@"Only direct runtime versions are supported now."];
  
  return runtime_version;
}

- (void)fetchRuntimeIfNeeded:(NSString*)runtime_version {
  if ([[NSFileManager defaultManager] fileExistsAtPath:runtime_version]) {
    return;
  }
  //NSString* exact_version = [self obtainExactVersionFromVersionString:runtime_version];
  //[self displayAlertWithMessageAndTerminate:[NSString stringWithFormat:@"Parsed version: %@", exact_version]];
  //NSString* fetch_url =
}

- (void)startRuntime:(NSString*)runtime_version
       withConfigURL:(NSString*)config_url
             andArgs:(NSString*)runtime_args {
  NSString* runtime_path = [self getPathForRuntimeVersion:runtime_version];
  NSURL* runtime_local_url = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@/Contents/MacOS/OpenFin", runtime_path]];
  NSMutableArray* args = [[runtime_args componentsSeparatedByString:@" "] mutableCopy];
  [args addObject:[NSString stringWithFormat:@"--config=%@", config_url]];
  NSError* error;
  [NSTask launchedTaskWithExecutableURL:runtime_local_url
                              arguments:args
                                  error:&error
                     terminationHandler:nil];
  if (error) {
    [self displayAlertWithMessageAndTerminate:[NSString stringWithFormat:@"Failed to launch runtime from path: %@", runtime_path]];
  } else {
    [NSApp terminate:self];
  }
}

- (void)onManifestFetched:(NSString*)url
             asFileHandle:(NSFileHandle*)file_handle {
  NSString* runtime_version;
  NSString* runtime_args;
  [self parseManifestFile:file_handle
    andReadRuntimeVersion:&runtime_version
           andRuntimeArgs:&runtime_args];
  [self fetchRuntimeIfNeeded:runtime_version];
  [self startRuntime:runtime_version
       withConfigURL:url
             andArgs:runtime_args];
}

- (void)fetchManifestFromURL:(NSString*)url {
  NSURLSessionDownloadTask* download_task =
      [[NSURLSession sharedSession] downloadTaskWithURL:[NSURL URLWithString:url]
                                      completionHandler:^(NSURL* location, NSURLResponse* response, NSError* error) {
        NSFileHandle* file_handle = nil;
        if (!error) {
          file_handle = [NSFileHandle fileHandleForReadingFromURL:location
                                                            error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          if (error) {
            [self displayAlertWithMessageAndTerminate:[NSString stringWithFormat:@"Failed to fetch manifest from url: %@", url]];
          } else {
            [self onManifestFetched:url
                       asFileHandle:file_handle];
          }
        });
      }];
  [download_task resume];
}

- (void)registerProtocol {
  CFURLRef fins_url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("fins:"), NULL);
  CFURLRef current_handler_url = LSCopyDefaultApplicationURLForURL(fins_url, kLSRolesAll, nil);
  BOOL protocol_was_registered = current_handler_url != nil;
  CFStringRef protocol = CFStringCreateWithCString(NULL, "fins", kCFStringEncodingUTF8);
  NSString* handler_bundle_id = [[NSBundle mainBundle] bundleIdentifier];
  CFStringRef bundler_cf_string = (__bridge CFStringRef)handler_bundle_id;
  OSStatus status = LSSetDefaultHandlerForURLScheme(protocol, bundler_cf_string);
  NSString* message;
  if ((int)status == 0) {
    message = @"Handler has been successfully installed";
  } else {
    message = [NSString stringWithFormat:@"Installing handler failed with error code: %d", (int)status];
  }
  if (!protocol_was_registered) {
    [self displayAlertWithMessageAndTerminate:message];
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
  [self registerProtocol];
  [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleAppleEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  //[self fetchManifestFromURL:@"http://localhost:9070/app.json"];
  //[NSApp terminate:self];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
