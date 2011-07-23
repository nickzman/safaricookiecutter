//
//  SCCControl.h
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

#import <Cocoa/Cocoa.h>

// Define menu tags. Used by -validateMenuItem: primarily...
#define AddCookieMenuTag	56000
#define DeleteCookieMenuTag	56001

// Define toolbar constants.
#define SCCToolbarIdentifier			@"SCCToolbar"
#define SCCToolbarAddCookieIdentifier 		@"SCCToolbarAddCookie"
#define SCCToolbarDeleteCookieIdentifier	@"SCCToolbarDeleteCookie"

// This is the minimum version of Foundation that has WebKit support present.
#define SCCFoundationWithWebKitVersionNumber 462.1

@class SCCCookies;

@interface SCCControl : NSObject <NSToolbarDelegate>
{
    // Classes we use in this class
    SCCCookies *cookies;

    // IB outlets we use...
    IBOutlet NSTableView *tvCookies;
    IBOutlet NSWindow *wndMainWindow;

    // Sorting
    NSImage *triangleForTV;
    NSImage *reverseTriangleForTV;
    NSString *sortedColumnIdentifier;
    BOOL isSortedAscending;

    // Problem workaround for NSTableView (see NSTableView data source for details)
    BOOL isReloading;
}
// IB actions
- (IBAction)addCookie:(id)sender;
- (IBAction)deleteCookie:(id)sender;

@end
