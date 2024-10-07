#!/usr/bin/env bash

healthcheck() {
  attempt_counter=0
  max_attempts=5
  if [ -n "$2" ]; then
    max_attempts=$2
  fi
  echo "Healthcheck $1 for $max_attempts times"

  until (curl -m 5 --output /dev/null --silent --fail "$1"); do
      if [ -n "$3" ]; then
        docker compose logs --tail 100
      fi

      if [ $attempt_counter -eq $max_attempts ];then
        echo "Max attempts reached"
        exit 1
      fi

      function get_operator_pod_name() {
        kubectl get pods -n compute -o name | grep "operator" | head -n 1
      }

      # Get the operator pod name
      OPERATOR_POD_NAME=$(get_operator_pod_name)
      kubectl get pods -n compute
      kubectl describe $OPERATOR_POD_NAME -n compute
      printf '.'
      attempt_counter=$((attempt_counter+1))
      sleep 5
  done
  echo "Healthcheck $1 succeed."
}
