# AppraisalCopilot — AKS Spot Instance Deployment & Lifecycle Guide

## 1. Cost Optimization & Spot Strategy

Azure Spot VMs provide up to **80% savings** over on-demand pricing. This deployment implements a tiered resilience strategy:

| Workload | Spot Strategy | Rationale |
| :--- | :--- | :--- |
| **Frontend** | Prefer spot, fallback to on-demand | Stateless React/Nginx SPA, fast restarts |
| **Backend API** | Prefer spot, fallback to on-demand | Stateless FastAPI/Uvicorn, multi-replicas absorb evictions |
| **Document Ingestion** | Spot-only (required) | Batch OCR & embedding workload, fully restartable |

---

## 2. Verified Azure Environment

- **Subscription:** `Azure subscription 1` (`aae342e2-82e7-4465-8b76-06624029d9d0`)
- **Tenant ID:** `80b25198-13b2-48d4-9cdf-47002f8a39a7`
- **Resource Group:** `medassist-rg`
- **AKS Cluster Name:** `medassist-aks-public`
- **Location:** `eastus`
- **Kubernetes Version:** `v1.33.6`
- **Default Node Pool:** `aks-nodepool1` (2x `Standard_B2s` On-Demand)

---

## 3. Prerequisites

1. **Azure CLI authenticated:**
   ```bash
   az login --tenant "80b25198-13b2-48d4-9cdf-47002f8a39a7"
   ```
2. **Kubectl context set to AKS:**
   ```bash
   az aks get-credentials --resource-group medassist-rg --name medassist-aks-public --overwrite-existing
   ```

---

## 4. Deployment Steps

### Step 1 — Add the Spot Node Pool to AKS

The cluster currently runs on-demand `Standard_B2s` nodes. Add a cost-effective spot node pool (`Standard_D4as_v5` or `Standard_B2s`):

```bash
# Uses verified cluster defaults: medassist-rg / medassist-aks-public
bash k8s/spot/spot-node-pool.sh

# Or customize instance size and limits:
SPOT_VM_SIZE=Standard_D4as_v5 SPOT_MIN_COUNT=1 SPOT_MAX_COUNT=5 bash k8s/spot/spot-node-pool.sh
```

### Step 2 — Deploy the Application Workloads

```bash
# 1. Create namespace and configmap
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/configmap.yaml

# 2. Create required secrets
kubectl -n appraisal-copilot create secret generic appraisal-copilot-secrets \
  --from-literal=database-url='postgresql://user:pass@host:5432/appraisaldb'

kubectl -n appraisal-copilot create secret generic gcp-service-account \
  --from-file=service-account.json=/path/to/your/sa-key.json

# 3. Deploy base workloads and spot scheduling policies
kubectl apply -f k8s/base/
kubectl apply -f k8s/spot/
```

### Step 3 — Verify Spot Scheduling

```bash
# Verify spot nodes joined the cluster
kubectl get nodes -l kubernetes.azure.com/scalesetpriority=spot

# Confirm pods scheduled onto spot nodes
kubectl -n appraisal-copilot get pods -o wide
```

---

## 5. Cluster Lifecycle & Power Management Runbook

When the cluster is not actively in use, stopping the cluster halts VM compute charges completely.

### Halting Compute Billing ($0/hr VM Compute)
```bash
# Stop the cluster (deallocates VMs; disks and configs are preserved)
az aks stop --resource-group medassist-rg --name medassist-aks-public

# Verify status (PowerState: Stopped)
az aks show --resource-group medassist-rg --name medassist-aks-public \
  --query "{Name:name, ProvisioningState:provisioningState, PowerState:powerState.code}" -o json
```

### Starting the Cluster
```bash
# Restart the cluster when needed
az aks start --resource-group medassist-rg --name medassist-aks-public

# Verify nodes are Ready
kubectl get nodes
```

### Scaling Workloads to Zero (Soft Pause)
To keep the cluster running but free all memory/CPU without deallocating the VMs:
```bash
# Scale down all workloads in appraisal-copilot
kubectl -n appraisal-copilot scale deployment --all --replicas=0

# Restore workloads
kubectl -n appraisal-copilot scale deployment/frontend --replicas=2
kubectl -n appraisal-copilot scale deployment/backend --replicas=2
kubectl -n appraisal-copilot scale deployment/document-ingestion --replicas=1
```

---

## 6. How Spot Evictions Are Handled

1. **PodDisruptionBudgets (`k8s/spot/pdb.yaml`):** Guarantees minimum available pods during spot evictions.
2. **Pod Anti-Affinity:** Spreads frontend and backend replicas across nodes and zones.
3. **Horizontal Pod Autoscaling (`k8s/spot/hpa.yaml`):** Scales replacement pods on demand.
4. **Graceful Shutdown:** Configured `terminationGracePeriodSeconds` allows in-flight requests to complete.
5. **Batch Ingestion Resilience:** Ingestion pods use spot-only priority; evicted batch jobs automatically restart.

---

## 7. GitHub Actions CI/CD Pipeline

The automated deployment workflow is configured in [`.github/workflows/deploy-aks.yml`](.github/workflows/deploy-aks.yml). To enable automated deployment on push to `main`, set the following repository secrets in GitHub:

| Secret | Description | Example / Target |
| :--- | :--- | :--- |
| `AZURE_CLIENT_ID` | Managed Identity or App Client ID | Service Principal UUID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID | `80b25198-13b2-48d4-9cdf-47002f8a39a7` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `aae342e2-82e7-4465-8b76-06624029d9d0` |
| `ACR_LOGIN_SERVER` | Azure Container Registry server | `medassistacr.azurecr.io` |
| `ACR_NAME` | ACR short name | `medassistacr` |
| `AKS_RESOURCE_GROUP` | Resource Group | `medassist-rg` |
| `AKS_CLUSTER_NAME` | Cluster Name | `medassist-aks-public` |

---

## 8. Jev Economic Profile & Cost Analysis

| Strategy | Monthly Cost | Savings | Notes |
| :--- | :---: | :---: | :--- |
| **On-Demand Baseline (2x Standard_B2s)** | ~$105 / mo | Baseline | Running 24/7 on-demand compute + LB + SSDs |
| **1-Node Minimal Topology** | ~$75 / mo | 29% | Scales nodepool to 1 node during staging |
| **Spot Node Pool (`Standard_B2s`)** | ~$45 / mo | 58% | Utilizes Azure Spot VM pricing (~$0.0083/hr/VM) |
| **Cluster Stopped (`az aks stop`)** | **~$22 / mo** | **79%** | **$0/hr VM compute**; storage only |
