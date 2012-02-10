BUILD:=$(shell pwd)/build

all: build/lib/libcrypto.a spdylay


build/lib/libcrypto.a: OpenSSL-for-iPhone/build-libssl.sh
	cd OpenSSL-for-iPhone && INSTALL_DIR=$(BUILD) ./build-libssl.sh



spdylay/configure: spdylay/configure.ac
	cd spdylay && autoreconf -i && automake && autoconf

spdylay/Makefile: spdylay/configure
	cd spdylay && ./configure --prefix="$(BUILD)"

spdylay: spdylay/Makefile
	cd spdylay && make install


.PHONY: all spindly spdylay
