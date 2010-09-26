#import <Cocoa/Cocoa.h>
#import "DeliciousFetcher.h"

@interface ClassicDeliciousFetcher : DeliciousFetcher {
  NSURLConnection *connection_;
  NSMutableData *bookmarkData_;
}

- (id) initWithUrl:(NSString*) url
      keychainItem:(HGSKeychainItem*) keychainItem
         userAgent:(NSString*) userAgent
          receiver:(id<DeliciousReceiver>) receiver;

+ (NSString*) fillInUrlTemplate:(NSString*)url;

@property (nonatomic, retain) NSURLConnection *connection;

@end
