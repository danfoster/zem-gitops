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

ssh -T $NODENAME  bash << SSH
    #!/bin/bash
    set -e

    sudo mkdir -p /var/snap/microk8s/common/
    sudo tee /var/snap/microk8s/common/.microk8s.yaml > /dev/null << EOF 
---
version: 0.1.0
extraCNIEnv:
IPv4_SUPPORT: true
IPv4_CLUSTER_CIDR: 10.3.0.0/16
IPv4_SERVICE_CIDR: 10.153.183.0/24
IPv6_SUPPORT: true
IPv6_CLUSTER_CIDR: fd02::/64
IPv6_SERVICE_CIDR: fd99::/64
extraSANs:
- c01.zem.org.uk

EOF

    sudo snap install microk8s --classic --channel=1.28/stable
    sudo microk8s enable  metrics-server

    echo "Config:"
    sudo microk8s config
SSH

