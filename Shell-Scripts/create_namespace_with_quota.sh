#!/bin/bash

set -e  # Exit immediately if any command fails

# Function to log in to OpenShift
login_to_cluster() {
  read -r -p "Paste the full 'oc login' command (including the token): " LOGIN_COMMAND
  LOGIN_COMMAND=$(echo "$LOGIN_COMMAND" | xargs) # Trim whitespace

  echo "Logging in to the OpenShift cluster..."
  eval "$LOGIN_COMMAND"
  
  echo "Login successful."
}

# Function to create a namespace
create_namespace() {
  read -r -p "Enter desired namespace name: " NAMESPACE
  NAMESPACE=$(echo "$NAMESPACE" | xargs) # Trim whitespace

  if oc get namespace "$NAMESPACE" &>/dev/null; then
    echo "Error: Namespace '$NAMESPACE' already exists. Exiting..."
    exit 1
  fi

  echo "Creating namespace $NAMESPACE..."
  oc create namespace "$NAMESPACE"
  echo "Namespace '$NAMESPACE' created successfully."
}

# Function to set resource quotas
set_resource_quota() {
  read -r -p "Enter total CPU request (e.g., 500m for 0.5 cores): " REQUEST_CPU
  read -r -p "Enter total CPU limit (e.g., 1000m for 1 core): " LIMIT_CPU
  read -r -p "Enter total memory request (e.g., 512Mi): " REQUEST_MEMORY
  read -r -p "Enter total memory limit (e.g., 1Gi): " LIMIT_MEMORY

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

  echo "Resource quotas set successfully."
}

# Function to set LimitRange
set_limit_range() {
  echo "Creating LimitRange for namespace $NAMESPACE..."
  cat <<EOF | oc apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: $NAMESPACE
spec:
  limits:
    - type: Container
      max:
        cpu: "2"  # Maximum CPU per container
        memory: "4Gi"  # Maximum memory per container
      default:
        cpu: "500m"  # Default CPU limit
        memory: "1Gi"  # Default memory limit
      defaultRequest:
        cpu: "250m"  # Default CPU request
        memory: "512Mi"  # Default memory request
EOF

  echo "LimitRange created successfully."
}

# Function to assign admin role to a user
assign_admin_role() {
  read -r -p "Enter email address of the user who will be admin of the namespace: " ADMIN_USER
  ADMIN_USER=$(echo "$ADMIN_USER" | xargs) # Trim whitespace

  echo "Assigning admin role to $ADMIN_USER for namespace $NAMESPACE..."
  oc create rolebinding "${NAMESPACE}-admin" \
    --clusterrole=admin \
    --user="$ADMIN_USER" \
    --namespace="$NAMESPACE"

  echo "Admin role assigned successfully to $ADMIN_USER."
}

# Main script execution
echo "Welcome to the OpenShift Namespace Creator with Quotas and Admin Assignment"
login_to_cluster
create_namespace
set_resource_quota
set_limit_range
assign_admin_role
echo "Namespace, quotas, limit range, and admin assignment configured successfully!"
