# Enabling Horizontal Pod Autoscaling (HPA)

> This document assumes that the working machine from where you are running commands has access to the Google Kubernetes Engine (GKE) control plane.

Horizontal Pod Autoscaling (HPA) allows pods in Kubernetes to expand their capacity horizontally (adding more pods) when meeting CPU or memory thresholds. This repository provides independent HPA configurations for the primary Moodle web tier (`moodle-hpa`) and the dedicated file upload tier (`moodle-uploads-hpa`).

1. Connect to the GKE cluster via the command line and update local cluster credentials:

```bash
gcloud container clusters get-credentials <GKE-NAME> \
    --region <GKE-REGION> \
    --project <PROJECT-ID>
```

2. Apply the HPA manifests for the primary Moodle deployment and the dedicated upload deployment:

```bash
kubectl apply -f 9-hpa/moodle-hpa.yaml
kubectl apply -f 9-hpa/moodle-uploads-hpa.yaml
```

3. Verify that both HPA configurations were applied:

```bash
kubectl get hpa -n moodle
```
