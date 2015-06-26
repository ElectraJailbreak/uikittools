uikittools = uiduid uicache uiopen gssc sbdidlaunch sbreload cfversion iomfsetgamma libuicache.dylib

all: $(uikittools)

clean:
	rm -f $(uikittools) extrainst_

.PHONY: all clean package

private := -F/System/Library/PrivateFrameworks

cfversion := -framework CoreFoundation
gssc := -lobjc -framework CoreFoundation
iomfsetgamma := -I. $(private) -framework IOKit -framework IOMobileFramebuffer
sbdidlaunch := $(private) -framework CoreFoundation -framework SpringBoardServices
sbreload := -framework CoreFoundation
uicache := -framework Foundation -framework UIKit # XXX: UIKit -> MobileCoreServices
uiduid := -framework Foundation -framework UIKit
uiopen := -framework Foundation -framework UIKit
uishoot := -framework CoreFoundation -framework Foundation -framework UIKit
extrainst_ := -framework CoreFoundation -framework Foundation

uicache: csstore.cpp
extrainst_: csstore.cpp

%.dylib: %.mm
	cycc -i2.0 -o$@ -- -dynamiclib -Werror $^ $($@) -lobjc
	ldid -S $@

%: %.mm
	cycc -i2.0 -o$@ -- -Werror $^ $($@)
	ldid -S$(wildcard $@.xml) $@

%: %.c
	cycc -i2.0 -o$@ -- -Werror -x c $^ $($@)
	ldid -S$(wildcard $@.xml) $@

package: all extrainst_
	sudo rm -rf _
	mkdir -p _/usr/lib
	cp -a $(filter %.dylib,$(uikittools)) _/usr/lib
	mkdir -p _/usr/bin
	cp -a $(filter-out %.dylib,$(uikittools)) _/usr/bin
	mkdir -p _/DEBIAN
	./control.sh _ >_/DEBIAN/control
	cp -a extrainst_ _/DEBIAN/
	mkdir -p debs
	ln -sf debs/uikittools_$$(./version.sh)_iphoneos-arm.deb uikittools.deb
	sudo chown -R 0 _
	sudo chgrp -R 0 _
	dpkg-deb -b _ uikittools.deb
	readlink uikittools.deb
