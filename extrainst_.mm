/* UIKit Tools - command-line utilities for UIKit
 * Copyright (C) 2008-2012  Jay Freeman (saurik)
*/

/* Modified BSD License {{{ */
/*
 *        Redistribution and use in source and binary
 * forms, with or without modification, are permitted
 * provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer in the documentation
 *    and/or other materials provided with the
 *    distribution.
 * 3. The name of the author may not be used to endorse
 *    or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 * BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/* }}} */

#import <Foundation/Foundation.h>

#include <notify.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include "csstore.hpp"

@interface NSObject (Cydia)
- (NSDictionary *) dictionaryOfInfoDictionaries;
@end

@implementation NSObject (Cydia)

- (NSDictionary *) dictionaryOfInfoDictionaries {
    return nil;
}

@end

@interface NSArray (Cydia)
- (NSDictionary *) dictionaryOfInfoDictionaries;
@end

@implementation NSArray (Cydia)

- (NSDictionary *) dictionaryOfInfoDictionaries {
    // XXX: implement?
    return nil;
}

@end

@interface NSDictionary (Cydia)
- (NSDictionary *) dictionaryOfInfoDictionaries;
@end

@implementation NSDictionary (Cydia)

- (NSDictionary *) dictionaryOfInfoDictionaries {
    return self;
}

@end

bool FinishCydia(const char *finish) {
    if (finish == NULL)
        return true;

    const char *cydia(getenv("CYDIA"));
    if (cydia == NULL)
        return false;

    int fd([[[[NSString stringWithUTF8String:cydia] componentsSeparatedByString:@" "] objectAtIndex:0] intValue]);
    FILE *fout(fdopen(fd, "w"));
    fprintf(fout, "finish:%s\n", finish);
    fclose(fout);
    return true;
}

void FixCache(NSString *home, NSString *plist) {
    printf("attempting to fix weather app issue:\n");

    DeleteCSStores([home UTF8String]);
    unlink([plist UTF8String]);

    system("launchctl stop com.apple.mobile.installd");
    system("launchctl start com.apple.mobile.installd");

    printf("waiting for application/icon cache rebuild...\n");
    printf("this will timeout (harmlessly) after 90 seconds\n");

    for (unsigned i(0); i != 90; ++i) {
        if (i != 0 && (i % 10) == 0)
            printf("after %i seconds, still waiting for rebuild...\n", i);
        if ([[NSMutableDictionary dictionaryWithContentsOfFile: plist] objectForKey: @"User"] != nil)
            break;
        sleep(1);
    }

    if (!FinishCydia("reboot"))
        printf("you must reboot to finalize your cache.\n");
}

int main(int argc, const char *argv[]) {
    if (argc < 2 || (
        strcmp(argv[1], "install") != 0 &&
        strcmp(argv[1], "upgrade") != 0 &&
    true)) return 0;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    if (kCFCoreFoundationVersionNumber >= 700) { // XXX: iOS 6.x
        NSString *home(@"/var/mobile");
        NSString *plist([NSString stringWithFormat:@"%@/Library/Caches/com.apple.mobile.installation.plist", home]);

        NSDictionary *cache([NSDictionary dictionaryWithContentsOfFile:plist]);
        NSObject *system([cache objectForKey:@"System"]);
        NSDictionary *dictionary([system dictionaryOfInfoDictionaries]);
        NSDictionary *weather([dictionary objectForKey:@"com.apple.weather"]);

        if (weather != nil && [weather objectForKey:@"Container"] == nil)
            FixCache(home, plist);
    }

    [pool release];
    return 0;
}
