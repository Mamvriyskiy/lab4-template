#!/usr/bin/env bash

set -e

variant=${1:-${VARIANT}}
deployment=${2:-${DEPLOYMENT_NAME}}
namespace=${3:-${NAMESPACE}}

[[ -z $namespace ]] && namespace="default"

path=$(dirname "$0")

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
  newman run \
    --delay-request=100 \
    --folder=success \
    --export-environment "$variant"/postman/environment.json \
    --environment "$variant"/postman/environment.json \
    "$variant"/postman/collection.json
}

step() {
  local step=$1
  [[ $((step % 2)) -eq 0 ]] && replicas=1 || replicas=0

  printf "=== Step %d: scale %s to %s ===\n" "$step" "$deployment" "$replicas"

  kubectl scale deployment "$deployment" -n "$namespace" --replicas "$replicas" 

  if [[ $replicas -eq 0 ]]; then
    echo "Waiting for bonus service to stop..."
    # Ждем пока pod исчезнет (максимум 30 секунд)
    for i in {1..30}; do
      pod_count=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/instance=bonus --no-headers 2>/dev/null | wc -l)
      if [[ $pod_count -eq 0 ]]; then
        echo "✓ Bonus service stopped"
        break
      fi
      sleep 1
    done
  else
    echo "Waiting for bonus service to start..."
    # Ждем пока pod будет готов (максимум 30 секунд)
    kubectl wait --for=condition=ready pod -n "$namespace" -l app.kubernetes.io/instance=bonus --timeout=30s
    echo "✓ Bonus service started"
  fi
  
  newman run \
    --delay-request=100 \
    --folder=step"$step" \
    --export-environment "$variant"/postman/environment.json \
    --environment "$variant"/postman/environment.json \
    "$variant"/postman/collection.json

  printf "=== Step %d completed ===\n" "$step"
}

start=$(date +%s)
trap 'timed $start' EXIT

printf "=== Start test scenario ===\n"

# success execute
success

# stop service
step 1

# start service
step 2

# stop service
step 3

# start service
step 4