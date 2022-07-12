# Copyright 2022 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
