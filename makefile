all: uialert

%: %.mm
	arm-apple-darwin-g++ -o $@ $< -framework CoreFoundation -framework Foundation -framework UIKit -lobjc
	arm-apple-darwin-strip $@
