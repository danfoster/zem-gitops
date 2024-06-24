#!/bin/bash -x 

cd $(dirname $0)

if [[ ! -d seaweedfs-csi-driver ]]; then
    git clone https://github.com/seaweedfs/seaweedfs-csi-driver.git
fi

cd seaweedfs-csi-driver
git pull --rebase

helm template seaweedfs ./deploy/helm/seaweedfs-csi-driver -f ../values.yaml -n seaweedfs > ../../seaweedfs.yaml