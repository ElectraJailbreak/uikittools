uikittools = uiduid uicache uiopen gssc sbdidlaunch sbreload cfversion iomfsetgamma

all: $(uikittools)

clean:
	rm -f $(uikittools)

.PHONY: all clean package

cfversion := -framework CoreFoundation
gssc := -framework CoreFoundation
sbdidlaunch := -framework CoreFoundation -framework SpringBoardServices
uicache := -framework Foundation -framework UIKit # XXX: UIKit -> MobileCoreServices
uiduid := -framework Foundation -framework UIKit
uiopen := -framework Foundation -framework UIKit
uishoot := -framework CoreFoundation -framework Foundation -framework UIKit
extrainst_ := -framework CoreFoundation -framework Foundation

uicache: csstore.cpp
extrainst_: csstore.cpp

%: %.mm
	$${PKG_TARG}-g++ -Wall -Werror -o $@ $^ $($@) -F"$${PKG_ROOT}"/System/Library/PrivateFrameworks -lobjc
	ldid -S$(wildcard $@.xml) $@

%: %.c
	$${PKG_TARG}-gcc -Wall -Werror -o $@ $< -framework CoreFoundation
	ldid -S$(wildcard $@.xml) $@

iomfsetgamma: iomfsetgamma.c
	$${PKG_TARG}-gcc -Wall -Werror -o $@ $< -F"$${PKG_ROOT}"/System/Library/PrivateFrameworks -framework IOKit -framework IOMobileFramebuffer
	ldid -S$(wildcard $@.xml) $@

package: all extrainst_
	rm -rf _
	mkdir -p _/usr/bin
	cp -a $(uikittools) _/usr/bin
	mkdir -p _/DEBIAN
	./control.sh _ >_/DEBIAN/control
	cp -a extrainst_ _/DEBIAN/
	mkdir -p debs
	ln -sf debs/uikittools_$$(./version.sh)_iphoneos-arm.deb uikittools.deb
	dpkg-deb -b _ uikittools.deb
	readlink uikittools.deb
