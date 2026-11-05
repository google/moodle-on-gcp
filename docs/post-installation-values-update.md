# Updating Environment Variables and Upgrading Pods

This guide walks through updating Moodle configuration values (ConfigMap or Secrets) and applying the changes to your running Google Kubernetes Engine (GKE) deployment.

> This document assumes that the working machine from where you are running commands has access to the GKE control plane.

## 1. Updating ConfigMap Values (`5a-deployment-no-helm`)

1. Edit `5a-deployment-no-helm/moodle-configmap-nginx.yaml` (or `moodle-configmap-nginx-uploads.yaml` if adjusting upload pod settings) with your updated environment variables:

```bash
kubectl apply -f 5a-deployment-no-helm/moodle-configmap-nginx.yaml
```

2. Note that Moodle's `config.php` is generated on first install and stored on the persistent volume (`$MOODLE_PATH/config.php`). If you are changing runtime PHP or NGINX limits (`PHP_MEMORY_LIMIT`, `PHP_UPLOAD_MAX_FILESIZE`, `PHP_POST_MAX_SIZE`, `NGINX_CLIENT_MAX_BODY_SIZE`), those are re-applied automatically from the ConfigMap every time a pod starts.

3. If you are changing database, Redis, or `wwwroot` parameters after initial installation, also update `$MOODLE_PATH/config.php` on the shared volume (or remove `$MOODLE_DATAROOT_PATH/.moodle-installed` only if you intend to re-run config initialization).

## 2. Restarting Pods to Pick Up Updated Configuration

After applying ConfigMap or Secret changes, trigger a rolling restart of the Moodle deployment:

```bash
kubectl rollout restart deployment/moodle -n moodle
kubectl rollout status deployment/moodle -n moodle
```
