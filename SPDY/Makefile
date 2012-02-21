
all:
	mkdir -p build/lib/i386 build/lib/armv7
	xcodebuild clean
	xcodebuild -sdk iphonesimulator4.3 -configuration Debug install
	cp build/UninstalledProducts/libSPDY.a build/lib/i386/libSPDY.a
	xcodebuild clean
	xcodebuild -arch armv7 -sdk iphoneos4.3 install
	cp build/UninstalledProducts/libSPDY.a build/lib/armv7/libSPDY.a
	lipo -create build/lib/armv7/libSPDY.a build/lib/i386/libSPDY.a -output ../build/lib/libSPDY.a
	mkdir -p ../build/include/SPDY
	cp build/include/SPDY/*.h ../build/include/SPDY/

check:
	xcodebuild clean
	xcodebuild -sdk iphonesimulator4.3 -target SPDYTests
