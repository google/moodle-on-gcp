# Redis Caching & Session Locking

> 7 nodes

## Key Concepts

- **validate_moodle_envs()** (4 connections) — `0-infra/envs.sh`
- **cleanup-moodle-install.sh** (2 connections) — `0-infra/cleanup-moodle-install.sh`
- **cleanup-moodle-install.sh script** (2 connections) — `0-infra/cleanup-moodle-install.sh`
- **infra-creation.sh** (2 connections) — `0-infra/infra-creation.sh`
- **infra-creation.sh script** (2 connections) — `0-infra/infra-creation.sh`
- **build-nginx-based-image.sh** (2 connections) — `4-moodle-image-builder/build-nginx-based-image.sh`
- **build-nginx-based-image.sh script** (2 connections) — `4-moodle-image-builder/build-nginx-based-image.sh`

## Relationships

- [GKE Deployments & Upload Isolation](GKE_Deployments_&_Upload_Isolation.md) (4 shared connections)

## Source Files

- `0-infra/cleanup-moodle-install.sh`
- `0-infra/envs.sh`
- `0-infra/infra-creation.sh`
- `4-moodle-image-builder/build-nginx-based-image.sh`

## Audit Trail

- EXTRACTED: 7 (70%)
- INFERRED: 3 (30%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [index](index.md) to navigate.*