#!/bin/bash
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


# habilita o modo verboso
set -eo pipefail

# carrega as env vars
source ../0-infra/envs.sh

# constrói a imagem para o nginx
gcloud builds submit \
  --config cloudbuild-nginx.yaml \
  --substitutions=_MOODLE_ROOT_PATH=$MOODLE_ROOT_PATH,_MOODLE_DATAROOT_PATH=$MOODLE_ROOT_PATH/moodledata,_MOODLE_PATH=$MOODLE_ROOT_PATH/moodle \
  --region $REGION
