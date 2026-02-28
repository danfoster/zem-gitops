# Restore Operations

## Restore to Same Namespace

Use this when recovering from data loss in the original namespace.

```bash
velero restore create <restore-name> --from-backup <backup-name>
```

Example:
```bash
velero restore create pce-restore --from-backup pce-backup-20260207
```

## Restore to Different Namespace

Use this for testing or running a copy alongside the original.

```bash
# Create target namespace first
kubectl create namespace <new-namespace>

# Restore with namespace mapping
velero restore create <restore-name> \
  --from-backup <backup-name> \
  --namespace-mappings <original-ns>:<new-ns>
```

Example:
```bash
kubectl create namespace pce-restore-test
velero restore create test-restore \
  --from-backup pce-backup-20260207 \
  --namespace-mappings pce-prod:pce-restore-test
```

## Restore Specific Resources

### Restore only PVCs and their data

```bash
velero restore create pvc-restore \
  --from-backup <backup-name> \
  --include-resources persistentvolumeclaims \
  --restore-volumes=true
```

### Restore specific resource types

```bash
velero restore create partial-restore \
  --from-backup <backup-name> \
  --include-resources deployments,services,configmaps
```

## Monitor Restore Progress

### Check restore status

```bash
velero restore describe <restore-name> --details
```

### Watch PodVolumeRestores

```bash
kubectl get podvolumerestores -n velero
```

### Check restored pods

```bash
kubectl get pods -n <restored-namespace>
```

### View restore logs

```bash
velero restore logs <restore-name>
```

## Restore to Different PVC Name

Velero doesn't natively support renaming resources. Workaround:

### Option 1: Resource Modifiers (Velero 1.14+)

```bash
# Create modifier ConfigMap
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: pvc-rename
  namespace: velero
  labels:
    velero.io/resource-modifier-config: "true"
data:
  pvc-rename.yaml: |
    version: v1
    resourceModifierRules:
    - conditions:
        resourceNameRegex: "^original-pvc-name$"
        groupResource: persistentvolumeclaims
      patches:
      - operation: replace
        path: "/metadata/name"
        value: "new-pvc-name"
EOF

# Restore with modifier
velero restore create renamed-restore \
  --from-backup <backup-name> \
  --resource-modifier-configmap pvc-rename
```

### Option 2: Restore to temp namespace and copy

```bash
# 1. Restore to temp namespace
velero restore create temp-restore \
  --from-backup <backup-name> \
  --namespace-mappings original-ns:temp-ns

# 2. Copy data between PVCs using a pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: data-copy
  namespace: temp-ns
spec:
  containers:
  - name: copy
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: source
      mountPath: /source
  volumes:
  - name: source
    persistentVolumeClaim:
      claimName: <restored-pvc>
EOF

# 3. Tar and pipe to destination
kubectl exec -n temp-ns data-copy -- tar cf - -C /source . | \
  kubectl exec -i -n target-ns <target-pod> -- tar xf - -C /target/path

# 4. Cleanup
kubectl delete namespace temp-ns
```

## ArgoCD Integration

After restoring to the **same namespace**, ArgoCD will adopt the resources:

```bash
argocd app sync <app-name>
```

When restoring to a **different namespace** for testing, the ArgoCD tracking labels still reference the original namespace. To run independently:

```bash
# Remove ArgoCD tracking annotations
for type in deployment service configmap secret pvc ingress; do
  kubectl annotate -n <restored-namespace> $type --all argocd.argoproj.io/tracking-id- 2>/dev/null
done
```

## Cleanup After Testing

```bash
kubectl delete namespace <test-namespace>
velero restore delete <restore-name>
```
