# AzureLaunch — Python FastAPI + Azure Container Registry

Deployed via GitHub Actions CI/CD.

---

## Project Structure

```
azurelaunch/
├── backend/
│   ├── main.py            # FastAPI app (/, /health, /version)
│   ├── pyproject.toml     # uv project dependencies
│   └── Dockerfile
├── frontend/
│   ├── index.html
│   ├── nginx.conf
│   └── Dockerfile
├── scripts/
│   └── azure-setup.sh     # One-time Azure infra setup
├── .github/workflows/
│   ├── ci.yml             # Build + smoke test on every push/PR
│   └── cd.yml             # Push images to ACR on merge to main
└── .gitignore
```

---

## CI/CD Flow Diagrams

> Open [`docs/pipeline.html`](docs/pipeline.html) in a browser for a live animated version of this pipeline.

## CI/CD Flow Diagram (ASCII)

```
Local Dev  ──git push──►  GitHub Repo (main)
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
              CI workflow             CD workflow
              (ci.yml)                (cd.yml)
                    │                       │
                    ▼                       ▼
            Docker build            Docker build
            backend+frontend        backend+frontend
                    │                       │
                    ▼                       ▼
            Smoke tests             Azure login (OIDC)
            GET /                   no passwords
            GET /health                     │
            GET /version                    ▼
                    │               docker push
            PR ✓ green              azurelaunchacr.azurecr.io
                                    :latest + :<git-sha>
                                            │
                                            ▼
                                  Azure Container Registry
                                  azurelaunchacr.azurecr.io
```

| Step | What happens |
|---|---|
| Step 0–1 | Create folders, write FastAPI app, run locally with `uv` |
| Step 2–3 | Push to GitHub, CI builds + smoke tests on every PR |
| Step 3 | Add Azure secrets, CD workflow activates on merge to main |
| Step 4 | OIDC login → `docker push` → images land in ACR |

Images are tagged with both `latest` and the git commit SHA for full traceability.

---

## Prerequisites — Azure Account & Azure CLI

### 1. Create a Free Azure Account

1. Go to [azure.microsoft.com/free](https://azure.microsoft.com/free)
2. Click **Start free** and sign in with a Microsoft account (or create one)
3. You get **$200 free credit** for 30 days — more than enough for this task
4. Once signed in, go to [portal.azure.com](https://portal.azure.com) to confirm your account is active
5. Note your **Subscription ID** — you'll need it in Step 4
   - In Azure Portal → search **Subscriptions** → copy the Subscription ID

---

### 2. Install Azure CLI

**Mac:**
```bash
brew install azure-cli
```

**Windows:**
```bash
winget install Microsoft.AzureCLI
```

**Linux (Ubuntu/Debian):**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Verify it worked:
```bash
az --version
```

### 3. Login to Azure via CLI

```bash
az login
```

This opens a browser — sign in with the same account you used to create the Azure account.
Confirm login worked:
```bash
az account show
```

You should see your subscription name and ID printed.

---

## Step 0 — Create Project Folder Structure

```bash
# Create root project folder
mkdir azurelaunch
cd azurelaunch

# Create subfolders
mkdir backend
mkdir frontend
mkdir scripts
mkdir -p .github/workflows

# Create all the files (copy contents from this repo)
touch backend/main.py
touch backend/Dockerfile
touch frontend/index.html
touch frontend/nginx.conf
touch frontend/Dockerfile
touch scripts/azure-setup.sh
touch .github/workflows/ci.yml
touch .github/workflows/cd.yml
touch .gitignore
```

**Or** in just 2 commands:

```bash
mkdir -p azurelaunch/{backend,frontend,scripts,.github/workflows}
cd azurelaunch && touch backend/{main.py,Dockerfile} frontend/{index.html,nginx.conf,Dockerfile} scripts/azure-setup.sh .github/workflows/{ci.yml,cd.yml} .gitignore
```

Your folder should look like this before moving to Step 1:

```
azurelaunch/
├── backend/
│   ├── main.py
│   └── Dockerfile
├── frontend/
│   ├── index.html
│   ├── nginx.conf
│   └── Dockerfile
├── scripts/
│   └── azure-setup.sh
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
└── .gitignore
```

---

## Step 1 — Create Virtual Environment (local dev)

```bash
# Install uv if you don't have it
pip install uv

cd backend
uv init                           # creates pyproject.toml (already exists here)
uv add fastapi uvicorn            # adds deps + creates uv.lock automatically
uv run uvicorn main:app --reload  # runs app — no activate needed!
```

No `requirements.txt` needed — `uv` manages everything via `pyproject.toml` and `uv.lock`.

Test endpoints:
- `http://localhost:8000/`        → Hello to my world!
- `http://localhost:8000/health`  → {"status":"healthy"}
- `http://localhost:8000/version` → {"version":"1.0.0",...}
- `http://localhost:8000/docs`    → FastAPI auto-generated docs

---

## Step 2 — Create GitHub Repo

```bash
cd ..   # back to project root
git init
git add .
git commit -m "Initial commit — AzureLaunch"
gh repo create azurelaunch --public --push --source=.
```

Or create manually on github.com and push.

---

## Step 3 — Create GitHub Actions

The workflows are already in `.github/workflows/`:

- **ci.yml** — runs on every push/PR: builds Docker images and smoke tests all endpoints
- **cd.yml** — runs on merge to main: pushes images to Azure Container Registry

Add these **5 secrets** to your GitHub repo  
(Settings → Secrets and variables → Actions → New repository secret):

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | From azure-setup.sh output |
| `AZURE_TENANT_ID` | From azure-setup.sh output |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `ACR_NAME` | e.g. `azurelaunchacr12345` |
| `ACR_LOGIN_SERVER` | e.g. `azurelaunchacr12345.azurecr.io` |

---

## Step 4 — Deploy to ACR

```bash
# One-time Azure setup (edit variables at top of script first)
chmod +x scripts/azure-setup.sh
./scripts/azure-setup.sh

# Then push to main to trigger the CD pipeline
git push origin main
```

The CD workflow will:
1. Login to Azure (OIDC — no password needed)
2. Build the backend Docker image
3. Push to ACR with your commit SHA as the tag
4. Build the frontend Docker image
5. Push to ACR

Your images will be visible in Azure Portal → Container Registry → Repositories.
