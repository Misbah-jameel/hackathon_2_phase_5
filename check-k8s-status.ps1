# Quick Kubernetes Setup Status Checker
# Run this anytime to verify your Kubernetes tools and cluster

# Color functions
function Write-Success { param($Message) Write-Host "[✓] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[ℹ] $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "[⚠] $Message" -ForegroundColor Yellow }
function Write-ErrorMsg { param($Message) Write-Host "[✗] $Message" -ForegroundColor Red }

Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Kubernetes Setup Status Check               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ============================================================================
# Check Minikube
# ============================================================================
Write-Host "`n[1/6] Checking Minikube..." -ForegroundColor Yellow
try {
    $minikubeVer = & minikube version --short 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Installed: $minikubeVer"
        Write-Host "      Location: $($(Get-Command minikube -ErrorAction SilentlyContinue).Source)" -ForegroundColor Gray
    } else {
        throw "Not found"
    }
} catch {
    Write-ErrorMsg "Not installed or not in PATH"
    Write-Info "Install with: Invoke-WebRequest -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -OutFile 'minikube.exe'"
}

# ============================================================================
# Check kubectl
# ============================================================================
Write-Host "`n[2/6] Checking kubectl..." -ForegroundColor Yellow
try {
    $kubectlVer = & kubectl version --client --short 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Installed: $kubectlVer"
        Write-Host "      Location: $($(Get-Command kubectl -ErrorAction SilentlyContinue).Source)" -ForegroundColor Gray
    } else {
        throw "Not found"
    }
} catch {
    Write-ErrorMsg "Not installed or not in PATH"
    Write-Info "Install from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
}

# ============================================================================
# Check Helm
# ============================================================================
Write-Host "`n[3/6] Checking Helm..." -ForegroundColor Yellow
try {
    $helmVer = & helm version --short 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Installed: $helmVer"
        Write-Host "      Location: $($(Get-Command helm -ErrorAction SilentlyContinue).Source)" -ForegroundColor Gray
    } else {
        throw "Not found"
    }
} catch {
    Write-ErrorMsg "Not installed or not in PATH"
    Write-Info "Install from: https://github.com/helm/helm/releases"
}

# ============================================================================
# Check Minikube Status
# ============================================================================
Write-Host "`n[4/6] Checking Minikube Cluster Status..." -ForegroundColor Yellow
try {
    $status = & minikube status 2>&1 | Out-String
    if ($status -match "Running") {
        Write-Success "Cluster is running"
        & minikube status | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    } else {
        Write-Warning "Cluster exists but not running"
        Write-Info "Start with: minikube start"
    }
} catch {
    Write-ErrorMsg "No cluster found"
    Write-Info "Create with: minikube start --driver=hyperv (or --driver=docker)"
}

# ============================================================================
# Check kubectl Connection
# ============================================================================
Write-Host "`n[5/6] Checking kubectl Connection to Cluster..." -ForegroundColor Yellow
try {
    $nodes = & kubectl get nodes 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Connected to cluster"
        Write-Host ""
        & kubectl get nodes | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    } else {
        throw "Cannot connect"
    }
} catch {
    Write-ErrorMsg "Cannot connect to cluster"
    Write-Info "Ensure Minikube is running: minikube start"
}

# ============================================================================
# Check Cluster Resources
# ============================================================================
Write-Host "`n[6/6] Checking Cluster Resources..." -ForegroundColor Yellow
try {
    $pods = & kubectl get pods -A 2>&1
    if ($LASTEXITCODE -eq 0) {
        $podCount = (& kubectl get pods -A --no-headers 2>&1 | Measure-Object).Count
        $runningPods = (& kubectl get pods -A --no-headers 2>&1 | Select-String "Running" | Measure-Object).Count
        Write-Success "Total Pods: $podCount | Running: $runningPods"

        Write-Host "`n      System Pods:" -ForegroundColor Gray
        & kubectl get pods -n kube-system --no-headers | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }
    } else {
        throw "Cannot get pods"
    }
} catch {
    Write-Warning "Cannot retrieve cluster resources"
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

$allGood = $true

# Check if all tools are available
try {
    & minikube version | Out-Null
    & kubectl version --client | Out-Null
    & helm version | Out-Null

    $status = & minikube status 2>&1 | Out-String
    if ($status -match "Running") {
        Write-Host ""
        Write-Success "All systems operational! 🚀"
        Write-Host ""
        Write-Info "Quick commands to try:"
        Write-Host "  • minikube dashboard        - Open Kubernetes dashboard" -ForegroundColor White
        Write-Host "  • kubectl get all -A        - See all resources" -ForegroundColor White
        Write-Host "  • helm repo add stable https://charts.helm.sh/stable - Add Helm repo" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Warning "Tools installed but cluster not running"
        Write-Info "Start cluster with: minikube start"
        $allGood = $false
    }
} catch {
    Write-Host ""
    Write-ErrorMsg "Some components are missing or not working"
    Write-Info "Run the automated setup: .\automated-k8s-setup.ps1"
    $allGood = $false
}

Write-Host ""
