# Complete Kubernetes Tools Installation Guide for Windows

**Target System:** Windows 10/11 | PowerShell | amd64 | Beginner-Friendly

This guide will install:
- Minikube (Local Kubernetes cluster)
- kubectl (Kubernetes CLI)
- Helm (Kubernetes package manager)
- kagent (AI-powered Kubernetes agent)

---

## Pre-Installation Checklist

### Step 0: Prepare Your System

1. **Open PowerShell as Administrator**
   - Press `Win + X`
   - Select "Windows PowerShell (Admin)" or "Terminal (Admin)"

2. **Check your system architecture**
   ```powershell
   systeminfo | findstr /B /C:"System Type"
   ```
   **Expected output:** `System Type: x64-based PC`

3. **Check PowerShell version**
   ```powershell
   $PSVersionTable.PSVersion
   ```
   **Expected output:** Version 5.1 or higher

4. **Enable script execution (required for installation scripts)**
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   ```
   **Expected output:** No errors

---

## Part 1: Install Minikube

### What is Minikube?
Minikube runs a local Kubernetes cluster on your Windows machine for development and learning.

### Step 1.1: Choose and Install a Driver

Minikube requires a virtualization driver. **Hyper-V** is recommended for Windows 10/11 Pro/Enterprise.

#### Option A: Enable Hyper-V (Recommended for Windows Pro/Enterprise)

```powershell
# Check if Hyper-V is available
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

# Enable Hyper-V
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
```

**⚠️ IMPORTANT:** You must restart your computer after this step.

```powershell
Restart-Computer
```

#### Option B: Install Docker Desktop (Alternative for Windows Home or if Hyper-V fails)

1. Download Docker Desktop from: https://www.docker.com/products/docker-desktop
2. Install and restart your computer
3. Open Docker Desktop and ensure it's running

### Step 1.2: Download Minikube

```powershell
# Create a directory for Kubernetes tools
New-Item -Path "$env:USERPROFILE\kube-tools" -ItemType Directory -Force

# Download the latest Minikube executable
Invoke-WebRequest -Uri "https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe" -OutFile "$env:USERPROFILE\kube-tools\minikube.exe"
```

**Expected output:**
```
    Directory: C:\Users\YourUsername\kube-tools

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----        2/2/2026   10:30 AM       87654321 minikube.exe
```

### Step 1.3: Add Minikube to PATH

```powershell
# Add the directory to PATH (User level)
$oldPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$newPath = "$oldPath;$env:USERPROFILE\kube-tools"
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

# Refresh PATH in current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

**Expected output:** No output means success.

### Step 1.4: Verify Minikube Installation

```powershell
minikube version
```

**Expected output:**
```
minikube version: v1.34.0
commit: abc123def456...
```

### Step 1.5: Start Minikube (This will also install kubectl if not present)

```powershell
# Start with Hyper-V driver
minikube start --driver=hyperv

# OR if using Docker Desktop:
# minikube start --driver=docker
```

**Expected output:**
```
😄  minikube v1.34.0 on Microsoft Windows 10 Pro 10.0.19045
✨  Using the hyperv driver based on user configuration
👍  Starting control plane node minikube in cluster minikube
🔥  Creating hyperv VM (CPUs=2, Memory=2200MB, Disk=20000MB) ...
🐳  Preparing Kubernetes v1.31.0 on Docker 27.2.0 ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

**⏱️ This may take 5-10 minutes on first run.**

**Common Issues:**

| Error | Solution |
|-------|----------|
| `Hyper-V is not installed` | Go back to Step 1.1 Option A and enable Hyper-V |
| `This computer doesn't have VT-X/AMD-v enabled` | Enable virtualization in BIOS (restart → F2/Del → Enable VT-X) |
| `Docker driver not found` | Install Docker Desktop and ensure it's running |

---

## Part 2: Install kubectl

### What is kubectl?
kubectl is the command-line tool for interacting with Kubernetes clusters.

### Step 2.1: Check if kubectl was installed by Minikube

```powershell
kubectl version --client
```

If this works, **kubectl is already installed** and you can skip to Part 3.

If you get `kubectl : The term 'kubectl' is not recognized`, continue below.

### Step 2.2: Download kubectl Manually

```powershell
# Get the latest stable version
$latestVersion = (Invoke-WebRequest -Uri "https://dl.k8s.io/release/stable.txt" -UseBasicParsing).Content.Trim()

# Download kubectl
Invoke-WebRequest -Uri "https://dl.k8s.io/release/$latestVersion/bin/windows/amd64/kubectl.exe" -OutFile "$env:USERPROFILE\kube-tools\kubectl.exe"
```

**Expected output:** File downloaded to `C:\Users\YourUsername\kube-tools\kubectl.exe`

### Step 2.3: Verify kubectl Installation

```powershell
# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

kubectl version --client
```

**Expected output:**
```
Client Version: v1.31.2
Kustomize Version: v5.4.2
```

### Step 2.4: Test kubectl with Minikube

```powershell
kubectl cluster-info
```

**Expected output:**
```
Kubernetes control plane is running at https://127.0.0.1:xxxxx
CoreDNS is running at https://127.0.0.1:xxxxx/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

```powershell
kubectl get nodes
```

**Expected output:**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   10m   v1.31.0
```

**✅ If you see this, kubectl is properly configured!**

---

## Part 3: Install Helm

### What is Helm?
Helm is a package manager for Kubernetes, like apt or yum for Linux.

### Step 3.1: Download Helm

```powershell
# Check the latest version at https://github.com/helm/helm/releases
# As of Feb 2026, the latest is v4.1.0

$helmVersion = "v4.1.0"
$helmUrl = "https://get.helm.sh/helm-$helmVersion-windows-amd64.zip"

# Download Helm
Invoke-WebRequest -Uri $helmUrl -OutFile "$env:TEMP\helm.zip"
```

**Expected output:** No errors

### Step 3.2: Extract Helm

```powershell
# Extract the zip file
Expand-Archive -Path "$env:TEMP\helm.zip" -DestinationPath "$env:TEMP\helm" -Force

# Move helm.exe to our tools directory
Move-Item -Path "$env:TEMP\helm\windows-amd64\helm.exe" -Destination "$env:USERPROFILE\kube-tools\helm.exe" -Force

# Clean up
Remove-Item -Path "$env:TEMP\helm.zip" -Force
Remove-Item -Path "$env:TEMP\helm" -Recurse -Force
```

**Expected output:** No errors

### Step 3.3: Verify Helm Installation

```powershell
# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

helm version
```

**Expected output:**
```
version.BuildInfo{Version:"v4.1.0", GitCommit:"abc123...", GitTreeState:"clean", GoVersion:"go1.23.4"}
```

### Step 3.4: Initialize Helm and Add a Repository

```powershell
# Add the stable repository
helm repo add stable https://charts.helm.sh/stable

# Update repositories
helm repo update
```

**Expected output:**
```
"stable" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈
```

### Step 3.5: Test Helm

```powershell
helm list --all-namespaces
```

**Expected output:**
```
NAME    NAMESPACE       REVISION        UPDATED STATUS  CHART   APP VERSION
```
(Empty list is normal if you haven't installed any Helm charts yet)

**✅ Helm is ready to use!**

---

## Part 4: Install kagent

### What is kagent?
kagent is an AI-powered Kubernetes assistant that helps you manage your cluster using natural language.

### Step 4.1: Install kagent CLI (Linux-style - Requires Git Bash or WSL)

**⚠️ Important:** The official kagent CLI installation script is designed for Linux/Mac. For Windows, we'll use the **Helm installation method** which is more reliable.

### Step 4.2: Install kagent via Helm (Recommended for Windows)

First, ensure Minikube is running:

```powershell
minikube status
```

**Expected output:**
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

If not running, start it:
```powershell
minikube start
```

### Step 4.3: Install kagent CRDs (Custom Resource Definitions)

```powershell
# Install kagent CRDs
helm install kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds --namespace kagent --create-namespace
```

**Expected output:**
```
Pulled: ghcr.io/kagent-dev/kagent/helm/kagent-crds:x.x.x
Digest: sha256:abc123...
NAME: kagent-crds
LAST DEPLOYED: Sun Feb  2 10:45:00 2026
NAMESPACE: kagent
STATUS: deployed
REVISION: 1
```

### Step 4.4: Set Up API Key for AI Provider

kagent requires an AI provider (OpenAI, Anthropic, etc.). For this guide, we'll use **Anthropic Claude** (you can substitute with OpenAI if you prefer).

```powershell
# Set your Anthropic API key (replace with your actual key)
$env:ANTHROPIC_API_KEY = "sk-ant-api03-your-key-here"
```

**⚠️ Replace `sk-ant-api03-your-key-here` with your actual API key from https://console.anthropic.com/**

### Step 4.5: Install kagent

```powershell
helm upgrade --install kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent `
  --namespace kagent `
  --set providers.default=anthropic `
  --set providers.anthropic.apiKey=$env:ANTHROPIC_API_KEY `
  --set ui.service.type=NodePort
```

**Expected output:**
```
Release "kagent" does not exist. Installing it now.
Pulled: ghcr.io/kagent-dev/kagent/helm/kagent:x.x.x
Digest: sha256:def456...
NAME: kagent
LAST DEPLOYED: Sun Feb  2 10:50:00 2026
NAMESPACE: kagent
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing kagent!
...
```

### Step 4.6: Verify kagent Installation

```powershell
# Check kagent pods
kubectl get pods -n kagent
```

**Expected output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
kagent-controller-xxxxx-yyyyy     1/1     Running   0          2m
kagent-ui-xxxxx-zzzzz             1/1     Running   0          2m
```

Wait until all pods show `Running` status.

### Step 4.7: Access kagent UI

```powershell
# Get the UI service URL
minikube service kagent-ui -n kagent --url
```

**Expected output:**
```
http://127.0.0.1:xxxxx
```

Open this URL in your browser to access the kagent dashboard!

**✅ kagent is installed and ready!**

---

## Part 5: Final Verification & Testing

### Step 5.1: Verify All Tools

Run this verification script:

```powershell
Write-Host "`n=== Kubernetes Tools Verification ===" -ForegroundColor Cyan

# Minikube
Write-Host "`n[1/4] Minikube:" -ForegroundColor Yellow
minikube version
minikube status

# kubectl
Write-Host "`n[2/4] kubectl:" -ForegroundColor Yellow
kubectl version --client
kubectl get nodes

# Helm
Write-Host "`n[3/4] Helm:" -ForegroundColor Yellow
helm version
helm repo list

# kagent
Write-Host "`n[4/4] kagent:" -ForegroundColor Yellow
kubectl get pods -n kagent

Write-Host "`n=== All tools verified! ===" -ForegroundColor Green
```

### Step 5.2: Create a Test Deployment

Test your setup by deploying a simple application:

```powershell
# Create a test deployment
kubectl create deployment hello-minikube --image=kicbase/echo-server:1.0

# Expose it as a service
kubectl expose deployment hello-minikube --type=NodePort --port=8080

# Get the service URL
minikube service hello-minikube --url
```

**Expected output:**
```
http://127.0.0.1:xxxxx
```

Open the URL in your browser - you should see "Request served by hello-minikube-xxxxx"

**Clean up:**
```powershell
kubectl delete service hello-minikube
kubectl delete deployment hello-minikube
```

---

## Part 6: Common Issues & Troubleshooting

### Issue 1: "Command not recognized" after installation

**Cause:** PATH not refreshed in current PowerShell session

**Solution:**
```powershell
# Manually refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# OR close PowerShell and open a NEW window
```

### Issue 2: SSL/TLS download errors

**Cause:** Windows SSL certificate issues

**Solution:**
```powershell
# Use this parameter in Invoke-WebRequest
Invoke-WebRequest -Uri "URL" -OutFile "file.exe" -UseBasicParsing

# Or update .NET Framework / Windows
```

### Issue 3: Minikube won't start - "VT-X is not available"

**Cause:** Virtualization disabled in BIOS

**Solution:**
1. Restart computer
2. Enter BIOS (usually F2, Del, or F12 during boot)
3. Find "Virtualization Technology" or "VT-X" or "AMD-V"
4. Enable it
5. Save and exit

### Issue 4: Hyper-V conflicts with VirtualBox/VMware

**Cause:** Hyper-V and other hypervisors can't run simultaneously

**Solution:**
```powershell
# Use Docker driver instead
minikube start --driver=docker

# Or disable Hyper-V if you need other hypervisors
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
```

### Issue 5: kubectl can't connect to cluster

**Cause:** Minikube not running or kubeconfig issue

**Solution:**
```powershell
# Check minikube status
minikube status

# If stopped, start it
minikube start

# Update kubectl context
kubectl config use-context minikube
```

### Issue 6: Helm "connection refused" errors

**Cause:** Kubernetes cluster not running

**Solution:**
```powershell
# Ensure minikube is running
minikube start

# Verify kubectl can connect
kubectl cluster-info
```

### Issue 7: kagent pods stuck in "Pending" or "ImagePullBackOff"

**Cause:** Resource constraints or network issues

**Solution:**
```powershell
# Check pod details
kubectl describe pod <pod-name> -n kagent

# Increase minikube resources
minikube stop
minikube start --memory=4096 --cpus=2

# Reinstall kagent
helm uninstall kagent -n kagent
helm uninstall kagent-crds -n kagent
# Then repeat Part 4
```

---

## Part 7: Daily Usage Commands

### Start Your Environment

```powershell
# Start Minikube
minikube start

# Verify cluster
kubectl get nodes

# Check all namespaces
kubectl get all --all-namespaces
```

### Stop Your Environment

```powershell
# Stop Minikube (preserves cluster state)
minikube stop

# OR delete the cluster entirely
minikube delete
```

### Quick Reference

```powershell
# Minikube
minikube status              # Check status
minikube dashboard           # Open Kubernetes dashboard
minikube ip                  # Get cluster IP
minikube ssh                 # SSH into the node

# kubectl
kubectl get pods             # List pods
kubectl get services         # List services
kubectl get deployments      # List deployments
kubectl logs <pod-name>      # View logs
kubectl describe pod <name>  # Detailed info

# Helm
helm list                    # List installed charts
helm search repo <keyword>   # Search for charts
helm install <name> <chart>  # Install a chart
helm uninstall <name>        # Remove a chart

# kagent
minikube service kagent-ui -n kagent --url   # Get UI URL
kubectl logs -n kagent -l app=kagent-controller  # View logs
```

---

## Part 8: Next Steps

### 1. Learn Kubernetes Basics
```powershell
# Deploy an example app
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
minikube service nginx --url
```

### 2. Explore Helm Charts
```powershell
# Search for charts
helm search hub wordpress

# Install WordPress
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-wordpress bitnami/wordpress
```

### 3. Try kagent
- Open the kagent UI (from Step 4.7)
- Ask questions like "Show me all pods" or "What's the cluster status?"

### 4. Enable Minikube Addons
```powershell
# List available addons
minikube addons list

# Enable useful addons
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable ingress
```

---

## Summary of Installed Locations

| Tool | Location | Version Command |
|------|----------|-----------------|
| Minikube | `C:\Users\YourUsername\kube-tools\minikube.exe` | `minikube version` |
| kubectl | `C:\Users\YourUsername\kube-tools\kubectl.exe` | `kubectl version --client` |
| Helm | `C:\Users\YourUsername\kube-tools\helm.exe` | `helm version` |
| kagent | Deployed in Kubernetes (kagent namespace) | `kubectl get pods -n kagent` |

**PATH Environment Variable:**
- Added `C:\Users\YourUsername\kube-tools` to User PATH

---

## Sources & Official Documentation

- **Minikube**: [minikube.sigs.k8s.io/docs/start/](https://minikube.sigs.k8s.io/docs/start/)
- **kubectl**: [kubernetes.io/docs/tasks/tools/install-kubectl-windows/](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)
- **Helm**: [helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)
- **kagent**: [github.com/kagent-dev/kagent](https://github.com/kagent-dev/kagent)

---

**🎉 Congratulations! You now have a complete Kubernetes development environment on Windows!**

For questions or issues:
- Minikube: https://github.com/kubernetes/minikube/issues
- kubectl: https://kubernetes.io/docs/reference/kubectl/
- Helm: https://helm.sh/docs/
- kagent: https://github.com/kagent-dev/kagent/issues
