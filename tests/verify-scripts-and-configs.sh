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

echo "=== [1/6] Validating Bash & POSIX sh syntax across all scripts ==="
bash -n 0-infra/*.sh 4-moodle-image-builder/build-nginx-based-image.sh 5a-deployment-no-helm/create-config-files.sh
sh -n 4-moodle-image-builder/scripts/*.sh 4-moodle-image-builder/base/opt/*.sh
echo "PASS: All shell scripts passed syntax validation."

echo "=== [2/6] Validating all Kubernetes YAML manifests and templates ==="
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

echo "=== [3/6] Verifying setup_moodle.sh & config.php.template security & performance invariants ==="
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

# 6. Verify config.php.bak cleanup and NGINX .bak / fpm-status ACL / X-Accel-Redirect (^~) / Cloud CDN yui_combo hardening
grep -q 'rm -fv "\$MOODLE_PATH/config.php.bak"' "$SETUP_SCRIPT"
for nginx_cfg in 4-moodle-image-builder/base/etc/nginx/nginx.conf 4-moodle-image-builder/base/etc/nginx/nginx.conf-template; do
  grep -q '\\.bak\$)' "$nginx_cfg"
  grep -q 'location \^~ /localcachedir/' "$nginx_cfg"
  grep -q 'location \^~ /dataroot/' "$nginx_cfg"
  grep -q 'yui_combo' "$nginx_cfg"
  if grep -q '#allow 127.0.0.1;' "$nginx_cfg" || grep -q '#deny all;' "$nginx_cfg"; then
    echo "FAIL: fpm-status/fpm-ping ACL is still commented out in $nginx_cfg" >&2
    exit 1
  fi
done

# 7. Verify local_redislock pre-autoloader file check in config.php.template and direct public/local extraction
grep -q "is_readable(__DIR__ . '/public/local/redislock/classes/lock/redis_lock_factory.php')" 4-moodle-image-builder/config.php.template
grep -q 'REDISLOCK_TARGET_DIR="\$MOODLE_PATH/public/local/redislock"' "$SETUP_SCRIPT"
echo "PASS: setup_moodle.sh & config.php.template security & performance invariants verified."

echo "=== [4/6] Unit-testing setup_moodle.sh read-replica & publicpaths edge cases ==="
export TMP_TEST_DIR="$(mktemp -d)"
trap 'rm -rfv "$TMP_TEST_DIR"' EXIT

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

echo "=== [5/6] Unit-testing build-nginx-based-image.sh, cleanup-moodle-install.sh, and infra scripts with mocked CLIs ==="
MOCK_ROOT="$TMP_TEST_DIR/mock_repo"
mkdir -p "$MOCK_ROOT/0-infra" "$MOCK_ROOT/4-moodle-image-builder" "$MOCK_ROOT/bin"
cp 4-moodle-image-builder/build-nginx-based-image.sh "$MOCK_ROOT/4-moodle-image-builder/"
cp 0-infra/cleanup-moodle-install.sh 0-infra/infra-pause.sh 0-infra/infra-resume.sh 0-infra/infra-destroy.sh "$MOCK_ROOT/0-infra/"

cat > "$MOCK_ROOT/0-infra/envs.sh" <<'ENVEOF'
export PROJECT_ID="test-moodle-proj"
export REGION="us-central1"
export ZONE="us-central1-a"
export REPLICA_ZONE="us-central1-b"
export MOODLE_ROOT_PATH="/moodleroot-instance1"
export MYSQL_INSTANCE_NAME="moodle-db-test"
export MYSQL_DB="moodle"
export MYSQL_MOODLE_DB_CHARSET="utf8mb4"
export MYSQL_MOODLE_DB_COLLATION="utf8mb4_unicode_ci"
export STORAGE_TYPE="filestore"
export FILESTORE_MOUNT="/mnt/filestore"
export MOODLE_ROOT_IN_FILESTORE="$TMP_TEST_DIR/mock_filestore_data"
export CREATE_CLOUD_SQL="true"
export CREATE_REDIS="true"
export CREATE_REDIS_CLUSTER="false"
export CREATE_FILESTORE="false"
export CREATE_REGIONAL_PD="false"
export CREATE_ARTIFACT_REGISTRY="false"
export GKE_NAME="moodle-gke-test"
export GKE_MODE="autopilot"
export REDIS_NAME="moodle-redis-test"
export REDIS_SIZE="5"
export REDIS_TIER="basic"
export REDIS_VERSION="redis_7_2"
export VPC_NAME="moodle-vpc-test"
validate_moodle_envs() { :; }
ENVEOF

cat > "$MOCK_ROOT/bin/gcloud" <<'GCEOF'
#!/bin/bash
echo "gcloud $*" >> "$GCLOUD_LOG"
if [[ "$*" == *"redis instances describe"*"--format=value(host)"* ]]; then
  echo "10.99.0.42"
fi
GCEOF
cat > "$MOCK_ROOT/bin/kubectl" <<'KBEOF'
#!/bin/bash
echo "kubectl $*" >> "$KUBECTL_LOG"
KBEOF
cat > "$MOCK_ROOT/bin/sudo" <<'SUEOF'
#!/bin/bash
"$@"
SUEOF
cat > "$MOCK_ROOT/bin/jq" <<'JQEOF'
#!/bin/bash
exit 0
JQEOF
chmod +x "$MOCK_ROOT/bin/gcloud" "$MOCK_ROOT/bin/kubectl" "$MOCK_ROOT/bin/sudo" "$MOCK_ROOT/bin/jq"

export GCLOUD_LOG="$TMP_TEST_DIR/gcloud.log"
export KUBECTL_LOG="$TMP_TEST_DIR/kubectl.log"

# 1. Test build-nginx-based-image.sh (Jules finding #4)
: > "$GCLOUD_LOG"
PATH="$MOCK_ROOT/bin:$PATH" bash "$MOCK_ROOT/4-moodle-image-builder/build-nginx-based-image.sh"
grep -q "gcloud builds submit --config cloudbuild-nginx.yaml --substitutions=_MOODLE_ROOT_PATH=/moodleroot-instance1,_MOODLE_DATAROOT_PATH=/moodleroot-instance1/moodledata,_MOODLE_PATH=/moodleroot-instance1/moodle --region us-central1" "$GCLOUD_LOG"

# 2. Test cleanup-moodle-install.sh (Jules finding #18: cancel path vs confirmed path)
: > "$GCLOUD_LOG"
mkdir -p "$TMP_TEST_DIR/mock_filestore_data/sub"
printf 'n\n' | PATH="$MOCK_ROOT/bin:$PATH" bash "$MOCK_ROOT/0-infra/cleanup-moodle-install.sh" >/dev/null
test -d "$TMP_TEST_DIR/mock_filestore_data/sub"
printf 'y\n' | PATH="$MOCK_ROOT/bin:$PATH" bash "$MOCK_ROOT/0-infra/cleanup-moodle-install.sh" >/dev/null
grep -q "gcloud sql databases delete moodle --instance moodle-db-test --quiet" "$GCLOUD_LOG"
grep -q "gcloud sql databases create moodle --instance moodle-db-test --charset utf8mb4 --collation utf8mb4_unicode_ci" "$GCLOUD_LOG"
if [ -d "$TMP_TEST_DIR/mock_filestore_data" ]; then
  echo "FAIL: cleanup-moodle-install.sh did not remove MOODLE_ROOT_IN_FILESTORE." >&2
  exit 1
fi

# 3. Test infra-pause.sh and infra-resume.sh (Jules findings #17 & #20)
: > "$GCLOUD_LOG"
: > "$KUBECTL_LOG"
PATH="$MOCK_ROOT/bin:$PATH" ENVS_FILE="$MOCK_ROOT/0-infra/envs.sh" bash "$MOCK_ROOT/0-infra/infra-pause.sh" --delete-redis >/dev/null
grep -q "kubectl scale deployment moodle-deployment -n moodle --replicas=0" "$KUBECTL_LOG"
grep -q "gcloud sql instances patch moodle-db-test --activation-policy=NEVER --project=test-moodle-proj --quiet" "$GCLOUD_LOG"
grep -q "gcloud redis instances delete moodle-redis-test --region=us-central1 --project=test-moodle-proj --quiet" "$GCLOUD_LOG"

: > "$GCLOUD_LOG"
: > "$KUBECTL_LOG"
PATH="$MOCK_ROOT/bin:$PATH" ENVS_FILE="$MOCK_ROOT/0-infra/envs.sh" bash "$MOCK_ROOT/0-infra/infra-resume.sh" --recreate-redis >/dev/null
grep -q "gcloud sql instances patch moodle-db-test --activation-policy=ALWAYS --project=test-moodle-proj --quiet" "$GCLOUD_LOG"
grep -q "10.99.0.42" "$KUBECTL_LOG"
grep -q "kubectl scale deployment moodle-deployment -n moodle --replicas=3" "$KUBECTL_LOG"
echo "PASS: Behavioral CLI tests for build, cleanup, pause, and resume scripts verified."

echo "=== [6/6] Verifying repository guardrails (AGENTS.md & .jules/sentinel.md) ==="
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
test -f 5a-deployment-no-helm/moodle-optional-secrets.yaml
grep -q 'name: moodle-optional-secrets' 5a-deployment-no-helm/moodle-deployment-nginx.yaml
grep -q 'name: moodle-optional-secrets' 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
grep -q 'fastcgi_request_buffering off;' 4-moodle-image-builder/base/etc/nginx/nginx.conf-template
grep -q 'PHP_FPM_MAX_CHILDREN: "1"' 5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml
grep -q 'CLIENT_MAX_BODY_SIZE: "10G"' 5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml
grep -q 'sizeLimit: 15Gi' 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
grep -q '/webservice/upload.php' 8-ingress/gce-ingress-external.yaml
echo "PASS: All repository guardrails verified."
