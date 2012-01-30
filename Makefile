
all: OpenSSL-for-iPhone/libcrypto.a spindly


OpenSSL-for-iPhone/libcrypto.a: OpenSSL-for-iPhone/build-libssl.sh
	cd OpenSSL-for-iPhone && ./build-libssl.sh


spindly/Makefile: spindly/configure
	cd spindly && ./configure


spindly: spindly/Makefile
	cd spindly && make


.PHONY: all spindly
