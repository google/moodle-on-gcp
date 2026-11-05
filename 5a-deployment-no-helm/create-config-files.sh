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

# halt on execution errors and pipe failures
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# carrega as env vars
source "$SCRIPT_DIR/../0-infra/envs.sh"

# garante que o sistema esteja atualizado quando solicitado
if [ "${RUN_APT_UPGRADE:-false}" = "true" ]; then
  sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
fi

# garante que o envsubst esteja instalado
if ! command -v envsubst >/dev/null 2>&1; then
  sudo apt update && sudo apt install -y gettext-base
fi

if [ -z "${PVC_CLAIM_NAME:-}" ]; then
  if [ "${STORAGE_TYPE:-filestore}" = "regional-pd" ]; then
    export PVC_CLAIM_NAME="pvc-regional-pd"
  else
    export PVC_CLAIM_NAME="pvc-filestore"
  fi
fi

export FILESTORE_IP="${FILESTORE_IP:-<YOUR-FILESTORE-INTERNAL-IP>}"

CONFIGURE_SMTP="${ENABLE_SMTP:-}"
if [ -z "$CONFIGURE_SMTP" ] && [ -t 0 ]; then
  read -rp "Do you want to configure an SMTP password for Moodle email delivery now? [y/N]: " smtp_answer
  case "$smtp_answer" in
    [yY]|[yY][eE][sS]) CONFIGURE_SMTP="true" ;;
    *) CONFIGURE_SMTP="false" ;;
  esac
fi

if [ "$CONFIGURE_SMTP" = "true" ] && [ -z "${SMTP_PASSWORD:-}" ] && [ -t 0 ]; then
  while true; do
    read -rsp "Enter SMTP password: " SMTP_PASSWORD
    echo
    if [ -z "$SMTP_PASSWORD" ]; then
      echo "SMTP password cannot be empty when SMTP is enabled. Please try again."
      continue
    fi
    read -rsp "Confirm SMTP password: " SMTP_PASSWORD_CONFIRM
    echo
    if [ "$SMTP_PASSWORD" = "$SMTP_PASSWORD_CONFIRM" ]; then
      unset SMTP_PASSWORD_CONFIRM
      break
    else
      echo "Passwords do not match. Please try again."
    fi
  done
fi

cd "$SCRIPT_DIR"

# gera os arquivos de configmap específicos (principal e uploads)
envsubst '$MOODLE_ROOT_PATH_NO_SLASH' < ./deployment-templates/moodle-configmap-nginx-template.yaml > ./moodle-configmap-nginx.yaml
envsubst '$MOODLE_ROOT_PATH_NO_SLASH' < ./deployment-templates/moodle-configmap-nginx-uploads-template.yaml > ./moodle-configmap-nginx-uploads.yaml

# gera os arquivos de deployment específicos (principal e uploads)
envsubst '$MOODLE_ROOT_PATH_NO_SLASH $PVC_CLAIM_NAME' < ./deployment-templates/moodle-deployment-nginx-template.yaml > ./moodle-deployment-nginx.yaml
envsubst '$MOODLE_ROOT_PATH_NO_SLASH $PVC_CLAIM_NAME' < ./deployment-templates/moodle-deployment-nginx-uploads-template.yaml > ./moodle-deployment-nginx-uploads.yaml

# gera os manifestos de PV/PVC e StorageClass com os tamanhos configurados em envs.sh
envsubst '$PV_STORAGE_SIZE $FILESTORE_SHARE_NAME $FILESTORE_IP_ADDRESS' < ./deployment-templates/pv-filestore-template.yaml > ../1-pv/pv-filestore.yaml
envsubst '$PVC_STORAGE_SIZE $PVC_LIMIT_STORAGE_SIZE' < ./deployment-templates/pvc-filestore-template.yaml > ../3-pvc/pvc-filestore.yaml
envsubst '$PD_DISK_TYPE $ZONE $REPLICA_ZONE' < ./deployment-templates/storageclass-regional-pd-template.yaml > ../1-pv/storageclass-regional-pd.yaml
envsubst '$PD_DISK_SIZE $PD_ACCESS_MODE $PROJECT_ID $REGION $PD_DISK_NAME $ZONE $REPLICA_ZONE' < ./deployment-templates/pv-regional-pd-template.yaml > ../1-pv/pv-regional-pd.yaml
envsubst '$PD_DISK_SIZE $PD_ACCESS_MODE' < ./deployment-templates/pvc-regional-pd-template.yaml > ../3-pvc/pvc-regional-pd.yaml

if [ -n "${SMTP_PASSWORD:-}" ]; then
  ESCAPED_SMTP_PASSWORD=$(printf '%s\n' "$SMTP_PASSWORD" | sed -e 's/[\/&]/\\&/g')
  sed -i "s/<REPLACE_WITH_YOUR_SMTP_PASSWORD>/$ESCAPED_SMTP_PASSWORD/g" ./moodle-configmap-nginx.yaml
  sed -i "s/<REPLACE_WITH_YOUR_SMTP_PASSWORD>/$ESCAPED_SMTP_PASSWORD/g" ./moodle-configmap-nginx-uploads.yaml
fi
