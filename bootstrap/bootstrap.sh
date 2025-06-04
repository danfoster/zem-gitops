#!/bin/bash
set -e

render_and_apply() {
  local app="$1"
  local appkey="$2"
  helm template deployments/infra -s templates/${appkey}.namespace.yaml | \
    kubectl apply -f -
  helm dependency build "apps/infra/zem-${app}"
  cat "clusters/${CLUSTER}/infra-new.yaml" | \
    yq ".spec.source.helm.valuesObject.features.${appkey}" -y | \
    helm template "$app"  "apps/infra/zem-${app}" -f - | \
    kubectl delete -f -
}

if [ $# -ne 2 ]; then
  echo "Usage: $0 <cluster> <bitwarden-auth-token>"
  exit 1
fi

CLUSTER="$1"
BW_AUTH_TOKEN="$2"

cd $(dirname $0)/..

# render_and_apply external-secrets externalsecrets
# render_and_apply argocd argocd
# render_and_apply tailscale tailscale

# kubectl apply -f bootstrap/${CLUSTER}.yaml

## Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.17.2 \
  --set crds.enabled=true

## Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets \
   external-secrets/external-secrets \
   -n external-secrets \
   --create-namespace \
   --set bitwarden-sdk-server.enabled=true
helm upgrade --install zem-external-secrets \
  --create-namespace \
  -n external-secrets \
  apps/infra/zem-external-secrets \
  --set-string bitwarden.auth_token="$BW_AUTH_TOKEN"


## Install Tailscale Operator
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm upgrade --install \
  tailscale-operator \
  tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string apiServerProxyConfig.mode=true \
  --set-string operatorConfig.hostname=$CLUSTER \
  --set operatorConfig.defaultTags={"tag:$CLUSTER-operator"} \
  --set proxyConfig.defaultTags="tag:$CLUSTER"
helm upgrade --install zem-tailscale \
  --create-namespace \
  -n tailscale \
  apps/infra/zem-tailscale \
  --set-string oauth.clientIdKey="tailscale-${CLUSTER}-client-id" \
  --set-string oauth.clientSecretKey="tailscale-${CLUSTER}-client-secret"