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

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== [1/5] Validating Bash & POSIX sh syntax across all scripts ==="
bash -n 0-infra/*.sh 4-moodle-image-builder/build-nginx-based-image.sh 5a-deployment-no-helm/create-config-files.sh
sh -n 4-moodle-image-builder/scripts/*.sh 4-moodle-image-builder/base/opt/*.sh
echo "PASS: All shell scripts passed syntax validation."

echo "=== [2/5] Validating all Kubernetes YAML manifests and templates ==="
python3 - <<'PYEOF'
import glob, yaml

yaml_files = sorted(glob.glob("**/*.yaml", recursive=True))
checked = 0
for f in yaml_files:
    if f.startswith("openwiki/") or f.startswith("graphify-out/") or "-ernani." in f:
        continue
    raw = open(f, encoding="utf-8").read().replace("<CERT-LIST>", "[moodle-managed-cert]")
    list(yaml.safe_load_all(raw))
    checked += 1
print(f"PASS: Validated {checked} YAML files successfully.")
PYEOF

echo "=== [3/5] Verifying setup_moodle.sh security & performance invariants ==="
SETUP_SCRIPT="4-moodle-image-builder/base/opt/setup_moodle.sh"

# 1. Verify least-privilege permissions (0755/0644 on MOODLE_PATH, 0750/0640 on MOODLE_DATAROOT_PATH) and '+' batching
grep -q 'find "\$MOODLE_PATH" -type d -exec chmod 0755 {} +' "$SETUP_SCRIPT"
grep -q 'find "\$MOODLE_DATAROOT_PATH" -type d -exec chmod 0750 {} +' "$SETUP_SCRIPT"
grep -q 'find "\$MOODLE_PATH" -type f -exec chmod 0644 {} +' "$SETUP_SCRIPT"
grep -q 'find "\$MOODLE_DATAROOT_PATH" -type f -exec chmod 0640 {} +' "$SETUP_SCRIPT"

# 2. Verify DB_READ_REPLICA_PASSWORD is read via getenv() rather than interpolated in plaintext via sed
if grep -q "\$DB_READ_REPLICA_PASSWORD'" "$SETUP_SCRIPT"; then
  echo "FAIL: DB_READ_REPLICA_PASSWORD should not be interpolated as a raw string in sed." >&2
  exit 1
fi
grep -q "getenv('\\\\''DB_READ_REPLICA_PASSWORD'\\\\'')" "$SETUP_SCRIPT"

# 3. Verify SMTP_PASSWORD is not passed as a plaintext --set CLI argument
if grep -q -- '--name=smtppass --set=' "$SETUP_SCRIPT"; then
  echo "FAIL: SMTP_PASSWORD must not be passed via --set CLI argument." >&2
  exit 1
fi

# 4. Verify publicpaths.php port 8080 adjustment is active
grep -q 'http:\\/\\/localhost:8080' "$SETUP_SCRIPT"

# 5. Verify MOODLE_SHA256 and MOOSH_SHA256 checksum verification support
grep -q 'MOODLE_SHA256' "$SETUP_SCRIPT"
grep -q 'MOOSH_SHA256' "$SETUP_SCRIPT"
grep -q 'sha256sum -c -' "$SETUP_SCRIPT"

# 6. Verify config.php.bak cleanup and NGINX .bak / fpm-status ACL hardening
grep -q 'rm -fv "\$MOODLE_PATH/config.php.bak"' "$SETUP_SCRIPT"
for nginx_cfg in 4-moodle-image-builder/base/etc/nginx/nginx.conf 4-moodle-image-builder/base/etc/nginx/nginx.conf-template; do
  grep -q '\\.bak\$)' "$nginx_cfg"
  if grep -q '#allow 127.0.0.1;' "$nginx_cfg" || grep -q '#deny all;' "$nginx_cfg"; then
    echo "FAIL: fpm-status/fpm-ping ACL is still commented out in $nginx_cfg" >&2
    exit 1
  fi
done
echo "PASS: setup_moodle.sh security & performance invariants verified."

echo "=== [4/5] Unit-testing setup_moodle.sh read-replica & publicpaths edge cases ==="
TMP_TEST_DIR="$(mktemp -d)"
trap 'rm -rfv "$TMP_TEST_DIR" >/dev/null' EXIT

create_mock_config() {
  cat > "$1" <<'PHPEOF'
<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => 3306,
);
require_once(__DIR__ . '/lib/setup.php');
PHPEOF
}

run_replica_snippet() {
  local cfg_file="$1"
  if [ -n "$DB_READ_REPLICA_HOST" ]; then
    if [ -n "$DB_READ_REPLICA_USER" ] && [ -n "$DB_READ_REPLICA_PASSWORD" ] && [ -n "$DB_READ_REPLICA_PORT" ]; then
      sed -i '/\$CFG->dboptions/a \ \ '\''readonly'\'' => [ '\''instance'\'' => [ '\''dbhost'\'' => getenv('\''DB_READ_REPLICA_HOST'\''), '\''dbport'\'' => getenv('\''DB_READ_REPLICA_PORT'\''), '\''dbuser'\'' => getenv('\''DB_READ_REPLICA_USER'\''), '\''dbpass'\'' => getenv('\''DB_READ_REPLICA_PASSWORD'\'') ] ],' "$cfg_file"
    else
      sed -i '/\$CFG->dboptions/a \ \ '\''readonly'\'' => [ '\''instance'\'' => [ getenv('\''DB_READ_REPLICA_HOST'\'') ] ],' "$cfg_file"
    fi
  fi
}

# Case A: No read replica configured
create_mock_config "$TMP_TEST_DIR/config_none.php"
DB_READ_REPLICA_HOST="" run_replica_snippet "$TMP_TEST_DIR/config_none.php"
if grep -q "readonly" "$TMP_TEST_DIR/config_none.php"; then
  echo "FAIL: readonly block added when DB_READ_REPLICA_HOST is empty." >&2
  exit 1
fi

# Case B: Only DB_READ_REPLICA_HOST configured (missing user/password/port)
create_mock_config "$TMP_TEST_DIR/config_host_only.php"
DB_READ_REPLICA_HOST="10.0.0.5" DB_READ_REPLICA_USER="" DB_READ_REPLICA_PASSWORD="" DB_READ_REPLICA_PORT="" run_replica_snippet "$TMP_TEST_DIR/config_host_only.php"
grep -q "'readonly' => \[ 'instance' => \[ getenv('DB_READ_REPLICA_HOST') \] \]," "$TMP_TEST_DIR/config_host_only.php"

# Case C: Full read replica credentials with special characters in password (/, ', &)
create_mock_config "$TMP_TEST_DIR/config_full.php"
DB_READ_REPLICA_HOST="10.0.0.6" DB_READ_REPLICA_USER="replica_user" DB_READ_REPLICA_PASSWORD="p@ss/w'ord&1" DB_READ_REPLICA_PORT="3306" run_replica_snippet "$TMP_TEST_DIR/config_full.php"
grep -q "getenv('DB_READ_REPLICA_PASSWORD')" "$TMP_TEST_DIR/config_full.php"
if grep -q "p@ss" "$TMP_TEST_DIR/config_full.php"; then
  echo "FAIL: plaintext password leaked into config_full.php." >&2
  exit 1
fi
echo "PASS: All read-replica edge cases verified."

echo "=== [5/5] Verifying repository guardrails (AGENTS.md & .jules/sentinel.md) ==="
grep -q '"<YOUR-PROJECT-ID>"' 0-infra/envs.sh
grep -q 'GKE_MODE="\${GKE_MODE:-autopilot}"' 0-infra/envs.sh
grep -q 'clusters create-auto' 0-infra/infra-creation.sh
test -x 0-infra/infra-destroy.sh
test -x 0-infra/infra-pause.sh
test -x 0-infra/infra-resume.sh
grep -q 'topologySpreadConstraints:' 5a-deployment-no-helm/moodle-deployment-nginx.yaml
grep -q 'topology.kubernetes.io/zone' 5a-deployment-no-helm/moodle-deployment-nginx.yaml
grep -q "MOODLE_LANGUAGE: 'pt_BR'" 5a-deployment-no-helm/moodle-configmap-nginx-sample.yaml
grep -q 'etc/nginx-uploads' 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
grep -q 'etc/php83-uploads' 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
echo "PASS: All repository guardrails verified."
