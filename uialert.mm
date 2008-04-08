#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <unistd.h>
#include <cstdlib>

int argc_;
char **argv_;

@interface AlertSheet : UIApplication {
}

- (void) alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button;
- (void) applicationDidFinishLaunching:(id)unused;
@end

@implementation AlertSheet

- (void) alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button {
    [sheet dismiss];
    exit(button);
}

- (void) applicationDidFinishLaunching:(id)unused {
    NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:(argc_ - 3)];
    for (size_t i(0); i != argc_ - 3; ++i)
        [buttons addObject:[NSString stringWithCString:argv_[i + 3]]];

    UIAlertSheet *sheet = [[[UIAlertSheet alloc]
        initWithTitle:[NSString stringWithCString:argv_[1]]
        buttons:buttons
        defaultButtonIndex:0
        delegate:self
        context:self
    ] autorelease];

    [sheet setBodyText:[NSString stringWithCString:argv_[2]]];

    [sheet setShowsOverSpringBoardAlerts:YES];
    [sheet popupAlertAnimated:YES];
}

@end

int main(int argc, char *argv[]) {
    argc_ = argc;
    argv_ = argv;

    char *args[] = {
        (char *) "AlertSheet", NULL
    };

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    UIApplicationMain(1, args, [AlertSheet class]);
    [pool release];
    return 0;
}
