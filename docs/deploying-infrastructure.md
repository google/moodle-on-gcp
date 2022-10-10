# Deploying infrastructure

Deploying Modern Moodle on Google Cloud is a straightforward process, comprised of a sequence of steps to be performed in order. This document outlines every step of the way.

Modern Moodle's infrastructure is deployed through Google Cloud's command line utility, `gcloud`. We highlighted the process of getting it set up in a working machine in the [pre-requisites](pre-requisites.md) document.

Also, before getting started, make sure the file "envs.sh" is properly filled up as it will be referenced in the process of creating the infrastructure. If you're not sure about the role of this file, [this document](file-env-sh.md) can help.

To create Moodle's underlying infrastructure, you need to run, from a terminal (shell), the command chain available in the file [infra-creation.sh](../0-infra/infra-creation.sh).

The file's commands will perform the following:

1. Set up a default project ID (where resources will be deployed into).

```
gcloud config set project $PROJECT_ID
```

2. Creation of global IP address to be later attached to Cloud Load Balancer.

```
gcloud compute addresses create moodle-ingress-ip --global
```

3. Enables networking services creation (if not enabled already)

```
gcloud services enable servicenetworking.googleapis.com \
  &nbsp;--project=$PROJECT_ID
```

4. Creates a new Virtual Private Network (VPC) and a subnet to host Moodle's resources.

```
gcloud compute networks create $VPC_NAME \
  --subnet-mode=custom \
  --bgp-routing-mode=regional \
  --mtu=1460
```

```
gcloud compute networks subnets create $SUBNET_NAME \
  --project=$PROJECT_ID \
  --range=$SUBNET_RANGE \
  --stack-type=IPV4_ONLY \
  --network=$VPC_NAME \
  --region=$REGION
  ```

5. Create secondary ranges for the subnetwork to add to Google Kubernetes Engine (GKE).

```
gcloud compute networks subnets update $SUBNET_NAME \
  --region $REGION \
  --add-secondary-ranges pod-range-gke-1=$GKE_POD_RANGE;
```
```
gcloud compute networks subnets update $SUBNET_NAME \
  --region $REGION \
  --add-secondary-ranges svc-range-gke-1=$GKE_SVC_RANGE;
```
6. Enables container API

```
gcloud services enable container.googleapis.com \
  --project=$PROJECT_ID
```
7. Creates GKE with necessary add-ons.

```
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
```
8. Grants minimal roles to the cluster service account

```
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/monitoring.metricWriter
```
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/monitoring.viewer
```
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/logging.logWriter
```
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/storage.objectViewer
```
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/storage.objectAdmin
```
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/artifactregistry.reader
```
```
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$NODE_SA_EMAIL \
  --role roles/container.admin
```
9. Authorizes the cluster to be reached by some VM in the VPC (this will be needed later for cluster configuration).

```
gcloud container clusters update $GKE_NAME \
  --enable-master-authorized-networks \
  --master-authorized-networks $MASTER_AUTHORIZED_NETWORKS \
  --region=$REGION
```
10. Creates a router and NAT config for enabling cluster's outbound communication.

```
gcloud compute routers create $NAT_ROUTER \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --asn=64512 \
    --region=$REGION
```
```
gcloud compute routers nats create $NAT_CONFIG \
    --router=$NAT_ROUTER \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges \
    --enable-logging \
    --region=$REGION
```

11. Defines an IP address range for Filestore's VPC peering.

```
gcloud compute addresses create moodle-managed-range \
  --global \
  --purpose=VPC_PEERING \
  --addresses=$MOODLE_MYSQL_MANAGED_PEERING_RANGE \
  --prefix-length=24 \
  --description="Moodle Managed Services" \
  --network=$VPC_NAME
```

12. Attaches the range to the service networking API.

```
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=moodle-managed-range \
  --network=$VPC_NAME
```

13. Creates a Cloud SQL instance (managed).

```
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
```

14. Creates Moodle's database with proper charset.

```
gcloud sql databases create $MYSQL_DB \
  --instance $MYSQL_INSTANCE_NAME \
  --charset $MYSQL_MOODLE_DB_CHARSET \
  --collation $MYSQL_MOODLE_DB_COLLATION
```

15. Creates Memorystore for Redis.

```
gcloud redis instances create $REDIS_NAME \
  --size=1 \
  --network=$VPC_NAME \
  --enable-auth \
  --maintenance-window-day=sunday \
  --maintenance-window-hour=08 \
  --redis-version=redis_6_x \
  --redis-config maxmemory-policy=allkeys-lru \
  --region=$REGION
```

16. Defines an IP address range for VPC peering for filestore.

```
gcloud compute addresses create moodle-managed-range-filestore \
  --global \
  --purpose=VPC_PEERING \
  --addresses=$MOODLE_FILESTORE_MANAGED_PEERING_RANGE \
  --prefix-length=24 \
  --description="Moodle Managed Services" \
  --network=$VPC_NAME
```

17. Updates the peering connection adding both SQL and Filestore ranges.

```
gcloud services vpc-peerings update \
  --service=servicenetworking.googleapis.com \
  --ranges=moodle-managed-range,moodle-managed-range-filestore \
  --network=$VPC_NAME
```

18. Creates a Filestore service for NFS support.

```
gcloud filestore instances create $FILESTORE_NAME \
  --description="NFS to support Moodle data." \
  --tier=BASIC_SSD \
  --file-share="name=moodleshare,capacity=2.5TB" \
  --network="name=$VPC_NAME,reserved-ip-range=moodle-managed-range-filestore,connect-mode=PRIVATE_SERVICE_ACCESS" \
  --zone=$ZONE
```

19. If not enabled yet, turns on Artifact Registry API.

```
gcloud services enable artifactregistry.googleapis.com
```

20. Creates an Artifact Registry repo for building Moodle images (you can skip it if you already have a repo for images).

```
gcloud artifacts repositories create moodle-filestore \
  --location=$REGION \
  --repository-format=docker
```

21. Grants access to Cloud Build to push images to Artifact Registry.

```
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$CLOUD_BUILD_SA_EMAIL \
  --role roles/artifactregistry.writer
```

22. Builds Moodle's image with Image Builder on GCP (make sure to properly fill up the file "4-moodle-image-builder" > `cloudbuild.yaml`).

```
cd ../4-moodle-image-builder && \
  gcloud builds submit --region $REGION
```