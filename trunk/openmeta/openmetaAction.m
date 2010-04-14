//
//  openmetaAction.m
//  openmeta
//
//  Created by Dave MacLachlan on 2010-04-07.
//  Copyright Google Inc 2010. All rights reserved.
//

#import <Vermilion/Vermilion.h>
#import "OpenMeta.h"
#import "OpenMetaPrefs.h"

@interface OpenMetaAction : HGSAction
- (NSArray *)tagsFromResult:(HGSResult *)result;
@end

@interface OpenMetaActionAddTag : HGSAction
@end

@interface OpenMetaActionRemoveTag : HGSAction
@end

@interface OpenMetaActionTagArgument : HGSActionArgument
@end

static NSArray *TagsFromInfo(NSDictionary *info) {
  HGSResultArray *tags
    = [info objectForKey:@"com.google.qsb.openmeta.action.argument.tag"];
  NSMutableArray *textTags = [NSMutableArray arrayWithCapacity:[tags count]];
  for (HGSResult *tag in tags) {
    NSDictionary *value 
      = [tag valueForKey:kHGSObjectAttributePasteboardValueKey];
    NSString *textValue = [value objectForKey:NSStringPboardType];
    if (textValue) {
      [textTags addObject:textValue];
    } else {
      HGSLogDebug(@"Couldn't get text from %@", tag);
    }
  }
  return textTags;
}

@implementation  OpenMetaActionAddTag

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL wasGood = YES;
  NSArray *tags = TagsFromInfo(info);
  HGSResultArray *directObjects 
    = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *file in directObjects) {
    NSString *filePath = [file filePath];
    NSError *error;
    NSArray *oldFileTags = [OpenMeta getUserTags:filePath error:&error];
    if (error) {
      [NSApp presentError:error];
      wasGood = NO;
      break;
    }
    error = [OpenMeta addUserTags:tags path:filePath];
    if (error) {
      [NSApp presentError:error];
      wasGood = NO;
      break;
    }
    [OpenMetaPrefs updatePrefsRecentTags:oldFileTags newTags:tags];
  }
  return wasGood;
}

@end

@implementation  OpenMetaActionRemoveTag

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL wasGood = YES;
  NSArray *tags = TagsFromInfo(info);
  HGSResultArray *directObjects 
    = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *file in directObjects) {
    NSString *filePath = [file filePath];
    NSError *error = [OpenMeta clearUserTags:tags path:filePath];
    if (error) {
      [NSApp presentError:error];
      wasGood = NO;
      break;
    }
  }
  return wasGood;
}

@end

@implementation OpenMetaActionTagArgument

- (NSArray *)resultsForQuery:(HGSQuery *)query source:(HGSSearchSource *)source {
  NSArray *recentTags = [OpenMetaPrefs recentTags];
  NSMutableArray *scoredTags 
    = [NSMutableArray arrayWithCapacity:[recentTags count]];
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSString *fileType = NSFileTypeForHFSTypeCode(kClippingTextType);
  NSImage *image = [ws iconForFileType:fileType];
  HGSTokenizedString *tokenizedQueryString = [query tokenizedQueryString];
  for (NSString *recentTag in recentTags) {
    NSDictionary *attributes
      = [NSDictionary dictionaryWithObjectsAndKeys:
         image, kHGSObjectAttributeIconKey,
         nil];
    HGSScoredResult *hgsObject
      = [HGSScoredResult resultWithURI:@"openmetatag:text"
                                  name:recentTag
                                  type:kHGSTypeTextUserInput
                                source:source
                            attributes:attributes
                                 score:HGSCalibratedScore(kHGSCalibratedPerfectScore)
                                 flags:eHGSSpecialUIRankFlag
                           matchedTerm:tokenizedQueryString
                        matchedIndexes:nil];
    [scoredTags addObject:hgsObject];
  }
  return scoredTags;
}

@end

