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
#include <dlfcn.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <string.h>

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
    printf("attempting to fix weather app issue, please wait...\n");

    DeleteCSStores([home UTF8String]);
    unlink([plist UTF8String]);

    bool succeeded(false);

    if (void *MobileInstallation$ = dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation", RTLD_GLOBAL | RTLD_LAZY)) {
        int (*MobileInstallation$_MobileInstallationRebuildMap)(CFBooleanRef, CFBooleanRef, CFBooleanRef);
        MobileInstallation$_MobileInstallationRebuildMap = reinterpret_cast<int (*)(CFBooleanRef, CFBooleanRef, CFBooleanRef)>(dlsym(MobileInstallation$, "_MobileInstallationRebuildMap"));
        if (MobileInstallation$_MobileInstallationRebuildMap != NULL) {
            if (int error = MobileInstallation$_MobileInstallationRebuildMap(kCFBooleanTrue, kCFBooleanTrue, kCFBooleanTrue))
                printf("failed to rebuild cache (but we gave it a good try); error #%d\n", error);
            else {
                printf("successfully rebuilt application information cache.\n");
                succeeded = true;
            }
        } else
            printf("unable to find _MobileInstallationRebuildMap symbol.\n");
    } else
        printf("unable to load MobileInstallation library.\n");

    if (!succeeded)
        printf("this is not a problem: it will be regenerated as the device boots\n");

    if (!FinishCydia("reboot"))
        printf("you must reboot to finalize your cache.\n");
}

#define INSTALLD "/usr/libexec/installd"

static void *(*$memmem)(const void *, size_t, const void *, size_t);

static bool PatchInstall() {
    int fd(open(INSTALLD, O_RDWR));
    if (fd == -1)
        return false;

    struct stat stat;
    if (fstat(fd, &stat) == -1) {
        close(fd);
        return false;
    }

    size_t size(stat.st_size);
    void *data(mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0));
    close(fd);
    if (data == MAP_FAILED)
        return false;

    bool changed(false);
    for (;;) {
        void *name($memmem(data, size, "__restrict", 10));
        if (name == NULL)
            break;
        else {
            memcpy(name, "__uicache_", 10);
            changed = true;
        }
    }

    munmap(data, size);

    if (changed) {
        system("ldid -s "INSTALLD"");
        system("cp -af "INSTALLD" "INSTALLD"_");
        system("mv -f "INSTALLD"_ "INSTALLD"");
    }

    return true;
}

#define SubstrateLaunchDaemons_ "/Library/LaunchDaemons"
#define SubstrateVariable_ "DYLD_INSERT_LIBRARIES"
#define SubstrateLibrary_ "/usr/lib/libuicache.dylib"

static bool HookInstall() {
    NSString *file([NSString stringWithFormat:@"%@/%s.plist", @ SubstrateLaunchDaemons_, "com.apple.mobile.installd"]);
    if (file == nil)
        return false;

    NSMutableDictionary *root([NSMutableDictionary dictionaryWithContentsOfFile:file]);
    if (root == nil)
        return false;

    NSMutableDictionary *environment([root objectForKey:@"EnvironmentVariables"]);
    if (environment == nil) {
        environment = [NSMutableDictionary dictionaryWithCapacity:1];
        if (environment == nil)
            return false;

        [root setObject:environment forKey:@"EnvironmentVariables"];
    }

    NSString *variable([environment objectForKey:@ SubstrateVariable_]);
    if (variable == nil || [variable length] == 0)
        [environment setObject:@ SubstrateLibrary_ forKey:@ SubstrateVariable_];
    else {
        NSArray *dylibs([variable componentsSeparatedByString:@":"]);
        if (dylibs == nil)
            return false;

        NSUInteger index([dylibs indexOfObject:@ SubstrateLibrary_]);
        if (index != NSNotFound)
            return false;

        [environment setObject:[NSString stringWithFormat:@"%@:%@", variable, @ SubstrateLibrary_] forKey:@ SubstrateVariable_];
    }

    NSString *error;
    NSData *data([NSPropertyListSerialization dataFromPropertyList:root format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error]);
    if (data == nil)
        return false;

    if (![data writeToFile:file atomically:YES])
        return false;

    system("launchctl unload /Library/LaunchDaemons/com.apple.mobile.installd.plist");
    system("launchctl load /Library/LaunchDaemons/com.apple.mobile.installd.plist");
    return true;
}

int main(int argc, const char *argv[]) {
    if (argc < 2 || (
        strcmp(argv[1], "install") != 0 &&
        strcmp(argv[1], "upgrade") != 0 &&
    true)) return 0;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    $memmem = reinterpret_cast<void *(*)(const void *, size_t, const void *, size_t)>(dlsym(RTLD_DEFAULT, "memmem"));

    if (kCFCoreFoundationVersionNumber >= 1143) // XXX: iOS 8.3+
        if (PatchInstall())
            if (HookInstall())
                FinishCydia("reboot");

    if (kCFCoreFoundationVersionNumber >= 700 && kCFCoreFoundationVersionNumber < 800) { // XXX: iOS 6.x
        NSString *home(@"/var/mobile");
        NSString *plist([NSString stringWithFormat:@"%@/Library/Caches/com.apple.mobile.installation.plist", home]);
        NSDictionary *cache([NSDictionary dictionaryWithContentsOfFile:plist]);

        NSArray *cached([cache objectForKey:@"MICachedKeys"]);
        if (cached != nil && [cached containsObject:@"Container"]) {
            NSObject *system([cache objectForKey:@"System"]);
            NSDictionary *dictionary([system dictionaryOfInfoDictionaries]);
            NSDictionary *weather([dictionary objectForKey:@"com.apple.weather"]);

            if (weather != nil && [weather objectForKey:@"Container"] == nil)
                FixCache(home, plist);
        }
    }

    [pool release];
    return 0;
}
