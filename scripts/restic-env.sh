#!/bin/bash
set -euo pipefail

# Extracts restic credentials from the backup-credentials K8s secret
# in the current namespace and outputs env vars to source.
#
# Usage: eval $(./scripts/restic-env.sh)
#   or:  source <(./scripts/restic-env.sh)

NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}')
NAMESPACE="${NAMESPACE:-default}"
SECRET_NAME="backup-credentials"

SECRET_JSON=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o json)

AWS_ACCESS_KEY_ID=$(echo "$SECRET_JSON" | jq -r '.data.ACCESS_KEY_ID' | base64 -d)
AWS_SECRET_ACCESS_KEY=$(echo "$SECRET_JSON" | jq -r '.data.SECRET_ACCESS_KEY' | base64 -d)
RESTIC_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.data.RESTIC_PASSWORD' | base64 -d)

# Get the repo URL from the K8up Schedule
SCHEDULE_JSON=$(kubectl get schedule zem-backups -n "${NAMESPACE}" -o json 2>/dev/null)
ENDPOINT=$(echo "$SCHEDULE_JSON" | jq -r '.spec.backend.s3.endpoint')
BUCKET=$(echo "$SCHEDULE_JSON" | jq -r '.spec.backend.s3.bucket')

echo "export AWS_ACCESS_KEY_ID='${AWS_ACCESS_KEY_ID}'"
echo "export AWS_SECRET_ACCESS_KEY='${AWS_SECRET_ACCESS_KEY}'"
echo "export RESTIC_PASSWORD='${RESTIC_PASSWORD}'"
echo "export RESTIC_REPOSITORY='s3:${ENDPOINT}/${BUCKET}'"
