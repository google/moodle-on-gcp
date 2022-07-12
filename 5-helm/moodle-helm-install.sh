#!/bin/bash

# add helm chart
helm repo add bitnami https://charts.bitnami.com/bitnami

# update helm repo list
helm repo update

# make sure db is empty and filestore volume is too.

# install Moodle via Helm chart
helm install \
  --namespace moodle \
  -f moodle-values.yaml \
  moodle bitnami/moodle
