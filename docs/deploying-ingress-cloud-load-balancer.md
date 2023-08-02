# Deploying Ingress - Cloud Load Balancer

> This document assumes that the working machine from where you pushing commands from has access to Google Kubernetes Engine (GKE) control plane.

1. Connect to the GKE cluster via the command line and update local cluster credentials.

```
gcloud container clusters get-credentials <GKE-NAME> \
    --region <GKE-REGION> \
    --project <PROJECT ID>
```

2. Replace the entry in the file `gce-ingress-external.yaml` corresponding to your Public IP Address or hostname, such as:

If decided to go with nip.io domain, use the following command:

```
MY_MOODLE_PUBLIC_IP_ADDRESS=$(gcloud compute addresses describe moodle-ingress-ip --global --format='get(address)')

sed -i "s/<YOUR-LB-EXTERNAL-IP>/$MY_MOODLE_PUBLIC_IP_ADDRESS/g" 8-ingress/gce-ingress-external.yaml
```

If you have your own domain, use the following command:

```
MY_HOSTNAME="www.somesite.com"

sed -i "s/moodle.<YOUR-LB-EXTERNAL-IP>.nip.io/$MY_HOSTNAME/g" 8-ingress/gce-ingress-external.yaml
```

3. Provision the ingress over Cloud Load Balancer by executing the command line below.

```
kubectl apply -f 8-ingress/gce-ingress-external.yaml
```

4. Make sure the ingress configuration was successfully applied.

```
kubectl get ingress -n moodle
```

<p align="left">
    <img src="../img/ingress-created.png">
</p>