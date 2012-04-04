
CONFIGURATION=Release

install: armv6 armv7 i386
	mkdir -p ../install/include/SPDY ../install/lib
	lipo -create build/lib/armv6/libSPDY.a build/lib/armv7/libSPDY.a build/lib/i386/libSPDY.a -output ../install/lib/libSPDY.a
	cp build/include/SPDY/*.h ../install/include/SPDY/

check:
	xcodebuild -configuration Debug -sdk iphonesimulator4.3 clean
	xcodebuild -configuration Debug -sdk iphonesimulator4.3 -target SPDYTests

i386:
	mkdir -p build/lib/i386
	xcodebuild clean
	xcodebuild -sdk iphonesimulator4.3 -arch i386 -configuration Debug install
	cp build/UninstalledProducts/libSPDY.a build/lib/i386/libSPDY.a

armv6:
	mkdir -p build/lib/armv6
	xcodebuild clean
	xcodebuild -configuration $(CONFIGURATION) -arch armv6 -sdk iphoneos4.3 install
	cp build/UninstalledProducts/libSPDY.a build/lib/armv6/libSPDY.a

armv7:
	mkdir -p build/lib/armv7
	xcodebuild clean
	xcodebuild -configuration $(CONFIGURATION) -arch armv7 -sdk iphoneos4.3 install
	cp build/UninstalledProducts/libSPDY.a build/lib/armv7/libSPDY.a
