#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBPluginUI.h>
#import "DeliciousFetcherSource.h"

@class DeliciousAccountEditController;

@interface DeliciousAccount : HGSSimpleAccount<DeliciousFetcherSource> {
 @private
  // Set by and only useful within authentication.
  BOOL authCompleted_;
  BOOL authSucceeded_;
}
@end

@interface EditDeliciousAccountWindowController : QSBEditSimpleAccountWindowController
- (IBAction)openDeliciousHomePage:(id)sender;
@end

@interface SetUpDeliciousAccountViewController : QSBSetUpSimpleAccountViewController
- (IBAction)openDeliciousHomePage:(id)sender;
@end

