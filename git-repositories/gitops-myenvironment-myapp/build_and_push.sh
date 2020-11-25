#!/usr/bin/env bash

set -eux # European Union - Extended mode

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ENV="${1:-dev}"

docker login --username AWS -p "$(aws ecr get-login-password --region eu-west-1)" "232284734723.dkr.ecr.eu-west-1.amazonaws.com"
(
  cd "${DIR}"
  docker build --network host -t "232284734723.dkr.ecr.eu-west-1.amazonaws.com/k8s-dev-my-app:latest" .
  docker push "232284734723.dkr.ecr.eu-west-1.amazonaws.com/k8s-dev-my-app:latest"
)