#!/bin/bash

# Fetch all namespaces
NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

# Initialize totals
echo "Cluster Resource Usage (per namespace):"
echo "----------------------------------------"

# Function to convert memory units to MiB
convert_memory_to_mib() {
  local MEMORY=$1
  if [[ $MEMORY == *Ki ]]; then
    echo $(( ${MEMORY%Ki} / 1024 ))
  elif [[ $MEMORY == *Mi ]]; then
    echo ${MEMORY%Mi}
  elif [[ $MEMORY == *Gi ]]; then
    echo $(( ${MEMORY%Gi} * 1024 ))
  else
    echo 0
  fi
}

# Function to convert CPU units to millicores
convert_cpu_to_millicores() {
  local CPU=$1
  if [[ $CPU == *m ]]; then
    echo ${CPU%m}
  elif [[ $CPU =~ ^[0-9]+$ ]]; then
    echo $(( CPU * 1000 ))
  else
    echo 0
  fi
}

# Iterate through each namespace
for NAMESPACE in $NAMESPACES; do
  # Fetch resource data for the namespace
  RESOURCE_DATA=$(kubectl get pods -n "$NAMESPACE" -o json | jq '.items[].spec.containers[] | {requests: .resources.requests, limits: .resources.limits}')
  
  # Initialize namespace totals
  NAMESPACE_REQUEST_CPU=0
  NAMESPACE_REQUEST_MEMORY=0
  NAMESPACE_LIMIT_CPU=0
  NAMESPACE_LIMIT_MEMORY=0
  
  # Process resource data
  while read -r RESOURCE; do
    REQUEST_CPU=$(echo "$RESOURCE" | jq -r '.requests.cpu // "0"')
    REQUEST_MEMORY=$(echo "$RESOURCE" | jq -r '.requests.memory // "0"')
    LIMIT_CPU=$(echo "$RESOURCE" | jq -r '.limits.cpu // "0"')
    LIMIT_MEMORY=$(echo "$RESOURCE" | jq -r '.limits.memory // "0"')

    NAMESPACE_REQUEST_CPU=$(( NAMESPACE_REQUEST_CPU + $(convert_cpu_to_millicores "$REQUEST_CPU") ))
    NAMESPACE_REQUEST_MEMORY=$(( NAMESPACE_REQUEST_MEMORY + $(convert_memory_to_mib "$REQUEST_MEMORY") ))
    NAMESPACE_LIMIT_CPU=$(( NAMESPACE_LIMIT_CPU + $(convert_cpu_to_millicores "$LIMIT_CPU") ))
    NAMESPACE_LIMIT_MEMORY=$(( NAMESPACE_LIMIT_MEMORY + $(convert_memory_to_mib "$LIMIT_MEMORY") ))
  done <<< "$(echo "$RESOURCE_DATA" | jq -c '.')"
  
  # Display the results for the namespace
  echo "Namespace: $NAMESPACE"
  echo "  Total Requested CPU (millicores): $NAMESPACE_REQUEST_CPU"
  echo "  Total Requested Memory (MiB): $NAMESPACE_REQUEST_MEMORY"
  echo "  Total Limit CPU (millicores): $NAMESPACE_LIMIT_CPU"
  echo "  Total Limit Memory (MiB): $NAMESPACE_LIMIT_MEMORY"
  echo "----------------------------------------"
done

