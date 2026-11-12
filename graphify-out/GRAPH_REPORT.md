# Graph Report - modern-moodle-correction  (2026-11-12)

## Corpus Check
- 63 files · ~116,036 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 41 file(s) not represented in the graph (top: .ini 30, .conf 4, (none) 2)

## Summary
- 277 nodes · 302 edges · 36 communities (26 shown, 10 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.68)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0e3aa594`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- envs.sh
- README.md
- GCP Infrastructure, Selective Adoption, and Cloud SQL MySQL 8.4
- Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)
- Cloud CDN for Moodle, NGINX/PHP-FPM Tuning, and Ingress Routing
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
- architecture.md
- Deploying Persistent Volume Claim (PVC)
- Deploying Persistent Volume (PV)
- Deployment
- Migrating from previous Bitnami image to NGINX based image (Recommended)
- Running a benchmark to check the performance
- Updating Environment Variables and Upgrading Pods
- Configuring SSL and forcing HTTPS redirect
- CONTRIBUTORS.md
- verify-scripts-and-configs.sh
- infra-pause.sh
- infra-resume.sh
- infra-destroy.sh
- infra-creation.sh

## God Nodes (most connected - your core abstractions)
1. `Sentinel's Journal — Security, Hardening & Review Guardrails (`google/moodle-on-gcp`)` - 11 edges
2. `Pre-requisites` - 7 edges
3. `Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)` - 7 edges
4. `Agent & Jules Configuration Guide (`google/moodle-on-gcp`)` - 6 edges
5. `GCP Infrastructure, Selective Adoption, and Cloud SQL MySQL 8.4` - 6 edges
6. `Namespace moodle` - 6 edges
7. `Deployment moodle-deployment-uploads (Dedicated Large Upload Pod, 512M/3600s)` - 6 edges
8. `Configuring Redis Cache with Moodle` - 5 edges
9. `Cloud CDN for Moodle, NGINX/PHP-FPM Tuning, and Ingress Routing` - 5 edges
10. `How to Contribute` - 4 edges

## Surprising Connections (you probably didn't know these)
- `Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)` --conceptually_related_to--> `Cloud Build Pipeline moodle-nginx Image Builder (Dockerfile.nginx)`  [INFERRED]
  5a-deployment-no-helm/moodle-deployment-nginx.yaml → 4-moodle-image-builder/cloudbuild-nginx.yaml
- `PersistentVolumeClaim pvc-regional-pd (200Gi ReadWriteOnce)` --references--> `Namespace moodle`  [EXTRACTED]
  3-pvc/pvc-regional-pd.yaml → 2-namespace/namespace-moodle.yaml
- `ConfigMap moodle-configmap-uploads (512M Uploads, 3600s PHP Execution Timeout)` --references--> `Namespace moodle`  [EXTRACTED]
  5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml → 2-namespace/namespace-moodle.yaml
- `HorizontalPodAutoscaler moodle-hpa (3-9 Replicas, CPU 75%, Memory 80%)` --references--> `Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)`  [EXTRACTED]
  9-hpa/moodle-hpa.yaml → 5a-deployment-no-helm/moodle-deployment-nginx.yaml
- `HorizontalPodAutoscaler moodle-uploads-hpa (1-5 Replicas, CPU 75%, Memory 80%)` --references--> `Deployment moodle-deployment-uploads (Dedicated Large Upload Pod, 512M/3600s)`  [EXTRACTED]
  9-hpa/moodle-uploads-hpa.yaml → 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml

## Import Cycles
- None detected.

## Communities (36 total, 10 thin omitted)

### Community 0 - "envs.sh"
Cohesion: 0.04
Nodes (54): ARTIFACT_REGISTRY_NAME, CLOUD_BUILD_SA_EMAIL, CREATE_CLOUD_SQL, CREATE_JUMPBOX, CREATE_REDIS, CREATE_REDIS_CLUSTER, DB_TYPE, FILESTORE_CAPACITY (+46 more)

### Community 1 - "README.md"
Cohesion: 0.09
Nodes (14): Building Moodle's container image, Deploying Backend Configuration (`BackendConfig`), Deploying infrastructure, Infrastructure information needed for Moodle image configuration, Deploying Ingress - Cloud Load Balancer, Deploying Ingress, Deploying Ingress - NGINX, Deploying Moodle's namespace (+6 more)

### Community 2 - "GCP Infrastructure, Selective Adoption, and Cloud SQL MySQL 8.4"
Cohesion: 0.14
Nodes (11): Files, Centralized Configuration and Pre-Flight Validation (`0-infra/envs.sh`), Cloud SQL MySQL 8.4 for Moodle 5.0+, GCP Infrastructure, Selective Adoption, and Cloud SQL MySQL 8.4, Infrastructure Cleanup and Lifecycle Scripts (`cleanup-moodle-install.sh`, `infra-destroy.sh`, `infra-pause.sh`, `infra-resume.sh`), Selective Infrastructure Adoption, VPC Network, Private GKE Cluster, and CSI Drivers, Comparison: Cloud Filestore vs. Regional Replicated PD (+3 more)

### Community 3 - "Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)"
Cohesion: 0.13
Nodes (22): PersistentVolume pv-filestore (2.5Ti ReadWriteMany NFS /moodleshare), PersistentVolume pv-regional-pd (200Gi ReadWriteOnce pd.csi.storage.gke.io), StorageClass moodle-regional-pd-sc (pd-balanced regional-pd WaitForFirstConsumer), Namespace moodle, PersistentVolumeClaim pvc-filestore (300Gi-500Gi ReadWriteMany), PersistentVolumeClaim pvc-regional-pd (200Gi ReadWriteOnce), Cloud Build Pipeline moodle-nginx Image Builder (Dockerfile.nginx), ConfigMap moodle-configmap (Moodle 5.2.4, Moosh, Cloud SQL, Redis Session/App/Lock, SSLProxy) (+14 more)

### Community 4 - "Cloud CDN for Moodle, NGINX/PHP-FPM Tuning, and Ingress Routing"
Cohesion: 0.15
Nodes (10): 1. Enabling `slasharguments`, `PATH_INFO`, and `X-Accel-Redirect` (`^~`) in Moodle and NGINX, 2. NGINX Cache Control Rules for Cloud CDN, 3. `BackendConfig` Configuration (`USE_ORIGIN_HEADERS` vs. `uploads`), 4. NGINX & PHP-FPM 8.3 Tuning and Ingress Routing, Cloud CDN for Moodle, NGINX/PHP-FPM Tuning, and Ingress Routing, 1. Automated Manifest Rendering (`create-config-files.sh`), 2. Configuration and Resource Isolation on Upload Pods, 3. Independent Horizontal Pod Autoscaling (`9-hpa/`) (+2 more)

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
Cohesion: 0.29
Nodes (5): 1. Multi-Stage `preloadable_libiconv.so` Compilation (MDL-80440), 2. PHP 8.3 and Dynamic Composer Checksum Verification, 3. Moodle 5.2.4 Bootstrap, Composer Dependencies, and `/public` Webroot (`setup_moodle.sh`), NGINX + PHP 8.3 Container Image, GNU libiconv, and Moodle 5.2+ Bootstrap, Files

### Community 14 - "Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`)"
Cohesion: 0.33
Nodes (6): 1. Selective Infrastructure Adoption in `0-infra/envs.sh`, 2. Configuring Storage Sizes, 3. Deploying Regional Replicated Persistent Disk (`regional-pd`) in GKE, Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`), Option A: Static Provisioning (Pre-created Disk via `0-infra/infra-creation.sh`), Option B: Dynamic Provisioning (via GKE CSI `StorageClass`)

### Community 15 - "How to Contribute"
Cohesion: 0.40
Nodes (4): Code Reviews, Community Guidelines, Contributor License Agreement, How to Contribute

### Community 16 - "Configuring Redis Cache with Moodle"
Cohesion: 0.40
Nodes (5): 1. Add or verify entries in Moodle's config.php file, 2. Create a mapping for Redis from Moodle UI, 3. CLI-based Redis Configuration Reference, 4. Large-Scale Deployments: Memorystore for Redis Cluster (MRC), Configuring Redis Cache with Moodle

### Community 17 - "Sentinel's Journal — Security, Hardening & Review Guardrails (`google/moodle-on-gcp`)"
Cohesion: 0.10
Nodes (19): 1. Repository Architecture & Current Stack (`main`), 2. Mandatory Guardrails (Preventing PR #38 Regressions), 3. Verification & Test Suite (Run Before Every Commit / PR), 4. Using the Jules CLI (`@google/jules`) with This Repository, Agent & Jules Configuration Guide (`google/moodle-on-gcp`), OpenWiki, Claude & Agent Instructions (`google/moodle-on-gcp`), OpenWiki (+11 more)

### Community 18 - "Configuring Cloud CDN and Dedicated Upload Pods with Functional Moodle"
Cohesion: 0.50
Nodes (4): 1. How Cloud CDN Caching Works with Moodle 5.2+, 2. Applying the BackendConfig and Dedicated Upload Manifests, 3. Verifying Cloud CDN Cache Hits, Configuring Cloud CDN and Dedicated Upload Pods with Functional Moodle

### Community 19 - "Project overview"
Cohesion: 0.50
Nodes (4): Benefits, Cost view, How it works?, Project overview

### Community 20 - "Documentation"
Cohesion: 0.50
Nodes (4): Basic installation, Documentation, Modern Moodle on Google Cloud Platform (GCP), Post-installation

### Community 22 - "Deploying Persistent Volume Claim (PVC)"
Cohesion: 0.67
Nodes (3): Deploying Persistent Volume Claim (PVC), Option A: Cloud Filestore (`STORAGE_TYPE="filestore"`), Option B: Regional Replicated Persistent Disk (`STORAGE_TYPE="regional-pd"`)

### Community 23 - "Deploying Persistent Volume (PV)"
Cohesion: 0.67
Nodes (3): Deploying Persistent Volume (PV), Option A: Cloud Filestore (`STORAGE_TYPE="filestore"`), Option B: Regional Replicated Persistent Disk (`STORAGE_TYPE="regional-pd"`)

### Community 24 - "Deployment"
Cohesion: 0.67
Nodes (3): Basic installation, Deployment, Post-installation

### Community 25 - "Migrating from previous Bitnami image to NGINX based image (Recommended)"
Cohesion: 0.67
Nodes (3): 1. Backup your DB and moodle data, 2. (Optional Step) For a fresh install and you want to start fresh, cleanup everyting Moodze in your current GKE first, Migrating from previous Bitnami image to NGINX based image (Recommended)

### Community 26 - "Running a benchmark to check the performance"
Cohesion: 0.67
Nodes (3): 1. Installing the plugin, 2. Running Moodle Benchmark, Running a benchmark to check the performance

### Community 27 - "Updating Environment Variables and Upgrading Pods"
Cohesion: 0.67
Nodes (3): 1. Updating ConfigMap Values (`5a-deployment-no-helm`), 2. Restarting Pods to Pick Up Updated Configuration, Updating Environment Variables and Upgrading Pods

### Community 28 - "Configuring SSL and forcing HTTPS redirect"
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

## Knowledge Gaps
- **166 isolated node(s):** `envs.sh script`, `PROJECT_NUMBER`, `PROJECT_ID`, `REGION`, `ZONE` (+161 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 173 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Pre-requisites` connect `Pre-requisites` to `README.md`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`)` connect `Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`)` to `README.md`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `Configuring Redis Cache with Moodle` connect `Configuring Redis Cache with Moodle` to `README.md`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `envs.sh script`, `PROJECT_NUMBER`, `PROJECT_ID` to the rest of the system?**
  _166 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `envs.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.03636363636363636 - nodes in this community are weakly interconnected._
- **Should `README.md` be split into smaller, more focused modules?**
  _Cohesion score 0.08906882591093117 - nodes in this community are weakly interconnected._
- **Should `GCP Infrastructure, Selective Adoption, and Cloud SQL MySQL 8.4` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._