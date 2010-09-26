#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBPluginUI.h>
#import "DeliciousFetcherSource.h"

@class YahooDeliciousAccountEditController;

@interface YahooDeliciousAccount : HGSSimpleAccount<DeliciousFetcherSource> {
@private
  // Set by and only useful within authentication.
  BOOL authCompleted_;
  BOOL authSucceeded_;
}
@end

@interface EditYahooDeliciousAccountWindowController : QSBEditSimpleAccountWindowController
- (IBAction)openDeliciousHomePage:(id)sender;
- (IBAction)getPIN:(id)sender;
@end

@interface SetUpYahooDeliciousAccountViewController : QSBSetUpSimpleAccountViewController
- (IBAction)openDeliciousHomePage:(id)sender;
- (IBAction)getPIN:(id)sender;
@end

