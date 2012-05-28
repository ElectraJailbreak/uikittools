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
