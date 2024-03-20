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

# set verbose mode
set -ex

# load envs vars file
source ./envs.sh

# ensure system is updated
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y

# ensure jq is installed
sudo apt install -y jq

# throw confirmation dialog
cat <<- warning
  WARNING: This script is meant to be ran from the underlying Support VM
  that relies in the same network as your GKE cluster and has a mounted
  filestore volume X.X.X.X/moodleshare as $FILESTORE_MOUNT
warning

read -p "Are you sure you want to continue? Please type Y or y to proceed..." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

  echo "Deleting $MYSQL_DB database, please wait ..."
  gcloud sql databases delete $MYSQL_DB \
    --instance $MYSQL_INSTANCE_NAME
  echo "Done deleting $MYSQL_DB database ..."

  echo "Re-creating MYSQL_DB database, please wait ..."
  gcloud sql databases create $MYSQL_DB \
    --instance $MYSQL_INSTANCE_NAME \
    --charset $MYSQL_MOODLE_DB_CHARSET \
    --collation $MYSQL_MOODLE_DB_COLLATION
  echo "Done re-creating MYSQL_DB database ..."

  DIR="$MOODLE_ROOT_IN_FILESTORE"

  if [ -d "$DIR" ]; then
    echo "Removing moodleroot path from filestore mount at $DIR ..."
    sudo rm -rvf $DIR
    echo "Done removing moodleroot path from filestore mount at $DIR ..."
  else
    echo "Directory $DIR does not exist...nothing to remove..."
  fi

  echo "Removing latest container images from artifact registry ..."

  SHA_256=$(gcloud artifacts docker images list \
    $REGION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/moodle-nginx \
    --quiet --format json | jq --raw-output '.[].version')

  gcloud artifacts docker images delete \
    $REGION-docker.pkg.dev/$PROJECT_ID/moodle-filestore/moodle-nginx@$SHA_256 \
    --delete-tags --quiet
else
  echo "You didn't reply Y or y..."
  echo "The cleanup process has been canceled..."
fi
