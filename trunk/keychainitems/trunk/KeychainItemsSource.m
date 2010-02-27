//
//  KeychainItemsSource.m
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

const NSString *kKeychainItemKey = @"keychainItem";
static NSString *kKeychainItemType = @"keychain";
static NSString *kCopyPasswordAction = @"com.google.qsb.plugin.keychain.copypassword";

@interface KeychainItemsSource : HGSMemorySearchSource {
 @private
  NSImage *keychainIcon_;
}
- (void)updateIndex;
@end

// callback for when the keychain has been updated
static OSStatus KeychainModified(SecKeychainEvent keychainEvent,
                                 SecKeychainCallbackInfo *info,
                                 void *context)
{
  HGSLogDebug(@"keychain modification event received");
  KeychainItemsSource *source = (KeychainItemsSource *)context;
  [source updateIndex];
  return noErr;
}

@implementation KeychainItemsSource

- (HGSResult*)resultForItem:(SecKeychainItemRef)itemRef ofClass:(SecItemClass)itemClass {
  CFRetain(itemRef); // HGSKeychainItem releases but doesn't retain
  HGSKeychainItem *item = [[[HGSKeychainItem alloc] initWithRef:itemRef] autorelease];

  // create and return the result
  NSString *name = [item label];
  NSString *urlString = [NSString stringWithFormat:@"keychain://%@/%@",
                         @"default",
                         [name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
  NSMutableDictionary *attributes =
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
      keychainIcon_, kHGSObjectAttributeIconKey,
      item, kKeychainItemKey,
      nil];
  HGSAction *action = [[HGSExtensionPoint actionsPoint] extensionWithIdentifier:kCopyPasswordAction];
  if (action) {
    [attributes setObject:action forKey:kHGSObjectAttributeDefaultActionKey];
  }
  return [HGSUnscoredResult resultWithURL:[NSURL URLWithString:urlString]
                                     name:name
                                     type:kKeychainItemType
                                   source:self
                               attributes:attributes];
}

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    // use the keychain access icon
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    keychainIcon_ = [ws iconForFile:[ws absolutePathForAppBundleWithIdentifier:@"com.apple.keychainaccess"]];
    [keychainIcon_ retain];

    // build the initial index
    [self updateIndex];
    
    // register a callback for when the keychain is modified
    OSStatus result = SecKeychainAddCallback(KeychainModified,
                                             kSecAddEventMask
                                             | kSecDeleteEventMask 
                                             | kSecUpdateEventMask 
                                             | kSecDefaultChangedEventMask 
                                             | kSecKeychainListChangedMask,
                                             self);
    if (result != noErr) {
      HGSLog(@"KeychainItemsSource: error %d while adding modification callback", result);
      [keychainIcon_ release];
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  // remove the keychain modification callback
  OSStatus result = SecKeychainRemoveCallback(KeychainModified);
  if (result != noErr) {
    HGSLog(@"KeychainItemsSource: error %d while removing modification callback", result);
  }

  [keychainIcon_ release];
  [super dealloc];
}

- (void)searchSecurityClass:(SecItemClass)targetClass {
  SecKeychainSearchRef searchRef;
  OSStatus result = SecKeychainSearchCreateFromAttributes(NULL, targetClass, NULL, &searchRef);
  if (result != noErr) {
    HGSLog(@"KeychainItemsSource: error %d while starting search", result);
    return;
  }
  
  SecKeychainItemRef itemRef;
  while ((result = SecKeychainSearchCopyNext(searchRef, &itemRef)) == noErr) {
    
    // create an indexable result for the item and index it
    HGSResult* newResult = [self resultForItem:itemRef ofClass:targetClass];
    if (newResult) {
      [self indexResult:newResult];
    }

    CFRelease(itemRef);
  }
  if (result != errSecItemNotFound) {
    HGSLog(@"KeychainItemsSource: error %d while iterating through search results", result);
  }
  
  CFRelease(searchRef);
}

- (void)updateIndex {
  HGSLogDebug(@"updating index");
  [self clearResultIndex];
  [self searchSecurityClass:kSecInternetPasswordItemClass];
  [self searchSecurityClass:kSecGenericPasswordItemClass];
}

@end
