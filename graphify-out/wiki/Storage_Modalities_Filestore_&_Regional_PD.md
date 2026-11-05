# Storage Modalities (Filestore & Regional PD)

> 13 nodes

## Key Concepts

- **Deployment moodle-deployment (Primary Web Pod, PHP 8.3 & NGINX Mounts, tmpfs /tmp)** (7 connections) — `5a-deployment-no-helm/moodle-deployment-nginx.yaml`
- **Namespace moodle** (6 connections) — `2-namespace/namespace-moodle.yaml`
- **Deployment moodle-deployment-uploads (Dedicated Large Upload Pod, 512M/3600s)** (6 connections) — `5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml`
- **PersistentVolumeClaim pvc-filestore (300Gi-500Gi ReadWriteMany)** (4 connections) — `3-pvc/pvc-filestore.yaml`
- **ConfigMap moodle-configmap (Moodle 5.2.4, Moosh, Cloud SQL, Redis Session/App/Lock, SSLProxy)** (3 connections) — `5a-deployment-no-helm/moodle-configmap-nginx.yaml`
- **PersistentVolume pv-regional-pd (200Gi ReadWriteOnce pd.csi.storage.gke.io)** (2 connections) — `1-pv/pv-regional-pd.yaml`
- **PersistentVolumeClaim pvc-regional-pd (200Gi ReadWriteOnce)** (2 connections) — `3-pvc/pvc-regional-pd.yaml`
- **Cloud Build Pipeline moodle-nginx Image Builder (Dockerfile.nginx)** (2 connections) — `4-moodle-image-builder/cloudbuild-nginx.yaml`
- **ConfigMap moodle-configmap-uploads (512M Uploads, 3600s PHP Execution Timeout)** (2 connections) — `5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml`
- **PersistentVolume pv-filestore (2.5Ti ReadWriteMany NFS /moodleshare)** (1 connections) — `1-pv/pv-filestore.yaml`
- **StorageClass moodle-regional-pd-sc (pd-balanced regional-pd WaitForFirstConsumer)** (1 connections) — `1-pv/storageclass-regional-pd.yaml`
- **HorizontalPodAutoscaler moodle-hpa (3-9 Replicas, CPU 75%, Memory 80%)** (1 connections) — `9-hpa/moodle-hpa.yaml`
- **HorizontalPodAutoscaler moodle-uploads-hpa (1-5 Replicas, CPU 75%, Memory 80%)** (1 connections) — `9-hpa/moodle-uploads-hpa.yaml`

## Relationships

- [GCP Infrastructure & Cloud SQL MySQL 8.4](GCP_Infrastructure_&_Cloud_SQL_MySQL_8.4.md) (2 shared connections)

## Source Files

- `1-pv/pv-filestore.yaml`
- `1-pv/pv-regional-pd.yaml`
- `1-pv/storageclass-regional-pd.yaml`
- `2-namespace/namespace-moodle.yaml`
- `3-pvc/pvc-filestore.yaml`
- `3-pvc/pvc-regional-pd.yaml`
- `4-moodle-image-builder/cloudbuild-nginx.yaml`
- `5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml`
- `5a-deployment-no-helm/moodle-configmap-nginx.yaml`
- `5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml`
- `5a-deployment-no-helm/moodle-deployment-nginx.yaml`
- `9-hpa/moodle-hpa.yaml`
- `9-hpa/moodle-uploads-hpa.yaml`

## Audit Trail

- EXTRACTED: 18 (90%)
- INFERRED: 2 (10%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [index](index.md) to navigate.*