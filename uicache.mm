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

#include <objc/runtime.h>

#include <MobileCoreServices/LSApplicationWorkspace.h>

@interface NSMutableArray (Cydia)
- (void) addInfoDictionary:(NSDictionary *)info;
@end

@implementation NSMutableArray (Cydia)

- (void) addInfoDictionary:(NSDictionary *)info {
    [self addObject:info];
}

@end

@interface NSMutableDictionary (Cydia)
- (void) addInfoDictionary:(NSDictionary *)info;
@end

@implementation NSMutableDictionary (Cydia)

- (void) addInfoDictionary:(NSDictionary *)info {
    NSString *bundle = [info objectForKey:@"CFBundleIdentifier"];
    [self setObject:info forKey:bundle];
}

@end

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    bool respring(false);

    NSString *home(NSHomeDirectory());
    NSString *path([NSString stringWithFormat:@"%@/Library/Caches/com.apple.mobile.installation.plist", home]);

    Class $LSApplicationWorkspace(objc_getClass("LSApplicationWorkspace"));
    LSApplicationWorkspace *workspace($LSApplicationWorkspace == nil ? nil : [$LSApplicationWorkspace defaultWorkspace]);

    if (NSMutableDictionary *cache = [NSMutableDictionary dictionaryWithContentsOfFile:path]) {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSError *error = nil;

        NSMutableDictionary *bundles([NSMutableDictionary dictionaryWithCapacity:16]);

        id system = [cache objectForKey:@"System"];
        if (system == nil)
            goto error;

        [system removeAllObjects];

        if (NSArray *apps = [manager contentsOfDirectoryAtPath:@"/Applications" error:&error]) {
            for (NSString *app in apps)
                if ([app hasSuffix:@".app"]) {
                    NSString *path = [@"/Applications" stringByAppendingPathComponent:app];
                    NSString *plist = [path stringByAppendingPathComponent:@"Info.plist"];

                    if (NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:plist]) {
                        if (NSString *identifier = [info objectForKey:@"CFBundleIdentifier"]) {
                            [bundles setObject:path forKey:identifier];
                            [info setObject:path forKey:@"Path"];
                            [info setObject:@"System" forKey:@"ApplicationType"];
                            [system addInfoDictionary:info];
                        } else
                            fprintf(stderr, "%s missing CFBundleIdentifier", [app UTF8String]);
                    }
                }
        } else goto error;

        [cache writeToFile:path atomically:YES];

        if (workspace != nil)
            for (NSString *bundle in bundles) {
                NSString *path([bundles objectForKey:identifier]);
                [workspace unregisterApplication:[NSURL fileURLWithPath:path]];
                if ([workspace respondsToSelector:@selector(invalidateIconCache:)])
                    [workspace invalidateIconCache:identifier];
                [workspace registerApplication:[NSURL fileURLWithPath:path]];
            }

        if (false) error:
            fprintf(stderr, "%s\n", error == nil ? strerror(errno) : [[error localizedDescription] UTF8String]);
    } else fprintf(stderr, "cannot open cache file. incorrect user?\n");

    if (respring || kCFCoreFoundationVersionNumber >= 550.32) {
        unlink([[NSString stringWithFormat:@"%@/Library/Caches/com.apple.springboard-imagecache-icons", home] UTF8String]);
        unlink([[NSString stringWithFormat:@"%@/Library/Caches/com.apple.springboard-imagecache-icons.plist", home] UTF8String]);

        unlink([[NSString stringWithFormat:@"%@/Library/Caches/com.apple.springboard-imagecache-smallicons", home] UTF8String]);
        unlink([[NSString stringWithFormat:@"%@/Library/Caches/com.apple.springboard-imagecache-smallicons.plist", home] UTF8String]);

        system([[NSString stringWithFormat:@"rm -rf %@/Library/Caches/SpringBoardIconCache", home] UTF8String]);
        system([[NSString stringWithFormat:@"rm -rf %@/Library/Caches/SpringBoardIconCache-small", home] UTF8String]);

        system([[NSString stringWithFormat:@"rm -rf %@/Library/Caches/com.apple.IconsCache", home] UTF8String]);
    }

    system("killall installd");

    if (respring)
        system("launchctl stop com.apple.SpringBoard");
    else
        notify_post("com.apple.mobile.application_installed");

    [pool release];

    return 0;
}
