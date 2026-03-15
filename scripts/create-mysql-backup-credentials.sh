#!/bin/bash
set -euo pipefail

# Provision B2 backup credentials for MySQL backups via mariadb-operator
#
# Creates:
# 1. B2 application key scoped to <cluster>/mysql/ prefix
# 2. Stores {ACCESS_KEY_ID, SECRET_ACCESS_KEY} JSON in OCI Vault as "infra-mysql-backup"
#
# No OCI user/policy needed — uses existing ClusterSecretStore with infra-* IAM policy.
#
# Dependencies: oci, b2, jq
#
# Usage: ./scripts/create-mysql-backup-credentials.sh <cluster-name>
# Example: ./scripts/create-mysql-backup-credentials.sh cluster03

if [ $# -ne 1 ]; then
    echo "Usage: $0 <cluster-name>"
    echo "Example: $0 cluster03"
    exit 1
fi

CLUSTER="$1"

# OCI configuration
OCI_COMPARTMENT_OCID="${OCI_COMPARTMENT_OCID:-ocid1.compartment.oc1..aaaaaaaagyawjldswlrq2f2dnsqz2kqlzsvj6mirpcue7oqwzlyuwx7pqjha}"
OCI_VAULT_OCID="${OCI_VAULT_OCID:-ocid1.vault.oc1.uk-london-1.eruxsrmlaafja.abwgiljridwbzbxrs2vvay6b6n6x7xhi3ymapbgov36lrqmm7bkxgh3hmnka}"
OCI_VAULT_KEY_OCID="${OCI_VAULT_KEY_OCID:-ocid1.key.oc1.uk-london-1.eruxsrmlaafja.abwgiljtncunmpibvwvjygia2d3umhb6vf24axjuxuivbg52moq76tgdhdua}"

# B2 configuration
B2_BUCKET="zem-backups-eu"
B2_KEY_NAME="mysql-backup-${CLUSTER}"
B2_PREFIX="${CLUSTER}/mysql/"
VAULT_SECRET_NAME="infra-mysql-backup"

echo "=== Provisioning MySQL backup credentials for ${CLUSTER} ==="
echo ""

# Check dependencies
for cmd in oci b2 jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd is not installed or not in PATH"
        exit 1
    fi
done

# Verify OCI auth is working
echo "--- Preflight: checking OCI authentication ---"
if ! oci iam region list --output json </dev/null >/dev/null 2>&1; then
    echo "ERROR: OCI authentication failed. If using security_token auth, run: oci session refresh"
    exit 1
fi
echo "OCI auth OK"
echo ""

# Helper: create or update an OCI Vault secret
store_vault_secret() {
    local secret_name="$1"
    local secret_b64="$2"

    local existing_ocid
    existing_ocid=$(oci vault secret list \
        --compartment-id "${OCI_COMPARTMENT_OCID}" \
        --vault-id "${OCI_VAULT_OCID}" \
        --name "${secret_name}" \
        --output json 2>/dev/null | jq -r '.data[0].id // empty')

    if [ -n "${existing_ocid}" ]; then
        oci vault secret update-base64 \
            --secret-id "${existing_ocid}" \
            --secret-content-content "${secret_b64}" \
            --output json >/dev/null
        echo "  Updated: ${secret_name}"
    else
        oci vault secret create-base64 \
            --compartment-id "${OCI_COMPARTMENT_OCID}" \
            --vault-id "${OCI_VAULT_OCID}" \
            --key-id "${OCI_VAULT_KEY_OCID}" \
            --secret-name "${secret_name}" \
            --secret-content-content "${secret_b64}" \
            --output json >/dev/null
        echo "  Created: ${secret_name}"
    fi
}

# --- Step 1: B2 credentials (idempotent) ---
echo "--- Step 1: Provisioning B2 credentials ---"
B2_KEY_ID=""
B2_KEY_SECRET=""
B2_CREDS_VALID=false

# Check if credentials already exist in OCI Vault
EXISTING_BACKUP_OCID=$(oci vault secret list \
    --compartment-id "${OCI_COMPARTMENT_OCID}" \
    --vault-id "${OCI_VAULT_OCID}" \
    --name "${VAULT_SECRET_NAME}" \
    --output json 2>/dev/null | jq -r '.data[0].id // empty')

if [ -n "${EXISTING_BACKUP_OCID}" ]; then
    echo "  Found existing vault secret: ${VAULT_SECRET_NAME}"
    EXISTING_BACKUP_JSON=$(oci secrets secret-bundle get \
        --secret-id "${EXISTING_BACKUP_OCID}" \
        --output json 2>/dev/null | jq -r '.data."secret-bundle-content".content' | base64 -d)
    EXISTING_B2_KEY_ID=$(echo "$EXISTING_BACKUP_JSON" | jq -r '.ACCESS_KEY_ID // empty')
    EXISTING_B2_KEY_SECRET=$(echo "$EXISTING_BACKUP_JSON" | jq -r '.SECRET_ACCESS_KEY // empty')

    # Validate B2 credentials by trying to list files
    if [ -n "${EXISTING_B2_KEY_ID}" ] && [ -n "${EXISTING_B2_KEY_SECRET}" ]; then
        echo "  Testing existing B2 credentials (key: ${EXISTING_B2_KEY_ID})..."
        if B2_APPLICATION_KEY_ID="${EXISTING_B2_KEY_ID}" B2_APPLICATION_KEY="${EXISTING_B2_KEY_SECRET}" \
            b2 ls --recursive --limit 1 "${B2_BUCKET}" "${B2_PREFIX}" >/dev/null 2>&1; then
            echo "  B2 credentials are valid, reusing"
            B2_KEY_ID="${EXISTING_B2_KEY_ID}"
            B2_KEY_SECRET="${EXISTING_B2_KEY_SECRET}"
            B2_CREDS_VALID=true
        else
            echo "  B2 credentials are invalid, will create new key"
            # Clean up the dead key from B2 if it still exists
            if b2 key list 2>/dev/null | awk '{print $1}' | grep -qx "${EXISTING_B2_KEY_ID}"; then
                echo "  Deleting stale B2 key: ${EXISTING_B2_KEY_ID}"
                b2 key delete "${EXISTING_B2_KEY_ID}"
            fi
        fi
    fi
else
    echo "  No existing vault secret found, will create everything fresh"
fi

# Create new B2 key if existing creds were invalid or missing
if [ "${B2_CREDS_VALID}" = false ]; then
    # Clean up any orphaned B2 keys with the same name
    ORPHANED_KEYS=$(b2 key list 2>/dev/null | grep "${B2_KEY_NAME}" | awk '{print $1}' || true)
    for key_id in $ORPHANED_KEYS; do
        echo "  Deleting orphaned B2 key: ${key_id}"
        b2 key delete "${key_id}"
    done

    B2_KEY_RESULT=$(b2 key create \
        --bucket "${B2_BUCKET}" \
        --name-prefix "${B2_PREFIX}" \
        "${B2_KEY_NAME}" \
        "listBuckets,listFiles,readFiles,writeFiles,deleteFiles" 2>&1)
    B2_KEY_ID=$(echo "$B2_KEY_RESULT" | awk '{print $1}')
    B2_KEY_SECRET=$(echo "$B2_KEY_RESULT" | awk '{print $2}')
    echo "  Created new B2 key: ${B2_KEY_NAME}"
fi

# --- Step 2: Store credentials in OCI Vault ---
echo "--- Step 2: Storing credentials in OCI Vault ---"
BACKUP_SECRET_JSON=$(jq -n \
    --arg ak "$B2_KEY_ID" \
    --arg sk "$B2_KEY_SECRET" \
    '{ACCESS_KEY_ID: $ak, SECRET_ACCESS_KEY: $sk}')
store_vault_secret "${VAULT_SECRET_NAME}" "$(echo -n "$BACKUP_SECRET_JSON" | base64)"

# --- Summary ---
echo ""
echo "=== Provisioning complete ==="
echo ""
echo "Resources created:"
echo "  B2 Key:        ${B2_KEY_NAME} (prefix: ${B2_PREFIX}, reused: ${B2_CREDS_VALID})"
echo "  Vault Secret:  ${VAULT_SECRET_NAME}"
echo ""
echo "The backup feature in clusters/${CLUSTER}/infra.yaml should have:"
echo ""
echo "              backup:"
echo "                enabled: true"
echo "                vaultSecretName: ${VAULT_SECRET_NAME}"
echo "                b2:"
echo "                  prefix: ${CLUSTER}/mysql"
