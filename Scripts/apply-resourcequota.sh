#!/bin/bash

# Define target namespaces
TARGET_NAMESPACES=("mas-vccqa-core" "mas-vccqa-manage" "maximo-nfs-provisioner" "maximo-qa" "mongoce")

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

# Iterate through each target namespace
for NAMESPACE in "${TARGET_NAMESPACES[@]}"; do
  echo "Processing namespace: $NAMESPACE"

  # Fetch actual CPU and memory usage
  POD_USAGE=$(kubectl top pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")

  # Skip if no pods exist
  if [[ -z "$POD_USAGE" ]]; then
    echo "No pods found in $NAMESPACE, skipping..."
    continue
  fi

  # Initialize actual usage totals
  TOTAL_ACTUAL_CPU=0
  TOTAL_ACTUAL_MEMORY=0

  # Process actual usage from kubectl top pods
  while read -r POD CPU MEM; do
    ACTUAL_CPU=$(convert_cpu_to_millicores "$CPU")
    ACTUAL_MEMORY=$(convert_memory_to_mib "$MEM")

    TOTAL_ACTUAL_CPU=$(( TOTAL_ACTUAL_CPU + ACTUAL_CPU ))
    TOTAL_ACTUAL_MEMORY=$(( TOTAL_ACTUAL_MEMORY + ACTUAL_MEMORY ))
  done <<< "$POD_USAGE"

  # Apply a 40% buffer
  QUOTA_CPU=$(( TOTAL_ACTUAL_CPU * 140 / 100 ))
  QUOTA_MEMORY=$(( TOTAL_ACTUAL_MEMORY * 140 / 100 ))

  # Convert CPU back to cores (1 core = 1000 millicores)
  QUOTA_CPU_CORES=$(( QUOTA_CPU / 1000 )).$(( QUOTA_CPU % 1000 ))

  # Generate ResourceQuota YAML
  cat <<EOF > "/tmp/${NAMESPACE}-resource-quota.yaml"
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${NAMESPACE}-quota
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: "${QUOTA_CPU_CORES}"
    requests.memory: "${QUOTA_MEMORY}Mi"
    limits.cpu: "${QUOTA_CPU_CORES}"
    limits.memory: "${QUOTA_MEMORY}Mi"
EOF

  # Apply the quota to the namespace
  kubectl apply -f "/tmp/${NAMESPACE}-resource-quota.yaml"

  echo "Applied quota for namespace $NAMESPACE: CPU=${QUOTA_CPU_CORES} cores, Memory=${QUOTA_MEMORY}Mi"
  echo "------------------------------------------------------"
done

echo "All quotas applied successfully!"
