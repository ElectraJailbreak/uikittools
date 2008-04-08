all: uialert

%: %.mm
	$${PKG_TARG}-g++ -o $@ $< -framework Foundation -framework CoreFoundation -framework UIKit -lobjc
