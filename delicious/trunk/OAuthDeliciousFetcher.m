#import "OAuthDeliciousFetcher.h"
#import "DeliciousConstants.h"
#import "YOSSocial.h"

static const NSString *kOAuthDeliciousApiProtocol = @"http";
static const NSString *kOAuthDeliciousApiVersion = @"v2";

@interface OAuthDeliciousFetcher ()
- (void)startAsynchronousBookmarkFetch;
- (void)apiTicket:(OAServiceTicket*)ticket didFinishWithData:(NSData*) data;
- (void)apiTicket:(OAServiceTicket*)ticket didFailWithError:(NSError*) error;
@end

@implementation OAuthDeliciousFetcher

@synthesize fetcher = fetcher_;

+ (NSString*) fillInUrlTemplate:(NSString*)url {
  return [NSString stringWithFormat: url, kOAuthDeliciousApiProtocol, kOAuthDeliciousApiVersion];
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
  [super dealloc];
}

- (void)setFetcher:(OADataFetcher *)fetcher {
  if (fetcher_ != fetcher) {
    //[fetcher_ cancel];
    [fetcher_ release];
    fetcher_ = [fetcher_ retain];
  }
}

- (void)startAsynchronousBookmarkFetch {
  NSString *realUrl = [OAuthDeliciousFetcher fillInUrlTemplate: url_];
  NSURL *bookmarkRequestURL = [NSURL URLWithString:realUrl];
  
  YOSSession *session =
    [YOSSession sessionWithConsumerKey:kDeliciousOAuthConsumerKey  
                     andConsumerSecret:kDeliciousOAuthSharedSecret  
                      andApplicationId:kDeliciousOAuthAppId];
  
  [session setVerifier: [keychainItem_ password]];
  
  BOOL hasSession = [session resumeSession];
  if (!hasSession) {
    [receiver_ authenticationFailed];
    return;
  }
  
  [session saveSession];
  
  OAConsumer *consumer = [[OAConsumer alloc] initWithKey:kDeliciousOAuthConsumerKey
                                                  secret:kDeliciousOAuthSharedSecret];
  OAToken *accessToken = [[OAToken alloc] initWithKey: [[session accessToken] key]
                                               secret: [[session accessToken] secret]];
  OAMutableURLRequest *request =
    [[OAMutableURLRequest alloc] initWithURL:bookmarkRequestURL
                                    consumer:consumer
                                       token:accessToken
                                       realm:nil
                           signatureProvider:[[OAHMAC_SHA1SignatureProvider alloc] init]];
  
  OADataFetcher *fetcher = [[OADataFetcher alloc] init];
  [fetcher fetchDataWithRequest:request
                       delegate:self
              didFinishSelector:@selector(apiTicket:didFinishWithData:)
                didFailSelector:@selector(apiTicket:didFailWithError:)];
  
  [self setFetcher:fetcher];
}

- (void) cancel {
  //[[self request] cancel];
}


#pragma mark OADataFetcher Delegate Methods

- (void)apiTicket:(OAServiceTicket*)ticket didFinishWithData:(NSData*) data {
  HGSLogDebug(@"DeliciousBookmarks: Request finished, time to dispatch");
  [self setFetcher:nil];
  [receiver_ fetchComplete: data];
}

- (void)apiTicket:(OAServiceTicket*)ticket didFailWithError:(NSError*) error {
  HGSLogDebug(@"DeliciousBookmarks: Request failed");
  [self setFetcher:nil];
  [receiver_ fetchFailed: error];
}

@end
