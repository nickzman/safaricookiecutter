//
//  SCCDomainStringFormatter.m
//  SafariCookieCutter
//
//  Created by Nick Zitzmann on Mon Jul 14 2003.
//  Copyright (c) 2003 Nick Zitzmann. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SCCDomainStringFormatter.h"


@implementation SCCDomainStringFormatter

- (NSString *)stringForObjectValue:(id)obj
{
    // Make sure we only handle strings.
    if ([obj isKindOfClass:[NSString class]])
    {
        return obj;
    }
    [NSException raise:NSInternalInconsistencyException format:@"SCCDomainStringFormatter only handles string classes"];
    return nil;
}


- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error
{
    NSMutableString *scratchString = [NSMutableString string];
    NSCharacterSet *allowedCharactersInDomain = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-."];
    const NSUInteger stringLength = [string length];
    NSUInteger i;
    NSUInteger currentIndex = 0UL;
    unichar thisCharacter, lastCharacter = 0;

    for (i = 0 ; i < stringLength ; i++)
    {
        // Insert only the characters that can actually appear inside domains.
        thisCharacter = [string characterAtIndex:i];

        if ([allowedCharactersInDomain characterIsMember:thisCharacter])
        {
            // Make sure the last character and current character aren't both periods... NSHTTPCookieStorage doesn't like that.
            if (thisCharacter != '.' || (thisCharacter == '.' && lastCharacter != '.'))
            {
                [scratchString insertString:[NSString stringWithCharacters:&thisCharacter length:1] atIndex:currentIndex];
                currentIndex++;
            }
        }

        lastCharacter = thisCharacter;
    }

    if (currentIndex != 0)	// don't do the following operation if our scratch string ends up being empty
    {
        // Make sure that the final character is not a ., since that's another thing NSHTTPCookieStorage hates...
        currentIndex--;
        thisCharacter = [scratchString characterAtIndex:currentIndex];
        if (thisCharacter == '.')
        {
            [scratchString deleteCharactersInRange:NSMakeRange(currentIndex, 1)];
        }
    }

    // Now set obj and exit...
    *obj = [NSString stringWithString:scratchString];
    return YES;
}

@end
