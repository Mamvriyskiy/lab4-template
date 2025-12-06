#!/usr/bin/env bash

set -e
set -o pipefail
set -x  # Включаем трассировку для GitHub Actions

variant=${1:-${VARIANT}}
deployment=${2:-${DEPLOYMENT_NAME}}
namespace=${3:-${NAMESPACE}}

[[ -z $namespace ]] && namespace="default"

timed() {
  end=$(date +%s)
  dt=$(($end - $1))
  dd=$(($dt / 86400))
  dt2=$(($dt - 86400 * $dd))
  dh=$(($dt2 / 3600))
  dt3=$(($dt2 - 3600 * $dh))
  dm=$(($dt3 / 60))
  ds=$(($dt3 - 60 * $dm))
  LC_NUMERIC=C printf "\nTotal runtime: %02d min %02d seconds\n" "$dm" "$ds"
}

success() {
  echo "=== Running success scenario ===" >&2
  newman run \
    --delay-request=100 \
    --folder=success \
    --export-environment "$variant"/postman/environment.json \
    --environment "$variant"/postman/environment.json \
    "$variant"/postman/collection.json
  echo "=== Success scenario completed ===" >&2
}

step() {
  local step_num=$1
  local replicas
  if [[ $((step_num % 2)) -eq 0 ]]; then
    replicas=1
  else
    replicas=0
  fi

  echo "=== Step $step_num: Scaling deployment '$deployment' in namespace '$namespace' to $replicas replicas ===" >&2

  kubectl scale deployment "$deployment" -n "$namespace" --replicas="$replicas"

  # Ждём состояния pod перед запуском теста
  if [[ $replicas -eq 1 ]]; then
    echo "Waiting for deployment '$deployment' to become available..."
    kubectl wait --for=condition=available deployment "$deployment" -n "$namespace" --timeout=90s
  else
    echo "Waiting for pods of deployment '$deployment' to be deleted..."
    kubectl wait --for=delete pod -l app.kubernetes.io/name="$deployment" -n "$namespace" --timeout=90s || true
  fi

  echo "=== Step $step_num: Running Newman tests ===" >&2
  newman run \
    --delay-request=100 \
    --folder=step"$step_num" \
    --export-environment "$variant"/postman/environment.json \
    --environment "$variant"/postman/environment.json \
    "$variant"/postman/collection.json

  echo "=== Step $step_num completed ===" >&2
}

start=$(date +%s)
trap 'timed $start' EXIT

echo "=== Start test scenario ===" >&2

# Выполнение успешного сценария
success

# Чередуем остановку и запуск сервиса
step 1
step 2
step 3
step 4
