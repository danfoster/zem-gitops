# zem-gitops Project

## Repository Structure

This is a GitOps repository managed by ArgoCD for deploying infrastructure across multiple Kubernetes clusters.

### Key Directories

- `apps/infra/zem-<name>/` - Helm chart wrappers for infrastructure tools (each has Chart.yaml, values.yaml, templates/)
- `deployments/infra/` - App-of-apps pattern: values.yaml defines all features, templates/application.yaml generates ArgoCD Applications
- `clusters/<cluster-name>/` - Per-cluster configuration (infra.yaml, projects/, gitops.project.yaml)
- `projects/` - Application workloads (e.g., zem-collab, zem-external)

### Clusters

- **cluster01** - On-prem, uses OpenEBS/ZFS, MetalLB, Longhorn
- **cluster02** - Hosts zem-external and zem-internal projects
- **cluster03** - OCI (Oracle Cloud), uses OCI Block Storage, OCI NLB, Longhorn (disabled currently)

### How Infra Features Work

1. **Define feature** in `deployments/infra/values.yaml` under `features:` with `enabled: false` (default disabled)
2. **Each feature** has: `enabled`, `namespace`, `source` (repoURL + path or chart), optional `values`
3. **Template** at `deployments/infra/templates/application.yaml` iterates features and creates ArgoCD Applications
4. **Per-cluster overrides** in `clusters/<name>/infra.yaml` enable features and provide cluster-specific values
5. **Common values** (like cluster name) are set in `common.values` and merged with feature values

### Adding a New Infra Tool

1. Create `apps/infra/zem-<name>/Chart.yaml` (wrapper chart with dependency)
2. Create `apps/infra/zem-<name>/values.yaml` (pass-through config)
3. Add feature entry to `deployments/infra/values.yaml` (disabled by default)
4. Enable in target cluster's `clusters/<cluster>/infra.yaml`

### Source Patterns

- **Wrapper chart** (most common): `source.path: apps/infra/zem-<name>` with Chart.yaml listing upstream dependency
- **Direct chart** (simpler tools): `source.repoURL: <helm-repo>`, `source.chart: <name>`, `source.targetRevision: <version>`

### Secrets Management

- External Secrets Operator pulls from Bitwarden vault
- Secret store configured in `apps/infra/zem-external-secrets/`
- ExternalSecret CRDs reference `remoteRefKey` for vault items

### Onboarding a New Project

Run `scripts/create-project.sh <cluster> <namespace>` to provision backup credentials for a new project namespace. This creates OCI users, IAM policies, B2 keys, and stores credentials in OCI Vault. The script outputs YAML snippets to add to git (cluster infra.yaml and project config).

See also: `scripts/setup-oci-vault-clustersecretstore.sh <cluster>` — one-time per-cluster setup for the `oci-vault` ClusterSecretStore.

### Backup Infrastructure

- **K8up** (current): Restic-based, backs up to Backblaze B2 (`zem-backups-eu` bucket)
- **Velero** (being added): For OCI clusters, CSI snapshots + file backups to B2
- B2 credentials via ExternalSecrets from OCI Vault (two-tier model: `oci-vault` ClusterSecretStore distributes OCI API keys, per-namespace SecretStores pull backup secrets)

### Git Remote

- Repo URL used in sources: `https://github.com/danfoster/zem-gitops`
- Default branch: `main`
- ArgoCD namespace: `argocd`
