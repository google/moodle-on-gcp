## 2026-05-18 - Restoring Uploads Deployment after rebase conflict
**Vulnerability:** A rebase caused the loss of the custom NGINX uploads deployment YAML files.
**Learning:** Rebase operations can silently overwrite critical files if conflicts are resolved hastily or via aggressive cherry-picking.
**Prevention:** Regenerated the `moodle-deployment-nginx-uploads-template.yaml` and the `moodle-configmap-nginx-uploads-template.yaml` ensuring the PV mounts are properly isolated (`etc-uploads/nginx`) so the concurrent `sed` replacements on the shared NFS don't clobber each other. Restored the dynamic `sed` logic inside `setup_moodle.sh`.
