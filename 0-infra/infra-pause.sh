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
# Environment Pause Script for Moodle on GCP (infra-pause.sh)
# ==============================================================================
# Hibernates compute-billing resources when the environment is idle:
#   1. Scales Moodle Deployments & CronJobs in GKE to 0 replicas (on GKE Autopilot,
#      scaling pods to 0 reduces pod compute billing to $0.00/hr).
#   2. Stops the Cloud SQL for MySQL instance (--activation-policy=NEVER), reducing
#      database vCPU/RAM billing to $0.00/hr (retaining only SSD storage).
#   3. Optionally deletes the ephemeral Memorystore Redis cache (--delete-redis)
#      so it does not bill hourly while paused (recreated automatically by infra-resume.sh).
#
# Usage:
#   ./0-infra/infra-pause.sh [--delete-redis]

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/envs.sh"

validate_moodle_envs

DELETE_REDIS="false"
for arg in "$@"; do
  case "$arg" in
    --delete-redis)
      DELETE_REDIS="true"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--delete-redis]" >&2
      exit 1
      ;;
  esac
done

is_configured() {
  local val="$1"
  [ -n "$val" ] && [[ "$val" != \<*\> ]]
}

export CLOUDSDK_CONTAINER_USE_APPLICATION_DEFAULT_CREDENTIALS=false

# 1. Scale GKE Moodle deployments to 0 replicas
if is_configured "$GKE_NAME"; then
  if gcloud container clusters describe "$GKE_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Connecting to GKE cluster '$GKE_NAME' ($REGION) and scaling Moodle workloads to 0 replicas..."
    gcloud container clusters get-credentials "$GKE_NAME" --region="$REGION" --project="$PROJECT_ID"
    kubectl scale deployment moodle-deployment -n moodle --replicas=0 --ignore-not-found=true || true
    kubectl scale deployment moodle-deployment-uploads -n moodle --replicas=0 --ignore-not-found=true || true
    kubectl patch cronjob moodle-cronjob -n moodle -p '{"spec":{"suspend":true}}' 2>/dev/null || true
    echo "GKE Moodle workloads scaled to 0 replicas."
  fi
fi

# 2. Stop Cloud SQL instance (--activation-policy=NEVER)
if is_configured "$MYSQL_INSTANCE_NAME"; then
  if gcloud sql instances describe "$MYSQL_INSTANCE_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Stopping Cloud SQL instance '$MYSQL_INSTANCE_NAME' (--activation-policy=NEVER)..."
    gcloud sql instances patch "$MYSQL_INSTANCE_NAME" \
      --activation-policy=NEVER \
      --project="$PROJECT_ID" \
      --quiet
    echo "Cloud SQL instance '$MYSQL_INSTANCE_NAME' stopped."
  fi
fi

# 3. Optionally delete ephemeral Redis cache to eliminate hourly cache billing while paused
if [ "$DELETE_REDIS" = "true" ] && is_configured "$REDIS_NAME"; then
  if gcloud redis instances describe "$REDIS_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Deleting ephemeral Memorystore Redis instance '$REDIS_NAME' (will be recreated on resume)..."
    gcloud redis instances delete "$REDIS_NAME" --region="$REGION" --project="$PROJECT_ID" --quiet
  fi
fi

echo "Environment paused! Compute billing for GKE Autopilot pods and Cloud SQL is now $0.00/hr."
