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

# set to halt on execution errors and pipe failures
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# load envs vars file
source "$SCRIPT_DIR/envs.sh"

validate_moodle_envs

# ensure system is updated when requested
if [ "${RUN_APT_UPGRADE:-false}" = "true" ]; then
  sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
fi

# ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
  sudo apt update && sudo apt install -y jq
fi

# throw confirmation dialog
cat <<- warning
  WARNING: This script is meant to be ran from the underlying Support VM
  that relies in the same network as your GKE cluster and has a mounted
  storage volume ($FILESTORE_MOUNT) when using Filestore.
warning

read -p "Are you sure you want to continue? Please type Y or y to proceed..." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

  if [ "${CREATE_CLOUD_SQL:-true}" = "true" ]; then
    echo "Deleting $MYSQL_DB database, please wait ..."
    gcloud sql databases delete "$MYSQL_DB" \
      --instance "$MYSQL_INSTANCE_NAME" \
      --quiet
    echo "Done deleting $MYSQL_DB database ..."

    echo "Re-creating $MYSQL_DB database, please wait ..."
    gcloud sql databases create "$MYSQL_DB" \
      --instance "$MYSQL_INSTANCE_NAME" \
      --charset "$MYSQL_MOODLE_DB_CHARSET" \
      --collation "$MYSQL_MOODLE_DB_COLLATION"
    echo "Done re-creating $MYSQL_DB database ..."
  fi

  if [ "${STORAGE_TYPE:-filestore}" = "filestore" ]; then
    DIR="$MOODLE_ROOT_IN_FILESTORE"

    if [ -n "$DIR" ] && [ "$DIR" != "/" ] && [ -d "$DIR" ]; then
      echo "Removing moodleroot path from filestore mount at $DIR ..."
      sudo rm -rvf "${DIR:?}"
      echo "Done removing moodleroot path from filestore mount at $DIR ..."
    else
      echo "Directory $DIR does not exist...nothing to remove..."
    fi
  elif [ "${STORAGE_TYPE:-filestore}" = "regional-pd" ] && [ "${RESET_REGIONAL_PD_ON_CLEANUP:-false}" = "true" ]; then
    echo "Deleting and recreating Regional Replicated Persistent Disk $PD_DISK_NAME ..."
    gcloud compute disks delete "$PD_DISK_NAME" \
      --region="$REGION" \
      --quiet
    gcloud compute disks create "$PD_DISK_NAME" \
      --region="$REGION" \
      --replica-zones="$ZONE,$REPLICA_ZONE" \
      --type="$PD_DISK_TYPE" \
      --size="$PD_DISK_SIZE"
    echo "Done recreating Regional Replicated Persistent Disk $PD_DISK_NAME ..."
  fi

  if [ "${CREATE_ARTIFACT_REGISTRY:-true}" = "true" ]; then
    echo "Removing latest container images from artifact registry ..."

    SHA_256_LIST=$(gcloud artifacts docker images list \
      "$REGION-docker.pkg.dev/$PROJECT_ID/$ARTIFACT_REGISTRY_NAME/$IMAGE_NAME" \
      --quiet --format json | jq --raw-output '.[].version' || true)

    for SHA_256 in $SHA_256_LIST; do
      gcloud artifacts docker images delete \
        "$REGION-docker.pkg.dev/$PROJECT_ID/$ARTIFACT_REGISTRY_NAME/$IMAGE_NAME@$SHA_256" \
        --delete-tags --quiet
    done
  fi
else
  echo "You didn't reply Y or y..."
  echo "The cleanup process has been canceled..."
fi
