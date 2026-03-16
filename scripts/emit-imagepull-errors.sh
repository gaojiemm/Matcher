#!/usr/bin/env bash

set -euo pipefail

echo "k8s/deployment.yaml:17:18 Failed to pull image 'ghcr.io/example/private-app:missing': rpc error: code = NotFound desc = failed to pull and unpack image"
echo "k8s/deployment.yaml:17:18 ErrImagePull: pull access denied or repository does not exist"
echo "k8s/deployment.yaml:17:18 ImagePullBackOff: back-off pulling image 'ghcr.io/example/private-app:missing'"