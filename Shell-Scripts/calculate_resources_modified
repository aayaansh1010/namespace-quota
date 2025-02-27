#!/bin/bash

# Output CSV file
OUTPUT_FILE="namespace_resource_usage.csv"

# Write the CSV header
echo "Namespace,Requested CPU (millicores),Requested Memory (MiB),Limit CPU (millicores),Limit Memory (MiB),Actual CPU (millicores),Actual Memory (MiB)" > "$OUTPUT_FILE"

# Fetch all namespaces
NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

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
  # Fetch pod resource data
  RESOURCE_DATA=$(kubectl get pods -n "$NAMESPACE" -o json | jq -c '[.items[].spec.containers[] | {requests: .resources.requests, limits: .resources.limits}]')

  # Fetch actual CPU and memory usage
  POD_USAGE=$(kubectl top pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")

  # Skip empty namespaces
  if [[ -z "$RESOURCE_DATA" || "$RESOURCE_DATA" == "[]" ]]; then
    continue
  fi

  # Initialize namespace totals
  NAMESPACE_REQUEST_CPU=0
  NAMESPACE_REQUEST_MEMORY=0
  NAMESPACE_LIMIT_CPU=0
  NAMESPACE_LIMIT_MEMORY=0
  NAMESPACE_ACTUAL_CPU=0
  NAMESPACE_ACTUAL_MEMORY=0

  # Process resource data using jq
  while IFS= read -r RESOURCE; do
    REQUEST_CPU=$(echo "$RESOURCE" | jq -r '.requests.cpu // "0"')
    REQUEST_MEMORY=$(echo "$RESOURCE" | jq -r '.requests.memory // "0"')
    LIMIT_CPU=$(echo "$RESOURCE" | jq -r '.limits.cpu // "0"')
    LIMIT_MEMORY=$(echo "$RESOURCE" | jq -r '.limits.memory // "0"')

    NAMESPACE_REQUEST_CPU=$(( NAMESPACE_REQUEST_CPU + $(convert_cpu_to_millicores "$REQUEST_CPU") ))
    NAMESPACE_REQUEST_MEMORY=$(( NAMESPACE_REQUEST_MEMORY + $(convert_memory_to_mib "$REQUEST_MEMORY") ))
    NAMESPACE_LIMIT_CPU=$(( NAMESPACE_LIMIT_CPU + $(convert_cpu_to_millicores "$LIMIT_CPU") ))
    NAMESPACE_LIMIT_MEMORY=$(( NAMESPACE_LIMIT_MEMORY + $(convert_memory_to_mib "$LIMIT_MEMORY") ))
  done <<< "$(echo "$RESOURCE_DATA" | jq -c '.[]')"

  # Process actual usage from kubectl top pods
  while read -r POD CPU MEM; do
    ACTUAL_CPU=$(convert_cpu_to_millicores "$CPU")
    ACTUAL_MEMORY=$(convert_memory_to_mib "$MEM")

    NAMESPACE_ACTUAL_CPU=$(( NAMESPACE_ACTUAL_CPU + ACTUAL_CPU ))
    NAMESPACE_ACTUAL_MEMORY=$(( NAMESPACE_ACTUAL_MEMORY + ACTUAL_MEMORY ))
  done <<< "$POD_USAGE"

  # Append results to CSV file
  echo "$NAMESPACE,$NAMESPACE_REQUEST_CPU,$NAMESPACE_REQUEST_MEMORY,$NAMESPACE_LIMIT_CPU,$NAMESPACE_LIMIT_MEMORY,$NAMESPACE_ACTUAL_CPU,$NAMESPACE_ACTUAL_MEMORY" >> "$OUTPUT_FILE"
done

# Display completion message
echo "Resource usage data saved to $OUTPUT_FILE"
