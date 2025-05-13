#!/bin/bash

# OpenShift namespace to check
NAMESPACE="xps-app982"

# Prometheus route
PROMETHEUS_URL=$(oc get route prometheus-k8s -n openshift-monitoring --no-headers -o jsonpath='{.spec.host}')
PROMQL_QUERY="kube_daemonset_metadata_generation"

# Get OpenShift login token
TOKEN=$(oc whoami -t)

# Check if OpenShift login token is available
if [[ -z "$TOKEN" ]]; then
    echo "Error: Unable to get OpenShift token. Please login using 'oc login'."
    exit 1
fi

# Function to fetch pod statuses
function check_pod_status {
    echo -e "\nPod Status in Namespace: $NAMESPACE"
    echo "------------------------------------"
    echo -e "Pod Name\t\tStatus"

    oc get pods -n $NAMESPACE --no-headers -o custom-columns=":metadata.name,:status.phase"
}

# Function to fetch Prometheus metric
function fetch_prometheus_metric {
    echo -e "\nFetching $PROMQL_QUERY metric...\n"

    RESPONSE=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
        "https://$PROMETHEUS_URL/api/v1/query?query=$PROMQL_QUERY")

    # Extract and format results
    echo -e "DaemonSet\t\tNamespace\tGeneration"
    echo "------------------------------------------------"

    echo "$RESPONSE" | jq -r '.data.result[] | [.metric.daemonset, .metric.namespace, .value[1]] | @tsv' | column -t
}

# Run functions
check_pod_status
fetch_prometheus_metric
