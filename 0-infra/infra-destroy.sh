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

# ==============================================================================
# Selective Deprovisioning Counterpart Script for Moodle on GCP (infra-destroy.sh)
# ==============================================================================
# Safely removes Moodle-specific resources created by 0-infra/infra-creation.sh
# without deleting shared VPCs, Cloud NAT, or unrelated workloads unless
# --destroy-network is explicitly passed.
#
# Usage:
#   ./0-infra/infra-destroy.sh [--yes] [--destroy-network] [--delete-jumpbox]

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ENVS_FILE:-$SCRIPT_DIR/envs.sh}"

validate_moodle_envs

AUTO_APPROVE="false"
DESTROY_NETWORK="false"
DELETE_JUMPBOX="false"

for arg in "$@"; do
  case "$arg" in
    --yes|-y)
      AUTO_APPROVE="true"
      ;;
    --destroy-network)
      DESTROY_NETWORK="true"
      ;;
    --delete-jumpbox)
      DELETE_JUMPBOX="true"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--yes] [--destroy-network] [--delete-jumpbox]" >&2
      exit 1
      ;;
  esac
done

echo "=================================================================="
echo "Selective Moodle Infrastructure Deprovisioning"
echo "  Project ID : $PROJECT_ID"
echo "  Region     : $REGION (Zone: $ZONE)"
echo "  GKE Cluster: $GKE_NAME"
echo "  Cloud SQL  : $MYSQL_INSTANCE_NAME"
echo "  Redis      : $REDIS_NAME / $REDIS_CLUSTER_NAME"
echo "  Storage    : Filestore ($FILESTORE_NAME) / Regional PD ($PD_DISK_NAME)"
echo "  Destroy Net: $DESTROY_NETWORK"
echo "=================================================================="

if [ "$AUTO_APPROVE" != "true" ]; then
  read -rp "Proceed with selective deprovisioning of Moodle resources? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

gcloud config set project "$PROJECT_ID"

is_configured() {
  local val="$1"
  [ -n "$val" ] && [[ "$val" != \<*\> ]]
}

# 1. Delete GKE Cluster (Standard or Autopilot)
if is_configured "$GKE_NAME"; then
  if gcloud container clusters describe "$GKE_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting GKE cluster '$GKE_NAME' in '$REGION'..."
    gcloud container clusters delete "$GKE_NAME" --region="$REGION" --project="$PROJECT_ID" --quiet
  else
    echo "GKE cluster '$GKE_NAME' not found in '$REGION', skipping."
  fi
fi

# 2. Delete Cloud Filestore instance
if is_configured "$FILESTORE_NAME"; then
  if [ "$FILESTORE_TIER" = "REGIONAL" ] || [ "$FILESTORE_TIER" = "ENTERPRISE" ]; then
    FS_LOC="--location=$REGION"
  else
    FS_LOC="--zone=$ZONE"
  fi
  if gcloud filestore instances describe "$FILESTORE_NAME" "$FS_LOC" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting Cloud Filestore instance '$FILESTORE_NAME'..."
    gcloud filestore instances delete "$FILESTORE_NAME" "$FS_LOC" --project="$PROJECT_ID" --quiet
  else
    echo "Cloud Filestore instance '$FILESTORE_NAME' not found, skipping."
  fi
fi

# 3. Delete Regional Replicated Persistent Disk
if is_configured "$PD_DISK_NAME"; then
  if gcloud compute disks describe "$PD_DISK_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting Regional Replicated Persistent Disk '$PD_DISK_NAME' in '$REGION'..."
    gcloud compute disks delete "$PD_DISK_NAME" --region="$REGION" --project="$PROJECT_ID" --quiet
  else
    echo "Regional PD '$PD_DISK_NAME' not found in '$REGION', skipping."
  fi
fi

# 4. Delete Memorystore for Redis Cluster or Standard Redis
if is_configured "$REDIS_CLUSTER_NAME"; then
  if gcloud redis clusters describe "$REDIS_CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting Memorystore for Redis Cluster '$REDIS_CLUSTER_NAME'..."
    gcloud redis clusters delete "$REDIS_CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" --quiet
  fi
fi

if is_configured "$REDIS_NAME"; then
  if gcloud redis instances describe "$REDIS_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting Memorystore for Redis instance '$REDIS_NAME'..."
    gcloud redis instances delete "$REDIS_NAME" --region="$REGION" --project="$PROJECT_ID" --quiet
  else
    echo "Memorystore Redis '$REDIS_NAME' not found in '$REGION', skipping."
  fi
fi

# 5. Delete Cloud SQL for MySQL instance
if is_configured "$MYSQL_INSTANCE_NAME"; then
  if gcloud sql instances describe "$MYSQL_INSTANCE_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting Cloud SQL instance '$MYSQL_INSTANCE_NAME'..."
    gcloud sql instances delete "$MYSQL_INSTANCE_NAME" --project="$PROJECT_ID" --quiet
  else
    echo "Cloud SQL instance '$MYSQL_INSTANCE_NAME' not found, skipping."
  fi
fi

# 6. Delete Artifact Registry repository
if is_configured "${ARTIFACT_REGISTRY_NAME:-}"; then
  if gcloud artifacts repositories describe "$ARTIFACT_REGISTRY_NAME" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting Artifact Registry repository '$ARTIFACT_REGISTRY_NAME' in '$REGION'..."
    gcloud artifacts repositories delete "$ARTIFACT_REGISTRY_NAME" --location="$REGION" --project="$PROJECT_ID" --quiet
  fi
fi

# 7. Optionally delete Jumpbox VM (preserved by default if shared, e.g. ernani-test-vm)
if [ "$DELETE_JUMPBOX" = "true" ] && is_configured "${JUMPBOX_VM_NAME:-}"; then
  if gcloud compute instances describe "$JUMPBOX_VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting Jumpbox VM '$JUMPBOX_VM_NAME' in '$ZONE'..."
    gcloud compute instances delete "$JUMPBOX_VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" --quiet
  fi
fi

# 8. Optionally delete VPC, Subnet, Router, NAT, and Static IP if --destroy-network is set
if [ "$DESTROY_NETWORK" = "true" ]; then
  if gcloud compute addresses describe moodle-ingress-ip --global --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting global static IP 'moodle-ingress-ip'..."
    gcloud compute addresses delete moodle-ingress-ip --global --project="$PROJECT_ID" --quiet
  fi
  if is_configured "$NAT_CONFIG" && is_configured "$NAT_ROUTER"; then
    gcloud compute routers nats delete "$NAT_CONFIG" --router="$NAT_ROUTER" --region="$REGION" --project="$PROJECT_ID" --quiet || true
    gcloud compute routers delete "$NAT_ROUTER" --region="$REGION" --project="$PROJECT_ID" --quiet || true
  fi
  if is_configured "$SUBNET_NAME"; then
    gcloud compute networks subnets delete "$SUBNET_NAME" --region="$REGION" --project="$PROJECT_ID" --quiet || true
  fi
  if is_configured "$VPC_NAME"; then
    gcloud compute networks delete "$VPC_NAME" --project="$PROJECT_ID" --quiet || true
  fi
fi

echo "Selective Moodle infrastructure deprovisioning completed!"
