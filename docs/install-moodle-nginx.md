# Deploying Moodle in GKE with the NGINX + PHP 8.3 Image

1. Generate the Kubernetes manifests from `0-infra/envs.sh` (which also prompts optionally for your SMTP password and renders storage and upload manifests):

```bash
./5a-deployment-no-helm/create-config-files.sh
```

2. Populate your Cloud SQL, Redis, and Load Balancer IP addresses in `5a-deployment-no-helm/moodle-configmap-nginx.yaml` and `5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml`, and populate your MySQL and Moodle admin passwords in `5a-deployment-no-helm/moodle-secret.yaml`.

3. Apply the Secret, ConfigMaps, Deployments, and Services:

```bash
kubectl apply -f 5a-deployment-no-helm/moodle-secret.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-configmap-nginx.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-deployment-nginx.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-service.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-service-uploads.yaml
```

For migration guidance from legacy deployments, see [Migration Recommendations](migration-recommendations.md).
