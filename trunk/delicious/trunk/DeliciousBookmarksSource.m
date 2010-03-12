#import <Vermilion/HGSKeychainItem.h>
#import "DeliciousConstants.h"

static const NSTimeInterval kDeliciousRefreshSeconds = 3600.0;  // 60 minutes.

// Only report errors to user once an hour.
static const NSTimeInterval kDeliciousErrorReportingInterval = 3600.0;  // 1 hour

@interface DeliciousBookmarksSource : HGSMemorySearchSource <HGSAccountClientProtocol> {
 @private
  NSTimer *updateTimer_;
  NSMutableData *bookmarkData_;
  NSString *lastUpdate_;
  HGSSimpleAccount *account_;
  NSURLConnection *connection_;
  BOOL currentlyFetching_;
  SEL currentCallback_;
  NSTimeInterval previousErrorReportingTime_;
  NSImage *tagIcon_;
}

@property (nonatomic, retain) NSURLConnection *connection;

- (HGSKeychainItem *)keychainItem;
- (void)setUpPeriodicRefresh;
- (void)startAsynchronousBookmarkFetch:(NSString*)url
                              callback:(SEL)selector
                        waitIfFetching:(BOOL)shouldWait;
- (void)checkLastUpdate;
- (void)indexBookmarksFromData;
- (void)indexResultForUrl:(NSString *)url
                    title:(NSString *)title
                     type:(NSString *)type
                     tags:(NSArray *)tags
                     icon:(NSImage*)iconImage;

// Post user notification about a connection failure.
- (void)reportConnectionFailure:(NSString *)explanation
                    successCode:(NSInteger)successCode;

@end

@implementation DeliciousBookmarksSource

@synthesize connection = connection_;

- (id)initWithConfiguration:(NSDictionary *)configuration {
  HGSLogDebug(@"DeliciousBookmarks: Instance init");
  if ((self = [super initWithConfiguration:configuration])) {
    HGSLogDebug(@"DeliciousBookmarks: Configuring...");
    NSBundle* sourceBundle = HGSGetPluginBundle();
    NSString *iconPath = [sourceBundle pathForImageResource:@"delicious"];
    tagIcon_ = [[NSImage alloc] initByReferencingFile:iconPath];    
    account_ = [[configuration objectForKey:kHGSExtensionAccountKey] retain];
    lastUpdate_ = [@"unknown" retain];
    if (account_) {
      HGSLogDebug(@"DeliciousBookmarks: Setting up fetcher");
      // Fetch, and schedule a timer to update every hour.
      [self startAsynchronousBookmarkFetch:kDeliciousLastUpdateURL
                                  callback:@selector(checkLastUpdate)
                            waitIfFetching:true];
      [self setUpPeriodicRefresh];
      // Watch for credential changes.
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      [nc addObserver:self
             selector:@selector(loginCredentialsChanged:)
                 name:kHGSAccountDidChangeNotification
               object:account_];
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [bookmarkData_ release];
  [account_ release];
  [lastUpdate_ release];
  [tagIcon_ release];

  [super dealloc];
}


#pragma mark -

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = [super isValidSourceForQuery:query];
  // If we're pivoting on a tag then we can provide
  // a list of all the bookmarks with that tag.
  if (!isValid) {
    HGSResult *pivotObject = [query pivotObject];
    isValid = ([pivotObject conformsToType:HGS_SUBTYPE(kHGSTypeWebpage, @"delicioustag")]);
    if (isValid) {
      HGSLogDebug(@"DeliciousBookmarkSource pivoting on '%@'.", [pivotObject displayName]);
    }
  }
  return isValid;
}

- (HGSResult *)preFilterResult:(HGSResult *)result 
               matchesForQuery:(HGSQuery*)query
                   pivotObject:(HGSResult *)pivotObject {
  // Remove things that don't have the pivot tag.
  if ([pivotObject conformsToType:HGS_SUBTYPE(kHGSTypeWebpage, @"delicioustag")]) {
    NSString *tag = [pivotObject displayName];
    NSSet *tags = [result valueForKey:kObjectAttributeDeliciousTags];
    if (tags && [tags containsObject:tag]) {
      HGSLogDebug(@"DeliciousBookmarkSource keeping '%@' during pivot on '%@'.",
                  [result displayName], tag);
    }
    else {
      result = nil;
    }
  }
  return result;
}

- (HGSScoredResult *)postFilterScoredResult:(HGSScoredResult *)result 
                            matchesForQuery:(HGSQuery *)query
                               pivotObjects:(HGSResultArray *)pivotObjects {
  // If the query is empty, we must be pivoting - thus we boost the
  // rank of bookmarks that match the pivot to ensure they are displayed
  // (Anything that makes it to this method already matches the pivot)
  BOOL emptyQuery = [[query tokenizedQueryString] originalLength] == 0;
  if (emptyQuery) {
    CGFloat score = HGSCalibratedScore(kHGSCalibratedStrongScore);
    result = [HGSScoredResult resultWithResult:result
                                         score:score
                                    flagsToSet:0
                                  flagsToClear:0
                                   matchedTerm:[result matchedTerm]
                                matchedIndexes:[result matchedIndexes]];
  }
  
  return result;
}

#pragma mark Bookmarks Fetching

- (void)startAsynchronousBookmarkFetch:(NSString*)url
                              callback:(SEL)selector
                        waitIfFetching:(BOOL)shouldWait {
  HGSLogDebug(@"DeliciousBookmarks: Asked to fetch");
  HGSKeychainItem* keychainItem = [self keychainItem];
  NSString *userName = [keychainItem username];
  NSString *password = [keychainItem password];
  if ((!currentlyFetching_ || !shouldWait) && userName && password) {
    HGSLogDebug(@"DeliciousBookmarks: Going ahead with fetch");
    NSURL *bookmarkRequestURL = [NSURL URLWithString:url];
    NSMutableURLRequest *bookmarkRequest
      = [NSMutableURLRequest requestWithURL:bookmarkRequestURL 
                                cachePolicy:NSURLRequestReloadIgnoringCacheData 
                            timeoutInterval:15.0];
    [bookmarkRequest setValue: kDeliciousPluginUserAgent
           forHTTPHeaderField:@"User-Agent"];
    currentlyFetching_ = YES;
    currentCallback_ = selector;
    NSURLConnection *connection
      = [NSURLConnection connectionWithRequest:bookmarkRequest
                                      delegate:self];
    [self setConnection:connection];
  }
}

- (void)refreshBookmarks:(NSTimer *)timer {
  [self startAsynchronousBookmarkFetch:kDeliciousLastUpdateURL
                              callback:@selector(checkLastUpdate)
                        waitIfFetching:true];
}

- (void)checkLastUpdate {
  HGSLogDebug(@"DeliciousBookmarks: Checking last update time");
  NSXMLDocument* bookmarksXML
    = [[[NSXMLDocument alloc] initWithData:bookmarkData_
                                   options:0
                                     error:nil] autorelease];
  NSArray *updateNodes = [bookmarksXML nodesForXPath:@"//update" error:NULL];
  NSString *newLastUpdate = [[(NSXMLElement*)[updateNodes objectAtIndex:0]
                              attributeForName:@"time"] stringValue];

  BOOL upToDate = lastUpdate_ && [lastUpdate_ isEqualToString:newLastUpdate];
  [lastUpdate_ release];
  lastUpdate_ = [newLastUpdate retain];

  [bookmarkData_ release];
  bookmarkData_ = nil;

  if (!upToDate) {
    HGSLogDebug(@"DeliciousBookmarks: Out of date, need to refresh");
    [self startAsynchronousBookmarkFetch:kDeliciousAllBookmarksURL
                                callback:@selector(indexBookmarksFromData)
                          waitIfFetching:false];
  }
}

- (void)indexBookmarksFromData {
  HGSLogDebug(@"DeliciousBookmarks: Processing bookmark data");
  NSXMLDocument* bookmarksXML
    = [[[NSXMLDocument alloc] initWithData:bookmarkData_
                                   options:0
                                     error:nil] autorelease];
  NSArray *bookmarkNodes = [bookmarksXML nodesForXPath:@"//post" error:NULL];
  [self clearResultIndex];

  NSMutableSet *allTags = [NSMutableSet setWithCapacity:50];
  NSEnumerator *nodeEnumerator = [bookmarkNodes objectEnumerator];
  NSXMLElement *bookmark;
  while ((bookmark = [nodeEnumerator nextObject])) {
    HGSLogDebug(@"DeliciousBookmarks: Processing a bookmark");
    NSString *name = [[bookmark attributeForName: @"description"] stringValue];
    NSString *url  = [[bookmark attributeForName: @"href"] stringValue];
    NSString *tags = [[bookmark attributeForName: @"tag"] stringValue];

    if (!name || !url || !tags) {
      // Basic sanity check - the Delicious API is versioned at the URL level
      // and we hard-code the URLs, thus we always expect the same data format.
      // This just keeps us from blowing up if a response is 'strange'
      continue;
    }

    NSArray *tagArray = [tags componentsSeparatedByString:@" "];
    [allTags addObjectsFromArray:tagArray];
    [self indexResultForUrl:url
                      title:name
                       type:HGS_SUBTYPE(kHGSTypeWebBookmark, @"deliciousbookmarks")
                       tags:tagArray
                       icon:[NSImage imageNamed:@"blue-nav"]];
  }

  NSString *username = [[self keychainItem] username];
  for (NSString *tag in allTags) {
    NSString *url = [NSString stringWithFormat:@"http://delicious.com/%@/%@",
                     username, tag];
    [self indexResultForUrl:url
                      title:tag
                       type:HGS_SUBTYPE(kHGSTypeWebpage, @"delicioustag")
                       tags: nil
                       icon:tagIcon_];
  }

  currentlyFetching_ = NO;  
  [bookmarkData_ release];
  bookmarkData_ = nil;
}

- (void)indexResultForUrl:(NSString *)url
                    title:(NSString *)title
                     type:(NSString *)type
                     tags:(NSArray *)tags
                     icon:(NSImage*)iconImage {
  HGSLogDebug(@"DeliciousBookmarks: Indexing a bookmark");
  if (!url) {
    return;
  }

  NSNumber *rankFlags = [NSNumber numberWithUnsignedInt:eHGSUnderHomeRankFlag];
  NSMutableDictionary *attributes
    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
       rankFlags, kHGSObjectAttributeRankFlagsKey,
       url, kHGSObjectAttributeSourceURLKey,
       nil];

  if (tags) {
    [attributes setObject:tags forKey:kObjectAttributeDeliciousTags];
  }

  if (iconImage) {
    [attributes setObject:iconImage forKey:kHGSObjectAttributeIconKey];
  }

  HGSUnscoredResult* result 
    = [HGSUnscoredResult resultWithURL:[NSURL URLWithString:url]
                                  name:([title length] > 0 ? title : url)
                                  type:type
                                source:self
                            attributes:attributes];
  [self indexResult:result
               name:title
         otherTerms:tags];
  HGSLogDebug(@"DeliciousBookmarks: Done indexing a bookmark");
}

- (void)setConnection:(NSURLConnection *)connection {
  if (connection_ != connection) {
    [connection_ cancel];
    [connection_ release];
    connection_ = [connection retain];
  }
}

#pragma mark -
#pragma mark NSURLConnection Delegate Methods

- (void)connection:(NSURLConnection *)connection 
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
  HGSLogDebug(@"DeliciousBookmarks: Request was challenged");
  HGSAssert(connection == connection_, nil);
  HGSKeychainItem* keychainItem = [self keychainItem];
  NSString *userName = [keychainItem username];
  NSString *password = [keychainItem password];

  id<NSURLAuthenticationChallengeSender> sender = [challenge sender];
  NSInteger previousFailureCount = [challenge previousFailureCount];

  if (previousFailureCount > 3) {
    // Don't keep trying.
    [updateTimer_ invalidate];
    updateTimer_ = nil;
    NSString *errorFormat = HGSLocalizedString(@"Authentication for '%@' failed."
                                               @"Check your password.", nil);
    NSString *errorString = [NSString stringWithFormat:errorFormat, userName];
    [self reportConnectionFailure:errorString successCode:kHGSUserMessageNoteType];
    HGSLogDebug(@"DeliciousBookmarkSource authentication failure for account '%@'.",
                userName);
    return;
  }

  if (userName && password) {
    NSURLCredential *creds
      = [NSURLCredential credentialWithUser:userName
                                   password:password
                                persistence:NSURLCredentialPersistenceNone];
    [sender useCredential:creds forAuthenticationChallenge:challenge];
  } else {
    [sender continueWithoutCredentialForAuthenticationChallenge:challenge];
  }
}

- (void)connection:(NSURLConnection *)connection 
didReceiveResponse:(NSURLResponse *)response {
  HGSLogDebug(@"DeliciousBookmarks: Request got response");
  HGSAssert(connection == connection_, nil);
  [bookmarkData_ release];
  bookmarkData_ = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection 
    didReceiveData:(NSData *)data {
  HGSLogDebug(@"DeliciousBookmarks: Request got data");
  HGSAssert(connection == connection_, nil);
  [bookmarkData_ appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  HGSLogDebug(@"DeliciousBookmarks: Request finished, time to dispatch");
  HGSAssert(connection == connection_, nil);
  [self setConnection:nil];
  [self performSelector:currentCallback_];
}

- (void)connection:(NSURLConnection *)connection 
  didFailWithError:(NSError *)error {
  HGSLogDebug(@"DeliciousBookmarks: Request failed");
  HGSAssert(connection == connection_, nil);
  [self setConnection:nil];
  currentlyFetching_ = NO;
  [bookmarkData_ release];
  bookmarkData_ = nil;
  HGSKeychainItem* keychainItem = [self keychainItem];
  NSString *userName = [keychainItem username];
  NSString *errorFormat = HGSLocalizedString(@"Fetch for '%@' failed. (%d)", nil);
  NSString *errorString = [NSString stringWithFormat:errorFormat,
                           userName, [error code]];
  [self reportConnectionFailure:errorString successCode:kHGSUserMessageErrorType];
  HGSLogDebug(@"DeliciousBookmarkSource connection failure (%d) '%@'.",
              [error code], [error localizedDescription]);
}

#pragma mark Authentication & Refresh

- (void)loginCredentialsChanged:(NSNotification *)notification {
  HGSAccount* account = [notification object];
  HGSAssert(account == account_, @"Notification from bad account!");
  // Make sure we aren't in the middle of waiting for results; if we are, try
  // again later instead of changing things in the middle of the fetch.
  if (currentlyFetching_) {
    [self performSelector:@selector(loginCredentialsChanged:)
               withObject:notification
               afterDelay:60.0];
    return;
  }
  // If the login changes, we should update immediately, and make sure the
  // periodic refresh is enabled (it would have been shut down if the previous
  // credentials were incorrect).
  [self startAsynchronousBookmarkFetch:kDeliciousLastUpdateURL
                              callback:@selector(checkLastUpdate)
                        waitIfFetching:true];
  [self setUpPeriodicRefresh];
}

- (void)reportConnectionFailure:(NSString *)explanation
                    successCode:(NSInteger)successCode {
  NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
  NSTimeInterval timeSinceLastErrorReport = currentTime - previousErrorReportingTime_;
  if (timeSinceLastErrorReport > kDeliciousErrorReportingInterval) {
    previousErrorReportingTime_ = currentTime;
    HGSUserMessenger *messenger = [HGSUserMessenger sharedUserMessenger];
    NSString *errorSummary = HGSLocalizedString(@"Delicious Bookmarks", nil);
    [messenger displayUserMessage:errorSummary 
                      description:explanation 
                             name:@"DeliciousBookmarksSource" 
                            image:nil
                             type:successCode];
  }
}

- (void)setUpPeriodicRefresh {
  // Kick off a timer if one is not already running.
  if (!updateTimer_) {
    updateTimer_
      = [NSTimer scheduledTimerWithTimeInterval:kDeliciousRefreshSeconds
                                         target:self
                                       selector:@selector(refreshBookmarks:)
                                       userInfo:nil
                                        repeats:YES];
  }
}

- (HGSKeychainItem *)keychainItem {
  return [HGSKeychainItem keychainItemForService:[account_ identifier]
                                        username:nil];
}

#pragma mark -
#pragma mark HGSAccountClientProtocol Methods

- (BOOL)accountWillBeRemoved:(HGSAccount*)account {
  HGSAssert(account == account_, @"Notification from bad account!");
  return YES;
}

@end
