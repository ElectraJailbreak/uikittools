#import <GraphicsServices/GraphicsServices.h>
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <dlfcn.h>

static CFArrayRef (*$GSSystemCopyCapability)(CFStringRef);
static CFArrayRef (*$GSSystemGetCapability)(CFStringRef);

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

    const NSArray *capability;

    if ($GSSystemCopyCapability != NULL) {
        capability = reinterpret_cast<const NSArray *>((*$GSSystemCopyCapability)(reinterpret_cast<CFStringRef>(name)));
        capability = [capability autorelease];
    } else if ($GSSystemGetCapability != NULL) {
        capability = reinterpret_cast<const NSArray *>((*$GSSystemGetCapability)(reinterpret_cast<CFStringRef>(name)));
    } else
        capability = nil;

    NSLog(@"%@", capability);

    /*for (NSString *value in capability)
        printf("%s\n", [value UTF8String]);*/

    [pool release];

    return 0;
}
