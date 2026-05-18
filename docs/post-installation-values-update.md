# Update moodle-values.yaml and upgrade with Helm

This session is designed to guide you through some small adjustments that can improve Moodle's stability and performance in Google Cloud. 

> This document assumes that the working machine from where you pushing commands from has access to Google Kubernetes Engine (GKE) control plane.

## For installations based on Helm only

The instructions below apply only for scenarios in which the installation is Helm-based.

### 1. Update `moodleSkipInstall` in moodle-values.yaml (Helm-based only)

From your working machine, edit the file `moodle-values.yaml` under `5-helm` and update the value of the variable `moodleSkipInstall` to `true`, as you can see below.

```
...
moodleSkipInstall: false
...
```

### 2. Update `volumePermissions` in moodle-values.yaml (Helm-based only)

From your working machine, edit the file `moodle-values.yaml` under `5-helm` and update the value of the variable `volumePermissions` to `false`, as listed below.

```
...
volumePermissions:
  enabled: false
...
```

### 3. Upgrade your Moodle's pods (Helm-only)

Upgrade your Moodle's pods by running the file `moodle-helm-upgrade.sh` under `5-helm` through the command line, as described below.

```
./moodle-helm-upgrade.sh
```
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
### 2. Comment on the following segment in `moodle-deployment.yaml`

From your working machine, edit the file `moodle-deployment.yaml` under the directory `5a-deployment-no-helm-this-is-optional` and comment out the following code segment.

```
...
#initContainers:
#- command:
#  - sh
#  - -c
#  - |
#    mkdir -p "/bitnami/moodle" "/bitnami/moodledata"
#    chown -R "1001:1001" "/bitnami/moodle" "/bitnami/moodledata"
...
```
### 3. Apply the update

From your working machine make sure to apply the updates just made by running the following command.

```
kubectl apply -f 5a-deployment-no-helm-this-is-optional/moodle-deployment.yaml
```