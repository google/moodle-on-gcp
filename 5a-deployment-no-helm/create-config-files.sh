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

# habilita o modo verboso
set -ex

# carrega as env vars
source ../0-infra/envs.sh

# garante que o sistema esteja atualizado
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y

# garante que o envsubst esteja instalado
sudo apt install -y gettext-base

# gera o arquivo de configmap específico
envsubst \$MOODLE_ROOT_PATH_NO_SLASH < ./deployment-templates/moodle-configmap-nginx-template.yaml > ./moodle-configmap-nginx.yaml

# gera o arquivo de deployment específico
envsubst \$MOODLE_ROOT_PATH_NO_SLASH < ./deployment-templates/moodle-deployment-nginx-template.yaml > ./moodle-deployment-nginx.yaml
