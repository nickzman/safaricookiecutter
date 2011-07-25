//
//  SCCControl.m
//  SafariCookieCutter
//
//  Created by Nick Zitzmann on Sat Jul 12 2003.
//  Copyright (c) 2003 Nick Zitzmann. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SCCControl.h"
#import "SCCCookies.h"
#import "SCCDomainStringFormatter.h"

@interface SCCControl (Private)
- (void)setSortedColumn:(NSTableColumn *)tableColumn;
- (void)updateUI;
@end

@implementation SCCControl

#pragma mark Initialization/Uninitialization

- (id)init
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    self = [super init];

    // Load in those cookies.
    if (NSFoundationVersionNumber >= floor(SCCFoundationWithWebKitVersionNumber))
    {
        cookies = [[SCCCookies alloc] init];
    }
    else
    {
        cookies = nil;
    }
    
    // Initialize the stuff necessary for sorting.
    triangleForTV = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"TableViewTriangle" ofType:@"tiff"]];
    reverseTriangleForTV = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"TableViewTriangle" ofType:@"tiff"]];
    [triangleForTV setFlipped:YES];

    // Load in some user defaults.
    if ([defaults objectForKey:@"SCCSortedColumnID"] == nil)
    {
        if (NSFoundationVersionNumber < floor(SCCFoundationWithWebKitVersionNumber))
        {
            // User is using a version of Foundation that doesn't have NSHTTPCookieDomain etc. We're going to have to quit early later on, but for right now, stuff some dummy value in sortedColumnIdentifier so we don't crash...
            sortedColumnIdentifier = @"dummy";
        }
        else
        {
            sortedColumnIdentifier = NSHTTPCookieDomain;
        }
    }
    else
    {
        sortedColumnIdentifier = [[defaults objectForKey:@"SCCSortedColumnID"] retain];
    }

    if ([defaults objectForKey:@"SCCIsSortedAscending"] == nil)
    {
        isSortedAscending = YES;
    }
    else
    {
        isSortedAscending = [defaults boolForKey:@"SCCIsSortedAscending"];
    }
    isReloading = NO;
    
    return self;
}


- (void)dealloc
{
    [cookies release];
    [triangleForTV release];
    [reverseTriangleForTV release];
    [super dealloc];
}


- (void)awakeFromNib
{
    NSToolbar *mainToolbar = [[NSToolbar alloc] initWithIdentifier:SCCToolbarIdentifier];
    NSDateFormatter *expiresDateFormatter = [[NSDateFormatter alloc] init];
    NSTableColumn *columnToSelect = [tvCookies tableColumnWithIdentifier:sortedColumnIdentifier];

    [expiresDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[expiresDateFormatter setDateStyle:NSDateFormatterShortStyle];
	[expiresDateFormatter setTimeStyle:NSDateFormatterShortStyle];

    // Make sure the cookies got loaded. If they didn't, it's probably because the user is using an older version of Foundation that doesn't have NSHTTPCookie present...
    if (cookies == nil)
    {
        NSRunAlertPanel(NSLocalizedString(@"Safari is not installed.", @"Safari is not installed."), NSLocalizedString(@"Safari version 1.0 or later must be installed for SafariCookieCutter to work. Please install Safari 1.0 or later and try again.", @"Safari is not installed (long)"), NSLocalizedString(@"Quit", @"Quit"), nil, nil);
        [NSApp terminate:self];
    }

    // Set up the table columns to use Apple's identifiers and not ours.
    [[tvCookies tableColumnWithIdentifier:@"Domain"] setIdentifier:NSHTTPCookieDomain];
    [[tvCookies tableColumnWithIdentifier:@"Expires"] setIdentifier:NSHTTPCookieExpires];
    [[tvCookies tableColumnWithIdentifier:@"Name"] setIdentifier:NSHTTPCookieName];
    [[tvCookies tableColumnWithIdentifier:@"Path"] setIdentifier:NSHTTPCookiePath];
    [[tvCookies tableColumnWithIdentifier:@"Value"] setIdentifier:NSHTTPCookieValue];

    // Set up the formatters...
    [[[tvCookies tableColumnWithIdentifier:NSHTTPCookieExpires] dataCell] setFormatter:expiresDateFormatter];	// formatter for Expires column, needs to be equal to the user's date format
    [[[tvCookies tableColumnWithIdentifier:NSHTTPCookieDomain] dataCell] setFormatter:[[SCCDomainStringFormatter alloc] init]];	// formatter for the Domain column, needs to filter out URL token characters, since NSHTTPCookieStorage likes to eat cookies with token characters in the domain
    
    // Check to see if everything else loaded OK.
    if (triangleForTV == nil)
    {
        NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), NSLocalizedString(@"Couldn't load the resource file \"%@\". Please reinstall SafariCookieCutter.", @"Couldn't load a resource"), NSLocalizedString(@"Quit", @"Quit"), nil, nil, @"TableViewTriangle.tiff");
        [NSApp terminate:self];
    }

    // Set up sorting now; this will also update the UI and table view...
    if (columnToSelect != nil)
    {
        [self setSortedColumn:columnToSelect];
    }
    else
    {
        [self setSortedColumn:[tvCookies tableColumnWithIdentifier:NSHTTPCookieDomain]];	// revert to defaults if columnToSelect is nil
    }
    [self performSelector:@selector(policyDidChange:) withObject:nil];	// set up whether the user can edit the cookies or not

    // Set up our wonderful toolbar.
    [mainToolbar setAllowsUserCustomization:YES];
    [mainToolbar setAutosavesConfiguration:YES];
    [mainToolbar setDisplayMode:NSToolbarDisplayModeDefault];
    [mainToolbar setDelegate:self];
    [wndMainWindow setToolbar:mainToolbar];
    [mainToolbar release];

    // Workaround for a really annoying bug in keyed archiving and NSTableViews.
    [tvCookies setAutosaveName:@"tvCookies"];
    [tvCookies setAutosaveTableColumns:YES];

    // Public beta expiration...
    /*if ([(NSDate *)[NSDate date] compare:[NSDate dateWithString:@"2003-04-01 00:00:00 +0600"]] == NSOrderedDescending)
    {
        // The program's expired
        if (NSRunAlertPanel(@"This beta has expired.", @"This beta version of SafariCookieCutter has expired. Please go to the SCC home page and download a new version.", NSLocalizedString(@"Quit", @"Quit"), @"Visit the SCC home page", nil) == NSAlertAlternateReturn)
        {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://dreamless.home.attbi.com/scc.html"]];
        }
        [NSApp terminate:self];
    }*/

    // Oh, and one more thing...
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(helperCookiesDidChange:) name:SCCCookiesDidChangeNotification object:cookies];	// ...set up our notification so we know when the cookies were changed
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(policyDidChange:) name:NSHTTPCookieManagerAcceptPolicyChangedNotification object:nil];	// and we need to stay current on the policy, too...
}


#pragma mark NSApplication Delegate Methods


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // Save some of our user defaults now.
    [defaults setObject:sortedColumnIdentifier forKey:@"SCCSortedColumnID"];
    [defaults setBool:isSortedAscending forKey:@"SCCIsSortedAscending"];
    // There's more, like the window, etc. but we let Cocoa take care of that.
}


#pragma mark NSTableView Delegate Methods


- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
    // Is this the same row that the user last selected?
    if ([sortedColumnIdentifier isEqual:[tableColumn identifier]] == YES)
    {
        // If so, we reverse the sorting order.
        isSortedAscending = !isSortedAscending;
    }
    else
    {
        // If not, we update sortedColumnIdentifier.
        [sortedColumnIdentifier release];
        sortedColumnIdentifier = [[tableColumn identifier] retain];
    }
    [self setSortedColumn:tableColumn];
}


#pragma mark NSToolbar Delegate Methods


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:SCCToolbarAddCookieIdentifier, SCCToolbarDeleteCookieIdentifier, nil];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:SCCToolbarAddCookieIdentifier, SCCToolbarDeleteCookieIdentifier, nil];
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)willBeInserted
{
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdent];

    [toolbarItem autorelease];	// we don't need it after this
    if ([itemIdent isEqual:SCCToolbarAddCookieIdentifier])
    {
        // Set up the add cookie item.
        [toolbarItem setLabel:NSLocalizedString(@"Add Cookie", @"Add Cookie")];
        [toolbarItem setImage:[NSImage imageNamed:@"AddCookie"]];
        [toolbarItem setTarget:self];
        [toolbarItem setAction:@selector(addCookie:)];
    }
    else if ([itemIdent isEqual:SCCToolbarDeleteCookieIdentifier])
    {
        // Set up the delete cookie item.
        [toolbarItem setLabel:NSLocalizedString(@"Delete Cookie", @"Delete Cookie")];
        [toolbarItem setImage:[NSImage imageNamed:@"DeleteCookie"]];
        [toolbarItem setTarget:self];
        [toolbarItem setAction:@selector(deleteCookie:)];
    }
    else
    {
        // It's not something we recognize...
        return nil;
    }

    // toolbarItem is now properly configured, whatever it is, so return it.
    return toolbarItem;
}


#pragma mark Notifications


- (void)helperCookiesDidChange:(NSNotification *)aNotification
{
    // All we do when the cookies change is update our UI...
    [self updateUI];
}


- (void)policyDidChange:(NSNotification *)aNotification
{
    NSHTTPCookieAcceptPolicy newPolicy = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookieAcceptPolicy];
    NSEnumerator *tableEnum = [[tvCookies tableColumns] objectEnumerator];
    id column;

    // Depending on the user's policy settings, we either turn editing off (if the policy was set to "never") or on (if otherwise).
    while ((column = [tableEnum nextObject]) != nil)
    {
        [column setEditable:(newPolicy != NSHTTPCookieAcceptPolicyNever)];
    }
}


#pragma mark NSTableView Data Source


- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [cookies count];
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)aRow
{
    NSDictionary *tempDict = [[cookies cookieAtIndex:aRow] properties];

    // All we need to do is return the object at the row...
    return [tempDict objectForKey:[aTableColumn identifier]];
}


- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)aRow
{
    if (isReloading == NO)	// workaround for a "problem" with NSTableView where sometimes, if -reloadData is called right after this, then the method will be called twice, thus breaking the undo invocation...
    {
        NSHTTPCookie *theCookie = [cookies cookieAtIndex:aRow];	// this is the object that will be updated
        NSMutableDictionary *cookieProperties = [[[theCookie properties] mutableCopy] autorelease];
        NSUndoManager *undoManager = [[wndMainWindow firstResponder] undoManager];
        NSString *columnIdentifier = [aTableColumn identifier];

        if ([[NSHTTPCookieStorage sharedHTTPCookieStorage] cookieAcceptPolicy] == NSHTTPCookieAcceptPolicyNever)
        {
            return;	// don't edit the cookie if we can't; this shouldn't be reached, but if it is, we're ready
        }

        // If the object wasn't changed, then we skip it.
        if ([anObject isEqual:[cookieProperties objectForKey:columnIdentifier]] == NO)
        {
            id objectValue = [cookieProperties objectForKey:[aTableColumn identifier]];	// the existing object that's going to get modified

            // Prepare to undo this if necessary.
            [[undoManager prepareWithInvocationTarget:self] tableView:aTableView setObjectValue:objectValue forTableColumn:aTableColumn row:aRow];
            [undoManager setActionName:NSLocalizedString(@"Edit Cookie", @"Undo Edit Cookie (for undo manager)")];

            // Update the cookie properties...
            if ([columnIdentifier isEqualToString:NSHTTPCookieExpires])
            {
                if (anObject == nil)	// if the Expires column is blank
                {
                    // In this case, delete the Expires key and make the cookie expire at the end of the session.
                    [cookieProperties removeObjectForKey:NSHTTPCookieExpires];
                    //[cookieProperties setObject:@"TRUE" forKey:NSHTTPCookieDiscard];
                }
                else	// if the Expires column is not blank
                {
                    // In this case, set the Expires key and make sure the cookie doesn't expire at the end of the session.
                    [cookieProperties setObject:anObject forKey:NSHTTPCookieExpires];
                    //[cookieProperties setObject:@"FALSE" forKey:NSHTTPCookieDiscard];
                }
            }
            else	// or else just do a normal update
            {
                [cookieProperties setObject:anObject forKey:columnIdentifier];
            }
            // Remove the old cookie...
            [cookies removeCookie:theCookie];
            // Then add a new cookie with the new attributes...
            [cookies addCookie:[NSHTTPCookie cookieWithProperties:cookieProperties]];
            // I wish there was such a thing as an NSMutableHTTPCookie class, but at the time of this writing there isn't...
        }
    }
}


#pragma mark IB Actions


- (IBAction)addCookie:(id)sender
{
    NSUndoManager *undoManager = [[wndMainWindow firstResponder] undoManager];
    NSArray *cookieKeys = [NSArray arrayWithObjects:NSHTTPCookieDomain, NSHTTPCookieExpires, NSHTTPCookieName, NSHTTPCookiePath, NSHTTPCookieValue, NSHTTPCookieVersion, nil];
    NSArray *cookieObjects = [NSArray arrayWithObjects:@"www.somewhere.com", [NSDate distantFuture], @"name-me", @"/", @"value", @"0", nil];
    NSDictionary *cookieToAddProperties = [NSDictionary dictionaryWithObjects:cookieObjects forKeys:cookieKeys];
    NSHTTPCookie *cookieToAdd = [NSHTTPCookie cookieWithProperties:cookieToAddProperties];

    // Here's how we can undo this...
    [undoManager registerUndoWithTarget:self selector:@selector(removeCookieUndoManagerWrapper:) object:[NSArray arrayWithObject:cookieToAdd]];
    [undoManager setActionName:NSLocalizedString(@"Add Cookie", @"Add Cookie")];

    // Add the cookie into the array, then update.
    [cookies addCookie:cookieToAdd];

    // Show it to the user.
	[tvCookies selectRowIndexes:[NSIndexSet indexSetWithIndex:[cookies indexOfCookie:cookieToAdd]] byExtendingSelection:NO];
    [tvCookies scrollRowToVisible:[tvCookies selectedRow]];
}


- (IBAction)deleteCookie:(id)sender
{
    NSUndoManager *undoManager = [[wndMainWindow firstResponder] undoManager];
    NSIndexSet *selectedRows;
    NSUInteger currentCookieInEnumerator;
    NSMutableArray *cookiesToDeleteArray = [NSMutableArray array];
    
    // Sanity check: Is there anything selected?
    if ([tvCookies selectedRow] < 0)
    {
        return;	// guess not...
    }
    selectedRows = [tvCookies selectedRowIndexes];	// otherwise we see what cookies we need to delete

    // Get all of the cookies to delete and put them into cookiesToDeleteArray.
	currentCookieInEnumerator = [selectedRows firstIndex];
	while (currentCookieInEnumerator != NSNotFound)
	{
        [cookiesToDeleteArray addObject:[cookies cookieAtIndex:currentCookieInEnumerator]];
		currentCookieInEnumerator = [selectedRows indexGreaterThanIndex:currentCookieInEnumerator];
    }
    
    // Now let's get ready to undo this...
    [undoManager registerUndoWithTarget:self selector:@selector(addCookieUndoManagerWrapper:) object:[[cookiesToDeleteArray copy] autorelease]];
    [undoManager setActionName:NSLocalizedString(@"Delete Cookie(s)", @"Delete Cookie(s)")];

    // OK, now delete them all.
    [cookies removeCookies:cookiesToDeleteArray];
    
    [tvCookies deselectAll:self];	// unselect what was selected
}


#pragma mark Wrappers for Undo Support


- (void)addCookieUndoManagerWrapper:(NSArray *)cookiesArray
{
    NSUndoManager *undoManager = [[wndMainWindow firstResponder] undoManager];

    // Prepare undo/redo...
    [undoManager registerUndoWithTarget:self selector:@selector(removeCookieUndoManagerWrapper:) object:[[cookiesArray copy] autorelease]];
    // Then add each cookie...
    [cookies addCookies:cookiesArray];
}


- (void)removeCookieUndoManagerWrapper:(NSArray *)cookiesArray
{
    NSUndoManager *undoManager = [[wndMainWindow firstResponder] undoManager];

    // Prepare undo/redo...
    [undoManager registerUndoWithTarget:self selector:@selector(addCookieUndoManagerWrapper:) object:[[cookiesArray copy] autorelease]];
    // Then remove each cookie...
    [cookies removeCookies:cookiesArray];
}


#pragma mark Validation


- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    // I prefer switching on tags because it performs better than actions...
    switch ([item tag])
    {
        case AddCookieMenuTag:
            // Don't turn this on if the domain is set to "never".
            return ([[NSHTTPCookieStorage sharedHTTPCookieStorage] cookieAcceptPolicy] != NSHTTPCookieAcceptPolicyNever);
            break;

        case DeleteCookieMenuTag:
            // Turn this off if nothing's selected.
            if ([tvCookies selectedRow] == -1)
            {
                return NO;
            }
            break;
    }
    // Anything else is on by default...
    return YES;
}


- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
    if ([[item itemIdentifier] isEqual:SCCToolbarAddCookieIdentifier])
    {
        // Don't turn this on if the domain is set to "never".
        return ([[NSHTTPCookieStorage sharedHTTPCookieStorage] cookieAcceptPolicy] != NSHTTPCookieAcceptPolicyNever);
    }
    else if ([[item itemIdentifier] isEqual:SCCToolbarDeleteCookieIdentifier])
    {
        // Turn the cookie delete toolbar item off if there's nothing selected...
        if ([tvCookies selectedRow] == -1)
        {
            return NO;
        }
    }
    // Otherwise, we turn it on...
    return YES;
}

@end

@implementation SCCControl (Private)

- (void)setSortedColumn:(NSTableColumn *)tableColumn
{
    NSEnumerator *tableEnum = [[tvCookies tableColumns] objectEnumerator];
    id column;
    NSImage *sortImage = isSortedAscending ? reverseTriangleForTV : triangleForTV;

    // Turn off all the table indicator images for now.
    while ((column = [tableEnum nextObject]) != nil)
    {
        [tvCookies setIndicatorImage:nil inTableColumn:column];
    }
    // Set the highlighted table column to selectedTableColumn.
    [tvCookies setHighlightedTableColumn:tableColumn];
    // Turn on our table indicator just for the row the user has selected.
    [tvCookies setIndicatorImage:sortImage inTableColumn:tableColumn];
    // Call -updateUI so the user sees all the changes we made.
    [self updateUI];
}


- (void)updateUI
{
    // Make sure the table column for sortedColumnIdentifier actually exists...
    if ([tvCookies tableColumnWithIdentifier:sortedColumnIdentifier] != nil)
    {
        // If it does, then we sort here.
        [cookies sortWithKey:sortedColumnIdentifier ascending:isSortedAscending];
    }
    else
    {
        // This shouldn't happen, but just in case it does, we're prepared... Revert to the default selected column.
        [self setSortedColumn:[tvCookies tableColumnWithIdentifier:NSHTTPCookieDomain]];
    }

    // Reload! Reload!
    isReloading = YES;
    [tvCookies reloadData];
    isReloading = NO;
    // Make sure the table view is always the first responder...
    [wndMainWindow makeFirstResponder:tvCookies];
}

@end