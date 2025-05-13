#!/bin/bash
# Get the current date in dd-mm-yy format
current_date=$(date +'%d-%m-%y')

# Set the output file name
output_file="${current_date}_cluster_pre-postchecks.txt"

# Function to check cluster and node status
check_cluster_and_node_status() {
  echo "Checking cluster and node status..." >> "$output_file"

  # Get cluster version
  echo "3. Cluster Version:" >> "$output_file"
  oc get clusterversion >> "$output_file"
  echo >> "$output_file"

  # Get node status
  echo "4. Node Status:" >> "$output_file"
  oc get nodes >> "$output_file"
  echo >> "$output_file"

  # Get node resource usage
  echo "5. Node Resource Usage:" >> "$output_file"
  oc adm top nodes >> "$output_file"
  echo >> "$output_file"

  # Get cluster operators
  echo "6. Cluster Operators:" >> "$output_file"
  oc get co >> "$output_file"
  echo >> "$output_file"

  # Get machine config pools
  echo "7. Machine Config Pools:" >> "$output_file"
  oc get mcp >> "$output_file"
  echo >> "$output_file"
}

# Function to check running pods and their count
check_pods_status() {
  echo "Checking pods status..." >> "$output_file"

  # Get all running pods
  echo "8. Running Pods:" >> "$output_file"
  oc get pods --all-namespaces | grep -i Running >> "$output_file"
  echo >> "$output_file"

  # Count all running pods
  echo "9. Count of Running Pods:" >> "$output_file"
  oc get pods --all-namespaces | grep -i Running | wc -l >> "$output_file"
  echo >> "$output_file"
}

# Function to get deprecated APIs and query their usage
check_deprecated_apis() {
  echo "Checking deprecated APIs..." >> "$output_file"

  # Get list of deprecated APIs
  deprecated_apis=$(oc get apirequestcounts -o jsonpath='{range .items[?(@.status.removedInRelease!="")]}{.status.removedInRelease}{"\t"}{.metadata.name}{"\n"}{end}')
  echo "10. Deprecated APIs:" >> "$output_file"
  echo "$deprecated_apis" >> "$output_file"
  echo >> "$output_file"

  # Query usage of each deprecated API
  echo "11. Deprecated API Usage:" >> "$output_file"
  while read -r line; do
    api_name=$(echo "$line" | awk '{print $2}')
    echo "Usage of deprecated API: $api_name" >> "$output_file"
    oc get apirequestcounts $api_name -o jsonpath='{range .status.currentHour.byUser[*]}{.byVerb[*].verb}{","}{.username}{","}{.userAgent}{"\n"}{end}' >> "$output_file"
    echo >> "$output_file"
  done <<< "$deprecated_apis"
}

# Run all checks and save the output to the file
check_backup_status
check_cluster_and_node_status
check_pods_status
check_deprecated_apis

echo "Cluster pre-post checks have been saved to $output_file"
