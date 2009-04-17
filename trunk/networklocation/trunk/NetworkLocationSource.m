//
// NetworkLocationSource.m
// NetworkLocation
//
// Created by J. Nicholas Jitkoff on 3/15/09.
// Copyright Google Inc 2009. All rights reserved.
//

#import <Vermilion/Vermilion.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface NetworkLocationSource : HGSMemorySearchSource
@end

@implementation NetworkLocationSource

- (void)updateCache {
  [self clearResultIndex];
  SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("SystemConfiguration"), NULL);
  NSArray *array = (NSArray *)SCNetworkSetCopyAll(prefs);
  for (id item in array) {
    NSString *name = (NSString *)SCNetworkSetGetName((SCNetworkSetRef)item);
    NSString *key = (NSString *)SCNetworkSetGetSetID((SCNetworkSetRef)item);
    name = [NSString stringWithFormat:@"%@ Network Location", name];    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"qsb-netloc:%@", key]];
    HGSResult *newObject = [HGSResult resultWithURL:url
                                               name:name
                                               type:@"other.networklocation"
                                             source:self
                                         attributes:nil];
    [self indexResult:newObject nameString:name otherString:nil];
  }
  CFRelease(array);
  CFRelease(prefs);
}

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if (self = [super initWithConfiguration:configuration]){
    // TODO(alcor): register for network config change notifications
    [self updateCache];
  }
  return self;
}

- (id)provideValueForKey:(NSString*)key result:(HGSResult*)result {
  id value = nil;
  if ([key isEqualToString:kHGSObjectAttributeIconKey]) {
    value = [NSImage imageNamed:NSImageNameNetwork];
  } else if ([key isEqualToString:kHGSObjectAttributeDefaultActionKey]) {
    HGSExtensionPoint *actionPoint = [HGSExtensionPoint actionsPoint];
    value = [actionPoint extensionWithIdentifier:@"com.blacktree.qsb.action.SetNetworkLocation"];      
  }
  return value;
}

@end

@interface NetworkLocationAction : HGSAction
@end

@implementation NetworkLocationAction

- (BOOL)performWithInfo:(NSDictionary*)info {
  HGSResultArray *directObjects = [info objectForKey:kHGSActionDirectObjectsKey];
  BOOL success = NO;
  if (directObjects) {
    HGSResult *object = [directObjects lastObject];
    NSString *location = [[object url] resourceSpecifier];
    NSTask *setNetTask
      = [NSTask launchedTaskWithLaunchPath:@"/usr/sbin/scselect"
                                 arguments:[NSArray arrayWithObject:location]];
    [setNetTask waitUntilExit];
    
    NSDictionary *messageDict
    = [NSDictionary dictionaryWithObjectsAndKeys:
       [NSString stringWithFormat:@"Switched to %@", [object displayName]],
       kHGSSummaryMessageKey,
       [NSImage imageNamed:NSImageNameNetwork], 
       kHGSImageMessageKey,
       nil];
    [[NSNotificationCenter defaultCenter]
      postNotificationName:kHGSUserMessageNotification 
     object:self
     userInfo:messageDict];
  }
  
  // TODO(alcor): this format is probably more robust, but isn't working
  //    SCPreferencesRef prefs = SCPreferencesCreate(NULL, CFSTR("SystemConfiguration"), NULL);
  //    NSArray *array = (NSArray *)SCNetworkSetCopyAll(prefs);
  //    for (id item in array) {
  //      NSString *key = (NSString *)SCNetworkSetGetSetID((SCNetworkSetRef)item);
  //      NSLog(@"item %@ %@", key, location);
  //      if ([location isEqualToString:key]){
  //        success = SCNetworkSetSetCurrent((SCNetworkSetRef)item);
  //        success &= SCPreferencesCommitChanges(prefs);
  //        success &= SCPreferencesApplyChanges(prefs);
  //        break;
  //      }
  //    }
  //    CFRelease(array);
  //    CFRelease(prefs);
  
  return success;
}
@end




