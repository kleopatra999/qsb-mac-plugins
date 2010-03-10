//
// NetworkLocationSource.m
//
//  Copyright (c) 2008 Google Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//    * Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
//  copyright notice, this list of conditions and the following disclaimer
//  in the documentation and/or other materials provided with the
//  distribution.
//    * Neither the name of Google Inc. nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Vermilion/Vermilion.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface NetworkLocationSource : HGSMemorySearchSource
@end

@implementation NetworkLocationSource

- (void)updateCache {
  [self clearResultIndex];
  SCPreferencesRef prefs 
    = SCPreferencesCreate(NULL, CFSTR("SystemConfiguration"), NULL);
  NSArray *array = (NSArray *)SCNetworkSetCopyAll(prefs);
  for (id item in array) {
    NSString *name = (NSString *)SCNetworkSetGetName((SCNetworkSetRef)item);
    NSString *key = (NSString *)SCNetworkSetGetSetID((SCNetworkSetRef)item);
    name = [NSString stringWithFormat:@"%@ Network Location", name];
    NSString *urlString = [NSString stringWithFormat:@"qsb-netloc:%@", key];
    NSURL *url = [NSURL URLWithString:urlString];
    HGSUnscoredResult *newObject 
      = [HGSUnscoredResult resultWithURL:url
                                    name:name
                                    type:@"other.networklocation"
                                  source:self
                              attributes:nil];
    [self indexResult:newObject name:name otherTerm:nil];
  }
  CFRelease(array);
  CFRelease(prefs);
}

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
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
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:kHGSUserMessageNotification 
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




