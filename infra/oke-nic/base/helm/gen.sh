#!/bin/bash -x

cd $(dirname $0)

if [[ ! -d chart ]]; then
    git clone --single-branch https://github.com/oracle/oci-native-ingress-controller.git chart
fi

cd chart
git pull --rebase

helm template  --include-crds oci-native-ingress-controller helm/oci-native-ingress-controller  -f ../values.yaml -n github-runners > ../../helm-expanded.yaml