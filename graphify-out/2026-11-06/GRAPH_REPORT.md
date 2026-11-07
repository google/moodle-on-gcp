# Graph Report - modern-moodle-correction  (2026-11-06)

## Corpus Check
- 60 files · ~111,573 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 41 file(s) not represented in the graph (top: .ini 30, .conf 4, (none) 2)

## Summary
- 253 nodes · 280 edges · 32 communities (24 shown, 8 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 6 edges (avg confidence: 0.65)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `aab53eee`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- envs.sh
- README.md
- Infraestrutura GCP, Adoção Seletiva e Cloud SQL MySQL 8.4
- Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)
- Cloud CDN com Moodle Funcional, Tuning NGINX/PHP-FPM e Ingress
- validate_moodle_envs
- setup_moodle.sh
- create-config-files.sh
- entrypoint.sh
- build-gnu-libiconv.sh
- Pre-requisites
- openwiki/index.md
- Imagem Container NGINX + PHP 8.3, GNU libiconv e Bootstrap do Moodle 5.2+
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

## God Nodes (most connected - your core abstractions)
1. `Sentinel's Journal — Security, Hardening & Review Guardrails (`google/moodle-on-gcp`)` - 8 edges
2. `Pre-requisites` - 7 edges
3. `Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)` - 7 edges
4. `Agent & Jules Configuration Guide (`google/moodle-on-gcp`)` - 6 edges
5. `Infraestrutura GCP, Adoção Seletiva e Cloud SQL MySQL 8.4` - 6 edges
6. `Namespace moodle` - 6 edges
7. `Deployment moodle-deployment-uploads (Dedicated Large Upload Pod, 512M/3600s)` - 6 edges
8. `Configuring Redis Cache with Moodle` - 5 edges
9. `Cloud CDN com Moodle Funcional, Tuning NGINX/PHP-FPM e Ingress` - 5 edges
10. `validate_moodle_envs()` - 4 edges

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

## Communities (32 total, 8 thin omitted)

### Community 0 - "envs.sh"
Cohesion: 0.04
Nodes (48): CLOUD_BUILD_SA_EMAIL, CREATE_CLOUD_SQL, CREATE_JUMPBOX, CREATE_REDIS, CREATE_REDIS_CLUSTER, FILESTORE_CAPACITY, FILESTORE_IP_ADDRESS, FILESTORE_MOUNT (+40 more)

### Community 1 - "README.md"
Cohesion: 0.09
Nodes (13): Building Moodle's container image, Deploying Backend Configuration (`BackendConfig`), Deploying infrastructure, Infrastructure information needed for Moodle image configuration, Deploying Ingress - Cloud Load Balancer, Deploying Ingress, Deploying Ingress - NGINX, Deploying Moodle's namespace (+5 more)

### Community 2 - "Infraestrutura GCP, Adoção Seletiva e Cloud SQL MySQL 8.4"
Cohesion: 0.14
Nodes (11): Arquivos, Adoção Seletiva de Componentes de Infraestrutura, Cloud SQL MySQL 8.4 para Moodle 5.0+, Infraestrutura GCP, Adoção Seletiva e Cloud SQL MySQL 8.4, Limpeza e Reinicialização Segura (`0-infra/cleanup-moodle-install.sh`), Parametrização Central e Validação Pre-Flight (`0-infra/envs.sh`), Rede VPC, Cluster GKE Privado e Drivers CSI, Comparativo entre Cloud Filestore e Regional Replicated PD (+3 more)

### Community 3 - "Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)"
Cohesion: 0.13
Nodes (22): PersistentVolume pv-filestore (2.5Ti ReadWriteMany NFS /moodleshare), PersistentVolume pv-regional-pd (200Gi ReadWriteOnce pd.csi.storage.gke.io), StorageClass moodle-regional-pd-sc (pd-balanced regional-pd WaitForFirstConsumer), Namespace moodle, PersistentVolumeClaim pvc-filestore (300Gi-500Gi ReadWriteMany), PersistentVolumeClaim pvc-regional-pd (200Gi ReadWriteOnce), Cloud Build Pipeline moodle-nginx Image Builder (Dockerfile.nginx), ConfigMap moodle-configmap (Moodle 5.2.4, Moosh, Cloud SQL, Redis Session/App/Lock, SSLProxy) (+14 more)

### Community 4 - "Cloud CDN com Moodle Funcional, Tuning NGINX/PHP-FPM e Ingress"
Cohesion: 0.15
Nodes (10): 1. Habilitação de `slasharguments` e `PATH_INFO` no Moodle e NGINX, 2. Regras de Cache do NGINX para o Cloud CDN, 3. Configuração dos `BackendConfig` (`USE_ORIGIN_HEADERS` vs. `uploads`), 4. Tuning de NGINX e PHP-FPM 8.3 e Roteamento no Ingress, Cloud CDN com Moodle Funcional, Tuning NGINX/PHP-FPM e Ingress, 1. Renderização Automatizada de Manifestos (`create-config-files.sh`), 2. Isolamento de Configuração e Recursos nos Pods de Upload, 3. Escalonamento Horizontal Independente (`9-hpa/`) (+2 more)

### Community 5 - "validate_moodle_envs"
Cohesion: 0.29
Nodes (4): cleanup-moodle-install.sh script, validate_moodle_envs(), infra-creation.sh script, build-nginx-based-image.sh script

### Community 11 - "Pre-requisites"
Cohesion: 0.29
Nodes (7): Enable Moodle's underlying infrastructure services APIs in Google Cloud, Get a project set up and administrative rights for it, Google Cloud account, Install `gcloud` command line extension, Install git client, Pre-requisites, Save compute account (principal) data for later usage

### Community 12 - "openwiki/index.md"
Cohesion: 0.29
Nodes (5): Arquivos, Diretórios, Fluxo Rápido de Implantação (Passo a Passo), Mapa de Roteamento de Tarefas da Documentação OpenWiki, Quickstart e Mapa Arquitetural do Moodle on GCP

### Community 13 - "Imagem Container NGINX + PHP 8.3, GNU libiconv e Bootstrap do Moodle 5.2+"
Cohesion: 0.29
Nodes (5): 1. Compilação Multi-Stage do `preloadable_libiconv.so` (MDL-80440), 2. PHP 8.3 e Verificação Dinâmica do Composer, 3. Bootstrap do Moodle 5.2.4, Dependências Composer e Webroot `/public` (`setup_moodle.sh`), Imagem Container NGINX + PHP 8.3, GNU libiconv e Bootstrap do Moodle 5.2+, Arquivos

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
Cohesion: 0.11
Nodes (16): 1. Repository Architecture & Current Stack (`main`), 2. Mandatory Guardrails (Preventing PR #38 Regressions), 3. Verification & Test Suite (Run Before Every Commit / PR), 4. Using the Jules CLI (`@google/jules`) with This Repository, Agent & Jules Configuration Guide (`google/moodle-on-gcp`), OpenWiki, Claude & Agent Instructions (`google/moodle-on-gcp`), OpenWiki (+8 more)

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
Cohesion: 0.83
Nodes (3): create_mock_config(), run_replica_snippet(), verify-scripts-and-configs.sh script

## Knowledge Gaps
- **151 isolated node(s):** `envs.sh script`, `PROJECT_NUMBER`, `PROJECT_ID`, `REGION`, `ZONE` (+146 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 157 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Pre-requisites` connect `Pre-requisites` to `README.md`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`)` connect `Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`)` to `README.md`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `Configuring Redis Cache with Moodle` connect `Configuring Redis Cache with Moodle` to `README.md`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **What connects `envs.sh script`, `PROJECT_NUMBER`, `PROJECT_ID` to the rest of the system?**
  _151 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `envs.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.04081632653061224 - nodes in this community are weakly interconnected._
- **Should `README.md` be split into smaller, more focused modules?**
  _Cohesion score 0.09246088193456614 - nodes in this community are weakly interconnected._
- **Should `Infraestrutura GCP, Adoção Seletiva e Cloud SQL MySQL 8.4` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._