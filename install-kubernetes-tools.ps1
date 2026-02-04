# Kubernetes Tools Automated Installation Script for Windows
# This script installs: Minikube, kubectl, Helm
# Run as Administrator in PowerShell

#Requires -RunAsAdministrator

# Color functions for better readability
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Step { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Magenta }

# Error handling
$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Kubernetes Tools Installer for Windows       ║" -ForegroundColor Cyan
Write-Host "║  Minikube + kubectl + Helm                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan

# ============================================================================
# STEP 0: Pre-Installation Checks
# ============================================================================

Write-Step "Pre-Installation Checks"

# Check Windows version
$osInfo = Get-WmiObject -Class Win32_OperatingSystem
Write-Info "OS: $($osInfo.Caption) - Build $($osInfo.BuildNumber)"

# Check system architecture
$arch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
if ($arch -ne "64-bit") {
    Write-Error "This script requires 64-bit Windows. Detected: $arch"
    exit 1
}
Write-Success "Architecture: $arch"

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 5) {
    Write-Error "PowerShell 5.0 or higher required. Current: $psVersion"
    exit 1
}
Write-Success "PowerShell Version: $psVersion"

# Enable script execution
Write-Info "Setting execution policy..."
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Write-Success "Execution policy configured"

# ============================================================================
# STEP 1: Create Tools Directory
# ============================================================================

Write-Step "Creating Tools Directory"

$toolsDir = "$env:USERPROFILE\kube-tools"
if (-not (Test-Path $toolsDir)) {
    New-Item -Path $toolsDir -ItemType Directory -Force | Out-Null
    Write-Success "Created directory: $toolsDir"
} else {
    Write-Info "Directory already exists: $toolsDir"
}

# ============================================================================
# STEP 2: Install Minikube
# ============================================================================

Write-Step "Installing Minikube"

$minikubePath = "$toolsDir\minikube.exe"
$minikubeUrl = "https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe"

try {
    Write-Info "Downloading Minikube from GitHub..."
    Invoke-WebRequest -Uri $minikubeUrl -OutFile $minikubePath -UseBasicParsing
    Write-Success "Minikube downloaded to: $minikubePath"
} catch {
    Write-Error "Failed to download Minikube: $_"
    exit 1
}

# ============================================================================
# STEP 3: Install kubectl
# ============================================================================

Write-Step "Installing kubectl"

$kubectlPath = "$toolsDir\kubectl.exe"

try {
    Write-Info "Fetching latest kubectl version..."
    $latestVersion = (Invoke-WebRequest -Uri "https://dl.k8s.io/release/stable.txt" -UseBasicParsing).Content.Trim()
    Write-Info "Latest version: $latestVersion"

    $kubectlUrl = "https://dl.k8s.io/release/$latestVersion/bin/windows/amd64/kubectl.exe"
    Write-Info "Downloading kubectl..."
    Invoke-WebRequest -Uri $kubectlUrl -OutFile $kubectlPath -UseBasicParsing
    Write-Success "kubectl downloaded to: $kubectlPath"
} catch {
    Write-Error "Failed to download kubectl: $_"
    exit 1
}

# ============================================================================
# STEP 4: Install Helm
# ============================================================================

Write-Step "Installing Helm"

$helmVersion = "v4.1.0"
$helmUrl = "https://get.helm.sh/helm-$helmVersion-windows-amd64.zip"
$helmZip = "$env:TEMP\helm.zip"
$helmExtract = "$env:TEMP\helm-extract"

try {
    Write-Info "Downloading Helm $helmVersion..."
    Invoke-WebRequest -Uri $helmUrl -OutFile $helmZip -UseBasicParsing

    Write-Info "Extracting Helm..."
    Expand-Archive -Path $helmZip -DestinationPath $helmExtract -Force

    $helmExe = "$helmExtract\windows-amd64\helm.exe"
    $helmDest = "$toolsDir\helm.exe"
    Move-Item -Path $helmExe -Destination $helmDest -Force

    # Clean up
    Remove-Item -Path $helmZip -Force
    Remove-Item -Path $helmExtract -Recurse -Force

    Write-Success "Helm installed to: $helmDest"
} catch {
    Write-Error "Failed to install Helm: $_"
    exit 1
}

# ============================================================================
# STEP 5: Update PATH Environment Variable
# ============================================================================

Write-Step "Updating PATH Environment Variable"

$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')

if ($currentPath -notlike "*$toolsDir*") {
    $newPath = "$currentPath;$toolsDir"
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Success "Added $toolsDir to User PATH"

    # Update current session PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Success "PATH refreshed in current session"
} else {
    Write-Info "$toolsDir already in PATH"
}

# ============================================================================
# STEP 6: Verify Installations
# ============================================================================

Write-Step "Verifying Installations"

# Refresh PATH for verification
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verify Minikube
try {
    $minikubeVersion = & minikube version --short 2>&1
    Write-Success "Minikube: $minikubeVersion"
} catch {
    Write-Warning "Minikube verification failed. Try reopening PowerShell."
}

# Verify kubectl
try {
    $kubectlVersion = & kubectl version --client --short 2>&1 | Select-String "Client Version"
    Write-Success "kubectl: $kubectlVersion"
} catch {
    Write-Warning "kubectl verification failed. Try reopening PowerShell."
}

# Verify Helm
try {
    $helmVersionOutput = & helm version --short 2>&1
    Write-Success "Helm: $helmVersionOutput"
} catch {
    Write-Warning "Helm verification failed. Try reopening PowerShell."
}

# ============================================================================
# STEP 7: Check Virtualization
# ============================================================================

Write-Step "Checking Virtualization Support"

# Check if Hyper-V is available
$hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue

if ($hyperv -and $hyperv.State -eq "Enabled") {
    Write-Success "Hyper-V is enabled - Ready for Minikube!"
    $driver = "hyperv"
} else {
    Write-Warning "Hyper-V is not enabled."
    Write-Info "You have two options:"
    Write-Info "  1. Enable Hyper-V (Windows Pro/Enterprise):"
    Write-Info "     Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All"
    Write-Info "     Then restart your computer."
    Write-Info ""
    Write-Info "  2. Install Docker Desktop (All Windows versions):"
    Write-Info "     Download from: https://www.docker.com/products/docker-desktop"
    Write-Info "     Then use: minikube start --driver=docker"
    $driver = "docker"
}

# ============================================================================
# STEP 8: Start Minikube (Optional)
# ============================================================================

Write-Host ""
$startMinikube = Read-Host "Do you want to start Minikube now? (y/n)"

if ($startMinikube -eq "y" -or $startMinikube -eq "Y") {
    Write-Step "Starting Minikube"

    try {
        if ($driver -eq "hyperv") {
            Write-Info "Starting Minikube with Hyper-V driver..."
            & minikube start --driver=hyperv
        } else {
            Write-Info "Starting Minikube with Docker driver..."
            Write-Warning "Make sure Docker Desktop is installed and running!"
            & minikube start --driver=docker
        }

        Write-Success "Minikube started successfully!"

        # Verify cluster
        Write-Info "Verifying Kubernetes cluster..."
        & kubectl get nodes

    } catch {
        Write-Error "Failed to start Minikube: $_"
        Write-Info "You can start it manually later with: minikube start"
    }
} else {
    Write-Info "Skipping Minikube startup. Start it later with: minikube start"
}

# ============================================================================
# STEP 9: Summary
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          Installation Complete!                ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host ""
Write-Host "Installed Tools:" -ForegroundColor Cyan
Write-Host "  • Minikube: $minikubePath" -ForegroundColor White
Write-Host "  • kubectl:  $kubectlPath" -ForegroundColor White
Write-Host "  • Helm:     $toolsDir\helm.exe" -ForegroundColor White

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Close and reopen PowerShell to refresh PATH" -ForegroundColor Yellow
Write-Host "  2. Start Minikube: minikube start" -ForegroundColor White
Write-Host "  3. Verify cluster: kubectl get nodes" -ForegroundColor White
Write-Host "  4. Add Helm repos: helm repo add stable https://charts.helm.sh/stable" -ForegroundColor White
Write-Host "  5. See full guide: KUBERNETES_SETUP_GUIDE.md" -ForegroundColor White

Write-Host ""
Write-Host "Quick Commands:" -ForegroundColor Cyan
Write-Host "  minikube status     - Check Minikube status" -ForegroundColor White
Write-Host "  minikube dashboard  - Open Kubernetes dashboard" -ForegroundColor White
Write-Host "  kubectl get pods    - List all pods" -ForegroundColor White
Write-Host "  helm list           - List Helm releases" -ForegroundColor White

Write-Host ""
Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "  Minikube: https://minikube.sigs.k8s.io/docs/start/" -ForegroundColor White
Write-Host "  kubectl:  https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/" -ForegroundColor White
Write-Host "  Helm:     https://helm.sh/docs/intro/install/" -ForegroundColor White

Write-Host ""
Write-Success "Installation script completed successfully!"
Write-Host ""
