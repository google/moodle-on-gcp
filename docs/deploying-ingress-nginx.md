# Deploying Ingress - NGINX

> This document assumes that the working machine from where you pushing commands from has access to Google Kubernetes Engine (GKE) control plane.

> Before proceding, it is important to highlight that, if you already have an igress deployed, this one won't work. It is an additional approach that can be taken over Cloud Load Balancer.

1. Replace the contents inside of the file `nginx-ingress-external-this-is-optional.yaml` under `8-ingress` directory and then, update the host variables below (only the portion `<YOUR-LB-EXTERNAL-IP>` with your LB's public IP).

If decided to go with nip.io domain, use the following command:

```
MY_MOODLE_PUBLIC_IP_ADDRESS=$(gcloud compute addresses describe moodle-ingress-ip --global --format='get(address)')

sed -i "s/<YOUR-LB-EXTERNAL-IP>/$MY_MOODLE_PUBLIC_IP_ADDRESS/g" 8-ingress/nginx-ingress-external-this-is-optional.yaml
```

If you have your own domain, use the following command:

```
MY_HOSTNAME="www.somesite.com"

sed -i "s/moodle.<YOUR-LB-EXTERNAL-IP>.nip.io/$MY_HOSTNAME/g" 8-ingress/nginx-ingress-external-this-is-optional.yaml
```

2. Connect to the GKE cluster via the command line and update local cluster credentials.

```
gcloud container clusters get-credentials <GKE-NAME> \
    --region <GKE-REGION> \
    --project <PROJECT ID>
```

3. Provision the ingress through NGINX by executing the command line below.

```
kubectl apply -f 8-ingress/nginx-ingress-external-this-is-optional.yaml
```

4. Make sure the ingress configuration was successfully applied.

```
kubectl get ingress -n moodle
```