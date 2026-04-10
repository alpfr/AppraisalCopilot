# AppraisalCopilot — AKS Spot Instance Deployment

## Cost Optimization Strategy

Azure Spot VMs provide up to **80% savings** over on-demand pricing. This deployment uses a tiered approach:

| Workload | Spot Strategy | Rationale |
|----------|--------------|-----------|
| Frontend | Prefer spot, fallback to on-demand | Stateless, fast restart |
| Backend API | Prefer spot, fallback to on-demand | Stateless, multiple replicas absorb evictions |
| Document Ingestion | Spot-only (required) | Batch workload, fully restartable |

## Prerequisites

- AKS cluster with a **system node pool** (on-demand, for kube-system)
- Azure CLI authenticated
- `kubectl` configured for the cluster

## Step 1 — Add the Spot Node Pool

```bash
export RESOURCE_GROUP="your-rg"
export CLUSTER_NAME="your-aks-cluster"

# Uses Standard_D4as_v5 (4 vCPU, 16 GB) — good price/performance
bash k8s/spot/spot-node-pool.sh
```

Override defaults via environment variables:

```bash
SPOT_VM_SIZE=Standard_D8as_v5 SPOT_MAX_COUNT=10 bash k8s/spot/spot-node-pool.sh
```

## Step 2 — Deploy the Application

```bash
# Create namespace and configs
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/configmap.yaml

# Create secrets (one-time)
kubectl -n appraisal-copilot create secret generic appraisal-copilot-secrets \
  --from-literal=database-url='postgresql://user:pass@host:5432/appraisaldb'

kubectl -n appraisal-copilot create secret generic gcp-service-account \
  --from-file=service-account.json=/path/to/your/sa-key.json

# Deploy all workloads
kubectl apply -f k8s/base/
kubectl apply -f k8s/spot/
```

## Step 3 — Verify Spot Scheduling

```bash
# Check nodes — spot nodes show the taint
kubectl get nodes -l kubernetes.azure.com/scalesetpriority=spot

# Verify pods landed on spot nodes
kubectl -n appraisal-copilot get pods -o wide
```

## How Spot Evictions Are Handled

1. **PodDisruptionBudgets** ensure at least 1 frontend and 1 backend pod remain available during evictions
2. **Pod anti-affinity** spreads replicas across availability zones so a single zone eviction doesn't take down the service
3. **HPA** automatically scales up replacement pods when evictions increase load on survivors
4. **terminationGracePeriodSeconds** gives pods time to finish in-flight requests before shutdown
5. **Document ingestion** uses spot-only scheduling — evicted jobs are automatically restarted by Kubernetes

## GitHub Actions Secrets Required

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Service principal or managed identity client ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `ACR_LOGIN_SERVER` | e.g., `myregistry.azurecr.io` |
| `ACR_NAME` | ACR name (without `.azurecr.io`) |
| `AKS_RESOURCE_GROUP` | Resource group containing the AKS cluster |
| `AKS_CLUSTER_NAME` | AKS cluster name |

## Estimated Savings

| Component | On-Demand (D4as_v5) | Spot Price | Savings |
|-----------|---------------------|------------|---------|
| Per node/month | ~$140 | ~$28–42 | 70–80% |
| 3-node spot pool | ~$420/mo | ~$84–126/mo | ~$300/mo saved |
