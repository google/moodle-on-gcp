# File "envs.sh"

"envs.sh" is a support file that holds environment variables for "infra-creation. sh". Rather than keeping variables and `gcloud` commands altogether, we've separated one from another to make it easier to maintain.

> Please notice that you **_must_** properly fill in variable's values before running "infra-creation.sh".

The following table outlines all the variables that need to be filled in.

| Variable | Descriptiom |
| ---------- | ---------- |
| PROJECT_NUMBER | Refers to Google Cloud's Project Number in which Moodle's assets will be deployed into. It is a big number associated with Project ID. You can grab that information by browsing into Project's Dashboard in web console. |
| PROJECT_ID | Refers to Google Cloud's Project ID in which Moodle's assets will be deployed into. It is a string associated with a Project Number. You can grab that information by browsing into Project's Dashboard in web console. |
| REGION | Prefered region in Google Cloud to receive Moodle's assets once deployed. |
| ZONE | In case of a multi-zonal type resource being deployed, this variable holds the specific zone to which the asset will be deployed into. |
| VPC_NAME | Refers to the VPC being created in GCP to support Moodle's connectivity.  |
| SUBNET_NAME | Defines the name of the subnet which Moodle's resources will be connected to once deployed. |
| SUBNET_RANGE | Subnet range for the VPC being deployed. Suggestively, we put 10.10.0.0/24 as a viable range for it. But depending on the approach taken with the network, it must be changed. |
| NODE_SA_EMAIL | Refers to the account name generated when Kubernetes Engine API was activated. It looks like this: `1212121212-compute@developer.gserviceaccount.com`. By fullfiling $PROJECT_NUMBER variable, it should automatically bound to this one. |
| GKE_POD_RANGE | Refers to GKE's IP range for Pods. Suggestively, 10.168.0.0/14 comes filling in. |
| GKE_SVC_RANGE | Refers to GKE's IP range for Services. Suggestively, 10.172.0.0/19 comes filling in. |
| GKE_MASTER_IPV4_RANGE | Refers to GKE's range for Masters. Suggestively, 10.10.1.0/28 comes filling in. |
| CLOUD_BUILD_SA_EMAIL | Refers to Cloud Build's account name. It looks like this: `1212121212@cloudbuild.gserviceaccount.com`. By fullfiling $PROJECT_NUMBER variable, it should automatically bound to this one. |
| MASTER_AUTHORIZED_NETWORKS | Refers to resources sitting outside Moodle's VPC that needs to communicate back with GKE cluster. |
| MOODLE_MYSQL_MANAGED_PEERING_RANGE | Refers to Cloud SQL managed service IP range that need to be peered with Moodle's VPC. Default IP must be replaced if a different approach for network is taken. |
| MOODLE_FILESTORE_MANAGED_PEERING_RANGE | Refers to Filestore managed service IP range that need to be peered with Moodle's VPC. Default IP must be replaced if a different approach for network is taken. |
| NAT_CONFIG | Names Nat Config service. |
| NAT_ROUTER | Names Nat Router service.  |
| GKE_NAME | Names Google Kubernetes Engine (GKE) cluster that will host Moodle's web application. |
| MYSQL_INSTANCE_NAME | Names MySQL instance out of Cloud SQL. |
| MYSQL_ROOT_PASSWORD | Plain text that settles database's password. |
| MYSQL_DB | Names Moodle's MySQL database. |
| MYSQL_MOODLE_DB_CHARSET | Recommended charset for Moodle. Change only if necessary and you're absolutely sure of it. |
| MYSQL_MOODLE_DB_COLLATION | Recommended collation for Moodle. Change only if necessary and you're absolutely sure of it. |
| REDIS_NAME | Names Redis instance serving Moodle. |
| FILESTORE_NAME | Names Filestore instance serving Moodle. |