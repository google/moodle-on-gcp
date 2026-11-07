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

# set to halt on execution errors and pipe failures
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# load env vars file
source "$SCRIPT_DIR/envs.sh"

validate_moodle_envs

# prompt for mysql root password if Cloud SQL creation is enabled and password is not set
if [ "${CREATE_CLOUD_SQL:-true}" = "true" ] && [ -z "${MYSQL_ROOT_PASSWORD:-}" ]; then
  while true; do
    read -rsp "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
    echo
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
      echo "Password cannot be empty. Please try again."
      continue
    fi
    read -rsp "Confirm MySQL root password: " MYSQL_ROOT_PASSWORD_CONFIRM
    echo
    if [ "$MYSQL_ROOT_PASSWORD" = "$MYSQL_ROOT_PASSWORD_CONFIRM" ]; then
      unset MYSQL_ROOT_PASSWORD_CONFIRM
      break
    else
      echo "Passwords do not match. Please try again."
    fi
  done
fi

# sets up the default project where this infra will be deployed into
gcloud config set project "$PROJECT_ID"

# creates global ip address for moodle ingress controller (google cloud load balancer)
gcloud compute addresses create moodle-ingress-ip --global

# enables networking services creation (if not enabled already)
gcloud services enable servicenetworking.googleapis.com \
  --project="$PROJECT_ID"

# creates a new VPC (if not exists yet)
gcloud compute networks create "$VPC_NAME" \
  --subnet-mode=custom \
  --bgp-routing-mode=regional \
  --mtu=1460

# creates a new subnet to support deployment of underlying services
gcloud compute networks subnets create "$SUBNET_NAME" \
  --project="$PROJECT_ID" \
  --range="$SUBNET_RANGE" \
  --stack-type=IPV4_ONLY \
  --network="$VPC_NAME" \
  --region="$REGION"

# create secondary ranges for the subnetwork to add to gke
gcloud compute networks subnets update "$SUBNET_NAME" \
  --region "$REGION" \
  --add-secondary-ranges "pod-range-gke-1=$GKE_POD_RANGE"

gcloud compute networks subnets update "$SUBNET_NAME" \
  --region "$REGION" \
  --add-secondary-ranges "svc-range-gke-1=$GKE_SVC_RANGE"

# enable container api
gcloud services enable container.googleapis.com \
  --project="$PROJECT_ID"

# creates gke in Autopilot (recommended) or Standard mode with Filestore CSI and GCE Persistent Disk CSI drivers enabled
if [ "${GKE_MODE:-autopilot}" = "autopilot" ]; then
  echo "Provisioning GKE Autopilot cluster '$GKE_NAME' in '$REGION'..."
  gcloud container clusters create-auto "$GKE_NAME" \
    --release-channel=stable \
    --region="$REGION" \
    --enable-private-nodes \
    --enable-master-global-access \
    --network="$VPC_NAME" \
    --subnetwork="$SUBNET_NAME" \
    --master-ipv4-cidr="$GKE_MASTER_IPV4_RANGE" \
    --cluster-secondary-range-name=pod-range-gke-1 \
    --services-secondary-range-name=svc-range-gke-1
else
  echo "Provisioning GKE Standard cluster '$GKE_NAME' in '$REGION'..."
  gcloud container clusters create "$GKE_NAME" \
    --release-channel=stable \
    --region="$REGION" \
    --enable-dataplane-v2 \
    --enable-ip-alias \
    --enable-private-nodes \
    --enable-private-endpoint \
    --enable-master-global-access \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=3 \
    --enable-autorepair \
    --monitoring=SYSTEM \
    --num-nodes=1 \
    --scopes=storage-rw,compute-ro \
    --enable-intra-node-visibility \
    --machine-type=n1-standard-2 \
    --network="$VPC_NAME" \
    --subnetwork="$SUBNET_NAME" \
    --addons=HttpLoadBalancing,HorizontalPodAutoscaling,GcpFilestoreCsiDriver,GcePersistentDiskCsiDriver \
    --master-ipv4-cidr="$GKE_MASTER_IPV4_RANGE" \
    --logging=SYSTEM,WORKLOAD \
    --cluster-secondary-range-name=pod-range-gke-1 \
    --services-secondary-range-name=svc-range-gke-1
fi

# grant minimal roles to the cluster service account
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$NODE_SA_EMAIL" \
  --role roles/monitoring.metricWriter

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$NODE_SA_EMAIL" \
  --role roles/monitoring.viewer

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$NODE_SA_EMAIL" \
  --role roles/logging.logWriter

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$NODE_SA_EMAIL" \
  --role roles/storage.objectViewer

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$NODE_SA_EMAIL" \
  --role roles/storage.objectAdmin

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$NODE_SA_EMAIL" \
  --role roles/artifactregistry.reader

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$NODE_SA_EMAIL" \
  --role roles/container.admin

# authorize cluster to be reached by some VM in the VPC (this will be needed later for cluster configuration)
gcloud container clusters update "$GKE_NAME" \
  --enable-master-authorized-networks \
  --master-authorized-networks "$MASTER_AUTHORIZED_NETWORKS" \
  --region="$REGION"

# creates a router and NAT config for enabling cluster's outbound communication
gcloud compute routers create "$NAT_ROUTER" \
    --project="$PROJECT_ID" \
    --network="$VPC_NAME" \
    --asn=64512 \
    --region="$REGION"

gcloud compute routers nats create "$NAT_CONFIG" \
    --router="$NAT_ROUTER" \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges \
    --enable-logging \
    --region="$REGION"

if [ "${CREATE_CLOUD_SQL:-true}" = "true" ]; then
  # defines an ip address range for vpc peering for mysql
  gcloud compute addresses create moodle-managed-range-mysql \
    --global \
    --purpose=VPC_PEERING \
    --addresses="$MOODLE_MYSQL_MANAGED_PEERING_RANGE" \
    --prefix-length=24 \
    --description="Moodle Range for MYSQL" \
    --network="$VPC_NAME"

  # list addresses range created for vpc peering
  gcloud compute addresses list --global --filter="purpose=VPC_PEERING"

  # attach the range to the service networking API
  gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=moodle-managed-range-mysql \
    --network="$VPC_NAME"

  # list vpc peering connections
  gcloud services vpc-peerings list --network="$VPC_NAME"

  # creates cloud sql instance (managed)
  { set +x; } 2>/dev/null
  gcloud sql instances create "$MYSQL_INSTANCE_NAME" \
    --database-version="${MYSQL_DATABASE_VERSION:-MYSQL_8_4}" \
    --cpu 1 \
    --memory 3840MB \
    --zone "$ZONE" \
    --network="$VPC_NAME" \
    --retained-backups-count=7 \
    --enable-bin-log \
    --retained-transaction-log-days=7 \
    --maintenance-release-channel=production \
    --maintenance-window-day=SUN \
    --maintenance-window-hour=08 \
    --availability-type=zonal \
    --storage-type=SSD \
    --storage-auto-increase \
    --storage-size=10GB \
    --backup-start-time=03:00 \
    --database-flags=character_set_server=utf8mb4,default_time_zone=-03:00 \
    --root-password="$MYSQL_ROOT_PASSWORD"

  # list cloud sql instances created
  gcloud sql instances list

  # creates cloud sql database with proper charset for moodle
  gcloud sql databases create "$MYSQL_DB" \
    --instance "$MYSQL_INSTANCE_NAME" \
    --charset "$MYSQL_MOODLE_DB_CHARSET" \
    --collation "$MYSQL_MOODLE_DB_COLLATION"

  # list cloud sql databases created
  gcloud sql databases list --instance "$MYSQL_INSTANCE_NAME"
fi

if [ "${CREATE_REDIS:-true}" = "true" ]; then
  # creates memorystore redis (managed)
  gcloud redis instances create "$REDIS_NAME" \
    --size=1 \
    --network="$VPC_NAME" \
    --enable-auth \
    --maintenance-window-day=sunday \
    --maintenance-window-hour=08 \
    --redis-version=redis_6_x \
    --redis-config maxmemory-policy=allkeys-lru \
    --region="$REGION"

  # list redis instances created
  gcloud redis instances list --region "$REGION"
fi

if [ "${CREATE_REDIS_CLUSTER:-false}" = "true" ]; then
  echo "Provisioning Memorystore for Redis Cluster '$REDIS_CLUSTER_NAME' (shards: ${REDIS_CLUSTER_SHARD_COUNT:-3}, replicas: ${REDIS_CLUSTER_REPLICA_COUNT:-1})..."
  gcloud services enable redis.googleapis.com networkconnectivity.googleapis.com --project="$PROJECT_ID"
  gcloud redis clusters create "$REDIS_CLUSTER_NAME" \
    --region="$REGION" \
    --shard-count="${REDIS_CLUSTER_SHARD_COUNT:-3}" \
    --replica-count="${REDIS_CLUSTER_REPLICA_COUNT:-1}" \
    --node-type="${REDIS_CLUSTER_NODE_TYPE:-REDIS_STANDARD_SMALL}" \
    --network="projects/$PROJECT_ID/global/networks/$VPC_NAME" \
    --transit-encryption-mode=DISABLED \
    --authorization-mode=AUTH_MODE_DISABLED

  gcloud redis clusters list --region "$REGION"
fi

# ==============================================================================
# Selective Storage Provisioning (Filestore OR Regional Replicated PD)
# ==============================================================================
if [ "${CREATE_FILESTORE:-true}" = "true" ]; then
  echo "Provisioning Cloud Filestore instance '$FILESTORE_NAME' (tier: $FILESTORE_TIER, capacity: $FILESTORE_CAPACITY)..."
  gcloud services enable file.googleapis.com --project="$PROJECT_ID"

  # defines an ip address range for vpc peering for filestore
  gcloud compute addresses create moodle-managed-range-filestore \
    --global \
    --purpose=VPC_PEERING \
    --addresses="$MOODLE_FILESTORE_MANAGED_PEERING_RANGE" \
    --prefix-length=24 \
    --description="Moodle Range for Filestore" \
    --network="$VPC_NAME"

  if [ "${CREATE_CLOUD_SQL:-true}" = "true" ]; then
    PEERING_RANGES="moodle-managed-range-mysql,moodle-managed-range-filestore"
    gcloud services vpc-peerings update \
      --service=servicenetworking.googleapis.com \
      --ranges="$PEERING_RANGES" \
      --network="$VPC_NAME"
  else
    gcloud services vpc-peerings connect \
      --service=servicenetworking.googleapis.com \
      --ranges=moodle-managed-range-filestore \
      --network="$VPC_NAME"
  fi

  # Regional/Enterprise tiers use --location=$REGION; Zonal/Basic tiers use --zone=$ZONE
  if [ "$FILESTORE_TIER" = "REGIONAL" ] || [ "$FILESTORE_TIER" = "ENTERPRISE" ]; then
    FILESTORE_LOCATION_FLAG="--location=$REGION"
  else
    FILESTORE_LOCATION_FLAG="--zone=$ZONE"
  fi

  gcloud filestore instances create "$FILESTORE_NAME" \
    --description="NFS to support Moodle data." \
    --tier="$FILESTORE_TIER" \
    --file-share="name=${FILESTORE_SHARE_NAME:-moodleshare},capacity=${FILESTORE_CAPACITY:-2.5TB}" \
    --network="name=$VPC_NAME,reserved-ip-range=moodle-managed-range-filestore,connect-mode=PRIVATE_SERVICE_ACCESS" \
    "$FILESTORE_LOCATION_FLAG"

  gcloud filestore instances list
fi

if [ "${CREATE_REGIONAL_PD:-false}" = "true" ]; then
  echo "Provisioning Regional Replicated Persistent Disk '$PD_DISK_NAME' (type: $PD_DISK_TYPE, size: $PD_DISK_SIZE, zones: $ZONE,$REPLICA_ZONE)..."
  gcloud compute disks create "$PD_DISK_NAME" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --replica-zones="projects/$PROJECT_ID/zones/$ZONE,projects/$PROJECT_ID/zones/$REPLICA_ZONE" \
    --type="$PD_DISK_TYPE" \
    --size="$PD_DISK_SIZE"

  gcloud compute disks list --filter="name=$PD_DISK_NAME"
fi

# enable artifact registry api if not enabled yet
gcloud services enable artifactregistry.googleapis.com

# create artifact registry repo for building Moodle images (you can skip it if you already have a repo for images)
gcloud artifacts repositories create "${ARTIFACT_REGISTRY_NAME:-moodle-filestore}" \
  --location="$REGION" \
  --repository-format=docker

# lists artifact registries available
gcloud artifacts repositories list

# grant access to cloud build to push images to artifact registry
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$CLOUD_BUILD_SA_EMAIL" \
  --role roles/artifactregistry.writer

if [ "${CREATE_JUMPBOX:-true}" = "true" ]; then
  # create the jumpbox vm instance to manipulate the private GKE cluster on the same VPC
  gcloud compute instances create "${JUMPBOX_VM_NAME:-vm-jumpbox-moodle}" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type=e2-micro \
    --network-interface="stack-type=IPV4_ONLY,subnet=$SUBNET_NAME,no-address" \
    --metadata=enable-oslogin=true \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --instance-termination-action=STOP \
    --service-account="$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --create-disk="auto-delete=yes,boot=yes,device-name=${JUMPBOX_VM_NAME:-vm-jumpbox-moodle},image=projects/debian-cloud/global/images/debian-12-bookworm-v20240312,mode=rw,size=10,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced" \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --reservation-affinity=any
fi
