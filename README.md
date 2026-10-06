# AppraisalCopilot 🏡📊

> **AI-Powered Real Estate Appraisal Analysis & Document Intelligence Platform**

AppraisalCopilot streamlines commercial and residential real estate appraisals by automating document ingestion, property deed OCR, comparable sales analysis, and valuation drafting using modern LLM reasoning and zero-trust verification.

---

## 1. System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        AppraisalCopilot Frontend                       │
│  - React SPA served via Nginx (Port 80)                                │
│  - Document upload, valuation review, comp analysis workspace         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Reverse Proxy (/api -> :8000)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                       FastAPI Backend Service                          │
│  - Python 3.12, Uvicorn (Port 8000)                                    │
│  - PDF processing (poppler-utils) & OCR (Tesseract)                    │
│  - Valuation modeling, comp extraction & compliance verification       │
└───────────────────┬────────────────────────────────┬───────────────────┘
                    │                                │
                    ▼                                ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────┐
│     Batch Document Ingestion         │  │     PostgreSQL Database      │
│  - Spot-only background worker       │  │  - Property data & comps     │
│  - Batch document parsing & embedding│  │  - Audit lineage & valuations│
└──────────────────────────────────────┘  └──────────────────────────────┘
```

---

## 2. Key Features

- **Automated Document Intelligence:** Extracts critical property data from PDFs, scanned closing statements, and deed records using Tesseract OCR and Poppler.
- **Comparable Sales (Comps) Analysis:** Evaluates market comps with automated adjustment grids and location-based weighting.
- **Compliance & Valuation Guardrails:** Formats outputs according to USPAP (Uniform Standards of Professional Appraisal Practice) guidelines.
- **Cost-Optimized Cloud Architecture:** Designed for Azure Kubernetes Service (AKS) with up to **80% compute cost savings** via Azure Spot VMs.

---

## 3. Repository Structure

```
AppraisalCopilot/
├── backend/                  # FastAPI service
│   ├── Dockerfile            # Python 3.12-slim + poppler & tesseract OCR
│   ├── requirements.txt      # API & AI dependencies
│   └── main.py               # API endpoints and valuation engine
├── frontend/                 # React web application
│   ├── Dockerfile            # Multi-stage build + Nginx runtime
│   ├── nginx.conf            # Reverse proxy (/api -> backend:8000)
│   └── src/                  # User interface & appraisal dashboards
├── k8s/                      # Kubernetes manifests
│   ├── base/                 # Core namespace, deployments, configmaps, ingress
│   └── spot/                 # Spot VM node pool script, HPA, PodDisruptionBudgets
├── docs/                     # Specifications & compliance documents
│   ├── AppraisalCopilot_ARCHITECTURE.docx
│   ├── AppraisalCopilot_BUSINESS-CASE.docx
│   ├── AppraisalCopilot_COMPLIANCE.docx
│   ├── AppraisalCopilot_PROMPTS.docx
│   └── AppraisalCopilot_USER_GUIDE.docx
├── .github/workflows/        # CI/CD pipelines
│   └── deploy-aks.yml        # Automated build & deploy to Azure AKS
└── AKS_SPOT_DEPLOYMENT.md    # Detailed Azure AKS Spot deployment runbook
```

---

## 4. Local Development

### Prerequisites
- Docker & Docker Compose
- Python 3.12+
- Node.js 20+

### Running with Docker
```bash
# Build and run backend
cd backend
docker build -t appraisal-copilot-backend .
docker run -p 8000:8000 appraisal-copilot-backend

# Build and run frontend
cd ../frontend
docker build -t appraisal-copilot-frontend .
docker run -p 80:80 appraisal-copilot-frontend
```

---

## 5. Azure AKS & Spot Instance Deployment

AppraisalCopilot is configured for deployment on **Azure Kubernetes Service (AKS)** with Spot VM cost optimization.

### Quick Deployment

1. **Authenticate with Azure:**
   ```bash
   az login --tenant "80b25198-13b2-48d4-9cdf-47002f8a39a7"
   az aks get-credentials --resource-group medassist-rg --name medassist-aks-public --overwrite-existing
   ```

2. **Add the Spot Node Pool:**
   ```bash
   bash k8s/spot/spot-node-pool.sh
   ```

3. **Deploy Workloads:**
   ```bash
   kubectl apply -f k8s/base/namespace.yaml
   kubectl apply -f k8s/base/configmap.yaml
   kubectl apply -f k8s/base/
   kubectl apply -f k8s/spot/
   ```

For detailed lifecycle management, power management (`az aks stop` / `az aks start`), and cost analysis, see [**AKS_SPOT_DEPLOYMENT.md**](AKS_SPOT_DEPLOYMENT.md).

---

## 6. CI/CD Pipeline

Automated deployment is triggered on every push to `main` via GitHub Actions ([`.github/workflows/deploy-aks.yml`](.github/workflows/deploy-aks.yml)):
1. OIDC authentication to Azure
2. Builds and pushes multi-stage container images to Azure Container Registry (ACR)
3. Deploys base manifests and spot scheduling policies to AKS
4. Executes zero-downtime rolling updates with automatic health validation
