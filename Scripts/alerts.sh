#!/bin/bash

# Output file
OUTPUT_FILE="critical_high_alerts.csv"

# Header for CSV
echo "AlertName,Severity,Namespace,Pod,Instance,Description,StartsAt" > "$OUTPUT_FILE"

# Get token for accessing Prometheus
TOKEN=$(oc -n openshift-monitoring sa get-token prometheus-k8s)

# Get the Prometheus route
PROM_ROUTE=$(oc get route -n openshift-monitoring prometheus-k8s -o jsonpath="{.spec.host}")

# Get all alerts from Prometheus
curl -s -k -H "Authorization: Bearer $TOKEN" "https://$PROM_ROUTE/api/v1/alerts" | jq -r '
  .data.alerts[] |
  select(.labels.severity == "critical" or .labels.severity == "high") |
  [
    .labels.alertname,
    .labels.severity,
    (.labels.namespace // "N/A"),
    (.labels.pod // "N/A"),
    (.labels.instance // "N/A"),
    (.annotations.description // "N/A"),
    .startsAt
  ] | @csv' >> "$OUTPUT_FILE"

echo "Exported critical/high alerts to $OUTPUT_FILE"
