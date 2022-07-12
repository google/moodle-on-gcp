#!/bin/bash

helm upgrade \
  --namespace moodle \
  -f moodle-values.yaml \
  moodle bitnami/moodle
