# Deploying Moodle in GKE with the NGINX + PHP 8.3 Image

1. Generate the Kubernetes manifests from `0-infra/envs.sh` (which also prompts optionally for your SMTP password and renders storage and upload manifests):

```bash
./5a-deployment-no-helm/create-config-files.sh
```

2. Populate your Cloud SQL, Redis, and Load Balancer IP addresses in `5a-deployment-no-helm/moodle-configmap-nginx.yaml` and `5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml`, and populate your MySQL and Moodle admin passwords in `5a-deployment-no-helm/moodle-secret.yaml`.

11. Apply the Secrets, ConfigMaps, Deployments, and Services:

```bash
kubectl apply -f 5a-deployment-no-helm/moodle-externaldb-secret.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-password-secret.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-optional-secrets.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-configmap-nginx.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-deployment-nginx.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-service.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-service-uploads.yaml
```

## High-Concurrency Scaling (100k–300k+ Concurrent Users)

1. **Pod Rightsizing & GKE Autopilot `Guaranteed` QoS (`requests == limits`)**:
   - Both `moodle-deployment` and `moodle-deployment-uploads` set `requests == limits` (`cpu: 1000m`, `memory: 2Gi`). On GKE Autopilot, matching `requests` and `limits` guarantees `Guaranteed` QoS (preventing memory eviction under node pressure and ensuring HorizontalPodAutoscaler `averageUtilization: 75` scales accurately against the pod's true 1 vCPU capacity without CFS CPU throttling across the 8 PHP-FPM workers).
2. **Redis Binary Serialization & `zstd` Compression**:
   - `4-moodle-image-builder/config.php.template` enables `php83-pecl-igbinary` (`$CFG->session_redis_serializer_use_igbinary = true`) and `php83-pecl-zstd` (`$CFG->session_redis_compressor = 'zstd'`), reducing Redis session/MUC payload sizes by ~55% and cutting serialization CPU overhead by 4x.
3. **Optional ProxySQL Connection Multiplexing (`5a-deployment-no-helm/moodle-proxysql.yaml`)**:
   - For extreme load tests or large-scale production deployments where hundreds of PHP-FPM workers could exhaust Cloud SQL's `max_connections`, deploy the optional ProxySQL tier:
     ```bash
     kubectl apply -f 5a-deployment-no-helm/moodle-proxysql.yaml
     ```
   - Point Moodle pods to `moodle-proxysql` on port `6033` (and optionally set `DB_PERSIST: "true"` so PHP-FPM keeps persistent connections to the local ProxySQL service while ProxySQL multiplexes queries over a bounded pool of `200` backend Cloud SQL connections).

## Zero-Downtime Rollout & Probe Design (`startupProbe`, `readinessProbe`, `livenessProbe`)

In `4-moodle-image-builder/base/opt/entrypoint.sh`, `/opt/setup_moodle.sh` executes synchronously **before** `php-fpm83` and `nginx` start listening on port `8080`. To prevent Kubernetes from marking newly created pods as `Ready` while `setup_moodle.sh` is still running (which would prematurely terminate existing pods during a rolling update) — and to avoid overwhelming Cloud SQL or Redis when scaling to 50–100+ pods — both `moodle-deployment` and `moodle-deployment-uploads` implement a three-tier zero-DB-load probe architecture:

1. **Why `readinessProbe` and `livenessProbe` Intentionally Avoid Querying the Database (`/login/index.php`)**:
   - Pointing `readinessProbe` or `livenessProbe` at a full Moodle PHP page (such as `/login/index.php`) forces every probe tick to bootstrap Moodle core, acquire Redis session/MUC locks, and execute multiple SQL queries on Cloud SQL. At 50–100 pods (`periodSeconds: 5`), health checks alone would generate **30–40 full database/Redis requests per second**.
   - Worse, during a temporary 2–3 second database CPU spike or failover under heavy load, a DB-coupled `readinessProbe` fails simultaneously across all pods, causing Kubernetes to remove every pod from the Service/NEG at once (a cascading thundering-herd outage).
2. **`startupProbe` (`httpGet /healthz :8080`, `failureThreshold: 120`, `periodSeconds: 5`)**:
   - Gives `/opt/setup_moodle.sh` up to **10 minutes** (`120 × 5s`) to complete first-run database installation, Composer dependency setup, or Moodle upgrades before `livenessProbe` and `readinessProbe` take over, while releasing normal steady-state pods within ~5 seconds as soon as NGINX starts.
3. **`readinessProbe` (`test -S /var/run/php8.3-fpm-moodle.sock && curl -fs http://127.0.0.1:8080/healthz`)**:
   - Verifies **both** that PHP-FPM 8.3 has created its active Unix domain socket (`/var/run/php8.3-fpm-moodle.sock`) **and** that NGINX is serving `HTTP 200` on `:8080/healthz`, with **zero database or Redis overhead**.
4. **`livenessProbe` (`httpGet /healthz :8080`, `periodSeconds: 15`, `failureThreshold: 4`)**:
   - Checks that the NGINX daemon is alive without restarting containers when PHP-FPM workers are busy streaming large uploads or waiting on database queries.
5. **Graceful Connection Draining (`lifecycle.preStop`, `minReadySeconds: 10`, `maxUnavailable: 0`)**:
   - `rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }` and `minReadySeconds: 10` guarantee that no existing pod is terminated until the replacement pod has passed `readinessProbe` continuously for 10 seconds.
   - When a pod is terminated, `preStop` executes `sleep 5 && /usr/sbin/nginx -s quit`, giving GKE Container-Native Load Balancing (NEG) and `kube-proxy` time to stop routing new connections before NGINX gracefully drains in-flight PHP requests.

## Automated Moodle SemVer Monitoring (`.github/dependabot.yml` & `moodle-semver-updater.yml`)

- **`.github/dependabot.yml`**: Automatically monitors weekly updates for the `Dockerfile.nginx` base image (`docker` ecosystem) and GitHub Actions (`github-actions` ecosystem).
- **`.github/workflows/moodle-semver-updater.yml` & `4-moodle-image-builder/scripts/update-moodle-semver.py`**:
  - Because `MOODLE_URL` is parameterized inside Kubernetes `ConfigMap` YAML files (`https://github.com/moodle/moodle/archive/refs/tags/v5.2.4.tar.gz`), the `Moodle SemVer Auto-Updater` workflow polls official `moodle/moodle` GitHub tags every Monday (and supports manual on-demand execution via `workflow_dispatch`).
  - Supports configurable SemVer policies:
    - `patch` (default): updates within the current minor release series (e.g., `v5.2.4` $\rightarrow$ `v5.2.5`).
    - `minor`: updates to newer minor releases within the same major version (e.g., `v5.2.4` $\rightarrow$ `v5.3.0`).
    - `custom_series`: pins a specific target series (e.g., `5.3`).
  - Automatically downloads the target release tarball, computes its SHA-256 digest (`MOODLE_SHA256`), updates all `ConfigMap` manifests and templates, runs `./tests/verify-scripts-and-configs.sh`, and opens a Pull Request.

For migration guidance from legacy deployments, see [Migration Recommendations](migration-recommendations.md).
