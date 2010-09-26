#import "DeliciousFetcher.h"


@implementation DeliciousFetcher
- (id) initWithUrl:(NSString*) url
      keychainItem:(HGSKeychainItem*) keychainItem
         userAgent:(NSString*) userAgent
          receiver:(id<DeliciousReceiver>) receiver {
  if ((self = [super init])) {
    url_ = [url retain];
    keychainItem_ = [keychainItem retain];
    userAgent_ = [userAgent retain];
    receiver_ = receiver;
  }
  return self;
}

- (void)dealloc {
  [url_ release];
  [keychainItem_ release];
  [userAgent_ release];
  
  [super dealloc];
}

- (void)cancel {
  // do nothing, override in subclasses
  // zee java brain wants an abstract method here
}

@end
