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

#import <GraphicsServices/GraphicsServices.h>
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <dlfcn.h>
#include <objc/runtime.h>

static CFArrayRef (*$GSSystemCopyCapability)(CFStringRef);
static CFArrayRef (*$GSSystemGetCapability)(CFStringRef);

void OnGSCapabilityChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef info
) {
    CFRunLoopStop(CFRunLoopGetCurrent());
}

int main(int argc, char *argv[]) {
    dlopen("/System/Library/Frameworks/Foundation.framework/Foundation", RTLD_GLOBAL | RTLD_LAZY);
    dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_GLOBAL | RTLD_LAZY);

    NSAutoreleasePool *pool = [[objc_getClass("NSAutoreleasePool") alloc] init];

    NSString *name = nil;

    if (argc == 2)
        name = [objc_getClass("NSString") stringWithUTF8String:argv[0]];
    else if (argc > 2) {
        fprintf(stderr, "usage: %s [capability]\n", argv[0]);
        exit(1);
    }

    $GSSystemCopyCapability = reinterpret_cast<CFArrayRef (*)(CFStringRef)>(dlsym(RTLD_DEFAULT, "GSSystemCopyCapability"));
    $GSSystemGetCapability = reinterpret_cast<CFArrayRef (*)(CFStringRef)>(dlsym(RTLD_DEFAULT, "GSSystemGetCapability"));

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        &OnGSCapabilityChanged,
        CFSTR("GSCapabilitiesChanged"),
        NULL,
        NULL
    );

    const NSArray *capability;

    for (;;) {
        if ($GSSystemCopyCapability != NULL) {
            capability = reinterpret_cast<const NSArray *>((*$GSSystemCopyCapability)(reinterpret_cast<CFStringRef>(name)));
            if (capability != nil)
                capability = [capability autorelease];
        } else if ($GSSystemGetCapability != NULL) {
            capability = reinterpret_cast<const NSArray *>((*$GSSystemGetCapability)(reinterpret_cast<CFStringRef>(name)));
        } else {
            capability = nil;
            break;
        }

        if (capability != nil) {
            printf("%s\n", capability == nil ? "(null)" : [[capability description] UTF8String]);
            break;
        }

        CFRunLoopRun();
    }

    [pool release];

    return 0;
}
