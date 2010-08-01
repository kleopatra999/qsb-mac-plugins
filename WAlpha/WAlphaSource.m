#import <Vermilion/Vermilion.h>
#import <GTM/GTMNSString+URLArguments.h>

@interface WAlphaSource : HGSCallbackSearchSource
@end

@implementation WAlphaSource

#define kAlphaPrefixLen 6

static NSString *const kAlphaPrefix = @"alpha ";
static NSString *const kAlphaSearchURL = @"http://www.wolframalpha.com/input/?i=";

static NSImage *iconImage;

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  return ([query pivotObject] == NULL);
}

- (BOOL)isSearchConcurrent {
  return YES;
}

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  HGSQuery *query = [operation query];
  HGSTokenizedString *term = [query tokenizedQueryString];
  NSString *queryString = [term originalString];
  
  if (!iconImage)
    iconImage = [[self imageNamed:@"Alpha.jpg"] retain];
  
  if ([queryString hasPrefix:kAlphaPrefix] &&
      [queryString length] > kAlphaPrefixLen) {
    
    NSString *q = [queryString substringFromIndex:kAlphaPrefixLen];
    NSString *param = [q gtm_stringByEscapingForURLArgument];
    
    NSString *snipForm = HGSLocalizedString(@"Search Wolfram Alpha "
                                            @"for '%@'", nil);
    NSString *snippet = [NSString stringWithFormat:snipForm, q];
    
    NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
                          snippet, kHGSObjectAttributeSnippetKey,
                          iconImage, kHGSObjectAttributeIconKey, nil];
    
    CGFloat score = HGSCalibratedScore(kHGSCalibratedPerfectScore);
    NSString *uri = [kAlphaSearchURL stringByAppendingString:param];
    
    NSString *serviceName = HGSLocalizedString(@"Wolfram Alpha", nil);
    
    HGSScoredResult *result = [HGSScoredResult resultWithURI:uri
                                                        name:serviceName
                                                        type:kHGSTypeSearch
                                                      source:self
                                                  attributes:attr
                                                       score:score
                                                       flags:0
                                                 matchedTerm:term
                                              matchedIndexes:nil];
    
    [operation setRankedResults:[NSArray arrayWithObject:result]];
  }
  
  [operation finishQuery];
}

@end
