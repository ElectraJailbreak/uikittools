#import <UIKit/UIKit.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    if (argc != 2)
        fprintf(stderr, "usage: %s <url>\n", argv[0]);
    else {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [[UIApplication alloc] openURL:[NSURL URLWithString:[NSString stringWithUTF8String:argv[1]]]];
        [pool release];
    }

    return 0;
}
