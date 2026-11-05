#!/bin/bash
# Copyright 2022 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# environment variables required for the infra-creation script to run
# make changes to your project, region, zone and networking resources
# ip ranges here described are suggestive and can be adjusted to fit production's needs

export PROJECT_NUMBER="<YOUR-PROJECT-NUMBER>"
export PROJECT_ID="<YOUR-PROJECT-ID>"
export REGION="<YOUR-PREFERED-REGION>"
export ZONE="$REGION-a"
export REPLICA_ZONE="$REGION-b" # Secondary zone in $REGION used for Regional Replicated Persistent Disks

export VPC_NAME="<YOUR-VPC-NAME>"
export SUBNET_NAME="<YOUR-SUBNET-NAME>"
export SUBNET_RANGE="10.10.0.0/24"

# gke specific variables
export NODE_SA_EMAIL="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"
export GKE_POD_RANGE="10.168.0.0/14"
export GKE_SVC_RANGE="10.172.0.0/19"
export GKE_MASTER_IPV4_RANGE="10.10.1.0/28"

# cloud build specific variables
export CLOUD_BUILD_SA_EMAIL="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"

# if you have VMs in a different subnet, make sure to include it here, separated by comma (,)
export MASTER_AUTHORIZED_NETWORKS="10.11.0.6/32"

# peering ranges for managed services, such as cloud sql and filestore
export MOODLE_MYSQL_MANAGED_PEERING_RANGE="10.9.0.0"
export MOODLE_FILESTORE_MANAGED_PEERING_RANGE="10.12.0.0"

# NAT config
export NAT_CONFIG="<YOUR-NAT-CONFIG-NAME>"
export NAT_ROUTER="<YOUR-NAT-CONFIG-ROUTER>"

# db specific variables
export GKE_NAME="<YOUR-GKE-CLUSTER-NAME>"
export MYSQL_INSTANCE_NAME="<YOUR-MYSQL-INSTANCE-NAME>"
# Moodle 5.0+ requires MySQL 8.4 (MYSQL_8_4). Use MYSQL_8_0 only if deploying Moodle 4.x.
export MYSQL_DATABASE_VERSION="${MYSQL_DATABASE_VERSION:-MYSQL_8_4}"
# MYSQL_ROOT_PASSWORD is not set here to avoid hardcoding secrets.
# It will be prompted for during infra-creation.sh if not already set.
export MYSQL_DB="<YOUR-MOODLE-DB-NAME>"
export MYSQL_MOODLE_DB_CHARSET="utf8mb4" #recommended charset for Moodle. Change only if necessary.
export MYSQL_MOODLE_DB_COLLATION="utf8mb4_unicode_ci" #recommended collation for Moodle. Change only if necessary.

# other managed services variables
export REDIS_NAME="<YOUR-REDIS-CACHE-NAME>"
export REDIS_CLUSTER_NAME="${REDIS_CLUSTER_NAME:-<YOUR-REDIS-CLUSTER-NAME>}"
export REDIS_CLUSTER_SHARD_COUNT="${REDIS_CLUSTER_SHARD_COUNT:-3}"
export REDIS_CLUSTER_REPLICA_COUNT="${REDIS_CLUSTER_REPLICA_COUNT:-1}"
export REDIS_CLUSTER_NODE_TYPE="${REDIS_CLUSTER_NODE_TYPE:-REDIS_STANDARD_SMALL}"

# ==============================================================================
# Storage Modality, Selective Adoption & Configurable Sizes
# ==============================================================================
# STORAGE_TYPE controls which shared storage backend is provisioned and configured:
#   - "filestore"   : Google Cloud Filestore NFS (ReadWriteMany across multiple nodes/pods)
#   - "regional-pd" : Regional Replicated Persistent Disk across $ZONE and $REPLICA_ZONE
#                     (synchronous block replication via pd.csi.storage.gke.io; lower cost)
#   - "none"        : Skip storage creation in infra-creation.sh (bring your own storage/PVC)
export STORAGE_TYPE="${STORAGE_TYPE:-filestore}"

# Selective infrastructure toggles (set to "false" to skip provisioning specific services)
export CREATE_CLOUD_SQL="${CREATE_CLOUD_SQL:-true}"
export CREATE_REDIS="${CREATE_REDIS:-true}"
# Set CREATE_REDIS_CLUSTER="true" (and CREATE_REDIS="false") for large-scale deployments using
# Google Cloud Memorystore for Redis Cluster (MRC) with Moodle 5.2+ RedisCluster (Issue #23 / MDL-59196).
export CREATE_REDIS_CLUSTER="${CREATE_REDIS_CLUSTER:-false}"
export CREATE_JUMPBOX="${CREATE_JUMPBOX:-true}"

if [ "$STORAGE_TYPE" = "filestore" ]; then
  export CREATE_FILESTORE="${CREATE_FILESTORE:-true}"
  export CREATE_REGIONAL_PD="${CREATE_REGIONAL_PD:-false}"
elif [ "$STORAGE_TYPE" = "regional-pd" ]; then
  export CREATE_FILESTORE="${CREATE_FILESTORE:-false}"
  export CREATE_REGIONAL_PD="${CREATE_REGIONAL_PD:-true}"
else
  export CREATE_FILESTORE="${CREATE_FILESTORE:-false}"
  export CREATE_REGIONAL_PD="${CREATE_REGIONAL_PD:-false}"
fi

# --- Option A: Cloud Filestore Configuration ---
export FILESTORE_NAME="<YOUR-FILESTORE-NAME>"
export FILESTORE_IP_ADDRESS="${FILESTORE_IP_ADDRESS:-<YOUR-FILESTORE-INTERNAL-IP>}"
# Supported FILESTORE_TIER values:
#   - BASIC_SSD  (minimum capacity: 2.5TB)
#   - BASIC_HDD  (minimum capacity: 1TB)
#   - ZONAL      (minimum capacity: 1TB)
#   - REGIONAL   (minimum capacity: 1TB, multi-zone HA)
#   - ENTERPRISE (minimum capacity: 1TB, multi-zone HA)
export FILESTORE_TIER="${FILESTORE_TIER:-BASIC_SSD}"
export FILESTORE_SHARE_NAME="${FILESTORE_SHARE_NAME:-moodleshare}"
export FILESTORE_CAPACITY="${FILESTORE_CAPACITY:-2.5TB}"
export FILESTORE_MOUNT="/mnt/filestore1"

# --- Option B: Regional Replicated Persistent Disk (Regional PD) Configuration ---
export PD_DISK_NAME="${PD_DISK_NAME:-<YOUR-REGIONAL-PD-NAME>}"
# Supported PD_DISK_TYPE values: pd-balanced (default), pd-ssd, pd-standard, hyperdisk-balanced-high-availability
export PD_DISK_TYPE="${PD_DISK_TYPE:-pd-balanced}"
export PD_DISK_SIZE="${PD_DISK_SIZE:-200GB}"
# Access mode for Regional PD: ReadWriteOnce (standard for ext4 on pd-balanced/pd-ssd) or ReadWriteMany
export PD_ACCESS_MODE="${PD_ACCESS_MODE:-ReadWriteOnce}"

# --- Kubernetes PersistentVolume (PV) and PersistentVolumeClaim (PVC) Sizes ---
if [ "$STORAGE_TYPE" = "regional-pd" ]; then
  export PV_STORAGE_SIZE="${PV_STORAGE_SIZE:-200Gi}"
  export PVC_STORAGE_SIZE="${PVC_STORAGE_SIZE:-200Gi}"
  export PVC_LIMIT_STORAGE_SIZE="${PVC_LIMIT_STORAGE_SIZE:-200Gi}"
  export PVC_CLAIM_NAME="${PVC_CLAIM_NAME:-pvc-regional-pd}"
else
  export PV_STORAGE_SIZE="${PV_STORAGE_SIZE:-2.5Ti}"
  export PVC_STORAGE_SIZE="${PVC_STORAGE_SIZE:-300Gi}"
  export PVC_LIMIT_STORAGE_SIZE="${PVC_LIMIT_STORAGE_SIZE:-500Gi}"
  export PVC_CLAIM_NAME="${PVC_CLAIM_NAME:-pvc-filestore}"
fi

# variables for config files and companion shell scripts

# you can change this to any instance name for your current instance, later you can change this
# if you plan to install a different instance, rename it to some different squad name, etc.
export MOODLE_ROOT_PATH="/moodleroot-instance1"
export MOODLE_ROOT_PATH_NO_SLASH="${MOODLE_ROOT_PATH/?}"
export MOODLE_ROOT_IN_FILESTORE="$FILESTORE_MOUNT/$MOODLE_ROOT_PATH_NO_SLASH"

validate_moodle_envs() {
  local missing=0
  for var_name in PROJECT_NUMBER PROJECT_ID REGION; do
    local val="${!var_name:-}"
    if [ -z "$val" ] || [[ "$val" == \<*\> ]]; then
      echo "Error: Environment variable $var_name is not configured in 0-infra/envs.sh (current value: '$val')." >&2
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    echo "Please update 0-infra/envs.sh with your GCP project values before running this script." >&2
    return 1
  fi
}
