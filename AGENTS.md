# Agent & Jules Configuration Guide (`google/moodle-on-gcp`)

This file configures **Jules** (`https://jules.google/docs`, `@google/jules` CLI) and coding agents working on `google/moodle-on-gcp`.
Before making any changes, read both this file and [`.jules/sentinel.md`](.jules/sentinel.md).

---

## 1. Repository Architecture & Current Stack (`main`)

`google/moodle-on-gcp` provisions and deploys a cloud-native, horizontally scalable **Moodle LMS (`v5.2.4`)** on **Google Kubernetes Engine (GKE)** backed by **Cloud SQL for MySQL Enterprise (`MYSQL_8_4`)**, **Memorystore for Redis / Redis Cluster (`local_redislock`)**, selectable shared storage (**Filestore NFS (`RWX`)** or **Regional Replicated Persistent Disk (`regional-pd`)**), and **Google Cloud CDN (`USE_ORIGIN_HEADERS`)**.

| Directory | Purpose | Key Files |
| :--- | :--- | :--- |
| `0-infra/` | GCP VPC, NAT, GKE, Cloud SQL (`MYSQL_8_4`), Filestore, Regional PD, Memorystore (`redis` & `redis-cluster`), and Jumpbox provisioning scripts (`#!/bin/bash`, `set -eo pipefail`). | `0-infra/envs.sh`, `0-infra/infra-creation.sh` |
| `1-networking/` | Reserve global static IP (`moodle-ingress-ip`) for GKE External Ingress. | `1-networking/reserve-external-ip.md` |
| `2-pvc/` | PersistentVolume and PersistentVolumeClaim templates for Filestore NFS (`RWX`) and Regional Replicated Persistent Disk (`regional-pd`, `gcePersistentDisk`). | `2-pvc/pvc-filestore.yaml`, `2-pvc/pvc-regional-pd.yaml` |
| `3-Shortcut/` | Summary guide linking directly to `5a-deployment-no-helm/`. (Legacy Bitnami & `7-helm/` were removed in `PR #43`). | `3-Shortcut/README.md` |
| `4-moodle-image/` | Multi-stage Alpine `3.21` + PHP `8.3.36` + GNU `libiconv 1.18` (`preloadable_libiconv.so`) + Moodle `v5.2.4` + Moosh `1.51` + `local_redislock` image. | `4-moodle-image/Dockerfile`, `4-moodle-image/scripts/setup_moodle.sh`, `4-moodle-image/config/nginx/moodle.conf`, `4-moodle-image/config/nginx/nginx.conf`, `4-moodle-image/config/php83/php.ini`, `4-moodle-image/config/php83/fpm-pool.conf` |
| `5a-deployment-no-helm/` | Canonical Kubernetes manifests (`ConfigMap`, `Secret`, `Deployment`, `Service`, `BackendConfig`, `FrontendConfig`, `ManagedCertificate`, `Ingress`, `HorizontalPodAutoscaler`, `CronJob`) and interactive generator script. | `5a-deployment-no-helm/moodle-configmap-nginx.yaml`, `5a-deployment-no-helm/moodle-configmap-nginx-sample.yaml`, `5a-deployment-no-helm/create-config-files.sh` |
| `6-ssl-Redirect/` | Post-SSL activation manifests (`FrontendConfig` HTTP->HTTPS `301` redirect and `reverseproxy = true` in `ConfigMap`). | `6-ssl-Redirect/enable-ssl-redirect-after-cert-prov.yaml` |
| `.jules/` | Jules / Sentinel persistent security journal and review guardrails. | `.jules/sentinel.md` |

---

## 2. Mandatory Guardrails (Preventing PR #38 Regressions)

Every automated agent (including Jules and Sentinel) **MUST** enforce these 10 rules derived from the 110 inline review comments on PR `#38`:

1. **Preserve `<YOUR-...>` and `<ANGLE_BRACKETS>` Placeholders**:
   - Never replace template placeholders (e.g., `"<YOUR-PROJECT-ID>"`, `"<IPV4-FROM-CLOUD-SQL>"`, `"<NAME-OF-YOUR-DOMAIN-LIKE-example.com>"`, `<CERT-LIST>`) in `0-infra/envs.sh` or `5a-deployment-no-helm/moodle-configmap-nginx*.yaml` with hardcoded or dummy values (`moodle-project-12345`, `10.119.0.3`, `moodle.example.com`).
   - Always keep `<YOUR-...>` placeholders wrapped in double quotes in `0-infra/envs.sh` so `source 0-infra/envs.sh` never triggers Bash `<`/`>` redirection errors.
2. **Keep `REDIS_*` Variables Empty in Template YAML Manifests**:
   - In `5a-deployment-no-helm/moodle-configmap-nginx.yaml` and `moodle-configmap-nginx-sample.yaml`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_AUTH`, `REDIS_SSL`, and `REDIS_CLUSTER_MODE` must remain `""`.
3. **Preserve `MOODLE_LANGUAGE: "pt-BR"` in `moodle-configmap-nginx-sample.yaml`**:
   - `moodle-configmap-nginx.yaml` uses `"en"`, while `moodle-configmap-nginx-sample.yaml` intentionally showcases `"pt-BR"`.
4. **Isolate Upload Pod PVC `subPath` Mounts**:
   - `moodle-deployment` mounts `subPath: etc/nginx` and `subPath: etc/php83`.
   - `moodle-deployment-uploads` **MUST** mount `subPath: etc/nginx-uploads` and `subPath: etc/php83-uploads` so `setup_moodle.sh`'s `sed -i` overrides (`MOODLE_UPLOAD_MAX_FILESIZE: "2048"`) do not overwrite `php.ini` / `nginx.conf` for the standard web pods on shared storage.
5. **Keep Dynamic `sed -i` Overrides Immediately After `envsubst` in `setup_moodle.sh`**:
   - In `4-moodle-image/scripts/setup_moodle.sh`, the `sed -i` overrides for `MOODLE_MAX_INPUT_VARS`, `MOODLE_POST_MAX_SIZE`, `MOODLE_UPLOAD_MAX_FILESIZE`, and `MOODLE_MEMORY_LIMIT` must execute immediately after `envsubst` (around line 83), before NGINX and PHP-FPM start.
6. **Preserve Moodle 5.1+ `/public` Webroot (`MDL-83424`) and Cloud CDN Headers**:
   - NGINX `root` in `4-moodle-image/config/nginx/moodle.conf` must remain `/var/www/html/moodle/public`.
   - Static asset locations (`/theme/`, `/lib/javascript.php`, `/lib/requirejs.php`, `/lib/font.php`, `/pix/`) must include `fastcgi_hide_header Set-Cookie;` so Cloud CDN (`cacheMode: USE_ORIGIN_HEADERS`) caches public static assets without caching session cookies.
   - Private file locations (`/pluginfile.php`, `/draftfile.php`) must enforce `add_header Cache-Control "private, no-store, no-cache, must-revalidate" always;`.
7. **Preserve NGINX & PHP-FPM Container Tuning**:
   - Do not revert `worker_processes auto;` / `worker_connections 2048;` in `4-moodle-image/config/nginx/nginx.conf`, `pm = ondemand` / `pm.max_children = 8` in `4-moodle-image/config/php83/fpm-pool.conf`, or the OPcache / upload limits in `4-moodle-image/config/php83/php.ini`.
8. **Preserve Multi-Stage `gnu-libiconv` (`preloadable_libiconv.so`), Composer, and Moosh `1.51`**:
   - In `4-moodle-image/Dockerfile`, keep the `iconv-builder` stage (`libiconv-1.18`), `ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so`, `composer install --no-dev --classmap-authoritative`, and `local_redislock`.
9. **Keep `PRs` Atomic and Linear on `main`**:
   - Never combine unrelated infrastructure, runtime, and documentation changes into a single monolithic PR. Target `main` directly (`delete_branch_on_merge` is enabled on this repository).
10. **Never Delete `.jules/sentinel.md` Entries**:
    - Append new security learnings chronologically to `.jules/sentinel.md` without deleting prior entries.

---

## 3. Verification & Test Suite (Run Before Every Commit / PR)

Always run these verification commands locally before committing or submitting a session via Jules:

```bash
# 1. Validate Bash syntax on all infrastructure & config generator scripts
bash -n 0-infra/*.sh 5a-deployment-no-helm/create-config-files.sh

# 2. Validate POSIX sh syntax on container entrypoint scripts
sh -n 4-moodle-image/scripts/*.sh

# 3. Validate all Kubernetes YAML manifests (accounting for template placeholders)
python3 -c '
import glob, yaml
for f in sorted(glob.glob("**/*.yaml", recursive=True)):
    if f.startswith("openwiki/") or f.startswith("graphify-out/"):
        continue
    raw = open(f).read().replace("<CERT-LIST>", "[moodle-managed-cert]")
    list(yaml.safe_load_all(raw))
print("All YAML manifests valid!")
'

# 4. End-to-end smoke test of 5a-deployment-no-helm/create-config-files.sh
```

---

## 4. Using the Jules CLI (`@google/jules`) with This Repository

The official Jules CLI (`@google/jules`, `https://jules.google/docs/cli/reference`) is installed and can be used to dispatch scoped tasks that automatically inherit `AGENTS.md` and `.jules/sentinel.md`:

```bash
# Verify Jules CLI installation and authentication
jules version
jules login

# List connected repositories and active sessions
jules remote list --repo
jules remote list --session

# Start a scoped, atomic session on google/moodle-on-gcp (always keep tasks small and atomic)
jules remote new --repo google/moodle-on-gcp --session "<concise-atomic-task-description>"

# Pull or apply a completed session patch locally for verification before creating a PR
jules remote pull --session <SESSION_ID>
jules teleport <SESSION_ID>
```

<!-- OPENWIKI:START -->

## OpenWiki

This repository has a generated `openwiki/` evidence index. It is optional just-in-time context, not required startup reading.

- Treat source code and tests as authoritative. A brief's unknowns and review items are verification gaps, not automatic requirements.
- Prefer the narrowest quiet validation that proves the changed behavior. Preserve complete failure output.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->
