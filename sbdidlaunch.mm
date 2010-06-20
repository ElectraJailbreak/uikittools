#import <CoreFoundation/CoreFoundation.h>

extern "C" void *SBSSpringBoardServerPort();

void OnDidLaunch(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef info
) {
    CFRunLoopStop(CFRunLoopGetCurrent());
}

int main() {
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        &OnDidLaunch,
        CFSTR("SBSpringBoardDidLaunchNotification"),
        NULL,
        NULL
    );

    if (SBSSpringBoardServerPort() == NULL)
        CFRunLoopRun();

    return 0;
}
