#import <GraphicsServices/GraphicsServices.h>
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <dlfcn.h>

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
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *name = nil;

    if (argc == 2)
        name = [NSString stringWithUTF8String:argv[0]];
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

        if (capability != nil)
            break;

        CFRunLoopRun();
    }

    NSLog(@"%@", capability);

    /*for (NSString *value in capability)
        printf("%s\n", [value UTF8String]);*/

    [pool release];

    return 0;
}
