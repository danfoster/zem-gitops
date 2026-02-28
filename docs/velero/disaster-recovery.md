# Disaster Recovery

## Scenario: Complete Cluster Loss

If the entire cluster is lost, you need to:

1. Deploy a new cluster
2. Install Velero with the **same credentials**
3. Restore from B2 backups

### Step 1: Deploy New Cluster

Follow standard cluster provisioning process.

### Step 2: Install Velero

Velero will be deployed via ArgoCD from the GitOps repo. The critical requirement is that the **same secrets** are available:

| Secret | Source | Why It Matters |
|--------|--------|----------------|
| `velero-b2-credentials` | Bitwarden: `b2-eu-k8up-access-id`, `b2-eu-k8up-access-key` | Access to B2 bucket |
| `velero-repo-credentials` | Bitwarden: `velero-repo-password` | Decrypt kopia repository |

If the repo password is different, you **cannot decrypt existing backups**.

### Step 3: Verify Backup Location

```bash
# Wait for Velero to be ready
kubectl get pods -n velero

# Check backup location is accessible
velero backup-location get
```

### Step 4: List Available Backups

```bash
velero backup get
```

### Step 5: Restore Namespaces

```bash
# Restore each application namespace
velero restore create dr-restore --from-backup <latest-backup>

# Monitor progress
velero restore describe dr-restore --details
```

### Step 6: Sync ArgoCD

After restore, ArgoCD will adopt the resources:

```bash
# For each application
argocd app sync <app-name>
```

## Scenario: Single Namespace Recovery

If one namespace is corrupted but the cluster is fine:

```bash
# Delete corrupted namespace (if needed)
kubectl delete namespace <namespace>

# Restore from backup
velero restore create ns-restore \
  --from-backup <backup-name> \
  --include-namespaces <namespace>

# Sync with ArgoCD
argocd app sync <app-name>
```

## Scenario: Restore to Different Cluster

For migrating workloads to a new cluster:

### On Source Cluster

```bash
# Create a fresh backup
velero backup create migration-backup --include-namespaces=<namespaces>

# Wait for completion
velero backup describe migration-backup
```

### On Target Cluster

1. Install Velero with same B2 credentials and repo password
2. Configure same `BackupStorageLocation` (same bucket/prefix)

```bash
# Backups should appear automatically
velero backup get

# Restore
velero restore create migration-restore --from-backup migration-backup
```

## Critical: Protecting the Repo Password

The kopia repository password in `velero-repo-password` (Bitwarden) is **essential**. Without it:

- Existing backups cannot be decrypted
- All backup data is unrecoverable

Ensure this secret is:
- Stored in Bitwarden
- Backed up separately (e.g., password manager, secure vault)
- Never deleted or overwritten

## DR Testing Checklist

Regular DR testing should verify:

- [ ] Velero can connect to B2 (`velero backup-location get` shows `Available`)
- [ ] Backups complete successfully (`velero backup get` shows `Completed`)
- [ ] Restores work (`velero restore create` succeeds)
- [ ] Restored PVCs contain expected data
- [ ] Applications function after restore

### Test Procedure

```bash
# 1. Create test backup
velero backup create dr-test-backup --include-namespaces=<test-namespace>

# 2. Create test restore namespace
kubectl create namespace dr-test

# 3. Restore to test namespace
velero restore create dr-test-restore \
  --from-backup dr-test-backup \
  --namespace-mappings <original>:dr-test

# 4. Verify pods are running
kubectl get pods -n dr-test

# 5. Verify data (example for a pod with PVC)
kubectl exec -it -n dr-test <pod-name> -- ls -la /data

# 6. Cleanup
kubectl delete namespace dr-test
velero restore delete dr-test-restore
velero backup delete dr-test-backup
```
