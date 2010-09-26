#import "YahooDeliciousAccount.h"
#import "DeliciousConstants.h"
#import "OAuthDeliciousFetcher.h"
#import "YOSSocial.h"
#import <GTM/GTMBase64.h>
#import <GData/GDataHTTPFetcher.h>

@interface YahooDeliciousAccount ()

// Open delicious.com in the user's preferred browser.
+ (BOOL)openDeliciousHomePage;

// Open Yahoo page to get OAuth PIN
+ (BOOL)getPIN;

@property (nonatomic, assign) BOOL authCompleted;
@property (nonatomic, assign) BOOL authSucceeded;

@end

@implementation YahooDeliciousAccount

@synthesize authCompleted = authCompleted_;
@synthesize authSucceeded = authSucceeded_;

- (NSString *)type {
  return kOAuthDeliciousAccountTypeName;
}

#pragma mark Account Editing

- (void)authenticate {
  // TODO: Real impl
  [self setAuthenticated: YES];
}

- (BOOL)authenticateWithPassword:(NSString *)password {
  // TODO: Real impl
  BOOL authenticated = YES;
  return authenticated;
}

+ (BOOL)openDeliciousHomePage {
  NSURL *deliciousURL = [NSURL URLWithString:kDeliciousURLString];
  BOOL success = [[NSWorkspace sharedWorkspace] openURL:deliciousURL];
  return success;
}

+ (BOOL)getPIN {
  YOSSession *session =
    [YOSSession sessionWithConsumerKey:kDeliciousOAuthConsumerKey  
                     andConsumerSecret:kDeliciousOAuthSharedSecret  
                      andApplicationId:kDeliciousOAuthAppId];
  [session clearSession];
  [session sendUserToAuthorizationWithCallbackUrl:nil];
  [session saveSession];
  return TRUE;
}

#pragma mark DeliciousFetcherSource Methods

- (DeliciousFetcher*) fetcherForUrl:(NSString*) url
                   withKeychainItem:(HGSKeychainItem*) keychainItem
                          userAgent:(NSString*) userAgent
                           receiver:(id<DeliciousReceiver>) receiver{
  return [[[OAuthDeliciousFetcher alloc] initWithUrl: url
                                          keychainItem: keychainItem
                                             userAgent: userAgent
                                              receiver: receiver] autorelease];
}

@end


@implementation EditYahooDeliciousAccountWindowController

- (IBAction)openDeliciousHomePage:(id)sender {
  BOOL success = [YahooDeliciousAccount openDeliciousHomePage];
  if (!success) {
    NSBeep();
  }
}

- (IBAction)getPIN:(id)sender {
  BOOL success = [YahooDeliciousAccount getPIN];
  if (!success) {
    NSBeep();
  }
}

@end

@implementation SetUpYahooDeliciousAccountViewController

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil
                         bundle:nibBundleOrNil
               accountTypeClass:[YahooDeliciousAccount class]];
  return self;
}

- (IBAction)openDeliciousHomePage:(id)sender {
  BOOL success = [YahooDeliciousAccount openDeliciousHomePage];
  if (!success) {
    NSBeep();
  }
}

- (IBAction)getPIN:(id)sender {
  BOOL success = [YahooDeliciousAccount getPIN];
  if (!success) {
    NSBeep();
  }
}

@end
