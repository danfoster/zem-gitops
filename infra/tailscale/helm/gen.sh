#!/bin/bash

set -e

helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update

cd $(dirname $0)

for i in ../overlays/*; do
  if [ -d "$i" ]; then
    echo "Processing $i"
    helm template tailscale-operator  tailscale/tailscale-operator -n tailscale -f ./values.yaml -f $i/values.yaml  > $i/helm-expanded.yaml
  fi
done

