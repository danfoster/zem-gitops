# Troubleshooting

## Backup Issues

### Backup stuck in "InProgress"

Check node-agent logs:
```bash
kubectl logs -n velero -l name=node-agent --tail=100
```

Check for PodVolumeBackups:
```bash
kubectl get podvolumebackups -n velero
kubectl describe podvolumebackup -n velero <name>
```

### BackupStorageLocation shows "Unavailable"

Check Velero server logs:
```bash
kubectl logs -n velero -l app.kubernetes.io/name=velero --tail=100
```

Common causes:
- B2 credentials incorrect
- Bucket name contains `/` (use `prefix` field instead)
- Network connectivity issues

Verify credentials:
```bash
# Check secret exists
kubectl get secret velero-b2-credentials -n velero

# View credential format
kubectl get secret velero-b2-credentials -n velero -o jsonpath='{.data.cloud}' | base64 -d
```

### "repository not initialized" error

The kopia repository password doesn't match. Check:
```bash
kubectl get secret velero-repo-credentials -n velero
```

If the password was regenerated, existing backups cannot be accessed.

## Restore Issues

### Restore stuck in "InProgress"

Check PodVolumeRestores:
```bash
kubectl get podvolumerestores -n velero
```

Check if pods are starting in target namespace:
```bash
kubectl get pods -n <target-namespace>
kubectl describe pod -n <target-namespace> <pod-name>
```

### Restore helper image pull error

If you see `ImageInspectError` or `short name mode is enforcing`:
```
Failed to inspect image "velero/velero-restore-helper:v1.15.1"
```

The restore helper needs a fully qualified image name. Check the ConfigMap:
```bash
kubectl get configmap -n velero -l velero.io/plugin-config
kubectl describe configmap -n velero <velero>-fs-restore-action-config
```

Should show: `docker.io/velero/velero-restore-helper:v1.15.1`

### Restore stuck waiting for PVC

The restore waits for PVCs to be bound before restoring data:
```bash
kubectl get pvc -n <target-namespace>
```

If PVC is `Pending`, check:
- StorageClass exists
- PV provisioner is working
- Sufficient storage quota

### Resource already exists errors

When restoring to same namespace with existing resources:
```bash
velero restore create <name> \
  --from-backup <backup> \
  --existing-resource-policy update
```

## Stuck Resources

### Delete stuck backup

If backup is stuck in `Deleting`:
```bash
# Note: Use backups.velero.io to avoid conflict with other backup CRDs
kubectl patch backups.velero.io <backup-name> -n velero \
  --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'

# Or force delete
kubectl delete backups.velero.io <backup-name> -n velero --force --grace-period=0
```

### Delete stuck restore

```bash
kubectl delete restores.velero.io <restore-name> -n velero --force --grace-period=0
```

### Delete stuck namespace

```bash
kubectl get namespace <namespace> -o json | \
  jq '.spec.finalizers = []' | \
  kubectl replace --raw "/api/v1/namespaces/<namespace>/finalize" -f -
```

## Image Pull Issues

OCI/CRI-O clusters may enforce fully qualified image names. All Velero images should use `docker.io/` prefix:

| Component | Image |
|-----------|-------|
| Velero server | `docker.io/velero/velero` |
| Node-agent | `docker.io/velero/velero` |
| AWS plugin | `docker.io/velero/velero-plugin-for-aws` |
| Restore helper | `docker.io/velero/velero-restore-helper` |

## Checking Logs

### Velero server
```bash
kubectl logs -n velero -l app.kubernetes.io/name=velero -f
```

### Node-agent (all nodes)
```bash
kubectl logs -n velero -l name=node-agent --tail=100
```

### Node-agent (specific node)
```bash
kubectl logs -n velero <node-agent-pod-name> --tail=100
```

## Verifying B2 Connectivity

```bash
# Set credentials
export AWS_ACCESS_KEY_ID=$(kubectl get secret velero-b2-credentials -n velero -o jsonpath='{.data.cloud}' | base64 -d | grep aws_access_key_id | cut -d= -f2)
export AWS_SECRET_ACCESS_KEY=$(kubectl get secret velero-b2-credentials -n velero -o jsonpath='{.data.cloud}' | base64 -d | grep aws_secret_access_key | cut -d= -f2)

# List bucket contents
aws s3 ls s3://zem-backups-eu/cluster03-velero/ \
  --endpoint-url=https://s3.eu-central-003.backblazeb2.com

# Check kopia repository files
aws s3 ls s3://zem-backups-eu/cluster03-velero/kopia/ \
  --endpoint-url=https://s3.eu-central-003.backblazeb2.com --recursive | head -20
```

## Resource Conflicts

### MariaDB Backup CRD conflict

If `kubectl get backup` returns MariaDB resources instead of Velero:
```bash
# Use fully qualified resource name
kubectl get backups.velero.io -n velero
kubectl describe backups.velero.io <name> -n velero
```

## Cleanup Orphaned B2 Data

After changing backup location prefix, old data remains in B2:
```bash
# List old data
aws s3 ls s3://zem-backups-eu/<old-prefix>/ \
  --endpoint-url=https://s3.eu-central-003.backblazeb2.com

# Delete (careful!)
aws s3 rm s3://zem-backups-eu/<old-prefix>/ \
  --endpoint-url=https://s3.eu-central-003.backblazeb2.com --recursive
```
