#!/bin/bash
# submariner-auto-recover.sh
# Automated recovery script for Submariner connectivity issues

set -euo pipefail

KUBECONFIG_EU="/home/tolfx/.kube/node01-udl-tf.yaml"
KUBECONFIG_NA="/home/tolfx/.kube/na-va-01.udl.tf.yaml"

echo "[$(date)] Starting Submariner health check..."

# Function to check connection status
check_connections() {
    local kubeconfig=$1
    local cluster_name=$2
    
    echo "Checking connections from $cluster_name..."
    if ! subctl show connections --kubeconfig "$kubeconfig" | grep -q "connected"; then
        echo "❌ Connection issues detected in $cluster_name"
        return 1
    else
        echo "✅ Connections healthy in $cluster_name"
        return 0
    fi
}

# Function to restart Submariner components
restart_submariner() {
    local kubeconfig=$1
    local cluster_name=$2
    
    echo "🔄 Restarting Submariner components in $cluster_name..."
    kubectl --kubeconfig="$kubeconfig" -n submariner-operator delete pods --all
}

# Function to wait for pods to be ready
wait_for_ready() {
    local kubeconfig=$1
    local cluster_name=$2
    
    echo "⏳ Waiting for Submariner pods to be ready in $cluster_name..."
    kubectl --kubeconfig="$kubeconfig" -n submariner-operator wait --for=condition=Ready pods --all --timeout=300s
}

# Main health check and recovery logic
recovery_needed=false

# Check both clusters
if ! check_connections "$KUBECONFIG_EU" "eu-de-01"; then
    recovery_needed=true
fi

if ! check_connections "$KUBECONFIG_NA" "na-va-01"; then
    recovery_needed=true
fi

# If issues detected, perform recovery
if [ "$recovery_needed" = true ]; then
    echo "🚨 Issues detected, starting recovery process..."
    
    # Restart components in both clusters
    restart_submariner "$KUBECONFIG_EU" "eu-de-01" &
    restart_submariner "$KUBECONFIG_NA" "na-va-01" &
    wait
    
    # Wait for pods to be ready
    wait_for_ready "$KUBECONFIG_EU" "eu-de-01" &
    wait_for_ready "$KUBECONFIG_NA" "na-va-01" &
    wait
    
    # Verify recovery
    sleep 30  # Allow time for connections to establish
    
    if check_connections "$KUBECONFIG_EU" "eu-de-01" && check_connections "$KUBECONFIG_NA" "na-va-01"; then
        echo "✅ Recovery successful!"
        exit 0
    else
        echo "❌ Recovery failed! Manual intervention required"
        exit 1
    fi
else
    echo "✅ All connections healthy"
    exit 0
fi