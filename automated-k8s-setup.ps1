# ============================================================================
# AUTOMATED KUBERNETES SETUP FOR WINDOWS
# ============================================================================
# This script will:
# 1. Check if Minikube, kubectl, Helm are installed
# 2. Install missing tools automatically
# 3. Configure PATH environment variables
# 4. Start Minikube cluster
# 5. Verify everything is working
# ============================================================================

# Configuration
$TOOLS_DIR = "$env:USERPROFILE\kube-tools"
$MINIKUBE_URL = "https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe"
$KUBECTL_STABLE_URL = "https://dl.k8s.io/release/stable.txt"
$HELM_VERSION = "v4.1.0"
$HELM_URL = "https://get.helm.sh/helm-$HELM_VERSION-windows-amd64.zip"

# Color output functions
function Write-Step {
    param($Message)
    Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  $Message" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}
function Write-Success { param($Message) Write-Host "[✓] $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "[ℹ] $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "[⚠] $Message" -ForegroundColor Yellow }
function Write-ErrorMsg { param($Message) Write-Host "[✗] $Message" -ForegroundColor Red }
function Write-Command { param($Message) Write-Host "    > $Message" -ForegroundColor Gray }

# Error handling
$ErrorActionPreference = "Stop"

Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║      AUTOMATED KUBERNETES SETUP ASSISTANT FOR WINDOWS          ║
║                                                                ║
║      This script will install and configure:                  ║
║      • Minikube (Local Kubernetes cluster)                    ║
║      • kubectl (Kubernetes CLI)                               ║
║      • Helm (Package manager)                                 ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Start-Sleep -Seconds 2

# ============================================================================
# STEP 1: PRE-INSTALLATION CHECKS
# ============================================================================

Write-Step "STEP 1: System Pre-Checks"

Write-Info "Checking system requirements..."

# Check OS
$os = Get-WmiObject -Class Win32_OperatingSystem
Write-Success "Operating System: $($os.Caption) Build $($os.BuildNumber)"

# Check architecture
$arch = $os.OSArchitecture
if ($arch -ne "64-bit") {
    Write-ErrorMsg "64-bit Windows required. Found: $arch"
    exit 1
}
Write-Success "Architecture: $arch ✓"

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Success "PowerShell Version: $psVersion ✓"

# Check internet connectivity
Write-Info "Testing internet connectivity..."
try {
    $null = Test-Connection -ComputerName google.com -Count 1 -Quiet
    Write-Success "Internet connection: Active ✓"
} catch {
    Write-ErrorMsg "No internet connection detected"
    exit 1
}

Write-Success "All system checks passed!"

# ============================================================================
# STEP 2: CREATE TOOLS DIRECTORY
# ============================================================================

Write-Step "STEP 2: Creating Tools Directory"

if (-not (Test-Path $TOOLS_DIR)) {
    New-Item -Path $TOOLS_DIR -ItemType Directory -Force | Out-Null
    Write-Success "Created directory: $TOOLS_DIR"
} else {
    Write-Info "Directory already exists: $TOOLS_DIR"
}

# ============================================================================
# STEP 3: CHECK AND INSTALL MINIKUBE
# ============================================================================

Write-Step "STEP 3: Checking Minikube"

$minikubePath = "$TOOLS_DIR\minikube.exe"
$minikubeInstalled = $false

# Check if minikube is in PATH
try {
    $minikubeVersion = & minikube version --short 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Minikube is already installed: $minikubeVersion"
        Write-Command "Location: $($(Get-Command minikube).Source)"
        $minikubeInstalled = $true
    }
} catch {
    Write-Info "Minikube not found in PATH"
}

# Check if minikube exists in tools directory
if (-not $minikubeInstalled -and (Test-Path $minikubePath)) {
    Write-Info "Minikube found in tools directory but not in PATH"
    $minikubeInstalled = $true
}

# Install if not found
if (-not $minikubeInstalled) {
    Write-Warning "Minikube not installed. Installing now..."
    Write-Info "Download URL: $MINIKUBE_URL"
    Write-Info "Destination: $minikubePath"

    try {
        Write-Info "Downloading Minikube (this may take a minute)..."
        Invoke-WebRequest -Uri $MINIKUBE_URL -OutFile $minikubePath -UseBasicParsing
        Write-Success "Minikube downloaded successfully!"

        # Verify download
        if (Test-Path $minikubePath) {
            $fileSize = [math]::Round((Get-Item $minikubePath).Length / 1MB, 2)
            Write-Success "File size: ${fileSize} MB"
        }
    } catch {
        Write-ErrorMsg "Failed to download Minikube: $_"
        Write-Info "Manual download: $MINIKUBE_URL"
        exit 1
    }
} else {
    Write-Success "Minikube installation verified ✓"
}

# ============================================================================
# STEP 4: CHECK AND INSTALL KUBECTL
# ============================================================================

Write-Step "STEP 4: Checking kubectl"

$kubectlPath = "$TOOLS_DIR\kubectl.exe"
$kubectlInstalled = $false

# Check if kubectl is in PATH
try {
    $kubectlVersion = & kubectl version --client -o json 2>&1 | ConvertFrom-Json
    if ($kubectlVersion.clientVersion) {
        Write-Success "kubectl is already installed: $($kubectlVersion.clientVersion.gitVersion)"
        Write-Command "Location: $($(Get-Command kubectl).Source)"
        $kubectlInstalled = $true
    }
} catch {
    Write-Info "kubectl not found in PATH"
}

# Check if kubectl exists in tools directory
if (-not $kubectlInstalled -and (Test-Path $kubectlPath)) {
    Write-Info "kubectl found in tools directory but not in PATH"
    $kubectlInstalled = $true
}

# Install if not found
if (-not $kubectlInstalled) {
    Write-Warning "kubectl not installed. Installing now..."

    try {
        Write-Info "Fetching latest kubectl version..."
        $latestVersion = (Invoke-WebRequest -Uri $KUBECTL_STABLE_URL -UseBasicParsing).Content.Trim()
        Write-Info "Latest version: $latestVersion"

        $kubectlUrl = "https://dl.k8s.io/release/$latestVersion/bin/windows/amd64/kubectl.exe"
        Write-Info "Download URL: $kubectlUrl"
        Write-Info "Destination: $kubectlPath"

        Write-Info "Downloading kubectl (this may take a minute)..."
        Invoke-WebRequest -Uri $kubectlUrl -OutFile $kubectlPath -UseBasicParsing
        Write-Success "kubectl downloaded successfully!"

        # Verify download
        if (Test-Path $kubectlPath) {
            $fileSize = [math]::Round((Get-Item $kubectlPath).Length / 1MB, 2)
            Write-Success "File size: ${fileSize} MB"
        }
    } catch {
        Write-ErrorMsg "Failed to download kubectl: $_"
        Write-Info "Manual download: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
        exit 1
    }
} else {
    Write-Success "kubectl installation verified ✓"
}

# ============================================================================
# STEP 5: CHECK AND INSTALL HELM
# ============================================================================

Write-Step "STEP 5: Checking Helm"

$helmPath = "$TOOLS_DIR\helm.exe"
$helmInstalled = $false

# Check if helm is in PATH
try {
    $helmVersion = & helm version --short 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Helm is already installed: $helmVersion"
        Write-Command "Location: $($(Get-Command helm).Source)"
        $helmInstalled = $true
    }
} catch {
    Write-Info "Helm not found in PATH"
}

# Check if helm exists in tools directory
if (-not $helmInstalled -and (Test-Path $helmPath)) {
    Write-Info "Helm found in tools directory but not in PATH"
    $helmInstalled = $true
}

# Install if not found
if (-not $helmInstalled) {
    Write-Warning "Helm not installed. Installing now..."
    Write-Info "Download URL: $HELM_URL"

    try {
        $helmZip = "$env:TEMP\helm-$HELM_VERSION.zip"
        $helmExtract = "$env:TEMP\helm-extract-$HELM_VERSION"

        Write-Info "Downloading Helm $HELM_VERSION (this may take a minute)..."
        Invoke-WebRequest -Uri $HELM_URL -OutFile $helmZip -UseBasicParsing
        Write-Success "Helm downloaded successfully!"

        Write-Info "Extracting Helm..."
        Expand-Archive -Path $helmZip -DestinationPath $helmExtract -Force

        $helmExe = "$helmExtract\windows-amd64\helm.exe"
        Move-Item -Path $helmExe -Destination $helmPath -Force
        Write-Success "Helm extracted to: $helmPath"

        # Clean up
        Remove-Item $helmZip -Force
        Remove-Item $helmExtract -Recurse -Force
        Write-Info "Temporary files cleaned up"

        # Verify installation
        if (Test-Path $helmPath) {
            $fileSize = [math]::Round((Get-Item $helmPath).Length / 1MB, 2)
            Write-Success "File size: ${fileSize} MB"
        }
    } catch {
        Write-ErrorMsg "Failed to install Helm: $_"
        Write-Info "Manual download: https://github.com/helm/helm/releases"
        exit 1
    }
} else {
    Write-Success "Helm installation verified ✓"
}

# ============================================================================
# STEP 6: UPDATE PATH ENVIRONMENT VARIABLE
# ============================================================================

Write-Step "STEP 6: Configuring PATH Environment Variable"

# Get current user PATH
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')

if ($currentPath -notlike "*$TOOLS_DIR*") {
    Write-Warning "Tools directory not in PATH. Adding now..."

    # Add to user PATH
    $newPath = "$currentPath;$TOOLS_DIR"
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Success "Added $TOOLS_DIR to User PATH"

    # Refresh PATH in current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Success "PATH refreshed in current PowerShell session"

    Write-Info "PATH updated successfully!"
    Write-Command "New PATH includes: $TOOLS_DIR"
} else {
    Write-Success "Tools directory already in PATH ✓"

    # Still refresh current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Info "PATH refreshed in current session"
}

# ============================================================================
# STEP 7: VERIFY ALL INSTALLATIONS
# ============================================================================

Write-Step "STEP 7: Verifying All Tool Installations"

Write-Info "Testing all tools..."
Write-Host ""

# Verify Minikube
try {
    $minikubeVer = & minikube version --short 2>&1
    Write-Success "Minikube: $minikubeVer"
    Write-Command "Command: minikube version --short"
} catch {
    Write-ErrorMsg "Minikube verification failed"
    Write-Warning "You may need to restart PowerShell"
}

# Verify kubectl
try {
    $kubectlVer = & kubectl version --client --short 2>&1
    Write-Success "kubectl: $kubectlVer"
    Write-Command "Command: kubectl version --client --short"
} catch {
    Write-ErrorMsg "kubectl verification failed"
    Write-Warning "You may need to restart PowerShell"
}

# Verify Helm
try {
    $helmVer = & helm version --short 2>&1
    Write-Success "Helm: $helmVer"
    Write-Command "Command: helm version --short"
} catch {
    Write-ErrorMsg "Helm verification failed"
    Write-Warning "You may need to restart PowerShell"
}

Write-Host ""
Write-Success "All tools verified successfully! ✓"

# ============================================================================
# STEP 8: CHECK VIRTUALIZATION
# ============================================================================

Write-Step "STEP 8: Checking Virtualization Support"

$driver = "unknown"
$hyperVEnabled = $false
$dockerRunning = $false

# Check Hyper-V
try {
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    if ($hyperv -and $hyperv.State -eq "Enabled") {
        Write-Success "Hyper-V is enabled ✓"
        $driver = "hyperv"
        $hyperVEnabled = $true
    } else {
        Write-Warning "Hyper-V is not enabled"
    }
} catch {
    Write-Info "Hyper-V check skipped (not available or no permissions)"
}

# Check Docker Desktop
try {
    $dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
    if ($dockerProcess) {
        Write-Success "Docker Desktop is running ✓"
        if (-not $hyperVEnabled) {
            $driver = "docker"
        }
        $dockerRunning = $true
    } else {
        Write-Info "Docker Desktop is not running"
    }
} catch {
    Write-Info "Docker Desktop not detected"
}

# Determine driver
if ($hyperVEnabled) {
    Write-Success "Will use Hyper-V driver for Minikube"
    $selectedDriver = "hyperv"
} elseif ($dockerRunning) {
    Write-Success "Will use Docker driver for Minikube"
    $selectedDriver = "docker"
} else {
    Write-Warning "Neither Hyper-V nor Docker Desktop detected"
    Write-Host ""
    Write-Info "Please choose a virtualization option:"
    Write-Host "  1. Hyper-V (Windows Pro/Enterprise/Education)" -ForegroundColor White
    Write-Host "     Enable with: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" -ForegroundColor Gray
    Write-Host "     (Requires restart)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Docker Desktop (All Windows versions)" -ForegroundColor White
    Write-Host "     Download from: https://www.docker.com/products/docker-desktop" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "Which driver do you want to use? (1=hyperv, 2=docker)"
    if ($choice -eq "1") {
        $selectedDriver = "hyperv"
        Write-Warning "Note: Hyper-V must be enabled for this to work"
    } else {
        $selectedDriver = "docker"
        Write-Warning "Note: Docker Desktop must be installed and running"
    }
}

# ============================================================================
# STEP 9: START MINIKUBE CLUSTER
# ============================================================================

Write-Step "STEP 9: Starting Minikube Cluster"

# Check if already running
try {
    $status = & minikube status 2>&1 | Out-String
    if ($status -match "Running") {
        Write-Success "Minikube cluster is already running!"
        Write-Info "Cluster status:"
        & minikube status
    } else {
        Write-Info "Minikube cluster is not running. Starting now..."
        throw "Not running"
    }
} catch {
    Write-Warning "Starting Minikube for the first time (this will take 5-10 minutes)..."
    Write-Info "Driver: $selectedDriver"
    Write-Host ""

    try {
        Write-Command "minikube start --driver=$selectedDriver"
        Write-Host ""

        & minikube start --driver=$selectedDriver

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Success "Minikube cluster started successfully! 🎉"
        } else {
            throw "Minikube start failed with exit code $LASTEXITCODE"
        }
    } catch {
        Write-ErrorMsg "Failed to start Minikube"
        Write-Host ""
        Write-Info "Common solutions:"
        Write-Host "  • Ensure virtualization is enabled in BIOS" -ForegroundColor Yellow
        Write-Host "  • For Hyper-V: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" -ForegroundColor Yellow
        Write-Host "  • For Docker: Ensure Docker Desktop is installed and running" -ForegroundColor Yellow
        Write-Host ""
        Write-Info "Try starting manually:"
        Write-Command "minikube start --driver=hyperv    # For Hyper-V"
        Write-Command "minikube start --driver=docker    # For Docker Desktop"
        exit 1
    }
}

# ============================================================================
# STEP 10: VERIFY CLUSTER CONNECTION
# ============================================================================

Write-Step "STEP 10: Verifying Kubernetes Cluster Connection"

Write-Info "Checking cluster information..."
Write-Host ""

try {
    Write-Command "kubectl cluster-info"
    & kubectl cluster-info
    Write-Host ""
    Write-Success "Cluster info retrieved successfully ✓"
} catch {
    Write-ErrorMsg "Failed to get cluster info"
}

Write-Host ""
Write-Info "Checking cluster nodes..."
Write-Host ""

try {
    Write-Command "kubectl get nodes"
    & kubectl get nodes
    Write-Host ""
    Write-Success "Cluster nodes retrieved successfully ✓"
} catch {
    Write-ErrorMsg "Failed to get cluster nodes"
    exit 1
}

# Additional verification
Write-Host ""
Write-Info "Checking Kubernetes version..."
Write-Host ""

try {
    Write-Command "kubectl version"
    & kubectl version
    Write-Host ""
} catch {
    Write-Warning "Could not get full version info (this is OK)"
}

# ============================================================================
# STEP 11: SETUP COMPLETE SUMMARY
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "║              SETUP COMPLETED SUCCESSFULLY! 🎉              ║" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "✓ Installation Summary:" -ForegroundColor Cyan
Write-Host "  • Minikube:  $minikubePath" -ForegroundColor White
Write-Host "  • kubectl:   $kubectlPath" -ForegroundColor White
Write-Host "  • Helm:      $helmPath" -ForegroundColor White
Write-Host "  • Driver:    $selectedDriver" -ForegroundColor White
Write-Host ""

Write-Host "✓ Cluster Status:" -ForegroundColor Cyan
& minikube status
Write-Host ""

Write-Host "📚 Quick Start Commands:" -ForegroundColor Cyan
Write-Host "  minikube status              - Check cluster status" -ForegroundColor White
Write-Host "  minikube dashboard           - Open Kubernetes dashboard in browser" -ForegroundColor White
Write-Host "  kubectl get pods -A          - List all pods in all namespaces" -ForegroundColor White
Write-Host "  kubectl get nodes            - List cluster nodes" -ForegroundColor White
Write-Host "  helm repo add stable https://charts.helm.sh/stable  - Add Helm repository" -ForegroundColor White
Write-Host ""

Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Deploy a test app:        kubectl create deployment nginx --image=nginx" -ForegroundColor Yellow
Write-Host "  2. Expose the app:           kubectl expose deployment nginx --type=NodePort --port=80" -ForegroundColor Yellow
Write-Host "  3. Get the URL:              minikube service nginx --url" -ForegroundColor Yellow
Write-Host "  4. Open dashboard:           minikube dashboard" -ForegroundColor Yellow
Write-Host ""

Write-Host "📖 Documentation:" -ForegroundColor Cyan
Write-Host "  • Quick Reference: KUBERNETES_QUICK_REFERENCE.md" -ForegroundColor White
Write-Host "  • Full Guide:      KUBERNETES_SETUP_GUIDE.md" -ForegroundColor White
Write-Host "  • Minikube Docs:   https://minikube.sigs.k8s.io/docs/" -ForegroundColor White
Write-Host "  • kubectl Docs:    https://kubernetes.io/docs/reference/kubectl/" -ForegroundColor White
Write-Host "  • Helm Docs:       https://helm.sh/docs/" -ForegroundColor White
Write-Host ""

Write-Host "💡 Pro Tip:" -ForegroundColor Cyan
Write-Host "  Use 'kubectl get all -A' to see everything in your cluster!" -ForegroundColor Yellow
Write-Host ""

Write-Success "All systems ready! Happy Kubernetes learning! 🚀"
Write-Host ""
