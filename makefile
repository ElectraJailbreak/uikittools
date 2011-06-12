uikittools = uiduid uishoot uicache uiopen gssc sbdidlaunch sbreload cfversion iomfsetgamma

all: $(uikittools)

clean:
	rm -f $(uikittools)

.PHONY: all clean package

%: %.mm
	$${PKG_TARG}-g++ -Wall -Werror -o $@ $< -framework CoreFoundation -framework Foundation -framework UIKit -framework GraphicsServices -F"$${PKG_ROOT}"/System/Library/PrivateFrameworks -lobjc -framework SpringBoardServices
	ldid -S $@

%: %.c
	$${PKG_TARG}-gcc -Wall -Werror -o $@ $< -framework CoreFoundation
	ldid -S $@

iomfsetgamma: iomfsetgamma.c
	$${PKG_TARG}-gcc -Wall -Werror -o $@ $< -F"$${PKG_ROOT}"/System/Library/PrivateFrameworks -framework IOKit -framework IOMobileFramebuffer
	ldid -S $@

package: all
	rm -rf _
	mkdir -p _/usr/bin
	cp -a $(uikittools) _/usr/bin
	mkdir -p _/DEBIAN
	./control.sh _ >_/DEBIAN/control
	mkdir -p debs
	ln -sf debs/uikittools_$$(./version.sh)_iphoneos-arm.deb uikittools.deb
	dpkg-deb -b _ uikittools.deb
	readlink uikittools.deb
