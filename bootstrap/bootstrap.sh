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
    helm template "$app" "apps/infra/zem-${app}" -f - | \
    kubectl apply -f -
}

if [ $# -ne 1 ]; then
  echo "Usage: $0 <cluster>"
  exit 1
fi

CLUSTER="$1"

cd $(dirname $0)/..

# render_and_apply external-secrets externalsecrets
# render_and_apply argocd argocd
render_and_apply tailscale tailscale

kubectl apply -f bootstrap/${CLUSTER}.yaml