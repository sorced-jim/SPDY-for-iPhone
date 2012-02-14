
all:
	xcodebuild clean
	xcodebuild -sdk iphonesimulator4.3 install
	mkdir -p build/lib
	cp build/UninstalledProducts/libSPDY.a build/lib/libSPDY.a
	xcodebuild clean
	xcodebuild -arch armv7 -sdk iphoneos4.3 install
	lipo -create build/UninstalledProducts/libSPDY.a build/lib/libSPDY.a -output ../build/lib/libSPDY.a
