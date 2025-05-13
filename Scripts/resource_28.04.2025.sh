#!/bin/bash

# Output CSV file
OUTPUT_FILE="deployment_resource_usage.csv"

# Write CSV header
echo "Namespace,Deployment,Requested CPU (millicores),Requested Memory (MiB),Limit CPU (millicores),Limit Memory (MiB),Actual CPU Usage (millicores),Actual Memory Usage (MiB)" > "$OUTPUT_FILE"

# Function to convert memory units to MiB
convert_memory_to_mib() {
  local MEMORY=$1
  if [[ $MEMORY == *Ki ]]; then
    echo $(( ${MEMORY%Ki} / 1024 ))
  elif [[ $MEMORY == *Mi ]]; then
    echo ${MEMORY%Mi}
  elif [[ $MEMORY == *Gi ]]; then
    echo $(( ${MEMORY%Gi} * 1024 ))
  elif [[ $MEMORY == *Ti ]]; then
    echo $(( ${MEMORY%Ti} * 1024 * 1024 ))
  else
    echo 0
  fi
}

# Function to convert CPU units to millicores
convert_cpu_to_millicores() {
  local CPU=$1
  if [[ $CPU == *n ]]; then
    echo $(( ${CPU%n} / 1000000 ))
  elif [[ $CPU == *u ]]; then
    echo $(( ${CPU%u} / 1000 ))
  elif [[ $CPU == *m ]]; then
    echo ${CPU%m}
  elif [[ $CPU =~ ^[0-9]+$ ]]; then
    echo $(( CPU * 1000 ))
  else
    echo 0
  fi
}

# Fetch all namespaces excluding system ones
NAMESPACES=$(kubectl get namespaces --no-headers | awk '{print $1}' | grep -vE '^(openshift|kube|default)')

echo "Generating CSV report... please wait..."

for NAMESPACE in $NAMESPACES; do
  # Get all pods in the namespace
  PODS_JSON=$(kubectl get pods -n "$NAMESPACE" -o json)

  # Get pod metrics
  POD_METRICS=$(kubectl top pods -n "$NAMESPACE" --no-headers 2>/dev/null || true)

  # Map Deployment -> list of pods
  DEPLOYMENTS=$(echo "$PODS_JSON" | jq -r '.items[] | select(.metadata.ownerReferences != null) | .metadata.ownerReferences[] | select(.kind == "ReplicaSet") | .name' | sed 's/-[a-z0-9]\{10\}$//' | sort | uniq)

  for DEPLOYMENT in $DEPLOYMENTS; do
    # Initialize totals
    REQUEST_CPU=0
    REQUEST_MEMORY=0
    LIMIT_CPU=0
    LIMIT_MEMORY=0
    UTILIZATION_CPU=0
    UTILIZATION_MEMORY=0

    # Get pods belonging to this deployment
    DEPLOYMENT_PODS=$(echo "$PODS_JSON" | jq -r --arg DEPLOYMENT "$DEPLOYMENT" '.items[] | select(.metadata.ownerReferences != null) | select([.metadata.ownerReferences[].name | startswith($DEPLOYMENT)] | any) | .metadata.name')

    for POD in $DEPLOYMENT_PODS; do
      # Get container resources
      CONTAINERS=$(echo "$PODS_JSON" | jq --arg POD "$POD" -c '.items[] | select(.metadata.name == $POD) | .spec.containers[]')
      while read -r CONTAINER; do
        REQ_CPU=$(echo "$CONTAINER" | jq -r '.resources.requests.cpu // "0"')
        REQ_MEM=$(echo "$CONTAINER" | jq -r '.resources.requests.memory // "0"')
        LIM_CPU=$(echo "$CONTAINER" | jq -r '.resources.limits.cpu // "0"')
        LIM_MEM=$(echo "$CONTAINER" | jq -r '.resources.limits.memory // "0"')

        REQUEST_CPU=$(( REQUEST_CPU + $(convert_cpu_to_millicores "$REQ_CPU") ))
        REQUEST_MEMORY=$(( REQUEST_MEMORY + $(convert_memory_to_mib "$REQ_MEM") ))
        LIMIT_CPU=$(( LIMIT_CPU + $(convert_cpu_to_millicores "$LIM_CPU") ))
        LIMIT_MEMORY=$(( LIMIT_MEMORY + $(convert_memory_to_mib "$LIM_MEM") ))
      done <<< "$(echo "$CONTAINERS" | jq -c '.')"

      # Get utilization
      POD_METRIC_LINE=$(echo "$POD_METRICS" | grep "^$POD " || true)
      if [[ -n "$POD_METRIC_LINE" ]]; then
        POD_CPU=$(echo "$POD_METRIC_LINE" | awk '{print $2}')
        POD_MEM=$(echo "$POD_METRIC_LINE" | awk '{print $3}')

        UTILIZATION_CPU=$(( UTILIZATION_CPU + $(convert_cpu_to_millicores "$POD_CPU") ))
        UTILIZATION_MEMORY=$(( UTILIZATION_MEMORY + $(convert_memory_to_mib "$POD_MEM") ))
      fi
    done

    # Write to CSV
    echo "$NAMESPACE,$DEPLOYMENT,$REQUEST_CPU,$REQUEST_MEMORY,$LIMIT_CPU,$LIMIT_MEMORY,$UTILIZATION_CPU,$UTILIZATION_MEMORY" >> "$OUTPUT_FILE"
  done
done

echo "✅ CSV report generated: $OUTPUT_FILE"
