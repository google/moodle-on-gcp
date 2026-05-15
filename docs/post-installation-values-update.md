# Update moodle-deployment.yaml and upgrade with NGINX

This session is designed to guide you through some small adjustments that can improve Moodle's stability and performance in Google Cloud. 

> This document assumes that the working machine from where you pushing commands from has access to Google Kubernetes Engine (GKE) control plane.

## For installations not based on Helm (5a-deployment-no-helm)

The instructions below apply only for scenarios in which the installation is NOT Helm-based and should be disconsidered if otherwise.

### 1. Update `MOODLE_SKIP_BOOTSTRAP` in moodle-deployment.yaml (5a-deployment model only)

From your working machine, edit the file `moodle-deployment.yaml` under `5a-deployment-no-helm-this-is-optional` and update the value of variable `MOODLE_SKIP_BOOTSTRAP` to `yes`, as you can see below.

```
...
- name: MOODLE_SKIP_BOOTSTRAP
  value: "yes" 
...
```
### 2. Apply the update

From your working machine make sure to apply the updates just made by running the following command.

```
kubectl apply -f 5a-deployment-no-helm-this-is-optional/moodle-deployment.yaml
```
### 3. Extra Redis Settings (If applicable)

Since some Redis parameters were removed from the initial setup script, ensure you apply extra Redis configurations (like session handling, file locks, or application cache stores) as described in the external Redis documentation if you are continuing from an older installation or specifically requiring them.
