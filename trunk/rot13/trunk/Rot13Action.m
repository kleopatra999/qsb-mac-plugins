#import <Vermilion/Vermilion.h>
#import <QuartzCore/QuartzCore.h>
#import <GTM/GTMLargeTypeWindow.h>

static const CGFloat kRot13TwoThirdsAlpha = 0.66;
static const int kRot13FontSize = 16;

@interface Rot13Action : HGSAction
@end

@implementation Rot13Action

- (BOOL)performWithInfo:(NSDictionary*)info {
  HGSResultArray *directObjects = [info objectForKey:kHGSActionDirectObjectsKey];
  BOOL success = NO;
  if (directObjects) {
    NSString *text = [directObjects displayName];
    size_t length = [text length];

    unichar *buffer = malloc(length * sizeof(unichar));
    [text getCharacters:buffer];

    for (size_t i = 0; i < length; i++) {
      unichar c = buffer[i];
      buffer[i] = isalpha(c) ? (tolower(c) < 'n' ? c + 13 : c - 13) : c;
    }

    NSString *rot13ified = [NSString stringWithCharacters:buffer length:length];
    free(buffer);

    // Copy this from the easy large type window initWithString so we can control
    // the font size.
    NSMutableAttributedString *attrString
      = [[[NSMutableAttributedString alloc] initWithString:rot13ified] autorelease];

    NSRange fullRange = NSMakeRange(0, [rot13ified length]);
    [attrString addAttribute:NSForegroundColorAttributeName 
                       value:[NSColor whiteColor] 
                       range:fullRange];

    NSMutableParagraphStyle *style 
      = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [style setAlignment:NSCenterTextAlignment];
    [attrString addAttribute:NSParagraphStyleAttributeName 
                       value:style 
                       range:fullRange];

    NSShadow *textShadow = [[[NSShadow alloc] init] autorelease];
    [textShadow setShadowOffset:NSMakeSize(5, -5)];
    [textShadow setShadowBlurRadius:10];
    [textShadow setShadowColor:
     [NSColor colorWithCalibratedWhite:0 
                                 alpha:kRot13TwoThirdsAlpha]];
    [attrString addAttribute:NSShadowAttributeName 
                       value:textShadow 
                       range:fullRange];

    NSFont *font = [NSFont boldSystemFontOfSize:kRot13FontSize] ;
    [attrString addAttribute:NSFontAttributeName 
                       value:font
                       range:fullRange];

    GTMLargeTypeWindow *largeTypeWindow
      = [[GTMLargeTypeWindow alloc] initWithAttributedString:attrString];
    [largeTypeWindow setReleasedWhenClosed:YES];
    [largeTypeWindow makeKeyAndOrderFront:self];
    success = YES;
  }
  return success;
}
@end
