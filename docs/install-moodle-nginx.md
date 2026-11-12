# Deploying Moodle in GKE with the NGINX + PHP 8.3 Image

1. Generate the Kubernetes manifests from `0-infra/envs.sh` (which also prompts optionally for your SMTP password and renders storage and upload manifests):

```bash
./5a-deployment-no-helm/create-config-files.sh
```

2. Populate your Cloud SQL, Redis, and Load Balancer IP addresses in `5a-deployment-no-helm/moodle-configmap-nginx.yaml` and `5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml`, and populate your MySQL and Moodle admin passwords in `5a-deployment-no-helm/moodle-secret.yaml`.

11. Apply the Secrets, ConfigMaps, Deployments, and Services:

```bash
kubectl apply -f 5a-deployment-no-helm/moodle-externaldb-secret.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-password-secret.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-optional-secrets.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-configmap-nginx.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-deployment-nginx.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-deployment-nginx-uploads.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-service.yaml
kubectl apply -f 5a-deployment-no-helm/moodle-service-uploads.yaml
```

## High-Concurrency Scaling (100k–300k+ Concurrent Users)

1. **Pod Rightsizing & GKE Autopilot `Guaranteed` QoS (`requests == limits`)**:
   - Both `moodle-deployment` and `moodle-deployment-uploads` set `requests == limits` (`cpu: 1000m`, `memory: 2Gi`). On GKE Autopilot, matching `requests` and `limits` guarantees `Guaranteed` QoS (preventing memory eviction under node pressure and ensuring HorizontalPodAutoscaler `averageUtilization: 75` scales accurately against the pod's true 1 vCPU capacity without CFS CPU throttling across the 8 PHP-FPM workers).
2. **Redis Binary Serialization & `zstd` Compression**:
   - `4-moodle-image-builder/config.php.template` enables `php83-pecl-igbinary` (`$CFG->session_redis_serializer_use_igbinary = true`) and `php83-pecl-zstd` (`$CFG->session_redis_compressor = 'zstd'`), reducing Redis session/MUC payload sizes by ~55% and cutting serialization CPU overhead by 4x.
3. **Optional ProxySQL Connection Multiplexing (`5a-deployment-no-helm/moodle-proxysql.yaml`)**:
   - For extreme load tests or large-scale production deployments where hundreds of PHP-FPM workers could exhaust Cloud SQL's `max_connections`, deploy the optional ProxySQL tier:
     ```bash
     kubectl apply -f 5a-deployment-no-helm/moodle-proxysql.yaml
     ```
   - Point Moodle pods to `moodle-proxysql` on port `6033` (and optionally set `DB_PERSIST: "true"` so PHP-FPM keeps persistent connections to the local ProxySQL service while ProxySQL multiplexes queries over a bounded pool of `200` backend Cloud SQL connections).

For migration guidance from legacy deployments, see [Migration Recommendations](migration-recommendations.md).
