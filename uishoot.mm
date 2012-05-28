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

#import <CoreFoundation/CFData.h>
#import <CoreGraphics/CGImage.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIImage-UIImageInternal.h>

#include <stdint.h>
#include <stdlib.h>

#define _trace() NSLog(@"_trace():%s:%u", __FILE__, __LINE__)

extern "C" CGImageRef UIGetScreenImage();
extern "C" NSData *UIImagePNGRepresentation(UIImage *);
extern "C" NSData *UIImageJPEGRepresentation(UIImage *);

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    CGImageRef screen = UIGetScreenImage();
    UIImage *image = [UIImage imageWithCGImage:screen];
    NSData *png = UIImagePNGRepresentation(image);
    CFRelease(screen);

    NSString *dcim = [NSString stringWithFormat:@"%@/Media/DCIM", NSHomeDirectory()];
    NSString *apple = [NSString stringWithFormat:@"%@/999APPLE", dcim];

    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL directory;

    if (![manager fileExistsAtPath:apple isDirectory:&directory]) {
        if (![manager
            createDirectoryAtPath:apple
            withIntermediateDirectories:YES
            attributes:nil
            error:NULL
        ]) {
            NSLog(@"%@ does not exist and cannot be created", apple);
            return 1;
        }
    } else if (!directory) {
        NSLog(@"%@ exists and is not a directory", apple);
        return 1;
    }

    bool taken = false;

    for (unsigned i(0); i != 100 && !taken; ++i) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        for (unsigned j(0); j != 100 && !taken; ++j) {
            unsigned index = i * 100 + j;
            if (index == 0)
                continue;

            NSString *file = [NSString stringWithFormat:@"%@/IMG_%04u.PNG", apple, index];

            if (![manager fileExistsAtPath:file isDirectory:&directory]) {
                [png writeToFile:file atomically:YES];

                NSString *thm = [NSString stringWithFormat:@"%@/IMG_%04u.THM", apple, index];
                UIImage *thumb = [image _imageScaledToSize:CGSizeMake(55.0f, 55.0f) interpolationQuality:1];
                NSData *jpeg = UIImageJPEGRepresentation(thumb);
                [jpeg writeToFile:thm atomically:YES];

                NSString *poster = [NSString stringWithFormat:@"%@/.MISC/PosterImage.jpg", dcim, index];
                [jpeg writeToFile:poster atomically:YES];

                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    (CFStringRef) @"PictureWasTakenNotification",
                    NULL, NULL, YES
                );

                taken = true;

                NSLog(@"DONE: %@", file);
            }
        }

        [pool release];
    }

    if (!taken) {
        NSLog(@"%@ is too full", apple);
        return 1;
    }

    [pool release];
    return 0;
}
