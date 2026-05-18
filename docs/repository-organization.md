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
* *[](../4-moodle-image-builder/build-nginx-based-image.sh)*: Script that uses gcloud to trigger Google Cloud Build to build and push the image into Artifact Registry for the NGINX based image.
* *[cloudbuild-nginx.yaml](../4-moodle-image-builder/cloudbuild-nginx.yaml)*: Google Cloud service that allows building Moodle images through continuous integration (CI) using NGINX based setup.
* *[Dockerfile.nginx](../4-moodle-image-builder/Dockerfile.nginx)*: Dockerfile customizes Moodle images with necessary components for the NGINX based image.

**(Deprecated)**
* *[](../4-moodle-image-builder/build-bitnami-based-image.sh)*: Script that uses gcloud to trigger Google Cloud Build to build and push the image into Artifact Registry for the Bitnami based image.
* *[cloudbuild-bitnami.yaml](../4-moodle-image-builder/cloudbuild-bitnami.yaml)*: Google Cloud service that allows building Moodle images through continuous integration (CI) using Bitnami based setup.
* *[Dockerfile.bitnami](../4-moodle-image-builder/Dockerfile.bitnami)*: Dockerfile customizes Moodle images with necessary components for the Bitnami based image.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>5-helm (For Bitnami only) (Deprecated)</h2>

Once both Moodle's image and the infrastructure to host it are created, we can move forward and deploy it in GKE as a Helm Chart. This directory groups the tasks to do just it.
* *[moodle-helm-install.sh](../5-helm/moodle-helm-install.sh)*: Installs Helm chart using "moodle-values" as parameters for the deployment.
* *[moodle-helm-upgrade.sh](../5-helm/moodle-helm-upgrade.sh)*: Does upgrade a given version of Moodle already deployed.
* *[moodle-values.yaml](../5-helm/moodle-values.yaml)*: Parameters used by Helm chart to deploy Moodle objects in GKE.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>5a-deployment-no-helm (Mostly for NGINX and recommended)</h2>

Once both NGINX based Moodle's image and the infrastructure to host it are created, we can move forward and deploy it in GKE with vanilla deployment yaml files. This directory groups the tasks to do just it.

* *[moodle-configmap-nginx.yaml](../5a-deployment-no-helm/moodle-configmap-nginx.yaml)*: For NGINX based deployment, it should contain all variables necessary for Moodle to Work, such as Redis and DB's hostname/ip, user, etc. - make sure to populate this file appropriately.
* *[moodle-configmap-nginx-sample.yaml](../5a-deployment-no-helm/moodle-configmap-nginx-sample.yaml)*: A sample file of the configmap, explaining what to input in there.

Also, please find here the explanation of all the values:

  - `MOODLE_URL:` The moodle's latest url, as initial, you can leave it as default **which will deploy the 4.2.1 version**.
  - `MOOSH_URL:` The moosh's latest url, as initial, you can leave it as default **which will deploy the 1.11 version**.
  - `LANG:` The LANG in Unix format, **defaults it to: en_US.UTF-8**.
  - `LANGUAGE:` The OS LANGUAGE, **defaults it to: en_US**.
  - `MOODLE_LANGUAGE:` The Moodle default languagem, **defaults it to: en_US**.
  - `SITE_URL:` Your Moodle's main URL, i.e: **https://www.mymoodlesite.com**
  - `MOODLE_DATAROOT_PATH:` The famous moodledata path, this is set to the NFS volume too, **defaults to '/moodleroot/moodledata'**.
  - `MOODLE_PATH:` The famous moodle path, this is set to the NFS volume too, **defaults to '/moodleroot/moodle'**.
  - `DB_TYPE:` Supports MySQL, PostgreSQL, MS SQL,  **defaults to 'mysqli'**, MySQL in CloudSQL, works neatly and performs awesome, plus managed service, yay! Can also support PostgreSQL and MicrosoSQL server in CloudSQL flavors.
  - `DB_HOST:` Database's private IP address.
  - `DB_HOST_PORT:` Database's port, **defaults to '3306' for MySQL**.
  - `DB_NAME:` Database's schema name, **defaults to 'moodle-db'**.
  - `DB_USER:` Database's user, can be set to any user owner of $DB_NAME schema, **defaults to 'root'**.
  - `DB_PREFIX:` Moodle's database's table prefix, in case one has many different setups inside of the same schema, not recommended but possible, **defaults to 'mdl_'**.
  - `MOODLE_SITENAME:` The Moodle's default site name, **defaults to 'Moodle 4.2 On GKE'**.
  - `MOODLE_SITESUMMARY:` The Moodle's site summary, optional, leave '' if you want it blank.
  - `MOODLE_USERNAME:` The Moodle's initial and admin username, **defaults to 'admin'**.
  - `MOODLE_EMAIL:` The Moodle's email address when sending e-mails, **defaults to 'user@example.com'**.
  - `DB_READ_REPLICA_HOST:` Host or IP address of a read replica DB if any, optional. **(Don't use the same primary server here(**.
  - `DB_READ_REPLICA_PORT:` TCP Port of a read replica DB if any, optional.
  - `DB_READ_REPLICA_USER:` The user of a read replica DB if any, optional
  - `DB_READ_REPLICA_PASSWORD:` The password of a read replica DB if any, optional - can become a secret to increase security
  - `REDIS_SESSION_ID_HOST:` The Redis Host used to Store data for Session ID's, aka session cookies.
  - `REDIS_SESSION_ID_PORT:` The Redis Port used to Store data for Session ID's, aka session cookies.
  - **Note #1: You can use the same values for the remaining Redis related entries, but most likely a bigger instance will be required**.
  - **Note #2: With Redis Enterprise we were able to sustain 200K+ users at the same time on the site with big IOPS settings**.
  - `REDIS_SESSION_ID_AUTH_STRING:` The Redis AUTH String used to Store data for Session ID's, aka session cookies.
  - `REDIS_APP_IP_AND_PORT:` The Redis Host and Port used to Store data in Moodle's Application Store.
  - `REDIS_APP_AUTH_STRING:` The Redis AUTH String used to Store data in Moodle's Application Store.
  - `REDIS_SESSION_IP_AND_PORT:` The Redis Host and Port used to Store data in Moodle's Session Store.
  - `REDIS_SESSION_AUTH_STRING:` The Redis AUTH String used to Store data in Moodle's Session Store.
  - `REDIS_LOCK_HOST_AND_PORT:` The Redis Host and Port used to Store data for file locks.
  - `REDIS_LOCK_AUTH_STRING:` The Redis AUTH String used to Store data for file locks.
  - `SSLPROXY:` Tells if Moodle is running behind a proxied Webserver or Load Balancer, **defaults to 'true'**.
  - `NOEMAIL_EVER:` Tells if Moodle should send e-mails or not, should be changed to false in Production, **defaults to 'true'**.
  - `SMTP_HOST:` The SMTP hostname that Moodle uses to send e-mails.
  - `SMTP_PORT:` The SMTP port that Moodle uses to send e-mails.
  - `SMTP_USER:` The SMTP username that Moodle uses to send e-mails.
  - `SMTP_PASSWORD:` The SMTP password that Moodle uses to send e-mails.
  - `SMTP_PROTOCOL:` Defaults to 'tls'. The SMTP PROTOCOL that Moodle uses to send e-mails.
  - `MOODLE_MAIL_NOREPLY_ADDRESS:` The noreply address setting for Moodle's sent e-mails.
  - `MOODLE_MAIL_PREFIX:` Moodle mail prefix in subject line, **defaults to ']moodle]'**.

  Most of these values are set in Moodle's config.php file, which can be changed later to your own wish, these values are suggested as env vars and built into config.php during the initial setup process.

  For a more detailed understanding of Moodle's config.php file, check its distribution example file, which is located at: [https://github.com/moodle/moodle/blob/master/config-dist.php](https://github.com/moodle/moodle/blob/master/config-dist.php)
* *[moodle-externaldb-secret.yaml](../5a-deployment-no-helm/moodle-externaldb-secret.yaml)*: Kubernetes Secret, Base64 encoded value for Database (MySQL) password.
* *[moodle-password-secret.yaml](../5a-deployment-no-helm/moodle-password-secret.yaml)*: Kubernetes Secret, Base64 encoded value for Moodle's admin and initial user.
* *[moodle-deployment-nginx.yaml](../5a-deployment-no-helm/moodle-deployment-nginx.yaml)*: The Deployment object for the NGINX based image, make sure to change the image tags and repository name once you finsh building it and pushing it in [folder of Step 4](../4-moodle-image-builder/).
* *[moodle-deployment-bitnami.yaml](../5a-deployment-no-helm/moodle-deployment-bitnami.yaml)*: The Deployment object for the Bitnami's based image, make sure to change the image tags and repository name once you finsh building it and pushing it in [folder of Step 4](../4-moodle-image-builder/).
  **(Note: this won't use the given configmap up above, confogmap is only meant for NGINX based deployment)**.
* *[moodle-service-.yaml](../5a-deployment-no-helm/moodle-service.yaml)*: The Service object for any based image, you don't and shouldn't change anything in this file if you don't know about GKE's BackendConfig object, leave it default and it should suffice.


---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>6-backendconfig</h2>

This step is responsible for creating a backend config object that links the service with the Google Cloud's Load Balancer in form of an Ingress Controller, it also defines CDN and Cloud Armor rules as well as its own HTTP Healthcheck settings.

* *[ingress-backendconfig-nginx](../6-backendconfig/ingress-backendconfig-nginx.yaml)*: The given configuration for NGINX based deployment.
* *[ingress-backendconfig-bitnami](../6-backendconfig/ingress-backendconfig-bitnami.yaml)*: The given configuration for Bitnami based deployment.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>7-ssl-certificate-and-redirect</h2>

Holds tasks of provisioning managed certificates and HTTP -> HTTPS redirection.
* *[frontendconfig-redirect-http-to-https.yaml](../7-ssl-certificate-and-redirect/frontendconfig-redirect-http-to-https.yaml)*: Configs Cloud Load Balancer's frontend and creates HTTP to HTTPS redirection.
* *[google-managed-ssl-certificate.yaml](../7-ssl-certificate-and-redirect/google-managed-ssl-certificate.yaml)*: Does allocate a new managed certificate with Google Cloud to be used by Cloud Load Balancer.
---
<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>8-ingress</h2>

This final step does configure Cloud Load Balancer to properly serve Moodle's cluster as Ingress, choose only **one option** below.
* *[gce-ingress-external.yaml](../8-ingress/gce-ingress-external.yaml)*: (Recommended) Configues Google Cloud Load Balancer as ingress for the cluster.
* *[nginx-ingress-external.yaml](../8-ingress/nginx-ingress-external.yaml)*: (Optional) Configures an instance of NGINX as an external ingress controller for the cluster.
---

The reason we recommend GCE Ingress (Google Compute Engine / Load Balancer) is that it has its on SLA being a managed service, it supports CDN, Cloud Armor (Anti DDoS and WAF) and also has a global scale, in counterpart, if using OSS NGINX Ingress Controller, you will have community based support, or, have to pay for other alternatives to be able to get premium support.

<img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/folder.svg" width="50" height="50">
<h2>9-hpa</h2>

Horizontal Pod Autoscaling (HPA) is a state that allows pods in Kubernetes to expand their capacity horizontally (adding more pods) when meeting certain thresholds. This document adds HPA capacity to GKE to get Moodle's pods automatically scaling out.

* *[moodle-hpa](../9-hpa/moodle-hpa.yaml)*: Enables HPA for Moodle's pods in GKE.