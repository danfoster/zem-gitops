# Bootstrap

Install microk8s

Grab credentials

Install sealedsecrets:

```
k apply -k infra/sealedsecrets/overlays/cluster01
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

