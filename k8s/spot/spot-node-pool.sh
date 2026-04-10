#!/usr/bin/env bash
# ============================================================
# AKS Spot Node Pool Setup for AppraisalCopilot
# Adds a spot instance node pool to an existing AKS cluster
# to reduce compute costs by up to 80%.
# ============================================================
set -euo pipefail

# ---- Configuration (override via environment variables) ----
RESOURCE_GROUP="${RESOURCE_GROUP:?Set RESOURCE_GROUP}"
CLUSTER_NAME="${CLUSTER_NAME:?Set CLUSTER_NAME}"
SPOT_POOL_NAME="${SPOT_POOL_NAME:-spotpool}"
SPOT_VM_SIZE="${SPOT_VM_SIZE:-Standard_D4as_v5}"
SPOT_MIN_COUNT="${SPOT_MIN_COUNT:-1}"
SPOT_MAX_COUNT="${SPOT_MAX_COUNT:-5}"
SPOT_MAX_PRICE="${SPOT_MAX_PRICE:--1}"  # -1 = up to on-demand price
ZONES="${ZONES:-1 2 3}"

echo "==> Adding spot node pool '${SPOT_POOL_NAME}' to cluster '${CLUSTER_NAME}'"

az aks nodepool add \
  --resource-group "${RESOURCE_GROUP}" \
  --cluster-name "${CLUSTER_NAME}" \
  --name "${SPOT_POOL_NAME}" \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price "${SPOT_MAX_PRICE}" \
  --node-vm-size "${SPOT_VM_SIZE}" \
  --enable-cluster-autoscaler \
  --min-count "${SPOT_MIN_COUNT}" \
  --max-count "${SPOT_MAX_COUNT}" \
  --zones ${ZONES} \
  --node-taints "kubernetes.azure.com/scalesetpriority=spot:NoSchedule" \
  --labels "kubernetes.azure.com/scalesetpriority=spot" \
  --max-pods 30 \
  --os-type Linux \
  --no-wait

echo "==> Spot node pool '${SPOT_POOL_NAME}' creation initiated."
echo "    VM Size:   ${SPOT_VM_SIZE}"
echo "    Min/Max:   ${SPOT_MIN_COUNT}/${SPOT_MAX_COUNT}"
echo "    Max Price: ${SPOT_MAX_PRICE} (-1 = up to on-demand)"
echo ""
echo "Monitor with: az aks nodepool show -g ${RESOURCE_GROUP} --cluster-name ${CLUSTER_NAME} -n ${SPOT_POOL_NAME}"
