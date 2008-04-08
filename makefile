all: uialert

%: %.mm
	$${PKG_TARG}-g++ -o $@ $< -framework CoreFoundation -framework Foundation -framework UIKit -lobjc
