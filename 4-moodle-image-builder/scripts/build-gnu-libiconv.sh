#!/bin/sh
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Builds /usr/lib/preloadable_libiconv.so on Alpine Linux (musl) so PHP's
# iconv extension uses GNU libiconv (supporting //TRANSLIT and //IGNORE,
# required by Moodle per MDL-80440) without pulling legacy Alpine v3.13 packages.
#
# Modes:
#   Default: Compiles preloadable_libiconv.so shim linked against Alpine's
#            current gnu-libiconv-dev package (/usr/lib/libiconv.so.2).
#   --from-source: Downloads and compiles GNU libiconv 1.18 from upstream source
#                  tarball and produces a standalone preloadable_libiconv.so.

set -eu

MODE="${1:---shim}"
OUTPUT_SO="${OUTPUT_SO:-/usr/lib/preloadable_libiconv.so}"
LIBICONV_VERSION="${LIBICONV_VERSION:-1.18}"

cat << 'EOF' > /tmp/preloadable_libiconv_shim.c
#include <stddef.h>

typedef void* iconv_t;

extern iconv_t libiconv_open(const char* tocode, const char* fromcode);
extern size_t libiconv(iconv_t cd, char** inbuf, size_t* inbytesleft, char** outbuf, size_t* outbytesleft);
extern int libiconv_close(iconv_t cd);

iconv_t iconv_open(const char* tocode, const char* fromcode) {
    return libiconv_open(tocode, fromcode);
}

size_t iconv(iconv_t cd, char** inbuf, size_t* inbytesleft, char** outbuf, size_t* outbytesleft) {
    return libiconv(cd, inbuf, inbytesleft, outbuf, outbytesleft);
}

int iconv_close(iconv_t cd) {
    return libiconv_close(cd);
}
EOF

if [ "$MODE" = "--from-source" ]; then
  echo "Building GNU libiconv ${LIBICONV_VERSION} from upstream source..."
  apk add --no-cache build-base curl tar
  mkdir -p /tmp/libiconv-src
  curl -fsSL "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${LIBICONV_VERSION}.tar.gz" \
    | tar -xz --strip-components=1 -C /tmp/libiconv-src
  cat /tmp/preloadable_libiconv_shim.c >> /tmp/libiconv-src/lib/compat.c
  cd /tmp/libiconv-src
  ./configure --prefix=/usr/local --enable-shared --disable-static
  make -j"$(nproc)"
  make install
  cp -f /usr/local/lib/libiconv.so.2.* "$OUTPUT_SO"
  strip --strip-unneeded "$OUTPUT_SO"
  rm -rfv /tmp/libiconv-src /tmp/preloadable_libiconv_shim.c
else
  echo "Compiling preloadable_libiconv.so against Alpine gnu-libiconv-dev..."
  apk add --no-cache build-base gnu-libiconv-dev
  gcc -O2 -shared -fPIC /tmp/preloadable_libiconv_shim.c -liconv -Wl,-soname,preloadable_libiconv.so -o "$OUTPUT_SO"
  strip --strip-unneeded "$OUTPUT_SO"
  rm -fv /tmp/preloadable_libiconv_shim.c
fi

chmod 0755 "$OUTPUT_SO"
echo "Successfully built $OUTPUT_SO"
