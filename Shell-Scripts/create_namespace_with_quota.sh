#!/bin/bash

# Function to log in to OpenShift
login_to_cluster() {
  read -p "Paste the full 'oc login' command (including the token): " LOGIN_COMMAND
  echo "Logging in to the OpenShift cluster..."
  
  # Execute the provided login command
  eval "$LOGIN_COMMAND"
  
  if [ $? -ne 0 ]; then
    echo "Login failed. Please check your command and try again."
    exit 1
  fi
  echo "Login successful."
}

# Function to create a namespace
create_namespace() {
  read -p "Enter desired namespace name: " NAMESPACE
  echo "Creating namespace $NAMESPACE..."
  oc create namespace "$NAMESPACE"
  if [ $? -ne 0 ]; then
    echo "Failed to create namespace. It might already exist."
    exit 1
  fi
  echo "Namespace $NAMESPACE created successfully."
}

# Function to set resource quotas
set_resource_quota() {
  read -p "Enter total CPU request (e.g., 500m for 0.5 cores): " REQUEST_CPU
  read -p "Enter total CPU limit (e.g., 1000m for 1 core): " LIMIT_CPU
  read -p "Enter total memory request (e.g., 512Mi): " REQUEST_MEMORY
  read -p "Enter total memory limit (e.g., 1Gi): " LIMIT_MEMORY
  
  echo "Setting resource quotas for namespace $NAMESPACE..."
  cat <<EOF | oc apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: $REQUEST_CPU
    limits.cpu: $LIMIT_CPU
    requests.memory: $REQUEST_MEMORY
    limits.memory: $LIMIT_MEMORY
EOF

  if [ $? -eq 0 ]; then
    echo "Resource quotas set successfully."
  else
    echo "Failed to set resource quotas."
    exit 1
  fi
}

# Main script execution
echo "Welcome to the OpenShift Namespace Creator with Quotas"
login_to_cluster
create_namespace
set_resource_quota
echo "Namespace and quotas configured successfully!"

