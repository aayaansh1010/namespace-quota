#!/bin/bash

# Get the current date in dd-mm-yy format
current_date=$(date +'%d-%m-%y')

# Set the output file name with timestamp
output_file="clusterhealthcheck-${current_date}.txt"

# Redirect both stdout and stderr to the output file
exec >> "$output_file" 2>&1

# Function to check cluster and node status
check_cluster_and_node_status() {
  echo "Checking cluster and node status..."

  echo "3. Cluster Version:"
  oc get clusterversion
  echo

  echo "4. Node Status:"
  oc get nodes
  echo

  echo "5. Node Resource Usage:"
  oc adm top nodes
  echo

  echo "6. Cluster Operators:"
  oc get co
  echo

  echo "7. Machine Config Pools:"
  oc get mcp
  echo
}

# Function to check running pods (only system pods)
check_pods_status() {
  echo "Checking pods status..."

  echo "8. Running Pods (openshift/kube only):"
  oc get pods --all-namespaces | grep -iE '^(openshift|kube)-.*Running'
  echo

  echo "9. Count of Running Pods (openshift/kube only):"
  oc get pods --all-namespaces | grep -iE '^(openshift|kube)-.*Running' | wc -l
  echo
}

# Function to check latest cluster-related events (last 20)
check_cluster_events() {
  echo "10. Latest Cluster Events (from openshift/kube namespaces only):"
  for ns in $(oc get ns -o name | grep -E 'openshift|kube'); do
    ns_name="${ns#namespace/}"
    echo "Events in namespace: $ns_name"
    oc get events -n "$ns_name" --sort-by=.lastTimestamp | tail -n 20
    echo
  done
}

# Function to check status of router pods
check_router_pods() {
  echo "11. Router Pods in openshift-ingress Namespace:"
  oc get pods -n openshift-ingress
  echo
}

# Function to find nodes with > 50 pods
check_heavy_nodes() {
  echo "12. Nodes Running More Than 200 Pods:"
  oc get pods --all-namespaces -o wide | awk '{print $8}' | sort | uniq -c | awk '$1 > 200 {print $2, "has", $1, "pods"}'
  echo
}

# Run all checks
check_cluster_and_node_status
check_pods_status
check_cluster_events
check_router_pods
check_heavy_nodes

echo "Cluster pre-post checks have been saved to $output_file"
