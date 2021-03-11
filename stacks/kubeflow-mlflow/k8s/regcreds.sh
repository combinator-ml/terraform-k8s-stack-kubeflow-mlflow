#!/bin/bash
set -xeuo pipefail
for NS in \
    admin \
    auth \
    cert-manager \
    default \
    istio-operator \
    istio-system \
    kf \
    knative-serving \
    kube-node-lease \
    kube-public \
    kube-system \
    kubeflow \
    kubeflow-operator; do
        kubectl create ns $NS || echo "namespace $NS already existed"
        kubectl patch serviceaccount -n $NS \
            default -p '{"imagePullSecrets": [{"name": "regcred"}]}'
done
