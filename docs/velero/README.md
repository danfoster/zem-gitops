# Velero Backup and Restore

Velero provides backup and restore capabilities for Kubernetes clusters using file-system backups to Backblaze B2.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  velero namespace                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Velero       │  │ Credentials  │  │ BackupStorageLocation│  │
│  │ Server       │  │ (B2)         │  │ (B2 bucket)          │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Node-Agent DaemonSet (runs on each node)                 │  │
│  │ - Reads PVC data via hostPath                            │  │
│  │ - Performs kopia file-system backups                     │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │
         │ hostPath access to /var/lib/kubelet/pods
         ▼
┌─────────────────────┐    ┌─────────────────────┐
│  app-namespace-a    │    │  app-namespace-b    │
│  ┌───────────────┐  │    │  ┌───────────────┐  │
│  │ PVC data      │  │    │  │ PVC data      │  │
│  └───────────────┘  │    └───────────────────┘  │
└─────────────────────┘    └─────────────────────┘
```

## Key Components

| Component | Purpose |
|-----------|---------|
| Velero Server | Manages backup/restore operations |
| Node-Agent | DaemonSet that reads PVC data via hostPath |
| BackupStorageLocation | B2 bucket configuration |
| Kopia | File-system backup tool (built into Velero) |

## Storage

- **Bucket**: `zem-backups-eu`
- **Prefix**: `<cluster-name>-velero` (e.g., `cluster03-velero`)
- **Endpoint**: `s3.eu-central-003.backblazeb2.com`

## Secrets

| Secret | Purpose | Source |
|--------|---------|--------|
| `velero-b2-credentials` | B2 access keys | ExternalSecret from Bitwarden |
| `velero-repo-credentials` | Kopia repository encryption password | ExternalSecret from Bitwarden |

## Runbooks

- [Backup Operations](./backup-operations.md)
- [Restore Operations](./restore-operations.md)
- [Disaster Recovery](./disaster-recovery.md)
- [Troubleshooting](./troubleshooting.md)

## Scheduled Backups

Daily backups run at 02:00 UTC with 30-day retention. Excludes system namespaces (`kube-system`, `kube-public`, `kube-node-lease`, `velero`).
