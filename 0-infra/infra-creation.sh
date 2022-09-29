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

#!/bin/bash

# set to halt on execution errors and output the commands
set -ex

# load  env vars
source ./envs.sh

# sets up the default project where this infra will be deployed into
gcloud config set project $PROJECT_ID

# creates global ip address for moodle ingress controller (google cloud load balancer)
gcloud compute addresses create moodle-ingress-ip --global

# enables networking services creation (if not enabled already)
gcloud services enable servicenetworking.googleapis.com \
  --project=$PROJECT_ID

# creates a new VPC (if not exists yet)
gcloud compute networks create $VPC_NAME \
  --subnet-mode=custom \
  --bgp-routing-mode=regional \
  --mtu=1460

# creates a new subnet to support deployment of underlying services
gcloud compute networks subnets create $SUBNET_NAME \
  --project=$PROJECT_ID \
  --range=$SUBNET_RANGE \
  --stack-type=IPV4_ONLY \
  --network=$VPC_NAME \
  --region=$REGION

# create secondary ranges for the subnetwork to add to gke
gcloud compute networks subnets update $SUBNET_NAME \
  --region $REGION \
  --add-secondary-ranges pod-range-gke-1=$GKE_POD_RANGE;

gcloud compute networks subnets update $SUBNET_NAME \
  --region $REGION \
  --add-secondary-ranges svc-range-gke-1=$GKE_SVC_RANGE;

# enable container api
gcloud services enable container.googleapis.com \
  --project=$PROJECT_ID

# creates gke with necessary addons
gcloud container clusters create $GKE_NAME \
  --release-channel=stable \
  --region=$REGION \
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
  --enable-autorepair \
  --enable-intra-node-visibility \
  --machine-type=n1-standard-2 \
  --network=$VPC_NAME \
  --subnetwork=$SUBNET_NAME \
  --addons=HttpLoadBalancing,HorizontalPodAutoscaling,GcpFilestoreCsiDriver \
  --master-ipv4-cidr=$GKE_MASTER_IPV4_RANGE \
  --logging=SYSTEM,WORKLOAD \
  --cluster-secondary-range-name=pod-range-gke-1 \
  --services-secondary-range-name=svc-range-gke-1

# grant minimal roles to the cluster service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/monitoring.metricWriter

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/monitoring.viewer

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/logging.logWriter

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/storage.objectViewer

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/storage.objectAdmin

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/artifactregistry.reader

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/container.admin

# authorize cluster to be reached by some VM in the VPC (this will be needed later for cluster configuration)
gcloud container clusters update $GKE_NAME \
  --enable-master-authorized-networks \
  --master-authorized-networks $MASTER_AUTHORIZED_NETWORKS \
  --region=$REGION

# creates a router and NAT config for enabling cluster's outbound communication
gcloud compute routers create $NAT_ROUTER \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --asn=64512 \
    --region=$REGION

gcloud compute routers nats create $NAT_CONFIG \
    --router=$NAT_ROUTER \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges \
    --enable-logging \
    --region=$REGION

# defines an ip address range for vpc peering for filestore
gcloud compute addresses create moodle-managed-range \
  --global \
  --purpose=VPC_PEERING \
  --addresses=$MOODLE_MYSQL_MANAGED_PEERING_RANGE \
  --prefix-length=24 \
  --description="Moodle Managed Services" \
  --network=$VPC_NAME

# list addresses range created for vpc peering
gcloud compute addresses list --global --filter="purpose=VPC_PEERING"

# attach the range to the service networking API
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=moodle-managed-range \
  --network=$VPC_NAME

# list vpc peering connections
gcloud services vpc-peerings list --network=$VPC_NAME

# creates cloud sql instance (managed)
gcloud sql instances create $MYSQL_INSTANCE_NAME \
  --database-version=MYSQL_8_0 \
  --cpu 1 \
  --memory 3840MB \
  --zone $ZONE \
  --network=$VPC_NAME \
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
  --retained-backups-count=7 \
  --backup-start-time=03:00 \
  --database-flags=character_set_server=utf8,default_time_zone=-03:00 \
  --root-password=$MYSQL_ROOT_PASSWORD

# list cloud sql instances created
gcloud sql instances list

# creates cloud sql database with proper charset for moodle
gcloud sql databases create $MYSQL_DB \
  --instance $MYSQL_INSTANCE_NAME \
  --charset $MYSQL_MOODLE_DB_CHARSET \
  --collation $MYSQL_MOODLE_DB_COLLATION

# list cloud sql databases created
gcloud sql databases list --instance $MYSQL_INSTANCE_NAME

# creates memorystore redis (managed)
gcloud redis instances create $REDIS_NAME \
  --size=1 \
  --network=$VPC_NAME \
  --enable-auth \
  --maintenance-window-day=sunday \
  --maintenance-window-hour=08 \
  --redis-version=redis_6_x \
  --redis-config maxmemory-policy=allkeys-lru \
  --region=$REGION

# list redis instances created
gcloud redis instances list --region $REGION

# defines an ip address range for vpc peering for filestore
gcloud compute addresses create moodle-managed-range-filestore \
  --global \
  --purpose=VPC_PEERING \
  --addresses=$MOODLE_FILESTORE_MANAGED_PEERING_RANGE \
  --prefix-length=24 \
  --description="Moodle Managed Services" \
  --network=$VPC_NAME

# updates the peering connection adding both sql and filestore ranges
gcloud services vpc-peerings update \
  --service=servicenetworking.googleapis.com \
  --ranges=moodle-managed-range,moodle-managed-range-filestore \
  --network=$VPC_NAME

# creates a filestore service for NFS support
gcloud filestore instances create $FILESTORE_NAME \
  --description="NFS to support Moodle data." \
  --tier=BASIC_SSD \
  --file-share="name=moodleshare,capacity=2.5TB" \
  --network="name=$VPC_NAME,reserved-ip-range=moodle-managed-range-filestore,connect-mode=PRIVATE_SERVICE_ACCESS" \
  --zone=$ZONE

# lists filestores available
gcloud filestore instances list

# enable artifact registry api if not enabled yet
gcloud services enable artifactregistry.googleapis.com

# create artifact registry repo for building Moodle images (you can skip it if you already have a repo for images)
gcloud artifacts repositories create moodle-filestore \
  --location=$REGION \
  --repository-format=docker

# lists artifact registries available
gcloud artifacts repositories list

# grant access to cloud build to push images to artifact registry
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$CLOUD_BUILD_SA_EMAIL \
  --role roles/artifactregistry.writer

# builds Moodle's image with image builder in GCP
cd ../4-moodle-image-builder && \
  gcloud builds submit --region $REGION