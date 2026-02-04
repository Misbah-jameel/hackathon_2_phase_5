# Verification and Continuation Script for Kubernetes Tools
# Run this in PowerShell (doesn't need Administrator)

Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Kubernetes Tools Verification & Setup        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Color functions
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Step { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Magenta }

# ============================================================================
# STEP 1: Refresh PATH in current session
# ============================================================================

Write-Step "Refreshing PATH Environment Variable"

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
Write-Success "PATH refreshed"

# ============================================================================
# STEP 2: Verify Installations
# ============================================================================

Write-Step "Verifying Tool Installations"

$allInstalled = $true

# Check Minikube
try {
    $minikubeVer = & minikube version --short 2>&1
    Write-Success "Minikube: $minikubeVer"
} catch {
    Write-Error "Minikube not found in PATH"
    $allInstalled = $false
}

# Check kubectl
try {
    $kubectlVer = & kubectl version --client -o json 2>&1 | ConvertFrom-Json
    Write-Success "kubectl: $($kubectlVer.clientVersion.gitVersion)"
} catch {
    Write-Error "kubectl not found in PATH"
    $allInstalled = $false
}

# Check Helm
try {
    $helmVer = & helm version --short 2>&1
    Write-Success "Helm: $helmVer"
} catch {
    Write-Error "Helm not found in PATH"
    $allInstalled = $false
}

if (-not $allInstalled) {
    Write-Host ""
    Write-Warning "Some tools are not found. Please:"
    Write-Info "1. Close this PowerShell window"
    Write-Info "2. Open a NEW PowerShell window"
    Write-Info "3. Run this script again"
    Write-Host ""
    Write-Info "If that doesn't work, check installation locations:"
    Write-Info "  Default: $env:USERPROFILE\kube-tools\"
    exit 1
}

# ============================================================================
# STEP 3: Check Minikube Status
# ============================================================================

Write-Step "Checking Minikube Cluster Status"

try {
    $status = & minikube status 2>&1
    if ($status -match "Running") {
        Write-Success "Minikube cluster is running!"
        $clusterRunning = $true
    } else {
        Write-Warning "Minikube cluster is not running"
        $clusterRunning = $false
    }
} catch {
    Write-Warning "Minikube cluster not started yet"
    $clusterRunning = $false
}

# ============================================================================
# STEP 4: Start Minikube if not running
# ============================================================================

if (-not $clusterRunning) {
    Write-Step "Starting Minikube Cluster"

    Write-Info "This will take 5-10 minutes on first run..."
    Write-Info ""

    # Ask which driver to use
    Write-Host "Which driver do you want to use?" -ForegroundColor Yellow
    Write-Host "  1. Hyper-V (Windows Pro/Enterprise - recommended)" -ForegroundColor White
    Write-Host "  2. Docker Desktop (All Windows versions)" -ForegroundColor White
    $driverChoice = Read-Host "Enter 1 or 2"

    if ($driverChoice -eq "1") {
        Write-Info "Starting with Hyper-V driver..."
        & minikube start --driver=hyperv
    } else {
        Write-Info "Starting with Docker driver..."
        Write-Warning "Make sure Docker Desktop is installed and running!"
        & minikube start --driver=docker
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Minikube started successfully!"
    } else {
        Write-Error "Failed to start Minikube. See error above."
        exit 1
    }
}

# ============================================================================
# STEP 5: Verify Kubernetes Connection
# ============================================================================

Write-Step "Verifying Kubernetes Cluster Connection"

try {
    Write-Info "Checking cluster info..."
    & kubectl cluster-info
    Write-Host ""

    Write-Info "Checking nodes..."
    & kubectl get nodes
    Write-Host ""

    Write-Success "kubectl is connected to the cluster!"
} catch {
    Write-Error "Failed to connect to cluster"
    exit 1
}

# ============================================================================
# STEP 6: Setup Helm Repositories
# ============================================================================

Write-Step "Setting Up Helm Repositories"

try {
    Write-Info "Adding stable repository..."
    & helm repo add stable https://charts.helm.sh/stable 2>&1 | Out-Null

    Write-Info "Adding bitnami repository..."
    & helm repo add bitnami https://charts.bitnami.com/bitnami 2>&1 | Out-Null

    Write-Info "Updating repositories..."
    & helm repo update

    Write-Success "Helm repositories configured!"
} catch {
    Write-Warning "Some repositories may already exist (this is OK)"
}

# ============================================================================
# STEP 7: Install kagent (AI Kubernetes Assistant)
# ============================================================================

Write-Step "Installing kagent (AI Kubernetes Assistant)"

Write-Host ""
Write-Info "kagent is an AI-powered assistant for Kubernetes"
Write-Info "It requires an API key from an AI provider (Anthropic, OpenAI, etc.)"
Write-Host ""

$installKagent = Read-Host "Do you want to install kagent now? (y/n)"

if ($installKagent -eq "y" -or $installKagent -eq "Y") {

    Write-Host ""
    Write-Info "Which AI provider do you want to use?"
    Write-Host "  1. Anthropic Claude (recommended)" -ForegroundColor White
    Write-Host "  2. OpenAI GPT" -ForegroundColor White
    Write-Host "  3. Skip for now" -ForegroundColor White
    $providerChoice = Read-Host "Enter 1, 2, or 3"

    if ($providerChoice -eq "1") {
        Write-Host ""
        Write-Info "You need an Anthropic API key from: https://console.anthropic.com/"
        $apiKey = Read-Host "Enter your Anthropic API key (or press Enter to skip)"

        if ($apiKey) {
            Write-Info "Installing kagent CRDs..."
            & helm install kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds --namespace kagent --create-namespace

            Write-Info "Installing kagent with Anthropic..."
            & helm upgrade --install kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent `
                --namespace kagent `
                --set providers.default=anthropic `
                --set "providers.anthropic.apiKey=$apiKey" `
                --set ui.service.type=NodePort

            Write-Success "kagent installed!"
            Write-Info "Waiting for pods to start..."
            Start-Sleep -Seconds 5
            & kubectl get pods -n kagent

            Write-Host ""
            Write-Info "To access kagent UI, run:"
            Write-Host "  minikube service kagent-ui -n kagent --url" -ForegroundColor Yellow
        }
    } elseif ($providerChoice -eq "2") {
        Write-Host ""
        Write-Info "You need an OpenAI API key from: https://platform.openai.com/"
        $apiKey = Read-Host "Enter your OpenAI API key (or press Enter to skip)"

        if ($apiKey) {
            Write-Info "Installing kagent CRDs..."
            & helm install kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds --namespace kagent --create-namespace

            Write-Info "Installing kagent with OpenAI..."
            & helm upgrade --install kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent `
                --namespace kagent `
                --set providers.default=openai `
                --set "providers.openai.apiKey=$apiKey" `
                --set ui.service.type=NodePort

            Write-Success "kagent installed!"
            Write-Info "Waiting for pods to start..."
            Start-Sleep -Seconds 5
            & kubectl get pods -n kagent

            Write-Host ""
            Write-Info "To access kagent UI, run:"
            Write-Host "  minikube service kagent-ui -n kagent --url" -ForegroundColor Yellow
        }
    } else {
        Write-Info "Skipping kagent installation"
    }
} else {
    Write-Info "Skipping kagent installation"
}

# ============================================================================
# STEP 8: Deploy a Test Application
# ============================================================================

Write-Step "Deploy Test Application (Optional)"

Write-Host ""
$deployTest = Read-Host "Do you want to deploy a test application to verify everything works? (y/n)"

if ($deployTest -eq "y" -or $deployTest -eq "Y") {
    Write-Info "Deploying hello-world application..."

    & kubectl create deployment hello-k8s --image=kicbase/echo-server:1.0
    & kubectl expose deployment hello-k8s --type=NodePort --port=8080

    Write-Success "Test app deployed!"
    Write-Info "Getting service URL..."
    Start-Sleep -Seconds 2

    $url = & minikube service hello-k8s --url
    Write-Host ""
    Write-Success "Test application is running at: $url"
    Write-Info "Open this URL in your browser to verify!"
    Write-Host ""

    $cleanup = Read-Host "Clean up test application? (y/n)"
    if ($cleanup -eq "y" -or $cleanup -eq "Y") {
        & kubectl delete service hello-k8s
        & kubectl delete deployment hello-k8s
        Write-Success "Test application removed"
    }
}

# ============================================================================
# STEP 9: Summary and Next Steps
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          Setup Complete!                       ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host ""
Write-Host "✓ All tools verified and working!" -ForegroundColor Green
Write-Host "✓ Minikube cluster is running" -ForegroundColor Green
Write-Host "✓ kubectl connected to cluster" -ForegroundColor Green
Write-Host "✓ Helm repositories configured" -ForegroundColor Green

Write-Host ""
Write-Host "Quick Commands:" -ForegroundColor Cyan
Write-Host "  minikube status            - Check cluster status" -ForegroundColor White
Write-Host "  minikube dashboard         - Open Kubernetes dashboard" -ForegroundColor White
Write-Host "  kubectl get pods           - List all pods" -ForegroundColor White
Write-Host "  kubectl get all -A         - See everything in cluster" -ForegroundColor White
Write-Host "  helm list -A               - List Helm releases" -ForegroundColor White

Write-Host ""
Write-Host "Useful Resources:" -ForegroundColor Cyan
Write-Host "  • Quick Reference: KUBERNETES_QUICK_REFERENCE.md" -ForegroundColor White
Write-Host "  • Full Guide: KUBERNETES_SETUP_GUIDE.md" -ForegroundColor White

Write-Host ""
Write-Host "What's Next?" -ForegroundColor Cyan
Write-Host "  1. Open Kubernetes Dashboard: minikube dashboard" -ForegroundColor Yellow
Write-Host "  2. Deploy your first app: kubectl create deployment nginx --image=nginx" -ForegroundColor Yellow
Write-Host "  3. Explore Helm charts: helm search hub wordpress" -ForegroundColor Yellow
Write-Host "  4. Learn with examples in the quick reference guide" -ForegroundColor Yellow

Write-Host ""
Write-Success "Happy learning! 🚀"
Write-Host ""
