# Graph Report - modern-moodle-correction  (2026-11-05)

## Corpus Check
- 113 files · ~108,752 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 41 file(s) not represented in the graph (top: .ini 30, .conf 4, (none) 2)

## Summary
- 137 nodes · 161 edges · 11 communities (6 shown, 5 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 6 edges (avg confidence: 0.65)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- GKE Deployments & Upload Isolation
- Moodle 5.2 Runtime & PHP 8.3 Image
- Cloud CDN & Ingress Routing
- Storage Modalities (Filestore & Regional PD)
- GCP Infrastructure & Cloud SQL MySQL 8.4
- Redis Caching & Session Locking
- OpenWiki & Architecture Documentation
- SSL Certificates & Security Hardening
- Moodle Subsystem 8
- Moodle Subsystem 9

## God Nodes (most connected - your core abstractions)
1. `README: Modern Moodle on GCP Documentation Index` - 25 edges
2. `Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)` - 7 edges
3. `Namespace moodle` - 6 edges
4. `Deployment moodle-deployment-uploads (Dedicated Large Upload Pod, 512M/3600s)` - 6 edges
5. `Choosing and Configuring Storage (Filestore vs. Regional Replicated PD)` - 6 edges
6. `Quickstart e Mapa Arquitetural do Moodle on GCP` - 6 edges
7. `Configuring Cloud CDN and Dedicated Upload Pods with Moodle` - 5 edges
8. `Infraestrutura GCP, Adocao Seletiva e Cloud SQL MySQL 8.4` - 5 edges
9. `Modalidades de Storage: Filestore vs. Regional Replicated Persistent Disk` - 5 edges
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

## Communities (11 total, 5 thin omitted)

### Community 0 - "GKE Deployments & Upload Isolation"
Cohesion: 0.05
Nodes (43): CLOUD_BUILD_SA_EMAIL, CREATE_CLOUD_SQL, CREATE_JUMPBOX, CREATE_REDIS, FILESTORE_CAPACITY, FILESTORE_IP_ADDRESS, FILESTORE_MOUNT, FILESTORE_NAME (+35 more)

### Community 1 - "Moodle 5.2 Runtime & PHP 8.3 Image"
Cohesion: 0.09
Nodes (32): Cloud-Native Stateless Moodle Architecture (GKE, Cloud SQL, Filestore, Memorystore, Cloud CDN), Architecture: Modern Moodle on GCP Components, Building Moodle NGINX + PHP 8.3 Container Image with Cloud Build, Storage Tradeoff Rationale: Cloud Filestore RWX vs Regional PD RWO/ROX, Choosing and Configuring Storage (Filestore vs. Regional Replicated PD), Selective Infrastructure Adoption Flags (CREATE_* and STORAGE_TYPE), Dedicated Upload Pods Routing (/repository/repository_ajax.php & draftfiles_ajax.php), Configuring Cloud CDN and Dedicated Upload Pods with Moodle (+24 more)

### Community 2 - "Cloud CDN & Ingress Routing"
Cohesion: 0.12
Nodes (21): Cloud SQL MySQL 8.4 Requirement for Moodle 5.0+, Infraestrutura GCP, Adocao Seletiva e Cloud SQL MySQL 8.4, Custom VPC, Cloud NAT, and Private GKE Dataplane V2 with CSI Drivers, Selective Infrastructure Adoption Flags (CREATE_CLOUD_SQL, CREATE_REDIS, STORAGE_TYPE), Pre-Flight Environment Validation (validate_moodle_envs), Modalidades de Storage: Filestore vs. Regional Replicated Persistent Disk, Cloud Filestore NFS ReadWriteMany Storage Modality, Regional Replicated Persistent Disk (pd.csi.storage.gke.io) Storage Modality (+13 more)

### Community 3 - "Storage Modalities (Filestore & Regional PD)"
Cohesion: 0.23
Nodes (13): PersistentVolume pv-filestore (2.5Ti ReadWriteMany NFS /moodleshare), PersistentVolume pv-regional-pd (200Gi ReadWriteOnce pd.csi.storage.gke.io), StorageClass moodle-regional-pd-sc (pd-balanced regional-pd WaitForFirstConsumer), Namespace moodle, PersistentVolumeClaim pvc-filestore (300Gi-500Gi ReadWriteMany), PersistentVolumeClaim pvc-regional-pd (200Gi ReadWriteOnce), Cloud Build Pipeline moodle-nginx Image Builder (Dockerfile.nginx), ConfigMap moodle-configmap (Moodle 5.2.4, Moosh, Cloud SQL, Redis Session/App/Lock, SSLProxy) (+5 more)

### Community 4 - "GCP Infrastructure & Cloud SQL MySQL 8.4"
Cohesion: 0.25
Nodes (9): Service moodle (ClusterIP 80->8080, NEG & ingress-backendconfig), Service moodle-service-uploads (ClusterIP 80->8080, NEG & ingress-backendconfig-uploads), Cloud CDN USE_ORIGIN_HEADERS Policy (Caches Static/Versioned Moodle Assets, Protects Private Files), BackendConfig ingress-backendconfig (300s Timeout, /healthz, Cloud CDN USE_ORIGIN_HEADERS), BackendConfig ingress-backendconfig-uploads (3600s Timeout, /healthz, Cloud CDN Disabled), FrontendConfig moodle-ingress-frontendconfig-https (301 HTTP-to-HTTPS Redirect), ManagedCertificate moodle-google-managed-certificate, Ingress moodle-ingress (GCE External HTTP(S) Load Balancer, Path Routing for Ajax Uploads) (+1 more)

### Community 5 - "Redis Caching & Session Locking"
Cohesion: 0.29
Nodes (4): cleanup-moodle-install.sh script, validate_moodle_envs(), infra-creation.sh script, build-nginx-based-image.sh script

## Knowledge Gaps
- **66 isolated node(s):** `envs.sh script`, `PROJECT_NUMBER`, `PROJECT_ID`, `REGION`, `ZONE` (+61 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 75 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)` connect `Storage Modalities (Filestore & Regional PD)` to `GCP Infrastructure & Cloud SQL MySQL 8.4`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `envs.sh script`, `PROJECT_NUMBER`, `PROJECT_ID` to the rest of the system?**
  _66 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `GKE Deployments & Upload Isolation` be split into smaller, more focused modules?**
  _Cohesion score 0.045454545454545456 - nodes in this community are weakly interconnected._
- **Should `Moodle 5.2 Runtime & PHP 8.3 Image` be split into smaller, more focused modules?**
  _Cohesion score 0.09274193548387097 - nodes in this community are weakly interconnected._
- **Should `Cloud CDN & Ingress Routing` be split into smaller, more focused modules?**
  _Cohesion score 0.11904761904761904 - nodes in this community are weakly interconnected._