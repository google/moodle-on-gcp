# Deployment

This session is designed to support customers and partners on getting Modern Moodle on Google Cloud up and running on their own accounts.

Please, carefully follow the steps below and be sure to comply with all the pre-requisits described in the document [pre-requisits](pre-requisits.md) before getting started.

* [Pre-requisits](pre-requisits.md)
* [File "env.sh"]
* Deploying infrastructure
* Deploying persistent volume
* Deploying Moodle's namespace
* Deploying a persistent volume claim
* Building Moodle's container image
* Installing Modern Moodle with Helm
* Deploying backend config
* Configuring SSL and forcing HTTPS redirection
* Deploying ingress
  * Google Cloud Load Balancer
  * NGINX
* Configuring Redis Cache with Moodle
* Running benchmark to check performance