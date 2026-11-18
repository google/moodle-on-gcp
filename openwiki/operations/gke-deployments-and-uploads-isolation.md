---
type: operations
title: GKE Deployments, 10GB Upload Pod Isolation, ProxySQL, and Horizontal Pod Autoscaling
description: Kubernetes Deployment architecture for Moodle 5.2.5, Guaranteed QoS rightsizing, isolated 10GB+ upload pods (disk-backed /tmp, PHP_FPM_MAX_CHILDREN=1), optional Secrets, ProxySQL connection multiplexing, HPA policies, zero-downtime probes, and the coordinated Moodle + Alpine update automation (CLA-compliant pull requests).
tags: [gke, kubernetes, deployments, uploads, proxysql, hpa, configmap, secret, envsubst, dependabot, github-actions, alpine]
sources:
  - id: openwiki-source-79b37831c9c81206da1d88ec
    resource: repo://.github/dependabot.yml
  - id: openwiki-source-d90971da646b0fe193b31839
    resource: repo://.github/workflows/moodle-semver-updater.yml
  - id: openwiki-source-987a83de3394b5c94a465016
    resource: repo://4-moodle-image-builder/scripts/update-moodle-semver.py
  - id: openwiki-source-b23bb47d51c7c03a516ab733
    resource: repo://5a-deployment-no-helm/create-config-files.sh
  - id: openwiki-source-53006dbc93bd922d7c60cef7
    resource: repo://5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml
  - id: openwiki-source-a72c418fe1c6ecb6d937d386
    resource: repo://5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
  - id: openwiki-source-93141f93130a498670374709
    resource: repo://5a-deployment-no-helm/moodle-deployment-nginx.yaml
  - id: openwiki-source-14c80d2e5990cedcc69cd8f7
    resource: repo://9-hpa/moodle-hpa.yaml
  - id: openwiki-source-d5cb738866bc0951047c9d59
    resource: repo://9-hpa/moodle-uploads-hpa.yaml
  - id: openwiki-source-8b405ff0d1ec68bd339f2b74
    resource: repo://docs/install-moodle-nginx.md
  - id: openwiki-source-dc929078fccb69a8204d1722
    resource: repo://tests/smoke-test-container-image.sh
  - id: openwiki-source-6d8c98d53bdfbb0985562fa8
    resource: repo://tests/verify-scripts-and-configs.sh
generated: { by: "antigravity", at: "2026-11-18T12:02:02.964Z" }
verified:
  - by: openwiki/0.5.1
    at: 2026-11-18T12:05:03.622Z
---

# GKE Deployments, 10GB Upload Pod Isolation, ProxySQL, and Horizontal Pod Autoscaling

The `5a-deployment-no-helm/` directory implements a **two-tier application architecture on GKE** (plus an optional **ProxySQL** connection-multiplexing tier for extreme concurrency):
1. **Primary Web Tier (`moodle-deployment` + `moodle-configmap` + `moodle`)**: Right-sized with `Guaranteed` QoS (`requests == limits`: `cpu: 1000m`, `memory: 2Gi`) for low-latency interactive navigation, multi-zone topology spread across 3 zones, Cloud CDN edge caching, and horizontal autoscaling between 3 and 9 replicas (`9-hpa/moodle-hpa.yaml`).
2. **Dedicated 10GB+ Uploads Tier (`moodle-deployment-uploads` + `moodle-configmap-uploads` + `moodle-service-uploads`)**: Sized for streaming file uploads up to `10G` per request without consuming container RAM (`emptyDir: { sizeLimit: 15Gi }` on disk rather than `medium: Memory` `tmpfs`), processing 1 heavy upload at a time (`PHP_FPM_MAX_CHILDREN: "1"`) with socket backlog queueing (`listen.backlog = 128`), and scaling between 1 and 5 replicas (`9-hpa/moodle-uploads-hpa.yaml`).
3. **Optional ProxySQL Connection Multiplexer (`moodle-proxysql`)**: Multiplexes thousands of concurrent PHP-FPM connections over a bounded pool of `200` backend Cloud SQL connections (`multiplexing=true`) during 100k–300k+ student load tests.

```mermaid
flowchart TD
    Script["5a-deployment-no-helm/create-config-files.sh"] --> CM1["moodle-configmap-nginx.yaml + moodle-optional-secrets.yaml"]
    Script --> CM2["moodle-configmap-nginx-uploads.yaml - CLIENT_MAX_BODY_SIZE=10G, PHP_FPM_MAX_CHILDREN=1"]
    Script --> Dep1["moodle-deployment-nginx.yaml - subPath: etc/nginx & etc/php83"]
    Script --> Dep2["moodle-deployment-nginx-uploads.yaml - subPath: etc/nginx-uploads & etc/php83-uploads, disk /tmp 15Gi"]
    Dep1 --> HPA1["9-hpa/moodle-hpa.yaml (3..9 pods)"]
    Dep2 --> HPA2["9-hpa/moodle-uploads-hpa.yaml (1..5 pods)"]
```

## 1. Automated Manifest Rendering and Secret Isolation (`create-config-files.sh`)

`5a-deployment-no-helm/create-config-files.sh` loads `0-infra/envs.sh` and runs `envsubst` across the templates in `5a-deployment-no-helm/deployment-templates/`:

- Automatically determines `PVC_CLAIM_NAME` (`pvc-regional-pd` when `STORAGE_TYPE="regional-pd"`, or `pvc-filestore` otherwise).
- Renders `moodle-configmap-nginx.yaml`, `moodle-configmap-nginx-uploads.yaml`, `moodle-optional-secrets.yaml` (`chmod 0600`), `moodle-deployment-nginx.yaml`, and `moodle-deployment-nginx-uploads.yaml`.
- Sources `DB_READ_REPLICA_PASSWORD`, `REDIS_SESSION_ID_AUTH_STRING`, `REDIS_APP_AUTH_STRING`, `REDIS_SESSION_AUTH_STRING`, `REDIS_LOCK_AUTH_STRING`, and `SMTP_PASSWORD` from the `moodle-optional-secrets` Kubernetes `Secret` (`optional: true`) rather than plaintext `ConfigMap` keys.

## 2. 10GB+ Streaming Uploads and SubPath Isolation (`moodle-deployment-uploads`)

To prevent `setup_moodle.sh`'s dynamic `sed -i` overrides on upload pods from overwriting `php.ini` and `nginx.conf` for the primary web pods on shared storage:

- `5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml` mounts `/etc/nginx` at `subPath: $MOODLE_ROOT_PATH_NO_SLASH/etc/nginx-uploads` and `/etc/php83` at `subPath: $MOODLE_ROOT_PATH_NO_SLASH/etc/php83-uploads`.
- **Disk-Backed `/tmp` (`emptyDir: { sizeLimit: 15Gi }`)**: While primary web pods mount `/tmp` with `medium: Memory` (`tmpfs`) to accelerate `X-Accel-Redirect` static assets, upload pods mount `/tmp` on node SSD ephemeral storage so 10 GB temporary upload files (`/tmp/phpXXXXXX`) consume zero container RAM.
- `5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml` sets:
  - `CLIENT_MAX_BODY_SIZE: "10G"`, `UPLOAD_MAX_FILESIZE: "10G"`, `POST_MAX_SIZE: "10G"`
  - `PHP_MAX_EXECUTION_TIME: "3600"`, `PHP_MAX_INPUT_TIME: "3600"`
  - `PHP_MEMORY_LIMIT: "1024M"`, `PHP_FPM_MAX_CHILDREN: "1"`

## 3. Pod Rightsizing (`Guaranteed` QoS), ProxySQL, and HPA (`9-hpa/`)

- **Guaranteed QoS Rightsizing (`requests == limits`)**: Both `moodle-deployment` and `moodle-deployment-uploads` set `requests` equal to `limits` (`cpu: 1000m`, `memory: 2Gi`), preventing CFS CPU throttling across PHP-FPM workers and ensuring accurate HPA scaling on GKE Autopilot.
- **Optional ProxySQL Tier (`5a-deployment-no-helm/moodle-proxysql.yaml`)**: Deploys a 2-replica `proxysql/proxysql:2.7.1` service (`moodle-proxysql:6033`) with `multiplexing=true` and `max_connections=200` to prevent `Too many connections` errors on Cloud SQL during massive load tests.
- **Independent HPAs (`9-hpa/moodle-hpa.yaml` and `9-hpa/moodle-uploads-hpa.yaml`)**: Scale `moodle-deployment` (`3..9` pods) and `moodle-deployment-uploads` (`1..5` pods) at `75%` CPU and `80%` memory utilization.

## 4. Zero-Downtime Rollout Strategy and Zero-DB-Load Probe Architecture

In `4-moodle-image-builder/base/opt/entrypoint.sh`, `/opt/setup_moodle.sh` executes synchronously before `php-fpm83` and `nginx` start listening on port `8080`. Both `moodle-deployment-nginx.yaml` and `moodle-deployment-nginx-uploads.yaml` enforce a zero-downtime rolling update (`maxSurge: 1`, `maxUnavailable: 0`, `minReadySeconds: 10`) backed by three decoupled probes:

1. **Why Probes Intentionally Avoid Database and Redis Queries (`/login/index.php`)**:
   - Probing `/login/index.php` every 5 seconds boots the full Moodle PHP framework, acquires Redis locks, and runs multiple SQL queries. At 50–100 pods under HPA load testing, health probes alone would generate 30–40 database/Redis requests per second, and any brief database latency spike would cause all pods to fail `readinessProbe` simultaneously (a cascading thundering-herd outage).
2. **`startupProbe` (`httpGet /healthz :8080`, `failureThreshold: 120`, `periodSeconds: 5`)**:
   - Allows up to 10 minutes (`120 × 5s`) for first-run `/opt/setup_moodle.sh` installation or upgrades before `readinessProbe` and `livenessProbe` activate, while releasing normal steady-state pods within ~5 seconds as soon as NGINX starts.
3. **`readinessProbe` (`test -S /var/run/php8.3-fpm-moodle.sock && curl -fs http://127.0.0.1:8080/healthz >/dev/null`)**:
   - Verifies both that the PHP-FPM 8.3 Unix domain socket (`/var/run/php8.3-fpm-moodle.sock`) is active and that NGINX responds `200 OK` on `:8080/healthz` with zero database or Redis load, preventing Kubernetes from terminating old pods before replacement pods have finished `setup_moodle.sh`.
4. **`livenessProbe` (`httpGet /healthz :8080`, `periodSeconds: 15`, `failureThreshold: 4`) & `lifecycle.preStop`**:
   - Monitors NGINX responsiveness without restarting pods during heavy PHP-FPM or DB load, and runs `sleep 5 && /usr/sbin/nginx -s quit` on termination so GKE Container-Native Load Balancing (NEG) stops sending new traffic before NGINX gracefully drains active connections.

## 5. Coordinated Moodle and Alpine Update Automation (`moodle-semver-updater.yml`)

Every Monday at 06:00 UTC (and on demand through `workflow_dispatch`), `.github/workflows/moodle-semver-updater.yml` runs `4-moodle-image-builder/scripts/update-moodle-semver.py`, which applies **both** dependency updates to the working tree so that they are proposed in **a single pull request** from the `chore/moodle-semver-update` branch:

```mermaid
flowchart LR
    Identity["Resolve PR identity (MOODLE_UPDATER_TOKEN owner or github.actor)"] --> Script["update-moodle-semver.py"]
    Script --> Moodle["Moodle tags: patch / minor / major / custom_series - MOODLE_URL, MOODLE_SHA256, MOODLE_SITENAME"]
    Script --> Alpine["Alpine: releases.json + APKINDEX gate - FROM alpine:X.Y"]
    Moodle --> Verify["tests/verify-scripts-and-configs.sh"]
    Alpine --> Smoke["tests/smoke-test-container-image.sh (Alpine bumps only)"]
    Verify --> PR["Single PR: chore/moodle-semver-update"]
    Smoke --> PR
```

- **Moodle SemVer policy**: Polls official `moodle/moodle` GitHub tags with `semver_scope: patch | minor | major` or an explicit `custom_series`, downloads the target release archive, computes `MOODLE_SHA256`, and rewrites `MOODLE_URL`, `MOODLE_SHA256`, and `MOODLE_SITENAME` across all `ConfigMap` manifests and templates (plus the version references in `AGENTS.md` and `docs/repository-organization.md`).
- **Compatibility-gated Alpine bumps (`alpine_policy: latest`, default)**: Reads `https://alpinelinux.org/releases.json`, ignores `edge`, end-of-life branches, and branches without a published release, and walks the newer branches from newest to oldest. A branch is selected only if its `main` and `community` `x86_64` `APKINDEX` files provide every package installed by an `apk add` command in `Dockerfile.nginx` and `scripts/build-gnu-libiconv.sh` (package names or `provides` aliases such as `envsubst`; comment lines are ignored). Branches that dropped a required package (for example, a future release without the `php83-*` series) are skipped, the `FROM alpine:X.Y` lines and the Alpine version in `AGENTS.md` are rewritten only for a compatible branch, and the script emits a warning when the current release is end-of-life without a compatible successor. Network failures while checking Alpine only skip the Alpine part, and `alpine_policy: none` leaves the base image unchanged.
- **Dependabot division of labor**: `.github/dependabot.yml` keeps weekly `github-actions` updates, ignores the `alpine` dependency in the `docker` ecosystem so Alpine never arrives as a separate pull request, and applies a 7-day `cooldown` to both ecosystems.
- **Verification before the pull request**: The workflow runs `./tests/verify-scripts-and-configs.sh` (which also executes the updater's offline `--dry-run` self-test) and, when the Alpine base image changed, `./tests/smoke-test-container-image.sh`. The smoke test builds `Dockerfile.nginx` with Docker or Podman and checks the Alpine release, the PHP 8.3 extensions Moodle needs (including `redis`, `igbinary`, `zstd`, `apcu`, and OPcache), the GNU libiconv `//TRANSLIT` preload, `nginx -t` against the rendered repository template, and `php-fpm83 -t`. Because each step must succeed before the pull request step runs, a broken Alpine bump never reaches a pull request.
- **CLA-compliant pull request identity**: Google's CLA check (`cla/google`) validates the pull request opener and every commit author and committer, so a pull request opened by `github-actions[bot]` with `GITHUB_TOKEN` cannot pass it. When the optional `MOODLE_UPDATER_TOKEN` secret (a short-lived fine-grained personal access token of a CLA-covered maintainer, scoped to the repository with `Contents` and `Pull requests` write access) is configured, the workflow resolves its owner with `gh api user` and uses that token plus the owner's `<id>+<login>@users.noreply.github.com` identity as opener, author, and committer. A configured token that GitHub rejects (expired, revoked, or not yet approved) fails the run with an explicit error instead of silently falling back. Without the secret, it falls back to `GITHUB_TOKEN` and the `github.actor` noreply identity, and the generated pull request body explains how to re-open the pull request as a maintainer.
- **Generated pull request metadata**: The script derives the commit message, title (for example, `chore(deps): update Moodle v5.2.4 to v5.2.5 and Alpine 3.21 to 3.24` when both change), and Markdown body (component table with `MOODLE_SHA256`, Alpine end-of-life dates, verified package count, and resolved `php83`, `nginx`, and `gnu-libiconv-libs` versions), and exposes `updated`, `moodle_updated`, and `alpine_updated` step outputs that gate the following steps.
