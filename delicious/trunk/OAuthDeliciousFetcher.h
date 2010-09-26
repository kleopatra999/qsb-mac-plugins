#import "DeliciousFetcher.h"
#import "OADataFetcher.h"

@interface OAuthDeliciousFetcher : DeliciousFetcher {
  OADataFetcher *fetcher_;
}

- (id) initWithUrl:(NSString*) url
      keychainItem:(HGSKeychainItem*) keychainItem
         userAgent:(NSString*) userAgent
          receiver:(id<DeliciousReceiver>) receiver;

+ (NSString*) fillInUrlTemplate:(NSString*)url;

@property (nonatomic, retain) OADataFetcher *fetcher;

@end

