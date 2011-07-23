//
//  SCCSortSupport.m
//  SafariCookieCutter
//
//  Created by Nick Zitzmann on Mon Feb 03 2003.
//  Copyright (c) 2003 Nick Zitzmann. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SCCSortSupport.h"

NSComparisonResult compareDicts(NSHTTPCookie *cookie1, NSHTTPCookie *cookie2, void *context)
{
    NSString *key = (NSString *)context;
    NSDictionary *dict1 = [cookie1 properties];
    NSDictionary *dict2 = [cookie2 properties];

    // We branch here depending on whether we're doing strings or dates.
    if ([[dict1 objectForKey:key] isKindOfClass:[NSString class]] == YES)
    {
        NSString *string1 = [dict1 objectForKey:key];
        NSString *string2 = [dict2 objectForKey:key];
        // This is going to be called really, really often, so make it simple...
        NSComparisonResult stringComparison = [string1 compare:string2];

        // Check to see if we don't have to use some sort of other criteria...
        if (stringComparison != NSOrderedSame)
        {
            return stringComparison;
        }
        else
        {
            // If they're the same, then we compare their dates (Expires key).
            NSDate *dateAlt1 = [dict1 objectForKey:@"Expires"];
            NSDate *dateAlt2 = [dict2 objectForKey:@"Expires"];
            return [dateAlt1 compare:dateAlt2];
        }
    }
    else if ([[dict1 objectForKey:key] isKindOfClass:[NSDate class]] == YES)
    {
        NSDate *date1 = [dict1 objectForKey:key];
        NSDate *date2 = [dict2 objectForKey:key];

        // This is going to be called really, really often, so make it simple...
        return [date1 compare:date2];
    }
    // This shouldn't be reached, but I assume nothing.
    return NSOrderedSame;
}


NSComparisonResult compareDictsBackwards(NSHTTPCookie *cookie1, NSHTTPCookie *cookie2, void *context)
{
    NSString *key = (NSString *)context;
    NSDictionary *dict1 = [cookie1 properties];
    NSDictionary *dict2 = [cookie2 properties];

    // We branch here depending on whether we're doing strings or dates.
    if ([[dict1 objectForKey:key] isKindOfClass:[NSString class]] == YES)
    {
        NSString *string1 = [dict1 objectForKey:key];
        NSString *string2 = [dict2 objectForKey:key];
        // This is going to be called really, really often, so make it simple...
        NSComparisonResult stringComparison = [string2 compare:string1];

        // Check to see if we don't have to use some sort of other criteria...
        if (stringComparison != NSOrderedSame)
        {
            return stringComparison;
        }
        else
        {
            // If they're the same, then we compare their dates (Expires key).
            NSDate *dateAlt1 = [dict1 objectForKey:@"Expires"];
            NSDate *dateAlt2 = [dict2 objectForKey:@"Expires"];
            return [dateAlt2 compare:dateAlt1];
        }
    }
    else if ([[dict1 objectForKey:key] isKindOfClass:[NSDate class]] == YES)
    {
        NSDate *date1 = [dict1 objectForKey:key];
        NSDate *date2 = [dict2 objectForKey:key];

        // This is going to be called really, really often, so make it simple...
        return [date2 compare:date1];
    }
    // This shouldn't be reached, but I assume nothing.
    return NSOrderedSame;
}