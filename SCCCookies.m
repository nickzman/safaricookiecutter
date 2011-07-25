//
//  SCCCookies.m
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

#import "SCCCookies.h"
#import "SCCSortSupport.h"
#import <sys/event.h>

NSString *SCCCookiesDidChangeNotification = @"SCCCookiesDidChangeNotification";

@implementation SCCCookies

#pragma mark Init & Dealloc

- (id)init
{
    self = [super init];
	if (self)
	{
		SInt32 osVersion;
		
		Gestalt(gestaltSystemVersion, &osVersion);
		
		cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
		cookieArray = [[cookieJar cookies] mutableCopy];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cookiesDidChange:) name:NSHTTPCookieManagerCookiesChangedNotification object:nil];	// so we are told when someone changes the cookies
		if (osVersion >= 0x1070)
			[NSThread detachNewThreadSelector:@selector(threadedWatchCookies) toTarget:self withObject:nil];
		else
		{
			NSString *dcsNotificationName = [NSString stringWithFormat:@"[DiskCookieStorage %@/Library/Cookies/Cookies.plist]", NSHomeDirectory()];
			
			[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(cookiesDidChange:) name:dcsNotificationName object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
		}
	}
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [cookieArray release];
    [super dealloc];
}


- (void)threadedWatchCookies
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	int kQueue = kqueue();
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSURL *userLibraryURL = [fm URLForDirectory:NSLibraryDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
	NSURL *cookiesURL = [[[userLibraryURL URLByAppendingPathComponent:@"Cookies"] URLByAppendingPathComponent:@"Cookies.binarycookies"] retain];
	
	[pool drain];
	while (1)	// loop forever
	{
		@try
		{
			struct kevent kEvent, theEvent;
			int fd, numTries = 0;
			
			pool = [[NSAutoreleasePool alloc] init];
			do	// we want to watch ~/Library/Cookies/Cookies.binarycookies
			{
				fd = open(cookiesURL.path.fileSystemRepresentation, O_EVTONLY, 0);
				if (fd == 0)
				{
					sleep(1);
					numTries++;
				}
			} while (fd == 0 && numTries < 10);	// keep trying until it works
			if (numTries >= 10)
			{
				NSLog(@"Tried looking for ~/Library/Cookies/Cookies.binarycookies ten times and it wasn't there. Giving up.");
				[fm release];
				[cookiesURL release];
				[pool drain];
				return;
			}
			
			EV_SET(&kEvent, fd, EVFILT_VNODE, EV_ADD|EV_ENABLE|EV_CLEAR, NOTE_WRITE|NOTE_DELETE, 0, 0);
			kevent(kQueue, &kEvent, 1, NULL, 0, NULL);	// watch for changes to this file
			kevent(kQueue, NULL, 0, &theEvent, 1, NULL);	// block here until a change has been made
			[self performSelectorOnMainThread:@selector(cookiesDidChange:) withObject:nil waitUntilDone:YES];
			close(fd);	// clean up
		}
		@catch (NSException *exception)
		{
			NSLog(@"%@", exception);
		}
		@finally
		{
			[pool drain];
		}
	}
}


#pragma mark Cookie Control


- (void)addCookie:(NSHTTPCookie *)cookie
{
	SInt32 osVersion;
	
	Gestalt(gestaltSystemVersion, &osVersion);
    [cookieJar setCookie:cookie];
    // cookiesDidChange: will be called when this is done, so there's no need to update cookieArray...
	// ...except in Tiger, where -cookiesDidChange: is called on the next cycle through the run loop, which is not what we want to happen (we need to bring things up to date right now).
	if (osVersion >= 0x1039)
		[self performSelector:@selector(cookiesDidChange:) withObject:nil];
}


- (void)addCookies:(NSArray *)cookies
{
    NSEnumerator *cookieEnumerator = [cookies objectEnumerator];
    NSHTTPCookie *currentCookie;

    // This isn't an optimal way of adding multiple cookies, since -cookiesDidChange: is going to be called once for each cookie we add. NSHTTPCookieStorage does appear to have a method for adding an array of cookies, but it requires URLs that we don't have...
    while (currentCookie = [cookieEnumerator nextObject])
    {
        [self addCookie:currentCookie];
    }
}


- (NSHTTPCookie *)cookieAtIndex:(NSUInteger)index
{
    return (NSHTTPCookie *)[cookieArray objectAtIndex:index];
}


- (NSUInteger)count
{
    return [cookieArray count];
}


- (NSUInteger)indexOfCookie:(NSHTTPCookie *)cookie
{
    NSDictionary *propertiesToCheck;
    NSDictionary *cookieProperties = [cookie properties];
    const NSUInteger cookieArrayCount = [cookieArray count];
    NSUInteger i;

    // We have to search the array manually...
    for (i = 0 ; i < cookieArrayCount ; i++)
    {
        propertiesToCheck = [[cookieArray objectAtIndex:i] properties];
        if ([cookieProperties isEqualToDictionary:propertiesToCheck])
        {
            return i;	// at this point, i is the correct index number
        }
    }

    return NSNotFound;	// if the cookie couldn't be found...
}


- (void)removeCookie:(NSHTTPCookie *)cookie
{
    [cookieJar deleteCookie:cookie];
    // Again, cookiesDidChange: will be called in the above step...
}


/*- (void)removeCookieAtIndex:(unsigned)index
{
    NSHTTPCookie *cookieToRemove = [cookieArray objectAtIndex:index];

    [cookieJar deleteCookie:cookieToRemove];
}*/


- (void)removeCookies:(NSArray *)cookies
{
    NSHTTPCookie *currentCookie;
    NSEnumerator *cookiesToDeleteEnumerator = [cookies objectEnumerator];

    // This is not an optimal way of doing this, as -cookiesDidChange: is going to be called once for every cookie we remove, and if the user just deleted a lot of cookies, then that will suck the CPU dry on some older Macs. Unfortunately, NSHTTPCookieStorage has no methods for mass-removal of cookies, so we don't have any choice here...
    while (currentCookie = [cookiesToDeleteEnumerator nextObject])
    {
        [self removeCookie:currentCookie];
    }
}


#pragma mark Sorting


- (void)sortWithKey:(NSString *)key ascending:(BOOL)sortUp;
{
    // Just sort the array...
    [cookieArray sortUsingFunction:(sortUp ? compareDicts : compareDictsBackwards) context:key];
}


#pragma mark Notifications


- (void)cookiesDidChange:(NSNotification *)aNotification
{
#ifdef DEBUG
	NSLog(@"Cookies changed, reloading...");
#endif
    // Whenever a cookie is changed, by us or someone else (Safari, etc.), update our local store.
    //[cookieArray autorelease];
    [cookieArray release];
    cookieArray = [[cookieJar cookies] mutableCopy];

    // Let the controller know that it's time to update...
    [[NSNotificationCenter defaultCenter] postNotificationName:SCCCookiesDidChangeNotification object:self];
}

@end
