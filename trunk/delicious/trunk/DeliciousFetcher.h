#import <Cocoa/Cocoa.h>
#import <Vermilion/HGSKeychainItem.h>
#import "DeliciousReceiver.h"

@interface DeliciousFetcher : NSObject {
  NSString *url_;
  HGSKeychainItem *keychainItem_;
  NSString *userAgent_;
  id<DeliciousReceiver> receiver_;
}
- (id) initWithUrl:(NSString*) url
      keychainItem:(HGSKeychainItem*) keychainItem
         userAgent:(NSString*) userAgent
          receiver:(id<DeliciousReceiver>) receiver;

- (void) cancel;

@end
