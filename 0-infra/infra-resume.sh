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

# ==============================================================================
# Environment Resume Script for Moodle on GCP (infra-resume.sh)
# ==============================================================================
# Resumes a paused Moodle on GCP environment:
#   1. Starts Cloud SQL for MySQL (--activation-policy=ALWAYS).
#   2. Recreates Memorystore for Redis if it was deleted during pause (--recreate-redis).
#   3. Scales Moodle Deployments in GKE back to ${MOODLE_REPLICAS:-3} (1 pod per zone)
#      and unsuspends CronJobs.
#
# Usage:
#   ./0-infra/infra-resume.sh [--recreate-redis] [--replicas=3]

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ENVS_FILE:-$SCRIPT_DIR/envs.sh}"

validate_moodle_envs

RECREATE_REDIS="false"
TARGET_REPLICAS="${MOODLE_REPLICAS:-3}"

for arg in "$@"; do
  case "$arg" in
    --recreate-redis)
      RECREATE_REDIS="true"
      ;;
    --replicas=*)
      TARGET_REPLICAS="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--recreate-redis] [--replicas=3]" >&2
      exit 1
      ;;
  esac
done

is_configured() {
  local val="$1"
  [ -n "$val" ] && [[ "$val" != \<*\> ]]
}

export CLOUDSDK_CONTAINER_USE_APPLICATION_DEFAULT_CREDENTIALS=false

# 1. Start Cloud SQL instance (--activation-policy=ALWAYS)
if is_configured "$MYSQL_INSTANCE_NAME"; then
  echo "Starting Cloud SQL instance '$MYSQL_INSTANCE_NAME' (--activation-policy=ALWAYS)..."
  gcloud sql instances patch "$MYSQL_INSTANCE_NAME" \
    --activation-policy=ALWAYS \
    --project="$PROJECT_ID" \
    --quiet
fi

# 2. Recreate Memorystore Redis if requested and not currently running
if [ "$RECREATE_REDIS" = "true" ] && is_configured "$REDIS_NAME"; then
  if ! gcloud redis instances describe "$REDIS_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Recreating Memorystore Redis instance '$REDIS_NAME' in '$REGION'..."
    gcloud redis instances create "$REDIS_NAME" \
      --size=1 \
      --network="$VPC_NAME" \
      --redis-version=redis_7_2 \
      --redis-config maxmemory-policy=allkeys-lru \
      --region="$REGION" \
      --project="$PROJECT_ID"
  fi
fi

# 3. Scale GKE Moodle deployments back to TARGET_REPLICAS
if is_configured "$GKE_NAME"; then
  echo "Connecting to GKE cluster '$GKE_NAME' ($REGION) and scaling moodle-deployment to $TARGET_REPLICAS replicas..."
  gcloud container clusters get-credentials "$GKE_NAME" --region="$REGION" --project="$PROJECT_ID"
  if is_configured "$REDIS_NAME"; then
    NEW_REDIS_IP="$(gcloud redis instances describe "$REDIS_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(host)" 2>/dev/null || true)"
    if [ -n "$NEW_REDIS_IP" ]; then
      echo "Updating moodle-configmap with Redis host IP '$NEW_REDIS_IP'..."
      kubectl patch configmap moodle-configmap -n moodle --type merge -p "{\"data\":{\"REDIS_HOST\":\"$NEW_REDIS_IP\",\"REDIS_SESSION_ID_HOST\":\"$NEW_REDIS_IP\",\"REDIS_SESSION_IP_AND_PORT\":\"${NEW_REDIS_IP}:6379\",\"REDIS_APP_IP_AND_PORT\":\"${NEW_REDIS_IP}:6379\",\"REDIS_LOCK_HOST_AND_PORT\":\"${NEW_REDIS_IP}:6379\"}}" 2>/dev/null || true
    fi
  fi
  kubectl scale deployment moodle-deployment -n moodle --replicas="$TARGET_REPLICAS"
  kubectl patch cronjob moodle-cronjob -n moodle -p '{"spec":{"suspend":false}}' 2>/dev/null || true
  kubectl get pods -n moodle -o wide
fi

echo "Environment resumed with $TARGET_REPLICAS Moodle replicas!"
