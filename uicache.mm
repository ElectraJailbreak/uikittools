#import <Foundation/Foundation.h>

#include <notify.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include <objc/runtime.h>

#include <MobileCoreServices/LSApplicationWorkspace.h>

@interface NSMutableArray (Cydia)
- (void) addInfoDictionary:(NSDictionary *)info;
@end

@implementation NSMutableArray (Cydia)

- (void) addInfoDictionary:(NSDictionary *)info {
    [self addObject:info];
}

@end

@interface NSMutableDictionary (Cydia)
- (void) addInfoDictionary:(NSDictionary *)info;
@end

@implementation NSMutableDictionary (Cydia)

- (void) addInfoDictionary:(NSDictionary *)info {
    NSString *bundle = [info objectForKey:@"CFBundleIdentifier"];
    [self setObject:info forKey:bundle];
}

@end

int main() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *path([NSString stringWithFormat:@"%@/Library/Caches/com.apple.mobile.installation.plist", NSHomeDirectory()]);

    Class $LSApplicationWorkspace(objc_getClass("LSApplicationWorkspace"));
    LSApplicationWorkspace *workspace($LSApplicationWorkspace == nil ? nil : [$LSApplicationWorkspace defaultWorkspace]);

    if (NSMutableDictionary *cache = [NSMutableDictionary dictionaryWithContentsOfFile:path]) {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSError *error = nil;

        NSMutableArray *bundles([NSMutableArray arrayWithCapacity:16]);

        id system = [cache objectForKey:@"System"];
        if (system == nil)
            goto error;

        [system removeAllObjects];

        if (NSArray *apps = [manager contentsOfDirectoryAtPath:@"/Applications" error:&error]) {
            for (NSString *app in apps)
                if ([app hasSuffix:@".app"]) {
                    NSString *path = [@"/Applications" stringByAppendingPathComponent:app];
                    NSString *plist = [path stringByAppendingPathComponent:@"Info.plist"];

                    if (NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:plist]) {
                        if (NSString *bundle = [info objectForKey:@"CFBundleIdentifier"]) {
                            [bundles addObject:path];
                            [info setObject:path forKey:@"Path"];
                            [info setObject:@"System" forKey:@"ApplicationType"];
                            [system addInfoDictionary:info];
                        } else
                            fprintf(stderr, "%s missing CFBundleIdentifier", [app UTF8String]);
                    }
                }
        } else goto error;

        [cache writeToFile:path atomically:YES];

        if (workspace != nil)
            for (NSString *bundle in bundles) {
                [workspace unregisterApplication:[NSURL fileURLWithPath:bundle]];
                [workspace registerApplication:[NSURL fileURLWithPath:bundle]];
            }

        if (false) error:
            fprintf(stderr, "%s\n", error == nil ? strerror(errno) : [[error localizedDescription] UTF8String]);
    } else fprintf(stderr, "cannot open cache file. incorrect user?\n");

    notify_post("com.apple.mobile.application_installed");

    [pool release];

    return 0;
}
