# Backup Operations

## Ad-hoc Backup

### Backup a specific namespace

```bash
velero backup create <backup-name> --include-namespaces=<namespace>
```

Example:
```bash
velero backup create pce-backup-$(date +%Y%m%d) --include-namespaces=pce-prod
```

### Backup multiple namespaces

```bash
velero backup create <backup-name> --include-namespaces=ns1,ns2,ns3
```

### Backup all namespaces (excluding system)

```bash
velero backup create full-backup-$(date +%Y%m%d) \
  --exclude-namespaces=kube-system,kube-public,kube-node-lease,velero
```

## Monitor Backup Progress

### Check backup status

```bash
velero backup get
```

### Detailed backup info

```bash
velero backup describe <backup-name> --details
```

### View backup logs

```bash
velero backup logs <backup-name>
```

### Watch PodVolumeBackups (file-system backups)

```bash
kubectl get podvolumebackups -n velero
```

## Verify Backup

### Check backup location is healthy

```bash
velero backup-location get
```

Expected output:
```
NAME         PROVIDER   BUCKET/PREFIX                    PHASE       LAST VALIDATED   ACCESS MODE   DEFAULT
b2-default   aws        zem-backups-eu/cluster03-velero  Available   <timestamp>      ReadWrite     true
```

### List contents in B2

```bash
# Set credentials
export AWS_ACCESS_KEY_ID=$(kubectl get secret velero-b2-credentials -n velero -o jsonpath='{.data.cloud}' | base64 -d | grep aws_access_key_id | cut -d= -f2)
export AWS_SECRET_ACCESS_KEY=$(kubectl get secret velero-b2-credentials -n velero -o jsonpath='{.data.cloud}' | base64 -d | grep aws_secret_access_key | cut -d= -f2)

# List backups in B2
aws s3 ls s3://zem-backups-eu/cluster03-velero/ \
  --endpoint-url=https://s3.eu-central-003.backblazeb2.com
```

## Delete Backup

```bash
velero backup delete <backup-name>
```

Note: This deletes both the Velero backup object and the data in B2.

## How Kopia Deduplication Works

Kopia uses content-defined chunking with deduplication:

1. Files are split into variable-size chunks based on content
2. Each chunk is hashed and stored only once
3. Subsequent backups only upload new/changed chunks

This means incremental backups are efficient - if 100MB changes in a 10GB volume, only ~100MB is uploaded.
