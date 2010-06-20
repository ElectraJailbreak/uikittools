uikittools = uiduid uishoot uicache uiopen gssc sbdidlaunch

all: $(uikittools)

clean:
	rm -f $(uikittools)

.PHONY: all clean package

%: %.mm
	$${PKG_TARG}-g++ -o $@ $< -framework CoreFoundation -framework Foundation -framework UIKit -framework GraphicsServices -F"$${PKG_ROOT}"/System/Library/PrivateFrameworks -lobjc -framework SpringBoardServices
	ldid -S $@

package: all
	rm -rf package
	mkdir -p package/usr/bin
	cp -a $(uikittools) package/usr/bin
	mkdir -p package/DEBIAN
	cp -a control package/DEBIAN
	rpl '%S' "$$(du -ks package | cut -d $$'\t' -f 1)" package/DEBIAN/control
	dpkg-deb -b package uikittools_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb
