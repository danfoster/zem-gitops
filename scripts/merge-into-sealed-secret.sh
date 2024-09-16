#!/bin/bash

set -e 

KEY=$1
VALUE=$2
SEALEDSECRET=$3

echo -n "$VALUE" | kubectl create secret generic mysecret --dry-run=client --from-file="$KEY"=/dev/stdin -o json \
  | kubeseal -o yaml --merge-into "$SEALEDSECRET"