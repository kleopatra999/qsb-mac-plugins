#import <Vermilion/HGSKeychainItem.h>
#import "DeliciousConstants.h"
#import "DeliciousFetcherSource.h"
#import "DeliciousReceiver.h"

static const NSTimeInterval kDeliciousRefreshSeconds = 3600.0;  // 60 minutes.

// Only report errors to user once an hour.
static const NSTimeInterval kDeliciousErrorReportingInterval = 3600.0;  // 1 hour

@interface DeliciousBookmarksSource : HGSMemorySearchSource <HGSAccountClientProtocol, DeliciousReceiver> {
 @private
  NSTimer *updateTimer_;
  NSMutableData *bookmarkData_;
  NSString *lastUpdate_;
  HGSSimpleAccount *account_;
  DeliciousFetcher *fetcher_;
  BOOL currentlyFetching_;
  SEL currentCallback_;
  NSTimeInterval previousErrorReportingTime_;
  NSImage *tagIcon_;
}

@property (nonatomic, retain) DeliciousFetcher *fetcher;

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
                     icon:(NSImage*)iconImage
                 database:(HGSMemorySearchSourceDB *)database;

// Post user notification about a connection failure.
- (void)reportConnectionFailure:(NSString *)explanation
                    successCode:(NSInteger)successCode;
- (void)loginCredentialsChanged:(NSNotification *)notification;

@end

@implementation DeliciousBookmarksSource

@synthesize fetcher = fetcher_;

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
      [self setUpPeriodicRefresh];
      [self startAsynchronousBookmarkFetch:kDeliciousLastUpdateURL
                                  callback:@selector(checkLastUpdate)
                            waitIfFetching:true];
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
                  pivotObjects:(HGSResultArray *)pivotObjects {
  // For the time being, only worry about handling a single pivot
  if ([pivotObjects count] == 1) {
    HGSResult *pivotObject = [pivotObjects objectAtIndex:0];
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
    currentlyFetching_ = YES;
    currentCallback_ = selector;
    id<DeliciousFetcherSource> dfs = (id<DeliciousFetcherSource>)account_;
    DeliciousFetcher *fetcher = [dfs fetcherForUrl: url
                                  withKeychainItem: keychainItem
                                         userAgent: kDeliciousPluginUserAgent
                                          receiver: self];
    
    // The fetcher may be async, or it may be synchronous and already done
    // Only store it if we are still in-flight
    if (currentlyFetching_) {
      [self setFetcher:fetcher];
    }
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

  HGSMemorySearchSourceDB *db = [HGSMemorySearchSourceDB database];
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
                       icon:[NSImage imageNamed:@"blue-nav"]
                   database:db];
  }

  NSString *username = [[self keychainItem] username];
  for (NSString *tag in allTags) {
    NSString *url = [NSString stringWithFormat:@"http://delicious.com/%@/%@",
                     username, tag];
    [self indexResultForUrl:url
                      title:tag
                       type:HGS_SUBTYPE(kHGSTypeWebpage, @"delicioustag")
                       tags: nil
                       icon:tagIcon_
                   database:db];
  }
  [self replaceCurrentDatabaseWith:db];
  currentlyFetching_ = NO;
  [bookmarkData_ release];
  bookmarkData_ = nil;
}

- (void)indexResultForUrl:(NSString *)url
                    title:(NSString *)title
                     type:(NSString *)type
                     tags:(NSArray *)tags
                     icon:(NSImage*)iconImage
                 database:(HGSMemorySearchSourceDB *)database {
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
  [database indexResult:result
                   name:title
             otherTerms:tags];
  HGSLogDebug(@"DeliciousBookmarks: Done indexing a bookmark");
}

- (void)setFetcher:(DeliciousFetcher *)fetcher {
  if (fetcher_ != fetcher) {
    [fetcher_ cancel];
    [fetcher_ release];
    fetcher_ = [fetcher retain];
  }
}

#pragma mark -
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
  [self setUpPeriodicRefresh];
  [self startAsynchronousBookmarkFetch:kDeliciousLastUpdateURL
                              callback:@selector(checkLastUpdate)
                        waitIfFetching:true];
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
#pragma mark DeliciousReceiver Methods

- (void)authenticationFailed {
  currentlyFetching_ = NO;
  [updateTimer_ invalidate];
  updateTimer_ = nil;
  NSString *errorFormat = HGSLocalizedString(@"Authentication for '%@' failed."
                                             @"Check your password.", nil);
  NSString *userName = [[self keychainItem] username];
  NSString *errorString = [NSString stringWithFormat:errorFormat, userName];
  [self reportConnectionFailure:errorString successCode:kHGSUserMessageNoteType];
  HGSLogDebug(@"DeliciousBookmarkSource authentication failure for account '%@'.",
              userName);
}

-(void) fetchComplete:(NSData *)data {
  bookmarkData_ = [data retain];
  [self performSelector:currentCallback_];
}

-(void) fetchFailed:(NSError *)error {
  currentlyFetching_ = NO;
  HGSKeychainItem* keychainItem = [self keychainItem];
  NSString *userName = [keychainItem username];
  NSString *errorFormat = HGSLocalizedString(@"Fetch for '%@' failed. (%d)", nil);
  NSString *errorString = [NSString stringWithFormat:errorFormat,
                           userName, [error code]];
  [self reportConnectionFailure:errorString successCode:kHGSUserMessageErrorType];
  HGSLogDebug(@"DeliciousBookmarkSource connection failure (%d) '%@'.",
              [error code], [error localizedDescription]);
  
}

#pragma mark -
#pragma mark HGSAccountClientProtocol Methods

- (BOOL)accountWillBeRemoved:(HGSAccount*)account {
  HGSAssert(account == account_, @"Notification from bad account!");
  return YES;
}

@end
