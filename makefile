uikittools = uiduid uicache uiopen gssc sbdidlaunch sbreload cfversion iomfsetgamma ldrestart

all: $(uikittools)

clean:
	rm -f $(uikittools) extrainst_

.PHONY: all clean package

private := -F/System/Library/PrivateFrameworks

flags := -Os -Werror
flags += -framework CoreFoundation
flags += -framework Foundation
flags += -miphoneos-version-min=2.0
flags += -arch armv6

ldrestart := -std=c++11
gssc := -lobjc
iomfsetgamma := -I. $(private) -framework IOKit -framework IOMobileFramebuffer
sbdidlaunch := $(private) -framework SpringBoardServices
uicache := -framework UIKit # XXX: UIKit -> MobileCoreServices
uiduid := -framework UIKit
uiopen := -framework UIKit
uishoot := -framework UIKit

uicache: csstore.cpp
extrainst_: csstore.cpp

%: %.mm
	cycc -- -o $@ $^ $(flags) $($@)
	ldid -S$(wildcard $@.xml) $@

%: %.cpp
	cycc -- -o $@ $^ $(flags) $($@)
	ldid -S$(wildcard $@.xml) $@

%: %.c
	cycc -- -o $@ -x c $^ $(flags) $($@)
	ldid -S$(wildcard $@.xml) $@

package: all extrainst_
	sudo rm -rf _
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
