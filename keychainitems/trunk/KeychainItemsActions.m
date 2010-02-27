//
//  KeychainItemsActions.m
//
//  Copyright (c) 2009-2010 Google Inc. All rights reserved.
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
#import "HGSKeychainItemExt.h"

extern NSString *kKeychainItemKey;

@interface CopyPasswordAction : HGSAction
@end

@implementation CopyPasswordAction
- (BOOL)performWithInfo:(NSDictionary*)info {
  HGSResultArray *directObjects = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *result in directObjects) {
    HGSLogDebug(@"copy password action invoked on '%@'", [result displayName]);

    HGSKeychainItem* item = (HGSKeychainItem*)[result valueForKey:kKeychainItemKey];
    if (item) {
      // put it on the clipboard
      NSString *password = [item password];
      [[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:self];
      [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];

      // don't keep the data around
      [item unloadData];
    }
  }
  return YES;
}
@end

@interface CopyAccountNameAction : HGSAction
@end

@implementation CopyAccountNameAction
- (BOOL)performWithInfo:(NSDictionary*)info {
  HGSResultArray *directObjects = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *result in directObjects) {
    HGSLogDebug(@"copy account name action invoked on '%@'", [result displayName]);
    
    HGSKeychainItem* item = (HGSKeychainItem*)[result valueForKey:kKeychainItemKey];
    if (item) {
      // put it on the clipboard
      NSString *accountName = [item username];
      [[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:self];
      [[NSPasteboard generalPasteboard] setString:accountName forType:NSStringPboardType];

      // don't keep the data around
      [item unloadData];
    }
  }
  return YES;
}
@end

@interface ShowKeychainItemAction : HGSAction
@end

@implementation ShowKeychainItemAction
- (BOOL)performWithInfo:(NSDictionary*)info {
  HGSResultArray *directObjects = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *result in directObjects) {
    HGSLogDebug(@"show keychain item invoked on '%@'", [result displayName]);
    
    HGSKeychainItem* item = (HGSKeychainItem*)[result valueForKey:kKeychainItemKey];
    if (item) {
      // display in a message
      NSString *message = [NSString stringWithFormat:@"Account Name: %@\nPassword: %@", [item username], [item password]];
      [HGSUserMessenger displayUserMessage:[result displayName]
                               description:message
                                      name:@"KeychainItem"
                                     image:nil
                                      type:kHGSUserMessageNoteType];

      // don't keep the data around
      [item unloadData];
    }
  }
  return YES;
}
@end
