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

#/bin/bash

# environment variables required for the infra-creation script to run
# make changes to your project, region, zone and networking resources
# ip ranges here described are suggestive and can be adjusted to fit production's needs

PROJECT_NUMBER=123
PROJECT_ID=456
REGION=us-central1
ZONE=$REGION-a

VPC_NAME=vpc1
SUBNET_NAME=subnet1
SUBNET_RANGE=10.10.0.0/24

# gke specific variables
NODE_SA_EMAIL=$PROJECT_NUMBER-compute@developer.gserviceaccount.com
GKE_POD_RANGE=10.168.0.0/14
GKE_SVC_RANGE=10.172.0.0/19
GKE_MASTER_IPV4_RANGE=10.10.1.0/28

# cloud build specific variables
CLOUD_BUILD_SA_EMAIL=$PROJECT_NUMBER@cloudbuild.gserviceaccount.com

# if you have VMs in a different subnet, make sure to include it here, separated by comma (,)
MASTER_AUTHORIZED_NETWORKS=10.11.0.6/32

# peering ranges for managed services, such as cloud sql and filestore
MOODLE_MYSQL_MANAGED_PEERING_RANGE=10.9.0.0
MOODLE_FILESTORE_MANAGED_PEERING_RANGE=10.12.0.0

# NAT config
NAT_CONFIG=nat1
NAT_ROUTER=router1

# db specific variables
GKE_NAME=gke1
MYSQL_INSTANCE_NAME=db1
# MYSQL_ROOT_PASSWORD is not set here to avoid hardcoding secrets.
# It will be prompted for during infra-creation.sh if not already set.
MYSQL_DB=db1
MYSQL_MOODLE_DB_CHARSET=utf8mb4 #recommended charset for Moodle. Change only if necessary.
MYSQL_MOODLE_DB_COLLATION=utf8mb4_unicode_ci #recommended collation for Moodle. Change only if necessary.

# other managed services variables
REDIS_NAME=redis1
FILESTORE_NAME=fs1
FILESTORE_MOUNT=/mnt/filestore1

# variables for config files and companion shell scripts

# you can change this to any instance name for your current instance, later you can change this
# if you plan to install a different instance, rename it to some different squad name, etc.
export MOODLE_ROOT_PATH=/moodleroot-instance1 
export MOODLE_ROOT_PATH_NO_SLASH=${MOODLE_ROOT_PATH/?}
MOODLE_ROOT_IN_FILESTORE=$FILESTORE_MOUNT/$MOODLE_ROOT_PATH_NO_SLASH
