# Deployment

This session is designed to support customers and partners in getting Modern Moodle on Google Cloud up and running on their accounts.

Please, carefully follow the steps below and be sure to comply with all the prerequisites described in the document [pre-requisites](pre-requisites.md) before getting started.

## Basic installation

* [Pre-requisites](pre-requisites.md)
* [File "env.sh"](file-env-sh.md)
* [Deploying infrastructure](deploying-infrastructure.md)
* [Deploying persistent volume](deploying-persistent-volume.md)
* [Deploying Moodle's namespace](deploying-namespace.md)
* [Deploying a persistent volume claim](deploying-persistent-volume-claim.md)
* [Building Moodle's container image](building-moodle-image.md)
* [Installing Modern Moodle with Helm](install-moodle-helm.md)
* [Deploying backend config](deploying-backend-config.md)
* [Configuring SSL and forcing HTTPS redirection](provisioning-certificate-forcing-https.md)
* [Deploying ingress](deploying-ingress.md)
  * [Google Cloud Load Balancer](deploying-ingress-cloud-load-balancer.md)
  * [NGINX](deploying-ingress-nginx.md)
* [Enabling horizontal scalability for Pods (HPA)](enabling-hpa.md)
* [Configuring Redis Cache with Moodle](configuring-redis-cache-with-moodle.md)
* [Running a benchmark to check the performance](moodle-report-benchmark.md)

## Post-installation

* [Update environment variables values and upgrade the pods](docs/post-installation-values-update.md)
* [Migration recommendations](docs/migration-recommendations.md)