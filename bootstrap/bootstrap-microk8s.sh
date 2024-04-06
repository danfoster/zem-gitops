#!/bin/bash


usage() {
    echo "$0 HOSTNAME"
    echo
    echo "$0 is used for bootstrapping microk8s clusters. SSH access is required"
}

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

NODENAME=$1
TMP=$(mktemp -d)

echo $TMP
ssh $NODENAME sudo microk8s config > $TMP/remote.config
ssh $NODENAME sudo microk8s enable  metrics-server
