# Graph Report - modern-moodle-correction  (2026-11-18)

## Corpus Check
- 65 files · ~124,126 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 41 file(s) not represented in the graph (top: .ini 30, .conf 4, (none) 2)

## Summary
- 331 nodes · 394 edges · 33 communities (23 shown, 10 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `94fbc7d5`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- envs.sh
- README.md
- GCP Infrastructure, Selective Adoption, and Cloud SQL MySQL 8.4 / PostgreSQL 16
- Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)
- GKE Deployments, 10GB Upload Pod Isolation, ProxySQL, and Horizontal Pod Autoscaling
- validate_moodle_envs
- setup_moodle.sh
- create-config-files.sh
- entrypoint.sh
- build-gnu-libiconv.sh
- Pre-requisites
- openwiki/index.md
- NGINX + PHP 8.3 Container Image, GNU libiconv, and Moodle 5.2+ Bootstrap
- Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`)
- How to Contribute
- Configuring Redis Cache with Moodle
- Sentinel's Journal — Security, Hardening & Review Guardrails (`google/moodle-on-gcp`)
- Configuring Cloud CDN and Dedicated Upload Pods with Functional Moodle
- Project overview
- Documentation
- Deploying Persistent Volume Claim (PVC)
- smoke-test-container-image.sh
- Configuring SSL and forcing HTTPS redirect
- CONTRIBUTORS.md
- verify-scripts-and-configs.sh
- infra-pause.sh
- infra-resume.sh
- infra-destroy.sh
- infra-creation.sh
- update-moodle-semver.py
- Deploying Moodle in GKE with the NGINX + PHP 8.3 Image

## God Nodes (most connected - your core abstractions)
1. `main()` - 22 edges
2. `Sentinel's Journal — Security, Hardening & Review Guardrails (`google/moodle-on-gcp`)` - 12 edges
3. `run_self_test()` - 10 edges
4. `Pre-requisites` - 7 edges
5. `Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)` - 7 edges
6. `select_alpine_target()` - 6 edges
7. `Agent & Jules Configuration Guide (`google/moodle-on-gcp`)` - 6 edges
8. `GCP Infrastructure, Selective Adoption, and Cloud SQL MySQL 8.4 / PostgreSQL 16` - 6 edges
9. `GKE Deployments, 10GB Upload Pod Isolation, ProxySQL, and Horizontal Pod Autoscaling` - 6 edges
10. `Namespace moodle` - 6 edges

## Surprising Connections (you probably didn't know these)
- `1. Repository Architecture & Current Stack (`main`)` --references--> `main()`  [INFERRED]
  AGENTS.md → 4-moodle-image-builder/scripts/update-moodle-semver.py
- `2. Mandatory Guardrails (Preventing PR #38 Regressions)` --references--> `main()`  [INFERRED]
  AGENTS.md → 4-moodle-image-builder/scripts/update-moodle-semver.py
- `2026-11-18 — CLA-Compliant Update Pull Requests and Compatibility-Gated Alpine Bumps (`moodle-semver-updater.yml`)` --references--> `main()`  [INFERRED]
  .jules/sentinel.md → 4-moodle-image-builder/scripts/update-moodle-semver.py
- `5. Coordinated Moodle and Alpine Update Automation (`moodle-semver-updater.yml`)` --references--> `main()`  [INFERRED]
  openwiki/operations/gke-deployments-and-uploads-isolation.md → 4-moodle-image-builder/scripts/update-moodle-semver.py
- `4. Container Smoke Test and Compatibility-Gated Alpine Upgrades` --references--> `main()`  [INFERRED]
  openwiki/runtime/container-image-moodle52-php83.md → 4-moodle-image-builder/scripts/update-moodle-semver.py

## Import Cycles
- None detected.

## Communities (33 total, 10 thin omitted)

### Community 0 - "envs.sh"
Cohesion: 0.04
Nodes (54): ARTIFACT_REGISTRY_NAME, CLOUD_BUILD_SA_EMAIL, CREATE_CLOUD_SQL, CREATE_JUMPBOX, CREATE_REDIS, CREATE_REDIS_CLUSTER, DB_TYPE, FILESTORE_CAPACITY (+46 more)

### Community 1 - "README.md"
Cohesion: 0.06
Nodes (26): Architecture, Modern Moodle's architecture in GCP, Building Moodle's container image, Deploying Backend Configuration (`BackendConfig`), Deploying infrastructure, Infrastructure information needed for Moodle image configuration, Deploying Ingress - Cloud Load Balancer, Deploying Ingress (+18 more)

### Community 2 - "GCP Infrastructure, Selective Adoption, and Cloud SQL MySQL 8.4 / PostgreSQL 16"
Cohesion: 0.14
Nodes (11): Files, Centralized Configuration and Pre-Flight Validation (`0-infra/envs.sh`), Cloud SQL MySQL 8.4 and PostgreSQL 16 for Moodle 5.0+, GCP Infrastructure, Selective Adoption, and Cloud SQL MySQL 8.4 / PostgreSQL 16, Infrastructure Cleanup and Lifecycle Scripts (`cleanup-moodle-install.sh`, `infra-destroy.sh`, `infra-pause.sh`, `infra-resume.sh`), Selective Infrastructure Adoption, VPC Network, Private GKE Cluster, and CSI Drivers, Comparison: Cloud Filestore vs. Regional Replicated PD (+3 more)

### Community 3 - "Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)"
Cohesion: 0.13
Nodes (22): PersistentVolume pv-filestore (2.5Ti ReadWriteMany NFS /moodleshare), PersistentVolume pv-regional-pd (200Gi ReadWriteOnce pd.csi.storage.gke.io), StorageClass moodle-regional-pd-sc (pd-balanced regional-pd WaitForFirstConsumer), Namespace moodle, PersistentVolumeClaim pvc-filestore (300Gi-500Gi ReadWriteMany), PersistentVolumeClaim pvc-regional-pd (200Gi ReadWriteOnce), Cloud Build Pipeline moodle-nginx Image Builder (Dockerfile.nginx), ConfigMap moodle-configmap (Moodle 5.2.4, Moosh, Cloud SQL, Redis Session/App/Lock, SSLProxy) (+14 more)

### Community 4 - "GKE Deployments, 10GB Upload Pod Isolation, ProxySQL, and Horizontal Pod Autoscaling"
Cohesion: 0.13
Nodes (12): 1. Enabling `slasharguments`, `PATH_INFO`, and `X-Accel-Redirect` (`^~`) in Moodle and NGINX, 2. NGINX Cache Control Rules and Streaming Uploads, 3. `BackendConfig` Configuration (`USE_ORIGIN_HEADERS` vs. `uploads`), 4. NGINX & PHP-FPM 8.3 Tuning and Ingress Routing, Cloud CDN for Moodle, NGINX/PHP-FPM Tuning, and Ingress Routing, 1. Automated Manifest Rendering and Secret Isolation (`create-config-files.sh`), 2. 10GB+ Streaming Uploads and SubPath Isolation (`moodle-deployment-uploads`), 3. Pod Rightsizing (`Guaranteed` QoS), ProxySQL, and HPA (`9-hpa/`) (+4 more)

### Community 5 - "validate_moodle_envs"
Cohesion: 0.40
Nodes (3): cleanup-moodle-install.sh script, validate_moodle_envs(), build-nginx-based-image.sh script

### Community 11 - "Pre-requisites"
Cohesion: 0.29
Nodes (7): Enable Moodle's underlying infrastructure services APIs in Google Cloud, Get a project set up and administrative rights for it, Google Cloud account, Install `gcloud` command line extension, Install git client, Pre-requisites, Save compute account (principal) data for later usage

### Community 12 - "openwiki/index.md"
Cohesion: 0.29
Nodes (5): Directories, Files, End-to-End Deployment Quickstart (Step by Step), Moodle on GCP Quickstart & Architectural Map, OpenWiki Architectural Task-Routing Map

### Community 13 - "NGINX + PHP 8.3 Container Image, GNU libiconv, and Moodle 5.2+ Bootstrap"
Cohesion: 0.25
Nodes (6): 1. Multi-Stage `preloadable_libiconv.so` Compilation (MDL-80440), 2. PHP 8.3, Conditional `mysqli` vs. `pgsql` Drivers, and Dynamic Composer Verification, 3. Moodle 5.2.5 Bootstrap, Composer Dependencies, and `/public` Webroot (`setup_moodle.sh`), 4. Container Smoke Test and Compatibility-Gated Alpine Upgrades, NGINX + PHP 8.3 Container Image, GNU libiconv, and Moodle 5.2+ Bootstrap, Files

### Community 14 - "Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`)"
Cohesion: 0.18
Nodes (9): 1. Selective Infrastructure Adoption in `0-infra/envs.sh`, 2. Configuring Storage Sizes, 3. Deploying Regional Replicated Persistent Disk (`regional-pd`) in GKE, Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`), Option A: Static Provisioning (Pre-created Disk via `0-infra/infra-creation.sh`), Option B: Dynamic Provisioning (via GKE CSI `StorageClass`), Deploying Persistent Volume (PV), Option A: Cloud Filestore (`STORAGE_TYPE="filestore"`) (+1 more)

### Community 15 - "How to Contribute"
Cohesion: 0.40
Nodes (4): Code Reviews, Community Guidelines, Contributor License Agreement, How to Contribute

### Community 16 - "Configuring Redis Cache with Moodle"
Cohesion: 0.40
Nodes (5): 1. Add or verify entries in Moodle's config.php file, 2. Create a mapping for Redis from Moodle UI, 3. CLI-based Redis Configuration Reference, 4. Large-Scale Deployments: Memorystore for Redis Cluster (MRC), Configuring Redis Cache with Moodle

### Community 17 - "Sentinel's Journal — Security, Hardening & Review Guardrails (`google/moodle-on-gcp`)"
Cohesion: 0.09
Nodes (20): 1. Repository Architecture & Current Stack (`main`), 2. Mandatory Guardrails (Preventing PR #38 Regressions), 3. Verification & Test Suite (Run Before Every Commit / PR), 4. Using the Jules CLI (`@google/jules`) with This Repository, Agent & Jules Configuration Guide (`google/moodle-on-gcp`), OpenWiki, Claude & Agent Instructions (`google/moodle-on-gcp`), OpenWiki (+12 more)

### Community 18 - "Configuring Cloud CDN and Dedicated Upload Pods with Functional Moodle"
Cohesion: 0.50
Nodes (4): 1. How Cloud CDN Caching Works with Moodle 5.2+, 2. Applying the BackendConfig and Dedicated Upload Manifests, 3. Verifying Cloud CDN Cache Hits, Configuring Cloud CDN and Dedicated Upload Pods with Functional Moodle

### Community 19 - "Project overview"
Cohesion: 0.50
Nodes (4): Benefits, Cost view, How it works?, Project overview

### Community 20 - "Documentation"
Cohesion: 0.50
Nodes (4): Basic installation, Documentation, Modern Moodle on Google Cloud Platform (GCP), Post-installation

### Community 21 - "Deploying Persistent Volume Claim (PVC)"
Cohesion: 0.67
Nodes (3): Deploying Persistent Volume Claim (PVC), Option A: Cloud Filestore (`STORAGE_TYPE="filestore"`), Option B: Regional Replicated Persistent Disk (`STORAGE_TYPE="regional-pd"`)

### Community 23 - "Configuring SSL and forcing HTTPS redirect"
Cohesion: 0.67
Nodes (3): Configuring SSL and forcing HTTPS redirect, Forcing HTTPS for incoming requests, Provisioning a new certificate managed by Google Cloud

### Community 31 - "verify-scripts-and-configs.sh"
Cohesion: 0.38
Nodes (6): create_mock_config(), GCLOUD_LOG, KUBECTL_LOG, run_replica_snippet(), verify-scripts-and-configs.sh script, TMP_TEST_DIR

### Community 32 - "infra-pause.sh"
Cohesion: 0.67
Nodes (3): CLOUDSDK_CONTAINER_USE_APPLICATION_DEFAULT_CREDENTIALS, is_configured(), infra-pause.sh script

### Community 33 - "infra-resume.sh"
Cohesion: 0.67
Nodes (3): CLOUDSDK_CONTAINER_USE_APPLICATION_DEFAULT_CREDENTIALS, is_configured(), infra-resume.sh script

### Community 36 - "update-moodle-semver.py"
Cohesion: 0.08
Nodes (44): apply_alpine_update(), apply_moodle_update(), build_pr_metadata(), collect_required_packages(), compute_tarball_sha256(), fetch_alpine_branches(), fetch_alpine_index(), fetch_moodle_tags() (+36 more)

### Community 37 - "Deploying Moodle in GKE with the NGINX + PHP 8.3 Image"
Cohesion: 0.40
Nodes (5): Coordinated Moodle & Alpine Update Monitoring (`.github/dependabot.yml` & `moodle-semver-updater.yml`), Deploying Moodle in GKE with the NGINX + PHP 8.3 Image, High-Concurrency Scaling (100k–300k+ Concurrent Users), Opening Update Pull Requests Under a Maintainer Identity (Google CLA), Zero-Downtime Rollout & Probe Design (`startupProbe`, `readinessProbe`, `livenessProbe`)

## Knowledge Gaps
- **168 isolated node(s):** `envs.sh script`, `PROJECT_NUMBER`, `PROJECT_ID`, `REGION`, `ZONE` (+163 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 198 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `main()` connect `update-moodle-semver.py` to `Sentinel's Journal — Security, Hardening & Review Guardrails (`google/moodle-on-gcp`)`, `NGINX + PHP 8.3 Container Image, GNU libiconv, and Moodle 5.2+ Bootstrap`, `GKE Deployments, 10GB Upload Pod Isolation, ProxySQL, and Horizontal Pod Autoscaling`, `Deploying Moodle in GKE with the NGINX + PHP 8.3 Image`?**
  _High betweenness centrality (0.211) - this node is a cross-community bridge._
- **Why does `Deploying Moodle in GKE with the NGINX + PHP 8.3 Image` connect `Deploying Moodle in GKE with the NGINX + PHP 8.3 Image` to `README.md`?**
  _High betweenness centrality (0.163) - this node is a cross-community bridge._
- **Why does `Coordinated Moodle & Alpine Update Monitoring (`.github/dependabot.yml` & `moodle-semver-updater.yml`)` connect `Deploying Moodle in GKE with the NGINX + PHP 8.3 Image` to `update-moodle-semver.py`?**
  _High betweenness centrality (0.161) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `main()` (e.g. with `fetch_alpine_index()` and `1. Repository Architecture & Current Stack (`main`)`) actually correct?**
  _`main()` has 7 INFERRED edges - model-reasoned connections that need verification._
- **What connects `envs.sh script`, `PROJECT_NUMBER`, `PROJECT_ID` to the rest of the system?**
  _168 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `envs.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.03636363636363636 - nodes in this community are weakly interconnected._
- **Should `README.md` be split into smaller, more focused modules?**
  _Cohesion score 0.061224489795918366 - nodes in this community are weakly interconnected._