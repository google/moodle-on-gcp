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

echo "=== [4b/6] Unit-testing declarative MOODLE_AUTOUPGRADE reconciliation & double-checked locking ==="
(
  AUTOUPG_TEST_DIR="$TMP_TEST_DIR/autoupgrade_test"
  mkdir -p "$AUTOUPG_TEST_DIR/bin" "$AUTOUPG_TEST_DIR/moodle/public/report/customtest" \
           "$AUTOUPG_TEST_DIR/moodle/public/local/redislock" "$AUTOUPG_TEST_DIR/moodle/admin/cli" \
           "$AUTOUPG_TEST_DIR/moodledata" "$AUTOUPG_TEST_DIR/fixtures"
  UPGRADE_LOG="$AUTOUPG_TEST_DIR/upgrade_calls.log"
  : > "$UPGRADE_LOG"

  # Mock sudo, composer, and php83 so moodle_autoupgrade_lib.sh runs unprivileged
  cat > "$AUTOUPG_TEST_DIR/bin/sudo" <<'SUDOEOF'
#!/bin/sh
if [ "$1" = "-u" ]; then
  shift 2
fi
exec "$@"
SUDOEOF
  cat > "$AUTOUPG_TEST_DIR/bin/composer" <<'COMPEOF'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    --working-dir=*)
      wdir="${arg#--working-dir=}"
      mkdir -p "$wdir/vendor"
      echo "<?php // autoload" > "$wdir/vendor/autoload.php"
      ;;
  esac
done
exit 0
COMPEOF
  cat > "$AUTOUPG_TEST_DIR/bin/php83" <<PHPEOF
#!/bin/sh
echo "\$*" >> "$UPGRADE_LOG"
exit 0
PHPEOF
  chmod +x "$AUTOUPG_TEST_DIR/bin/sudo" "$AUTOUPG_TEST_DIR/bin/composer" "$AUTOUPG_TEST_DIR/bin/php83"
  export PATH="$AUTOUPG_TEST_DIR/bin:$PATH"

  export MOODLE_PATH="$AUTOUPG_TEST_DIR/moodle"
  export MOODLE_DATAROOT_PATH="$AUTOUPG_TEST_DIR/moodledata"
  export MOODLE_UPGRADE_LOCK_POLL_SECS=1

  # Seed an existing Moodle 5.2.4 installation with a custom plugin and an obsolete 5.2.4 file
  cat > "$MOODLE_PATH/public/version.php" <<'VEREOF'
<?php
$release  = '5.2.4 (Build: 20261001)';
VEREOF
  echo "<?php // custom config" > "$MOODLE_PATH/config.php"
  chmod 0444 "$MOODLE_PATH/config.php"
  echo "<?php // custom plugin" > "$MOODLE_PATH/public/report/customtest/version.php"
  echo "<?php // redislock" > "$MOODLE_PATH/public/local/redislock/version.php"
  echo "obsolete-in-5.2.5" > "$MOODLE_PATH/old_524_only.php"
  touch "$MOODLE_DATAROOT_PATH/.moodle-installed"

  # Build a realistic Moodle 5.2.5 release tarball fixture
  PKG_SRC="$AUTOUPG_TEST_DIR/fixtures/moodle-5.2.5"
  mkdir -p "$PKG_SRC/public/report/log" "$PKG_SRC/public/local" \
           "$PKG_SRC/public/lib/classes/check/environment" "$PKG_SRC/admin/cli"
  cat > "$PKG_SRC/public/version.php" <<'VER2EOF'
<?php
$release  = '5.2.5 (Build: 20261115)';
VER2EOF
  echo '{"name":"moodle/moodle"}' > "$PKG_SRC/composer.json"
  echo '<?php $url = $CFG->wwwroot;' > "$PKG_SRC/public/lib/classes/check/environment/publicpaths.php"
  for cli_f in maintenance.php upgrade.php build_theme_css.php; do
    echo "<?php // $cli_f" > "$PKG_SRC/admin/cli/$cli_f"
  done
  TARBALL_525="$AUTOUPG_TEST_DIR/fixtures/v5.2.5.tar.gz"
  tar -czf "$TARBALL_525" -C "$AUTOUPG_TEST_DIR/fixtures" moodle-5.2.5
  SHA256_525="$(sha256sum "$TARBALL_525" | awk '{print $1}')"

  . "$REPO_ROOT/4-moodle-image-builder/base/opt/moodle_autoupgrade_lib.sh"

  # 1. Steady-state bootstrap: disk=5.2.4 and MOODLE_URL=v5.2.4.tar.gz -> bootstraps state, 0 upgrades
  export MOODLE_URL="file://$AUTOUPG_TEST_DIR/fixtures/v5.2.4.tar.gz"
  export MOODLE_SHA256="deadbeef"
  export MOODLE_AUTOUPGRADE="true"
  moodle_reconcile_autoupgrade
  test -f "$MOODLE_DATAROOT_PATH/.moodle-version-state"
  if grep -q "upgrade.php" "$UPGRADE_LOG"; then
    echo "FAIL: upgrade.php should not run when disk version already matches MOODLE_URL." >&2
    exit 1
  fi

  # 2. Default opt-out (MOODLE_AUTOUPGRADE=false): changing MOODLE_URL to 5.2.5 must NOT upgrade
  export MOODLE_URL="file://$TARBALL_525"
  export MOODLE_SHA256="$SHA256_525"
  export MOODLE_AUTOUPGRADE="false"
  moodle_reconcile_autoupgrade
  grep -q "5.2.4" "$MOODLE_PATH/public/version.php"

  # 3. Declarative upgrade (MOODLE_AUTOUPGRADE=true): upgrades 5.2.4 -> 5.2.5, preserves config.php & custom plugins, prunes old file
  export MOODLE_AUTOUPGRADE="true"
  moodle_reconcile_autoupgrade
  grep -q "5.2.5" "$MOODLE_PATH/public/version.php"
  test -f "$MOODLE_PATH/vendor/autoload.php"
  test -f "$MOODLE_PATH/public/report/customtest/version.php"
  test -f "$MOODLE_PATH/public/local/redislock/version.php"
  grep -q "custom config" "$MOODLE_PATH/config.php"
  grep -q 'http://localhost:8080' "$MOODLE_PATH/public/lib/classes/check/environment/publicpaths.php"
  if [ -e "$MOODLE_PATH/old_524_only.php" ]; then
    echo "FAIL: Obsolete file from 5.2.4 was not removed during staging swap." >&2
    exit 1
  fi
  if [ -d "$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock" ]; then
    echo "FAIL: .moodle-upgrade.lock was not cleaned up after successful upgrade." >&2
    exit 1
  fi
  UPGRADE_COUNT_AFTER_FIRST="$(grep -c 'upgrade.php' "$UPGRADE_LOG")"
  [ "$UPGRADE_COUNT_AFTER_FIRST" -eq 1 ]

  # 4. Subsequent boot with MOODLE_AUTOUPGRADE=true still set -> 0 extra upgrades (no infinite loop!)
  moodle_reconcile_autoupgrade
  [ "$(grep -c 'upgrade.php' "$UPGRADE_LOG")" -eq 1 ]

  # 5. Follower pod waiting on active .moodle-upgrade.lock skips duplicate upgrade once leader updates state
  echo "old-state" > "$MOODLE_DATAROOT_PATH/.moodle-version-state"
  mkdir -p "$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock"
  date +%s > "$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock/started_at"
  (
    sleep 1
    printf '%s|%s\n' "$MOODLE_URL" "$MOODLE_SHA256" > "$MOODLE_DATAROOT_PATH/.moodle-version-state"
    rm -rfv "$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock" >/dev/null
  ) &
  BG_LEADER_PID=$!
  moodle_reconcile_autoupgrade
  wait "$BG_LEADER_PID"
  [ "$(grep -c 'upgrade.php' "$UPGRADE_LOG")" -eq 1 ]

  # 6. Stale lock (> max age) is automatically cleaned up
  mkdir -p "$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock"
  echo $(( $(date +%s) - 2000 )) > "$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock/started_at"
  MOODLE_UPGRADE_LOCK_MAX_AGE=900 moodle_clean_stale_lock
  if [ -d "$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock" ]; then
    echo "FAIL: Stale .moodle-upgrade.lock was not cleaned up." >&2
    exit 1
  fi
)
echo "PASS: Declarative MOODLE_AUTOUPGRADE reconciliation & locking verified."

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
grep -q 'php83-pgsql php83-pdo_pgsql' 4-moodle-image-builder/Dockerfile.nginx
grep -q '02_pgsql.ini' 4-moodle-image-builder/base/opt/setup_moodle.sh
grep -q 'POSTGRES_DATABASE_VERSION' 0-infra/envs.sh
grep -q 'session_redis_serializer_use_igbinary = true' 4-moodle-image-builder/config.php.template
grep -q "session_redis_compressor = 'zstd'" 4-moodle-image-builder/config.php.template
grep -q 'routerconfigured = true' 4-moodle-image-builder/config.php.template
grep -q 'try_files \$uri \$uri/ /r.php;' 4-moodle-image-builder/base/etc/nginx/nginx.conf-template
grep -q 'try_files \$fastcgi_script_name /r.php;' 4-moodle-image-builder/base/etc/nginx/nginx.conf-template
test -f 5a-deployment-no-helm/moodle-proxysql.yaml
grep -q 'multiplexing=true' 5a-deployment-no-helm/moodle-proxysql.yaml
grep -q 'startupProbe:' 5a-deployment-no-helm/moodle-deployment-nginx.yaml
grep -q 'readinessProbe:' 5a-deployment-no-helm/moodle-deployment-nginx.yaml
grep -q 'livenessProbe:' 5a-deployment-no-helm/moodle-deployment-nginx.yaml
grep -q 'maxUnavailable: 0' 5a-deployment-no-helm/moodle-deployment-nginx.yaml
grep -q 'startupProbe:' 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
test -f .github/dependabot.yml
test -f .github/workflows/moodle-semver-updater.yml
python3 4-moodle-image-builder/scripts/update-moodle-semver.py --dry-run >/dev/null
# Coordinated Moodle + Alpine updates: Dependabot must not open separate Alpine PRs,
# and Alpine bumps must be smoke-tested and opened under a CLA-covered identity.
grep -q 'dependency-name: "alpine"' .github/dependabot.yml
grep -q 'MOODLE_UPDATER_TOKEN' .github/workflows/moodle-semver-updater.yml
grep -q './tests/smoke-test-container-image.sh' .github/workflows/moodle-semver-updater.yml
bash -n tests/smoke-test-container-image.sh
grep -q "MOODLE_AUTOUPGRADE: 'false'" 5a-deployment-no-helm/moodle-configmap-nginx.yaml
grep -q "MOODLE_AUTOUPGRADE: 'false'" 5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml
grep -q 'key: MOODLE_AUTOUPGRADE' 5a-deployment-no-helm/moodle-deployment-nginx.yaml
grep -q 'key: MOODLE_SHA256' 5a-deployment-no-helm/moodle-deployment-nginx.yaml
test -f 4-moodle-image-builder/base/opt/moodle_autoupgrade_lib.sh
echo "PASS: All repository guardrails verified."
