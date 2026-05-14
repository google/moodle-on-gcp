## 2026-05-14 - Deprecating Bitnami and Hardening Images
**Vulnerability:** Hardcoded database secrets in infrastructure scripts and outdated Alpine/PHP base image susceptible to known CVEs.
**Learning:** Infrastructure setup scripts like `0-infra/infra-creation.sh` were sourcing passwords from `envs.sh` in clear text and executing `set -x`, leading to severe risk of secret leakage in CI/CD pipeline traces. Additionally, Bitnami base images were deprecated, creating an obsolete footprint.
**Prevention:** Added an interactive `read -sp` prompt in the bash script to dynamically request the password, removed `set -x` leakage entirely, and upgraded the entire deployment suite to use the more secure NGINX + Alpine 3.20 + PHP 8.3 base images. Re-enforced `set -eo pipefail` across the whole repository.

## 2026-05-14 - Fixing deployment clobbering and envs.sh placeholder
**Vulnerability:** Ficticious values in envs.sh and deployment configuration collisions over NFS.
**Learning:** When using envsubst to process templates that reside on a shared NFS volume, do not delete the template files inside the running pod, as it corrupts configuration for concurrent or subsequent pods. Placeholders in `envs.sh` must remain generic to force manual developer input.
**Prevention:** Removed `rm -rvf` in `setup_moodle.sh` against `.template` files and separated the `subPath` mount points (`/etc` vs `/etc-uploads`) for the NGINX and PHP configs so that the main deployment and the upload deployment don't clobber each other's files. Reverted fictitious DB and VPC values back to `<YOUR-...>`.
