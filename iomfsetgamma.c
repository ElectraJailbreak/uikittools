#include <mach/mach.h>

#include <stdio.h>
#include <stdlib.h>

#include <dlfcn.h>

#include <IOKit/IOKitLib.h>

#if 0
set -e

sdk=/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS4.3.sdk

/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/g++ \
    -Wall -fmessage-length=0 \
    -arch armv6 -miphoneos-version-min=2.0 \
    -isysroot "${sdk}" -I. -F"${sdk}"/System/Library/PrivateFrameworks \
    -framework IOKit -framework IOMobileFramebuffer \
    -o iomfsetgamma iomfsetgamma.c

ldid iomfsetgamma

exit 0
#endif

typedef void *IOMobileFramebufferRef;

kern_return_t IOMobileFramebufferOpen(io_service_t, mach_port_t, void *, IOMobileFramebufferRef *);
kern_return_t IOMobileFramebufferSetGammaTable(IOMobileFramebufferRef, void *);
kern_return_t (*$IOMobileFramebufferGetGammaTable)(IOMobileFramebufferRef, void *);

#define _assert(test) \
    if (!(test)) { \
        fprintf(stderr, "_assert(%s)\n", #test); \
        exit(-1); \
    }

int main(int argc, char *argv[]) {
    if (argc != 4) {
        fprintf(stderr, "usage: iomfsetgamma <red> <green> <blue>\n");
        fprintf(stderr, "  example: 1.00 0.78 0.64\n");
        return 1;
    }

    unsigned rs = strtod(argv[1], NULL) * 0x100;
    _assert(rs <= 0x100);

    unsigned gs = strtod(argv[2], NULL) * 0x100;
    _assert(gs <= 0x100);

    unsigned bs = strtod(argv[3], NULL) * 0x100;
    _assert(bs <= 0x100);

    kern_return_t error;
    mach_port_t self = mach_task_self();

    io_service_t service = 0;

    if (service == 0)
        service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleCLCD"));
    if (service == 0)
        service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleH1CLCD"));
    if (service == 0)
        service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleM2CLCD"));

    _assert(service != 0);

    IOMobileFramebufferRef fb;
    error = IOMobileFramebufferOpen(service, self, 0, &fb);
    _assert(error == 0);

    uint32_t data[0xc00 / sizeof(uint32_t)];
    memset(data, 0, sizeof(data));

    FILE *file = fopen("/tmp/.iomfgamma.dat", "r");
    if (file == NULL) {
        file = fopen("/tmp/.iomfgamma.dat", "wb");

        $IOMobileFramebufferGetGammaTable = dlsym(RTLD_DEFAULT, "IOMobileFramebufferGetGammaTable");

        _assert($IOMobileFramebufferGetGammaTable != NULL);
        error = $IOMobileFramebufferGetGammaTable(fb, data);
        _assert(error == 0);

        fwrite(data, 1, sizeof(data), file);
        fclose(file);

        file = fopen("/tmp/.iomfgamma.dat", "r");
    }

    fread(data, 1, sizeof(data), file);
    fclose(file);

    size_t i;
    for (i = 0; i != 256; ++i) {
        int j = 255 - i;

        int r = j * rs >> 8;
        int g = j * gs >> 8;
        int b = j * bs >> 8;

        data[j + 0x000] = data[r + 0x000];
        data[j + 0x100] = data[g + 0x100];
        data[j + 0x200] = data[b + 0x200];
    }

    error = IOMobileFramebufferSetGammaTable(fb, data);
    _assert(error == 0);

    return 0;
}
