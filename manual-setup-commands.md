# Manual Kubernetes Setup Commands for Windows

This file contains individual commands you can copy-paste if you prefer step-by-step manual setup.

---

## 🔹 STEP 1: Check Current Installation Status

### Check if Minikube is installed
```powershell
minikube version
```
**Expected Output (if installed):**
```
minikube version: v1.34.0
commit: abc123...
```
**If not installed:** `minikube : The term 'minikube' is not recognized...`

---

### Check if kubectl is installed
```powershell
kubectl version --client
```
**Expected Output (if installed):**
```
Client Version: v1.31.2
Kustomize Version: v5.4.2
```
**If not installed:** `kubectl : The term 'kubectl' is not recognized...`

---

### Check if Helm is installed
```powershell
helm version
```
**Expected Output (if installed):**
```
version.BuildInfo{Version:"v4.1.0", GitCommit:"...", ...}
```
**If not installed:** `helm : The term 'helm' is not recognized...`

---

## 🔹 STEP 2: Refresh PATH (If tools not recognized)

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```
**Expected Output:** None (silent success)

**Then retry version commands from Step 1**

---

## 🔹 STEP 3: Manual Installation (If tools not found)

### Create tools directory
```powershell
New-Item -Path "$env:USERPROFILE\kube-tools" -ItemType Directory -Force
```
**Expected Output:**
```
    Directory: C:\Users\YourName

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----         2/2/2026   10:30 AM                kube-tools
```

---

### Download Minikube
```powershell
Invoke-WebRequest -Uri "https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe" -OutFile "$env:USERPROFILE\kube-tools\minikube.exe" -UseBasicParsing
```
**Expected Output:** Silent success (file downloads)

**Verify:**
```powershell
Test-Path "$env:USERPROFILE\kube-tools\minikube.exe"
```
**Expected:** `True`

---

### Download kubectl
```powershell
# Get latest version
$latestVersion = (Invoke-WebRequest -Uri "https://dl.k8s.io/release/stable.txt" -UseBasicParsing).Content.Trim()

# Download kubectl
Invoke-WebRequest -Uri "https://dl.k8s.io/release/$latestVersion/bin/windows/amd64/kubectl.exe" -OutFile "$env:USERPROFILE\kube-tools\kubectl.exe" -UseBasicParsing
```
**Expected Output:** Silent success

**Verify:**
```powershell
Test-Path "$env:USERPROFILE\kube-tools\kubectl.exe"
```
**Expected:** `True`

---

### Download and Install Helm
```powershell
# Download Helm
$helmVersion = "v4.1.0"
Invoke-WebRequest -Uri "https://get.helm.sh/helm-$helmVersion-windows-amd64.zip" -OutFile "$env:TEMP\helm.zip" -UseBasicParsing

# Extract
Expand-Archive -Path "$env:TEMP\helm.zip" -DestinationPath "$env:TEMP\helm" -Force

# Move to tools directory
Move-Item -Path "$env:TEMP\helm\windows-amd64\helm.exe" -Destination "$env:USERPROFILE\kube-tools\helm.exe" -Force

# Clean up
Remove-Item -Path "$env:TEMP\helm.zip" -Force
Remove-Item -Path "$env:TEMP\helm" -Recurse -Force
```
**Expected Output:** Silent success

**Verify:**
```powershell
Test-Path "$env:USERPROFILE\kube-tools\helm.exe"
```
**Expected:** `True`

---

## 🔹 STEP 4: Add to PATH Permanently

```powershell
# Get current PATH
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')

# Add tools directory if not already there
if ($currentPath -notlike "*$env:USERPROFILE\kube-tools*") {
    $newPath = "$currentPath;$env:USERPROFILE\kube-tools"
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "PATH updated successfully" -ForegroundColor Green
} else {
    Write-Host "Tools directory already in PATH" -ForegroundColor Yellow
}

# Refresh current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```
**Expected Output:**
```
PATH updated successfully
```

---

## 🔹 STEP 5: Verify All Installations

```powershell
# Verify all tools
minikube version
kubectl version --client
helm version
```
**Expected Output:**
```
minikube version: v1.34.0
...
Client Version: v1.31.2
...
version.BuildInfo{Version:"v4.1.0", ...}
```

---

## 🔹 STEP 6: Check Virtualization Support

### Check Hyper-V status
```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
```
**Expected Output (if enabled):**
```
FeatureName      : Microsoft-Hyper-V-All
State            : Enabled
```

**If disabled, enable with:**
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```
**⚠️ Requires restart after enabling**

---

### Check Docker Desktop (Alternative)
```powershell
Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
```
**Expected Output (if running):**
```
Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    ...     ...      ...        ...       ...   1234   1 Docker Desktop
```
**If not running:** No output

---

## 🔹 STEP 7: Start Minikube Cluster

### Check current status
```powershell
minikube status
```
**Expected Output (if not started):**
```
❌  There is no local cluster named "minikube"
```

---

### Start with Hyper-V
```powershell
minikube start --driver=hyperv
```
**Expected Output:**
```
😄  minikube v1.34.0 on Microsoft Windows 10 Pro 10.0.19045
✨  Using the hyperv driver based on user configuration
👍  Starting control plane node minikube in cluster minikube
🔥  Creating hyperv VM (CPUs=2, Memory=2200MB, Disk=20000MB) ...
🐳  Preparing Kubernetes v1.31.0 on Docker 27.2.0 ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

**⏱️ This takes 5-10 minutes on first run**

---

### Alternative: Start with Docker
```powershell
minikube start --driver=docker
```
**Expected Output:** Similar to above, but with Docker driver

**⚠️ Ensure Docker Desktop is running first**

---

## 🔹 STEP 8: Verify Cluster Connection

### Get cluster info
```powershell
kubectl cluster-info
```
**Expected Output:**
```
Kubernetes control plane is running at https://127.0.0.1:xxxxx
CoreDNS is running at https://127.0.0.1:xxxxx/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

---

### Get nodes
```powershell
kubectl get nodes
```
**Expected Output:**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   5m    v1.31.0
```

**✅ If you see "Ready", your cluster is working!**

---

### Get all pods
```powershell
kubectl get pods -A
```
**Expected Output:**
```
NAMESPACE     NAME                               READY   STATUS    RESTARTS   AGE
kube-system   coredns-xxxxx                      1/1     Running   0          5m
kube-system   etcd-minikube                      1/1     Running   0          5m
kube-system   kube-apiserver-minikube            1/1     Running   0          5m
...
```

**✅ All pods should show STATUS: Running**

---

## 🔹 STEP 9: Deploy Test Application (Optional)

### Create a deployment
```powershell
kubectl create deployment hello-k8s --image=kicbase/echo-server:1.0
```
**Expected Output:**
```
deployment.apps/hello-k8s created
```

---

### Expose as service
```powershell
kubectl expose deployment hello-k8s --type=NodePort --port=8080
```
**Expected Output:**
```
service/hello-k8s exposed
```

---

### Get service URL
```powershell
minikube service hello-k8s --url
```
**Expected Output:**
```
http://127.0.0.1:xxxxx
```

**🌐 Open this URL in your browser - you should see:**
```
Request served by hello-k8s-xxxxx-xxxxx
```

---

### Clean up test app
```powershell
kubectl delete service hello-k8s
kubectl delete deployment hello-k8s
```
**Expected Output:**
```
service "hello-k8s" deleted
deployment.apps "hello-k8s" deleted
```

---

## 🔹 STEP 10: Stop Minikube (When Done)

### Stop cluster (preserves data)
```powershell
minikube stop
```
**Expected Output:**
```
✋  Stopping node "minikube"  ...
🛑  1 node stopped.
```

---

### Delete cluster completely
```powershell
minikube delete
```
**Expected Output:**
```
🔥  Deleting "minikube" in hyperv ...
💀  Removed all traces of the "minikube" cluster.
```

---

## 🆘 Troubleshooting Common Errors

### Error: "VT-X is not available"
**Cause:** Virtualization disabled in BIOS

**Solution:**
1. Restart computer
2. Enter BIOS (F2/Del/F12 during boot)
3. Find "Virtualization Technology" or "VT-X"
4. Enable it
5. Save and exit

---

### Error: "This computer doesn't have VT-X/AMD-v enabled"
**Same as above** - Enable virtualization in BIOS

---

### Error: "Hyper-V is not installed"
**Solution:**
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```
**Then restart computer**

---

### Error: "Docker driver not found"
**Solution:**
1. Download Docker Desktop: https://www.docker.com/products/docker-desktop
2. Install and restart
3. Ensure Docker Desktop is running
4. Try: `minikube start --driver=docker`

---

### Error: "Unable to connect to server"
**Solution:**
```powershell
# Check if minikube is running
minikube status

# If not, start it
minikube start

# Update kubectl context
kubectl config use-context minikube
```

---

### Error: "Command not recognized" after installation
**Solution:**
```powershell
# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# OR close PowerShell and open a NEW window
```

---

## 📊 Quick Status Check

Run this to check everything at once:

```powershell
Write-Host "`n=== Tool Versions ===" -ForegroundColor Cyan
minikube version
kubectl version --client
helm version

Write-Host "`n=== Cluster Status ===" -ForegroundColor Cyan
minikube status

Write-Host "`n=== Cluster Nodes ===" -ForegroundColor Cyan
kubectl get nodes

Write-Host "`n=== All Pods ===" -ForegroundColor Cyan
kubectl get pods -A
```

---

## 📚 Resources

- **Minikube Docs:** https://minikube.sigs.k8s.io/docs/
- **kubectl Cheatsheet:** https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **Helm Docs:** https://helm.sh/docs/
- **Quick Reference:** See `KUBERNETES_QUICK_REFERENCE.md`
