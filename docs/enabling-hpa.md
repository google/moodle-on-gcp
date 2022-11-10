# Enabling horizontal scale for Pods

> This document assumes that the working machine from where you pushing commands from has access to Google Kubernetes Engine (GKE) control plane.

Horizontal Pod Autoscaling (HPA) is a state that allows pods in Kubernetes to expand their capacity horizontally (adding more pods) when meeting certain thresholds. This document adds HPA capacity to GKE to get Moodle's pods automatically scaling out.

1. Connect to the GKE cluster via the command line and update local cluster credentials.

```
gcloud container clusters get-credentials <GKE-NAME> \
    --region <GKE-REGION> \
    --project <PROJECT ID>
```

1. If you want to keep the suggested configuration for HPA, simply go ahead and run the command below. If you want to customize its parameters, do so before running the command itself. 

```
kubectl apply -f 9-hpa/moodle-hpa.yaml
```

3. Make sure the HPA configuration was successfully applied.

```
kubectl get hpa -n moodle
```