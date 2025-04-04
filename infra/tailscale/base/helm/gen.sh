#!/bin/bash

set -e

helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update

cd $(dirname $0)

helm template tailscale-operator  tailscale/tailscale-operator -n tailscale -f ./values.yaml  > ../helm-expanded.yaml