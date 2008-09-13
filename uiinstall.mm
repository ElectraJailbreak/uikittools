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

#define Cache_ "/User/Library/Caches/com.apple.mobile.installation.plist"

int main() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    if (NSMutableDictionary *cache = [[NSMutableDictionary alloc] initWithContentsOfFile:@ Cache_]) {
        [cache autorelease];

        NSFileManager *manager = [NSFileManager defaultManager];
        NSError *error = nil;

        id system = [cache objectForKey:@"System"];
        if (system == nil)
            goto error;

        struct stat info;
        if (stat(Cache_, &info) == -1)
            goto error;

        [system removeAllObjects];

        if (NSArray *apps = [manager contentsOfDirectoryAtPath:@"/Applications" error:&error]) {
            for (NSString *app in apps)
                if ([app hasSuffix:@".app"]) {
                    NSString *path = [@"/Applications" stringByAppendingPathComponent:app];
                    NSString *plist = [path stringByAppendingPathComponent:@"Info.plist"];
                    if (NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithContentsOfFile:plist]) {
                        [info autorelease];
                        [info setObject:path forKey:@"Path"];
                        [info setObject:@"System" forKey:@"ApplicationType"];
                        [system addInfoDictionary:info];
                    }
                }
        } else goto error;

        [cache writeToFile:@Cache_ atomically:YES];

        if (chown(Cache_, info.st_uid, info.st_gid) == -1)
            goto error;
        if (chmod(Cache_, info.st_mode) == -1)
            goto error;

        if (false) error:
            fprintf(stderr, "%s\n", error == nil ? strerror(errno) : [[error localizedDescription] UTF8String]);
    }

    notify_post("com.apple.mobile.application_installed");

    [pool release];

    return 0;
}
