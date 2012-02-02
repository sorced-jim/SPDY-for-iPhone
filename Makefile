BUILD:=$(shell pwd)/build

all: OpenSSL-for-iPhone/libcrypto.a spindly spdylay


OpenSSL-for-iPhone/libcrypto.a: OpenSSL-for-iPhone/build-libssl.sh
	cd OpenSSL-for-iPhone && ./build-libssl.sh


spindly/Makefile: spindly/configure
	cd spindly && ./configure


spindly: spindly/Makefile
	cd spindly && make


spdylay/configure: spdylay/configure.ac
	cd spdylay && autoreconf -i && automake && autoconf

spdylay/Makefile: spdylay/configure
	cd spdylay && ./configure --prefix="$(BUILD)"

spdylay: spdylay/Makefile
	cd spdylay && make install


.PHONY: all spindly spdylay
