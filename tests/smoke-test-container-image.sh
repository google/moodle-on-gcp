#!/bin/bash
# Copyright 2026 Google LLC
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
# Builds 4-moodle-image-builder/Dockerfile.nginx and smoke-tests the image
# without a database, Redis, or Kubernetes. It is used by the
# `Moodle SemVer Auto-Updater` workflow before it proposes an Alpine bump, and
# it can be run locally with Docker or Podman:
#
#   ./tests/smoke-test-container-image.sh
#   CONTAINER_CLI=podman ./tests/smoke-test-container-image.sh
#
# Checks: Alpine release, PHP 8.3 CLI + every extension Moodle needs, the GNU
# libiconv //TRANSLIT preload, the repository NGINX template (`nginx -t`), and
# the PHP-FPM pool configuration (`php-fpm83 -t`).
set -euo pipefail

CONTAINER_CLI="${CONTAINER_CLI:-docker}"
IMAGE_TAG="${IMAGE_TAG:-moodle-on-gcp-smoke-test:local}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_CONTEXT="${REPO_ROOT}/4-moodle-image-builder"

echo "[1/2] Building ${IMAGE_TAG} from ${BUILD_CONTEXT}/Dockerfile.nginx with ${CONTAINER_CLI}..."
"${CONTAINER_CLI}" build -f "${BUILD_CONTEXT}/Dockerfile.nginx" -t "${IMAGE_TAG}" "${BUILD_CONTEXT}"

echo "[2/2] Smoke-testing ${IMAGE_TAG}..."
# shellcheck disable=SC2016 # the script below is expanded inside the container
"${CONTAINER_CLI}" run --rm --entrypoint /bin/sh "${IMAGE_TAG}" -c '
  set -eu
  echo "Alpine $(cat /etc/alpine-release)"
  php -v | head -n 1
  nginx -v 2>&1

  modules="$(php -m)"
  for ext in ctype curl dom exif fileinfo gd iconv intl mbstring mysqli openssl pdo_mysql \
             pdo_pgsql pgsql phar posix session simplexml soap sockets sodium tokenizer xml \
             xmlreader xmlwriter zip apcu igbinary redis zstd "Zend OPcache"; do
    if ! printf "%s\n" "${modules}" | grep -qix "${ext}"; then
      echo "FAIL: PHP extension not loaded: ${ext}" >&2
      exit 1
    fi
  done
  echo "PASS: all required PHP extensions are loaded"

  php -r "exit(iconv(\"UTF-8\", \"ASCII//TRANSLIT\", \"Olá\") === false ? 1 : 0);"
  echo "PASS: GNU libiconv //TRANSLIT preload works"

  mkdir -p /tmp/nginx /run/nginx
  cp -R /root/etc/nginx/* /etc/nginx/
  envsubst "\$MOODLE_ROOT_PATH" < /etc/nginx/nginx.conf-template > /etc/nginx/nginx.conf
  if ! nginx_test="$(nginx -t 2>&1)"; then
    # Rootless Podman without a subordinate UID range cannot chown the temp paths to
    # the `www` user (EINVAL). Only in that case, re-test with `user root;`.
    if printf "%s\n" "${nginx_test}" | grep -q "syntax is ok" \
        && printf "%s\n" "${nginx_test}" | grep -q "chown(.*failed (22: Invalid argument)"; then
      echo "WARN: nginx -t could not chown temp paths to user www (user namespace without UID 1000); re-testing with user root" >&2
      sed "s/^\([[:space:]]*user[[:space:]]\{1,\}\)[^;]*;/\1root;/" /etc/nginx/nginx.conf > /etc/nginx/nginx-smoke-test.conf
      nginx -t -c /etc/nginx/nginx-smoke-test.conf
    else
      printf "%s\n" "${nginx_test}" >&2
      exit 1
    fi
  else
    printf "%s\n" "${nginx_test}"
  fi

  cp -R /root/etc/php83/* /etc/php83/
  envsubst "\$MOODLE_ROOT_PATH" < /etc/php83/php.ini-template > /etc/php83/php.ini
  php-fpm83 -t
  echo "PASS: container image smoke test completed"
'
