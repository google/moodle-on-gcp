# Deploying Persistent Volume Claim (PVC)

> This document assumes that the working machine from where you pushing commands from has access to Google Kubernetes Engine (GKE) control plane.

1. Connect to GKE cluster via command line and update local cluster credentials.

```
gcloud container clusters get-credentials <GKE-NAME> \
    --region <GKE-REGION> \
    --project <PROJECT ID>
```

2. Create the new PVC by running the command below. It assumes you're running it from a directory a level above.

```
kubectl apply -f 3-pvc/pvc-filestore.yaml
```

3. Make sure the PVC was successfully created and is properly bounded.

```
kubectl get pvc -n moodle
```

<p align="left">
    <img src="../img/pvc-created.png">
</p>