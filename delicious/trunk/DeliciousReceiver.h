#import <Cocoa/Cocoa.h>


@protocol DeliciousReceiver
-(void) authenticationFailed;
-(void) fetchComplete:(NSData *)data;
-(void) fetchFailed:(NSError *)error;
@end
