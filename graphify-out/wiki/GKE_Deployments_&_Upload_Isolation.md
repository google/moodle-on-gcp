# GKE Deployments & Upload Isolation

> 44 nodes

## Key Concepts

- **envs.sh** (48 connections) — `0-infra/envs.sh`
- **CLOUD_BUILD_SA_EMAIL** (1 connections) — `0-infra/envs.sh`
- **CREATE_CLOUD_SQL** (1 connections) — `0-infra/envs.sh`
- **CREATE_JUMPBOX** (1 connections) — `0-infra/envs.sh`
- **CREATE_REDIS** (1 connections) — `0-infra/envs.sh`
- **FILESTORE_CAPACITY** (1 connections) — `0-infra/envs.sh`
- **FILESTORE_IP_ADDRESS** (1 connections) — `0-infra/envs.sh`
- **FILESTORE_MOUNT** (1 connections) — `0-infra/envs.sh`
- **FILESTORE_NAME** (1 connections) — `0-infra/envs.sh`
- **FILESTORE_SHARE_NAME** (1 connections) — `0-infra/envs.sh`
- **FILESTORE_TIER** (1 connections) — `0-infra/envs.sh`
- **GKE_MASTER_IPV4_RANGE** (1 connections) — `0-infra/envs.sh`
- **GKE_NAME** (1 connections) — `0-infra/envs.sh`
- **GKE_POD_RANGE** (1 connections) — `0-infra/envs.sh`
- **GKE_SVC_RANGE** (1 connections) — `0-infra/envs.sh`
- **MASTER_AUTHORIZED_NETWORKS** (1 connections) — `0-infra/envs.sh`
- **MOODLE_FILESTORE_MANAGED_PEERING_RANGE** (1 connections) — `0-infra/envs.sh`
- **MOODLE_MYSQL_MANAGED_PEERING_RANGE** (1 connections) — `0-infra/envs.sh`
- **MOODLE_ROOT_IN_FILESTORE** (1 connections) — `0-infra/envs.sh`
- **MOODLE_ROOT_PATH** (1 connections) — `0-infra/envs.sh`
- **MOODLE_ROOT_PATH_NO_SLASH** (1 connections) — `0-infra/envs.sh`
- **MYSQL_DATABASE_VERSION** (1 connections) — `0-infra/envs.sh`
- **MYSQL_DB** (1 connections) — `0-infra/envs.sh`
- **MYSQL_INSTANCE_NAME** (1 connections) — `0-infra/envs.sh`
- **MYSQL_MOODLE_DB_CHARSET** (1 connections) — `0-infra/envs.sh`
- *... and 19 more nodes in this community*

## Relationships

- [Redis Caching & Session Locking](Redis_Caching_&_Session_Locking.md) (4 shared connections)
- [SSL Certificates & Security Hardening](SSL_Certificates_&_Security_Hardening.md) (1 shared connections)

## Source Files

- `0-infra/envs.sh`

## Audit Trail

- EXTRACTED: 44 (92%)
- INFERRED: 4 (8%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [index](index.md) to navigate.*