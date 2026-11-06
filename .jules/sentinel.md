# Sentinel's Journal — Security, Hardening & Review Guardrails (`google/moodle-on-gcp`)

This journal records all security vulnerabilities, architectural invariants, and human review guardrails discovered across PRs `#35`, `#36`, `#37`, `#38`, `#42`, and the linearized PR stack `#43`–`#47`.

> **CRITICAL FOR JULES / SENTINEL / AUTOMATED AGENTS**:
> Never delete or overwrite earlier entries in `.jules/sentinel.md` during rebases, and strictly obey the **Human Review Guardrails (from PR #38 — 110 Inline Comments)** below before modifying any file in this repository.

---

## Chronological Security & Hardening Learnings

## 2026-05-14 — Shell Script Input Validation & Command Injection Prevention (`PR #35`, `PR #38`, `PR #44`)
**Vulnerability:** Unvalidated environment variables passed directly into `sed -i` expressions (`s|VAR|${VALUE}|g`) or `kubectl` / `gcloud` commands in `4-moodle-image/scripts/setup_moodle.sh` and `0-infra/*.sh` could break command syntax or allow command injection if values contain pipe (`|`), ampersand (`&`), or shell metacharacters. Additionally, scripts lacked `set -eo pipefail` and used `#!/bin/sh` despite relying on bashisms (`read -s`, `[[ ... ]]`).
**Learning:** Startup scripts and infrastructure provisioning scripts must fail closed before executing `envsubst`, `sed`, `gcloud`, or `kubectl`.
**Resolution (Merged in `d83451e` / `PR #44`):**
- Added `validate_moodle_envs()` in `4-moodle-image/scripts/setup_moodle.sh` to enforce:
  - Numeric validation (`^[0-9]+$`) for `MOODLE_MAX_INPUT_VARS`, `MOODLE_POST_MAX_SIZE`, `MOODLE_UPLOAD_MAX_FILESIZE`, and `MOODLE_MEMORY_LIMIT`.
  - Locale validation (`^[a-zA-Z0-9_-]+$`) for `MOODLE_LANGUAGE`.
- Standardized all `0-infra/*.sh` and `5a-deployment-no-helm/create-config-files.sh` scripts to `#!/bin/bash` with `set -eo pipefail`.
- Escaped `&` and `\` in `sed` replacements in `5a-deployment-no-helm/create-config-files.sh`.

## 2026-05-15 — Hardcoded Secrets & Interactive Secret Prompting (`PR #37`, `PR #38`, `PR #44`)
**Vulnerability:** `0-infra/envs.sh` and `5a-deployment-no-helm/create-config-files.sh` previously encouraged storing plaintext passwords (`MYSQL_ROOT_PASSWORD`, `MOODLE_MYSQL_USER_PASSWORD`, `MOODLE_ADMIN_PASSWORD`, `SMTP_PASSWORD`) directly in shell scripts or committed YAML manifests, and `0-infra/infra-creation.sh` had a duplicated `MYSQL_ROOT_PASSWORD` prompt.
**Learning:** Secret variables should default to empty strings `""` in versioned configuration files (`0-infra/envs.sh`, `5a-deployment-no-helm/create-config-files.sh`) and be prompted interactively via `read -s -p` at runtime if unset, then stored in Kubernetes `Secret` resources (`secretKeyRef`).
**Resolution (Merged in `d83451e` / `PR #44`):**
- Deduplicated the `MYSQL_ROOT_PASSWORD` prompt in `0-infra/infra-creation.sh`.
- Added interactive `read -s -p` prompts for `MYSQL_ROOT_PASSWORD`, `MOODLE_MYSQL_USER_PASSWORD`, `MOODLE_ADMIN_PASSWORD`, and `SMTP_PASSWORD` in `5a-deployment-no-helm/create-config-files.sh`.
- Removed `7-helm/` (which contained hardcoded example passwords in `moodle-values.yaml`) and deprecated Bitnami references in `a16528b` (`PR #43`).

## 2026-10-25 — Unquoted Angle-Bracket Placeholders in `0-infra/envs.sh` (`PR #38`, `PR #44`)
**Vulnerability:** Unquoted instructional placeholders such as `export PROJECT_ID=<YOUR-PROJECT-ID>` in `0-infra/envs.sh` are parsed by Bash as stdin/stdout redirection operators (`<` and `>`), causing syntax errors or unintended file creation if a user sources `envs.sh` before editing every variable.
**Learning:** Instructional placeholders in shell files MUST be preserved verbatim (so users and `create-config-files.sh` can identify unconfigured fields) AND wrapped in double quotes (e.g., `export PROJECT_ID="<YOUR-PROJECT-ID>"`).
**Resolution (Merged in `d83451e` / `PR #44`):**
- Quoted all `<YOUR-...>` placeholders in `0-infra/envs.sh` while preserving their exact `<YOUR-...>` placeholder names.

## 2026-11-05 — Moodle 5.2+ Public Webroot (`MDL-83424`), `gnu-libiconv`, and Cloud CDN Cookie Stripping (`PR #42`, `PR #45`, `PR #47`)
**Vulnerability / Architectural Shift:**
1. Moodle 5.1+ (`MDL-83424`) relocated all web-accessible entrypoints into `/var/www/html/moodle/public` while keeping libraries and `config.php` one level above (`/var/www/html/moodle`). Pointing NGINX `root` to `/var/www/html/moodle` on Moodle 5.1+ either breaks routing (`404`) or exposes internal library paths.
2. Alpine Linux's musl `iconv()` lacks `//IGNORE` and `//TRANSLIT` support required by Moodle and Moosh (`PR #42`).
3. Enabling Google Cloud CDN with `CACHE_ALL_STATIC` without stripping `Set-Cookie` on static asset loaders (`/theme/*`, `/lib/javascript.php`, `/lib/requirejs.php`) risks either zero cache hits or caching user-identifying `MoodleSession` cookies at the edge (`Issue #33`).
**Resolution (Merged in `0be3f74` / `PR #45` and `de2bd94` / `PR #47`):**
- Multi-stage `4-moodle-image/Dockerfile` compiles GNU `libiconv 1.18` (`preloadable_libiconv.so`) in a separate builder stage and injects it via `ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so` on PHP `8.3.36` (`alpine:3.21`), Moodle `v5.2.4`, and Moosh `1.51`.
- NGINX `root` points to `/var/www/html/moodle/public` (with automatic fallback to `/var/www/html/moodle` in `setup_moodle.sh` if `public/` does not exist).
- `BackendConfig` uses `cacheMode: USE_ORIGIN_HEADERS`, while NGINX strips `Set-Cookie` (`fastcgi_hide_header Set-Cookie;`) on `/theme/`, `/lib/javascript.php`, `/lib/requirejs.php`, `/lib/font.php`, and `/pix/`, and enforces `Cache-Control: private, no-store, no-cache, must-revalidate` on `/pluginfile.php` and `/draftfile.php`.

---

## Mandatory Guardrails for Jules & Coding Agents (Learned from PR #38 Review)

1. **NEVER Replace `<YOUR-...>` or `<ANGLE_BRACKETS>` Placeholders with Dummy Values**:
   - In `0-infra/envs.sh` and `5a-deployment-no-helm/moodle-configmap-nginx*.yaml`, placeholders like `"<YOUR-PROJECT-ID>"`, `"<IPV4-FROM-CLOUD-SQL>"`, `"<NAME-OF-YOUR-DOMAIN-LIKE-example.com>"`, and `<CERT-LIST>` are intentional template markers replaced by users or `5a-deployment-no-helm/create-config-files.sh`. Never replace them with `moodle-project-12345`, `10.119.0.3`, `moodle.example.com`, etc.
2. **Keep `REDIS_*` Variables Blank in Template YAML Manifests**:
   - In `5a-deployment-no-helm/moodle-configmap-nginx.yaml` and `moodle-configmap-nginx-sample.yaml`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_AUTH`, `REDIS_SSL`, and `REDIS_CLUSTER_MODE` must remain `""` (empty) by default because Redis configuration is optional and applied dynamically or documented in `docs/configuring-redis-cache-with-moodle.md`.
3. **Preserve `MOODLE_LANGUAGE: "pt-BR"` in `moodle-configmap-nginx-sample.yaml`**:
   - `moodle-configmap-nginx.yaml` defaults to `"en"`, whereas `moodle-configmap-nginx-sample.yaml` intentionally demonstrates `"pt-BR"`. Do not overwrite `"pt-BR"` with `"en"` in the sample file.
4. **Preserve Separate PVC `subPath` Directories for Upload Pods**:
   - `moodle-deployment` mounts `etc/nginx` and `etc/php83`.
   - `moodle-deployment-uploads` MUST mount `etc/nginx-uploads` and `etc/php83-uploads`. Mounting the same `subPath` causes `setup_moodle.sh`'s `sed -i` overrides (`MOODLE_UPLOAD_MAX_FILESIZE: "2048"`) to clobber the main web pods' `php.ini` and `nginx.conf` on shared storage.
5. **Keep `php.ini` and `nginx.conf` Dynamic `sed -i` Overrides Immediately After `envsubst` in `setup_moodle.sh`**:
   - In `4-moodle-image/scripts/setup_moodle.sh`, the `sed -i` blocks that apply `MOODLE_MAX_INPUT_VARS`, `MOODLE_POST_MAX_SIZE`, `MOODLE_UPLOAD_MAX_FILESIZE`, and `MOODLE_MEMORY_LIMIT` MUST remain immediately after `envsubst` (around line 83), before NGINX and PHP-FPM start. Do not move them to the bottom of `setup_moodle.sh`.
6. **Never Revert NGINX and PHP-FPM Container Tuning**:
   - `4-moodle-image/config/nginx/nginx.conf`: keep `worker_processes auto;`, `worker_connections 2048;`, `multi_accept on;`, `use epoll;`, `client_max_body_size 100M;`, `fastcgi_buffers 16 16k;`, `fastcgi_buffer_size 32k;`.
   - `4-moodle-image/config/php83/fpm-pool.conf`: keep `pm = ondemand`, `pm.max_children = 8`, `pm.process_idle_timeout = 10s`, `pm.max_requests = 500`.
   - `4-moodle-image/config/php83/php.ini`: keep `memory_limit = 256M`, `post_max_size = 100M`, `upload_max_filesize = 100M`, `max_execution_time = 300`, `max_input_time = 300`, `max_input_vars = 5000`, `opcache.memory_consumption = 128`, `opcache.max_accelerated_files = 10000`.
7. **Do Not Re-Add Commented-Out Redis CLI Blocks in `setup_moodle.sh`**:
   - Redis MUC/Session setup instructions belong in `docs/configuring-redis-cache-with-moodle.md` (`PR #36`). Keep `setup_moodle.sh` clean of dead commented-out Redis CLI blocks.

## 2026-11-06 — Proactive Hardening: Least-Privilege File Permissions, `getenv()` Read-Replica & SMTP Secret Isolation, Batch `set_config()`, and `publicpaths.php` Port 8080 (`PR #48`)
**Vulnerabilities & Code-Health Findings (from Jules Proactive Analysis):**
1. **Permissive Directory & File Permissions + Slow `find -exec chmod {} \;` (`4-moodle-image-builder/base/opt/setup_moodle.sh:140-145`)**:
   - Directories and files under `$MOODLE_PATH` and `$MOODLE_DATAROOT_PATH` were granted `0775` and `0664` permissions (allowing group write access to executable PHP source code), and `find ... -exec chmod ... \;` spawned a separate `chmod` process per file.
2. **Plaintext Secret Exposure in `config.php` (`DB_READ_REPLICA_PASSWORD` via `sed -i`) and Process Arguments (`SMTP_PASSWORD` via `--set` in `ps`), plus 13 Sequential `cfg.php` Invocations (`4-moodle-image-builder/base/opt/setup_moodle.sh:186-228`)**:
   - Interpolating `$DB_READ_REPLICA_PASSWORD` directly into `config.php` via `sed -i` left plaintext credentials on shared storage and risked `sed` delimiter breakage or PHP code injection if passwords contained `/`, `'`, or `\`.
   - Calling `php83 ... admin/cli/cfg.php` 13 times sequentially passed `--set="$SMTP_PASSWORD"` on the process command line (visible in `ps`) and bootstrapped Moodle 13 separate times.
3. **Incomplete `publicpaths.php` Port `8080` Check, Unverified Archive Downloads, & Missing Automated Verification Suite (`4-moodle-image-builder/base/opt/setup_moodle.sh`, `Task 17792592824761015611`, `Task 8163948643911318982`)**:
   - The `publicpaths.php` block only created `publicpaths.modified` without rewriting `$CFG->wwwroot` to `"http://localhost:8080"` for internal container self-checks (`Task 17792592824761015611`).
   - Downloading Moodle and Moosh tarballs via `curl | tar -xz` lacked optional `MOODLE_SHA256` and `MOOSH_SHA256` integrity verification (`Task 8163948643911318982`), and `moodle-configmap-nginx-uploads*.yaml` had placeholder domain strings in `MOODLE_URL`/`MOOSH_URL` instead of tarball URLs.
**Resolution (Merged in `PR #48`):**
- Restricted `$MOODLE_PATH` to `0755` (directories) / `0644` (files) and `$MOODLE_DATAROOT_PATH` to `0750` (directories) / `0640` (files) using batched `find ... -exec chmod ... +`.
- Replaced raw `sed -i` string interpolation of `DB_READ_REPLICA_*` with `getenv('DB_READ_REPLICA_HOST')`, `getenv('DB_READ_REPLICA_PORT')`, `getenv('DB_READ_REPLICA_USER')`, and `getenv('DB_READ_REPLICA_PASSWORD')` inside `$CFG->dboptions['readonly']`.
- Consolidated the 13 `admin/cli/cfg.php` calls into a single `php83 -r` invocation that calls `set_config()` in one bootstrap and reads `SMTP_PASSWORD` from `getenv('SMTP_PASSWORD')` (never passing it on the CLI command line).
- Added optional `MOODLE_SHA256` and `MOOSH_SHA256` SHA-256 checksum verification (`sha256sum -c -`) before extracting `/tmp/moodle.tar.gz` and `/tmp/moosh.tar.gz` (`Task 8163948643911318982`), and fixed `MOODLE_URL` / `MOOSH_URL` in `moodle-configmap-nginx-uploads*.yaml`.
- Restored the `sed -i 's/\$CFG->wwwroot/"http:\/\/localhost:8080"/g'` rewrite on `publicpaths.php` before touching `publicpaths.modified` (`Task 17792592824761015611`), and added `tests/verify-scripts-and-configs.sh`.
