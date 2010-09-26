#import <Cocoa/Cocoa.h>
#import "DeliciousFetcher.h"


@protocol DeliciousFetcherSource

- (DeliciousFetcher*) fetcherForUrl:(NSString*) url
                   withKeychainItem:(HGSKeychainItem*) keychainItem
                          userAgent:(NSString*) userAgent
                           receiver:(id<DeliciousReceiver>) receiver;
@end
