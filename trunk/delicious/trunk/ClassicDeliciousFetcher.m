#import "ClassicDeliciousFetcher.h"

static const NSString *kClassicDeliciousApiProtocol = @"https";
static const NSString *kClassicDeliciousApiVersion = @"v1";

@interface ClassicDeliciousFetcher ()
- (void)startAsynchronousBookmarkFetch;
@end

@implementation ClassicDeliciousFetcher

@synthesize connection = connection_;

+ (NSString*) fillInUrlTemplate:(NSString*)url {
  return [NSString stringWithFormat: url, kClassicDeliciousApiProtocol, kClassicDeliciousApiVersion];
}

- (id) initWithUrl:(NSString*) url
      keychainItem:(HGSKeychainItem*) keychainItem
         userAgent:(NSString*) userAgent
          receiver:(id<DeliciousReceiver>) receiver {
  if ((self = [super initWithUrl:url
                    keychainItem:keychainItem
                       userAgent:userAgent
                        receiver: receiver])) {
    [self startAsynchronousBookmarkFetch];
  }
  return self;
}

- (void)dealloc {
  [bookmarkData_ release];
  [super dealloc];
}

- (void)setConnection:(NSURLConnection *)connection {
  if (connection_ != connection) {
    [connection_ cancel];
    [connection_ release];
    connection_ = [connection retain];
  }
}

- (void)startAsynchronousBookmarkFetch {
  NSString *realUrl = [ClassicDeliciousFetcher fillInUrlTemplate: url_];
  NSURL *bookmarkRequestURL = [NSURL URLWithString:realUrl];
  NSMutableURLRequest *bookmarkRequest
    = [NSMutableURLRequest requestWithURL:bookmarkRequestURL
                              cachePolicy:NSURLRequestReloadIgnoringCacheData
                          timeoutInterval:15.0];
  [bookmarkRequest setValue: userAgent_
         forHTTPHeaderField:@"User-Agent"];
  NSURLConnection *connection
    = [NSURLConnection connectionWithRequest:bookmarkRequest
                                    delegate:self];
  [self setConnection:connection];
}

- (void) cancel {
  [[self connection] cancel];
}


#pragma mark NSURLConnection Delegate Methods

- (void)connection:(NSURLConnection *)connection
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
  HGSLogDebug(@"DeliciousBookmarks: Request was challenged");
  HGSAssert(connection == connection_, nil);
  NSString *userName = [keychainItem_ username];
  NSString *password = [keychainItem_ password];
  
  id<NSURLAuthenticationChallengeSender> sender = [challenge sender];
  NSInteger previousFailureCount = [challenge previousFailureCount];
  
  if (previousFailureCount > 3) {
    // Don't keep trying.
    [receiver_ authenticationFailed];
    return;
  }
  
  if (userName && password) {
    NSURLCredential *creds
    = [NSURLCredential credentialWithUser:userName
                                 password:password
                              persistence:NSURLCredentialPersistenceNone];
    [sender useCredential:creds forAuthenticationChallenge:challenge];
  } else {
    [sender continueWithoutCredentialForAuthenticationChallenge:challenge];
  }
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response {
  HGSLogDebug(@"DeliciousBookmarks: Request got response");
  HGSAssert(connection == connection_, nil);
  [bookmarkData_ release];
  bookmarkData_ = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)data {
  HGSLogDebug(@"DeliciousBookmarks: Request got data");
  HGSAssert(connection == connection_, nil);
  [bookmarkData_ appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  HGSLogDebug(@"DeliciousBookmarks: Request finished, time to dispatch");
  HGSAssert(connection == connection_, nil);
  [self setConnection:nil];
  [receiver_ fetchComplete: bookmarkData_];
  [bookmarkData_ release];
  bookmarkData_ = nil;
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
  HGSLogDebug(@"DeliciousBookmarks: Request failed");
  HGSAssert(connection == connection_, nil);
  [self setConnection:nil];
  [bookmarkData_ release];
  bookmarkData_ = nil;
  [receiver_ fetchFailed: error];
}


@end
