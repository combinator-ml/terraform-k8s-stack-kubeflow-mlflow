#!/bin/bash
set -euo pipefail
IP=$(grep "##EXTERNAL_IP=" "$KUBECONFIG" |cut -d '=' -f 2-)
PORT=$(grep "##SSH_FORWARDED_PORT=" "$KUBECONFIG" |cut -d '=' -f 2-)
grep "##PRIVATE_KEY_ONELINER=" "$KUBECONFIG" |cut -d '=' -f 2- |base64 -d > id_rsa
chmod 0600 id_rsa
# SOCKS proxy, but doesn't seem to work.
#exec ssh -D 9999 -i id_rsa -p "$PORT" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$IP" "$@"
exec ssh -i id_rsa -p "$PORT" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@"$IP" "$@"
