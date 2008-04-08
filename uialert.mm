#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <unistd.h>
#include <cstdlib>

int argc_;
char **argv_;

@interface AlertSheet : UIApplication
#ifdef __OBJC2__
<UIModalViewDelegate>
#endif
{
}

#ifdef __OBJC2__
- (void) modalView:(UIModalView *)modalView didDismissWithButtonIndex:(NSInteger)buttonIndex;
#else
- (void) alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button;
#endif

- (void) applicationDidFinishLaunching:(id)unused;
@end

@implementation AlertSheet

#ifdef __OBJC2__
- (void) modalView:(UIModalView *)modalView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    exit(buttonIndex);
}
#else
- (void) alertSheet:(UIAlertSheet *)alertSheet buttonClicked:(int)button {
    [alertSheet dismiss];
    exit(button);
}
#endif

- (void) applicationDidFinishLaunching:(id)unused {
    NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:(argc_ - 3)];
    for (size_t i(0); i != argc_ - 3; ++i)
        [buttons addObject:[NSString stringWithCString:argv_[i + 3]]];

#ifdef __OBJC2__
    UIAlertView *alert = [[[UIAlertView alloc]
        initWithTitle:[NSString stringWithCString:argv_[1]]
        message:[NSString stringWithCString:argv_[2]]
        delegate:self
        cancelButtonTitle:nil
        otherButtonTitles:nil
    ] autorelease];

    [alert show];
#else
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
#endif
}

@end

int main(int argc, char *argv[]) {
    argc_ = argc;
    argv_ = argv;

    char *args[] = {
        (char *) "AlertSheet", NULL
    };

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#ifdef __OBJC2__
    UIApplicationMain(1, args, nil, @"AlertSheet");
#else
    UIApplicationMain(1, args, [AlertSheet class]);
#endif
    [pool release];
    return 0;
}
