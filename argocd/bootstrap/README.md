
# OCI Auth

```
oci session authenticate
```

# Config file

```
oci ce cluster create-kubeconfig --cluster-id ocid1.cluster.oc1.uk-london-1.aaaaaaaa7lqhsglvpski4m6i5dbmtatrckwrhwuby55ps5esvcnzils5lc2q --file $HOME/.kube/config-zem-oci-prod  --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT
```

# Bootstrap

Install microk8s

Grab credentials

Install sealedsecrets:

```
k apply -k infra/sealedsecrets/overlays/cluster01
```

Install MetalLB:

```
k apply -k infra/metallb/overlays/cluster01
```


Install argocd, by running this. You might have to run it twice if you get an error:

```
k apply -k infra/argo/overlays/cluster01
```

Change `cluster01` to your cluster.

Get the initial password:
```
k get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

# From vanilla k8s to running ArgoCD


Install cert-manager:
```
kubectl apply -k infra/cert-manager/overlays/cluster03
```

Install external-secrets:
```
kubectl apply -k infra/external-secrets/overlays/cluster03
```

You'll need to manually supply the bitwarden auth token, see bitwarden-token.yaml.example