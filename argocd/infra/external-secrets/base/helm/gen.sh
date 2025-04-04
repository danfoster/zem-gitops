#!/bin/bash

set -e

helm repo add external-secrets https://charts.external-secrets.io
helm repo update

cd $(dirname $0)

helm template external-secrets  external-secrets/external-secrets  -f ../values.yaml -n external-secrets  > ../helm-expanded.yaml