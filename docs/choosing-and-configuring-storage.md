# Choosing and Configuring Storage (`Filestore` vs. `Regional Replicated Persistent Disk`)

Moodle requires shared persistent storage for its data directory (`$CFG->dataroot`, mounted at `/moodledata`) and, in this deployment architecture, the shared webroot (`/var/www/html/moodle`) and runtime configuration files (`/etc/nginx`, `/etc/php83`).

This repository supports **selective storage adoption** and **configurable storage capacities** via `0-infra/envs.sh`, allowing you to choose the storage backend that best matches your scale, high-availability requirements, and budget:

1. **Cloud Filestore (`STORAGE_TYPE="filestore"`, default)**:
   - Managed NFS file storage supporting **`ReadWriteMany` (`RWX`)** across any number of GKE nodes and zones.
   - Recommended for multi-node horizontally autoscaled (`HPA`) Moodle deployments where multiple pods simultaneously write to `$CFG->dataroot`.
   - Configurable tier (`BASIC_HDD`, `BASIC_SSD`, `ZONAL`, `REGIONAL`, `ENTERPRISE`) and capacity (`FILESTORE_CAPACITY`, e.g., `1Ti`, `2.5Ti`) in `0-infra/envs.sh`.

2. **Regional Replicated Persistent Disk (`STORAGE_TYPE="regional-pd"`)**:
   - Synchronous block-level replication across two zones in the same region (`$ZONE` and `$REPLICA_ZONE`) using the GKE Compute Engine Persistent Disk CSI Driver (`pd.csi.storage.gke.io`).
   - Supports capacities starting as low as **10 GiB–200 GiB** (`PD_DISK_SIZE="200Gi"`, `PD_DISK_TYPE="pd-balanced"` or `"pd-ssd"`), providing a significantly lower minimum entry cost than Cloud Filestore (`1Ti` minimum on `BASIC_HDD` / `2.5Ti` on `BASIC_SSD`) while still maintaining regional high availability across two zones.
   - **Access Mode Considerations (`ReadWriteOnce` vs. `ReadOnlyMany`)**:
     - Standard Compute Engine Persistent Disks (including Regional PDs) support **`ReadWriteOnce` (`RWO`)** for read-write mounts (all pods mounting the volume read-write must be scheduled onto the same GKE node, or Failover occurs automatically to `$REPLICA_ZONE` if the primary zone/node becomes unavailable) or **`ReadOnlyMany` (`ROX`)** across multiple nodes.
     - When using `STORAGE_TYPE="regional-pd"` with `PD_ACCESS_MODE="ReadWriteOnce"`, you can either:
       - Run single-node or node-colocated Moodle pods (where HPA scales pods within the node holding the attached Regional PD, and GKE automatically fails over the Regional PD to `$REPLICA_ZONE` on node/zone outage), or
       - Offload `$CFG->dataroot` file storage to an object storage plugin (`tool_objectfs` with Google Cloud Storage) while keeping `/var/www/html/moodle` on the Regional PD.

3. **Bring-Your-Own Storage (`STORAGE_TYPE="none"`)**:
   - Skips storage provisioning in `0-infra/infra-creation.sh` when you are connecting to an existing NFS server, NetApp Volumes instance, or custom CSI `StorageClass`.

---

## 1. Selective Infrastructure Adoption in `0-infra/envs.sh`

Every major infrastructure component in `0-infra/infra-creation.sh` can be toggled independently:

```bash
export STORAGE_TYPE="filestore" # Options: "filestore" | "regional-pd" | "none"

export CREATE_VPC_AND_NAT="${CREATE_VPC_AND_NAT:-true}"
export CREATE_GKE="${CREATE_GKE:-true}"
export CREATE_CLOUD_SQL="${CREATE_CLOUD_SQL:-true}"
export CREATE_REDIS="${CREATE_REDIS:-true}"
export CREATE_FILESTORE="${CREATE_FILESTORE:-true}"
export CREATE_REGIONAL_PD="${CREATE_REGIONAL_PD:-false}"
export CREATE_ARTIFACT_REGISTRY="${CREATE_ARTIFACT_REGISTRY:-true}"
export CREATE_JUMPBOX="${CREATE_JUMPBOX:-true}"
```

- When `STORAGE_TYPE="filestore"`, `0-infra/infra-creation.sh` provisions the VPC peering range and Cloud Filestore instance (when `CREATE_FILESTORE=true`).
- When `STORAGE_TYPE="regional-pd"`, `0-infra/infra-creation.sh` skips Filestore VPC peering and Filestore instance creation, and instead provisions a Regional Replicated Persistent Disk across `$ZONE` and `$REPLICA_ZONE`:
  ```bash
  gcloud compute disks create "$PD_DISK_NAME" \
    --region="$REGION" \
    --replica-zones="$ZONE,$REPLICA_ZONE" \
    --type="$PD_DISK_TYPE" \
    --size="$PD_DISK_SIZE"
  ```

---

## 2. Configuring Storage Sizes

All storage capacities for both infrastructure creation and Kubernetes `PV`/`PVC` manifests are centralized in `0-infra/envs.sh`:

```bash
# Cloud Filestore tier and capacity
export FILESTORE_TIER="BASIC_SSD"     # BASIC_HDD (>=1Ti), BASIC_SSD (>=2.5Ti), ZONAL, REGIONAL, ENTERPRISE
export FILESTORE_CAPACITY="2.5Ti"

# Regional Replicated Persistent Disk (regional-pd) settings
export REPLICA_ZONE="us-central1-b"
export PD_DISK_NAME="moodle-regional-pd"
export PD_DISK_TYPE="pd-balanced"     # pd-balanced, pd-ssd, pd-standard
export PD_DISK_SIZE="200Gi"
export PD_ACCESS_MODE="ReadWriteOnce"

# Kubernetes PV and PVC sizes (rendered by 5a-deployment-no-helm/create-config-files.sh)
export PV_STORAGE_SIZE="${FILESTORE_CAPACITY}"
export PVC_STORAGE_SIZE="300Gi"
export PVC_LIMIT_STORAGE_SIZE="500Gi"
```

When you run `5a-deployment-no-helm/create-config-files.sh`, it automatically updates:
- `1-pv/pv-filestore.yaml` and `3-pvc/pvc-filestore.yaml`
- `1-pv/storageclass-regional-pd.yaml`, `1-pv/pv-regional-pd.yaml`, and `3-pvc/pvc-regional-pd.yaml`
- `5a-deployment-no-helm/moodle-deployment-nginx.yaml` (setting `claimName: pvc-filestore` or `claimName: pvc-regional-pd` based on `STORAGE_TYPE`)

---

## 3. Deploying Regional Replicated Persistent Disk (`regional-pd`) in GKE

You can deploy Regional Replicated Persistent Disks in GKE using either **Static Provisioning** (with the disk created by `0-infra/infra-creation.sh`) or **Dynamic Provisioning** (via `StorageClass`):

### Option A: Static Provisioning (Pre-created Disk via `0-infra/infra-creation.sh`)
```bash
kubectl apply -f 1-pv/pv-regional-pd.yaml
kubectl apply -f 2-namespace/moodle-namespace.yaml
kubectl apply -f 3-pvc/pvc-regional-pd.yaml
```

### Option B: Dynamic Provisioning (via GKE CSI `StorageClass`)
If you prefer GKE to dynamically create the Regional Replicated Persistent Disk when the PVC is claimed:
1. Apply the Regional PD `StorageClass`:
   ```bash
   kubectl apply -f 1-pv/storageclass-regional-pd.yaml
   ```
2. In `3-pvc/pvc-regional-pd.yaml`, set `storageClassName: moodle-regional-pd` and omit `volumeName: pv-regional-pd`, then apply:
   ```bash
   kubectl apply -f 3-pvc/pvc-regional-pd.yaml
   ```
