#import <Foundation/Foundation.h>
#import <UIKit/UIDevice.h>
#include <cstdio>

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    printf("%s\n", [[UIDevice uniqueIdentifier] UTF8String];

    [pool release];
    return 0;
}
