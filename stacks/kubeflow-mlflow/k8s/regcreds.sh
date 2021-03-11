#!/bin/bash
set -euo pipefail
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
        (
            while ! kubectl get ns $NS 2>/dev/null; do
                echo "waiting for ns $NS to be created..."
                sleep 10
            done
            kubectl patch serviceaccount -n $NS \
                default -p '{"imagePullSecrets": [{"name": "regcred"}]}'
        ) &
done
