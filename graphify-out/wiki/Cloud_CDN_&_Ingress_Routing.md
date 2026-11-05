# Cloud CDN & Ingress Routing

> 21 nodes

## Key Concepts

- **Quickstart e Mapa Arquitetural do Moodle on GCP** (6 connections) — `openwiki/quickstart.md`
- **Infraestrutura GCP, Adocao Seletiva e Cloud SQL MySQL 8.4** (5 connections) — `openwiki/architecture/infrastructure-and-networking.md`
- **Modalidades de Storage: Filestore vs. Regional Replicated Persistent Disk** (5 connections) — `openwiki/architecture/storage-modalities.md`
- **Cloud CDN com Moodle Funcional, Tuning NGINX/PHP-FPM e Ingress** (4 connections) — `openwiki/operations/cloud-cdn-and-ingress.md`
- **Deployments GKE, Isolamento de Pods de Upload e HPA** (4 connections) — `openwiki/operations/gke-deployments-and-uploads-isolation.md`
- **Imagem Container NGINX + PHP 8.3, GNU libiconv e Bootstrap do Moodle 5.2+** (3 connections) — `openwiki/runtime/container-image-moodle52-php83.md`
- **Dedicated Upload Pods SubPath Isolation (etc/nginx-uploads, etc/php83-uploads) and 512M/3600s Tuning** (3 connections) — `openwiki/operations/gke-deployments-and-uploads-isolation.md`
- **Custom VPC, Cloud NAT, and Private GKE Dataplane V2 with CSI Drivers** (2 connections) — `openwiki/architecture/infrastructure-and-networking.md`
- **Regional Replicated Persistent Disk (pd.csi.storage.gke.io) Storage Modality** (2 connections) — `openwiki/architecture/storage-modalities.md`
- **GKE Ingress Routing of /repository/repository_ajax.php and /repository/draftfiles_ajax.php to Upload Service** (2 connections) — `openwiki/operations/cloud-cdn-and-ingress.md`
- **Automated Manifest Rendering via create-config-files.sh and envsubst** (2 connections) — `openwiki/operations/gke-deployments-and-uploads-isolation.md`
- **Selective Infrastructure Adoption Flags (CREATE_CLOUD_SQL, CREATE_REDIS, STORAGE_TYPE)** (2 connections) — `openwiki/architecture/infrastructure-and-networking.md`
- **Moodle 5.1/5.2+ Composer Install, /public Webroot Auto-Detection (MDL-83424), and Moosh 1.51 Bootstrap** (2 connections) — `openwiki/runtime/container-image-moodle52-php83.md`
- **Pre-Flight Environment Validation (validate_moodle_envs)** (1 connections) — `openwiki/architecture/infrastructure-and-networking.md`
- **Cloud Filestore NFS ReadWriteMany Storage Modality** (1 connections) — `openwiki/architecture/storage-modalities.md`
- **Independent HorizontalPodAutoscalers for Web (3-9 pods) and Uploads (1-5 pods)** (1 connections) — `openwiki/operations/gke-deployments-and-uploads-isolation.md`
- **End-to-End Moodle 5.2.4 GKE Deployment Flow (0-infra to 9-hpa)** (1 connections) — `openwiki/quickstart.md`
- **Cloud SQL MySQL 8.4 Requirement for Moodle 5.0+** (1 connections) — `openwiki/architecture/infrastructure-and-networking.md`
- **Cloud CDN USE_ORIGIN_HEADERS, Set-Cookie Stripping on Theme Loaders, and Private pluginfile.php Bypass** (1 connections) — `openwiki/operations/cloud-cdn-and-ingress.md`
- **Moodle slasharguments and FastCGI PATH_INFO Splitting** (1 connections) — `openwiki/operations/cloud-cdn-and-ingress.md`
- **Multi-Stage GNU preloadable_libiconv.so Compilation on Alpine 3.21 (MDL-80440)** (1 connections) — `openwiki/runtime/container-image-moodle52-php83.md`

## Relationships

- No strong cross-community connections detected

## Source Files

- `openwiki/architecture/infrastructure-and-networking.md`
- `openwiki/architecture/storage-modalities.md`
- `openwiki/operations/cloud-cdn-and-ingress.md`
- `openwiki/operations/gke-deployments-and-uploads-isolation.md`
- `openwiki/quickstart.md`
- `openwiki/runtime/container-image-moodle52-php83.md`

## Audit Trail

- EXTRACTED: 25 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [index](index.md) to navigate.*