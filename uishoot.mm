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

    for (unsigned i(0); i != 10 && !taken; ++i) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        for (unsigned j(0); j != 1000 && !taken; ++j) {
            unsigned index = i * 1000 + j;

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
            }
        }

        [pool release];
    }

    if (!taken) {
        NSLog(@"%@ is full", apple);
        return 1;
    }

    [pool release];
    return 0;
}
