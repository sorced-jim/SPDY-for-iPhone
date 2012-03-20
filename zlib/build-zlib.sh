#!/bin/sh
set -e

# Copyright (c) 2010, Pierre-Olivier Latour
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * The name of Pierre-Olivier Latour may not be used to endorse or
#       promote products derived from this software without specific prior
#       written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Download source
ZLIB_VERSION=${ZLIB_VERSION:-1.2.6}
ARCH=${ARCH:-armv7}
DEVELOPER=${DEVELOPER:-`xcode-select --print-path`}
PLATFORM=${PLATFORM:-iPhoneOS}
SDK=${SDK:-4.3}
if [ ! -e "zlib-${ZLIB_VERSION}.tar.gz" ]
then
  curl -O "http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz"
fi

# Extract source
rm -rf "zlib-${ZLIB_VERSION}"
tar zxvf "zlib-${ZLIB_VERSION}.tar.gz"

# Build
pushd "zlib-${ZLIB_VERSION}"
export DEVROOT="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
export SDKROOT="${DEVROOT}/SDKs/${PLATFORM}${SDK}.sdk"
export CC=${DEVROOT}/usr/bin/gcc
export LD=${DEVROOT}/usr/bin/ld
export CPP=${DEVROOT}/usr/bin/cpp
export CXX=${DEVROOT}/usr/bin/g++
unset AR
unset AS
export NM=${DEVROOT}/usr/bin/nm
export CXXCPP=${DEVROOT}/usr/bin/cpp
export RANLIB=${DEVROOT}/usr/bin/ranlib
export LDFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -L${ROOTDIR}/lib"
export CFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${ROOTDIR}/include"
export CXXFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${ROOTDIR}/include"
./configure --prefix=${ROOTDIR}
make
make install
popd

# Clean up
rm -rf "zlib-${ZLIB_VERSION}"
