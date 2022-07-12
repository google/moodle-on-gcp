
#/bin/bash

# environment variables required for the infra-creation script to run
# make changes to your project, region, zone and networking resources
# ip ranges here described are suggestive and can be adjusted to fit production's needs

PROJECT=<YOUR-PROJECT-NAME>
REGION=<YOUR-PREFERED-REGION>
ZONE=$REGION-a

VPC_NAME=<YOUR-VPC-NAME>
SUBNET_NAME=<YOUR-SUBNET-NAME>
SUBNET_RANGE=10.10.0.0/24

# gke specific variables
NODE_SA_EMAIL=<YOUR-SERVICE-ACCOUNT-WITH-IAM>@developer.gserviceaccount.com
GKE_POD_RANGE=10.168.0.0/14
GKE_SVC_RANGE=10.172.0.0/19
GKE_MASTER_IPV4_RANGE=10.10.1.0/28

# if you have VMs in a different subnet, make sure to include it here, separated by comma (,)
MASTER_AUTHORIZED_NETWORKS=10.11.0.6/32

# peering ranges for managed services, such as cloud sql and filestore
MOODLE_MYSQL_MANAGED_PEERING_RANGE=10.9.0.0
MOODLE_FILESTORE_MANAGED_PEERING_RANGE=10.12.0.0

# NAT config
NAT_CONFIG=<YOUR-NAT-CONFIG-NAME>
NAT_ROUTER=<YOUR-NAT-CONFIG-ROUTER>

# db specific variables
GKE_NAME=<YOUR-GKE-CLUSTER-NAME>
MYSQL_INSTANCE_NAME=<YOUR-MYSQL-INSTANCE-NAME>
MYSQL_ROOT_PASSWORD=<YOUR-MYSQL-INSTANCE-PASSWORD>
MYSQL_DB=<YOUR-MOODLE-DB-NAME>
COLLATION=utf8mb4_unicode_ci #recommended collation for Moodle. Change only if necessary.

# other managed services variables
REDIS_NAME=<YOUR-REDIS-CACHE-NAME>
FILESTORE_NAME=<YOUR-FILESTORE-NAME>