# Repository organization

This repository groups different types of files which are logically segmented to facilitate the understanding about how to get Modern Moodle up and running quickly in organization's Google Cloud environment.

The way we segment scripts and config files in this is through diretories. Each directory represent a big step to be completed in the deployment process, while file(s) underneath represent specific and specialized tasks that play a role towards parent step completion.

Below you can see the rational behind the current distribution.

---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>0-infra</h2>

Very fist step to perform. Set of shell scripts that groups an initial set of actions to deploy Moodle's infrastructure on Google Cloud.
  * *[envs.sh](../0-infra/envs.sh)*: Environment variables used by infra-creation.sh.
  * *[infra-creation.sh](../0-infra/infra-creation.sh)*: Deploys suggestive initial infrastructure for Moodle in Google Cloud.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>1-pv</h2>

Once Google Kubernetes Engine (GKE) is deployed, we first deploy a persistent volume (pv).
  * *[pv-filestore.yaml](../1-pv/pv-filestore.yaml)*: YAML file that creates a persistent volume object with GKE.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>2-namespace</h2>

Next, we need to create a new namespace to group Moodle's objects. That's what this directory exists for.
* *[namespace-moodle.yaml](../2-namespace/namespace-moodle.yaml)*: Creates a new namespace called "moodle" to group Moodle's objects in GKE.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>3-pvc</h2>

Once the file store (PV) exists we can go ahead and claim access to it. This is accomplished by the task executed under step 3.
* *[pvc-filestore.yaml](../3-pvc/pvc-filestore.yaml)*: Does create a Persistent Volume Claim (PVC) object with Kubernetes cluster.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>4-moodle-image-builder</h2>

Responsible for group steps needed to generate a customer Moodle image.
* *[cloudbuild.yaml](../4-moodle-image-builder/cloudbuild.yaml)*: Google Cloud service that allows building Moodle images through continuous integration (CI). 
* *[Dockerfile](../4-moodle-image-builder/Dockerfile)*: Dockerfile customizes Moodle images with necessary components.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>5-helm</h2>

Once both Moodle's image and the infrastructure to host it are created, we can move forward and deploy it in GKE as a Helm Chart. This directory groups the tasks to do just it.
* *[moodle-helm-install.sh](../5-helm/moodle-helm-install.sh)*: Installs Helm chart using "moodle-values" as parameters for the deployment.
* *[moodle-helm-upgrade.sh](../5-helm/moodle-helm-upgrade.sh)*: Does upgrade a given version of Moodle already deployed.
* *[moodle-values.yaml](../5-helm/moodle-values.yaml)*: Parameters used by Helm chart to deploy Moodle objects in GKE.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>6-backendconfig</h2>

This step creates is responsible for creating a new global load balancer for the cluster.
* *[ingress-backendconfig](../6-backendconfig/ingress-backendconfig.yaml)*: It does create a new Cloud Load Balancer in Google Cloud and configures the backend to be hit from the balancer.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>7-ssl-certificate-and-redirect</h2>

Holds tasks of provisioning managed certificates and HTTP -> HTTPS redirection.
* *[frontendconfig-redirect-http-to-https.yaml](../7-ssl-certificate-and-redirect/frontendconfig-redirect-http-to-https.yaml)*: Configs Cloud Load Balancer's frontend and creates HTTP to HTTPS redirection.
* *[google-managed-ssl-certificate.yaml](../7-ssl-certificate-and-redirect/google-managed-ssl-certificate.yaml)*: Does allocate a new managed certificate with Google Cloud to be used by Cloud Load Balancer.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>8-ingress</h2>

This final step does configure Cloud Load Balancer to properly serve Moodle's cluster as Ingress.
* *[gce-ingress-external.yaml](../8-ingress/gce-ingress-external.yaml)*: Configues Google Cloud Load Balancer as ingress for the cluster.
* *[nginx-ingress-external.yaml](../8-ingress/nginx-ingress-external.yaml)*: Configures an instance of NGINX as an external ingress controller for the cluster.
---

<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>9-hpa</h2>

Horizontal Pod Autoscaling (HPA) is a state that allows pods in Kubernetes to expand their capacity horizontally (adding more pods) when meeting certain thresholds. This document adds HPA capacity to GKE to get Moodle's pods automatically scaling out.

* *[moodle-hpa](../9-hpa/moodle-hpa.yaml)*: Enables HPA for Moodle's pods in GKE.