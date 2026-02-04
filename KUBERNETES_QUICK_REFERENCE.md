# Kubernetes Tools - Quick Reference Card

**For Windows PowerShell** | Last Updated: Feb 2026

---

## 🚀 Daily Startup/Shutdown

```powershell
# Start your environment
minikube start

# Check status
minikube status

# Stop (preserves data)
minikube stop

# Delete everything
minikube delete
```

---

## 📦 Minikube Commands

| Command | Description |
|---------|-------------|
| `minikube start` | Start local Kubernetes cluster |
| `minikube stop` | Stop cluster (keeps data) |
| `minikube delete` | Delete cluster completely |
| `minikube status` | Check cluster status |
| `minikube dashboard` | Open Kubernetes web UI |
| `minikube ip` | Get cluster IP address |
| `minikube ssh` | SSH into the cluster node |
| `minikube service <name>` | Get URL for a service |
| `minikube addons list` | List available addons |
| `minikube addons enable <name>` | Enable an addon |

**Common Addons:**
```powershell
minikube addons enable dashboard       # Kubernetes dashboard
minikube addons enable metrics-server  # Resource metrics
minikube addons enable ingress         # Ingress controller
```

---

## ☸️ kubectl Commands

### Cluster Info
```powershell
kubectl cluster-info              # Cluster information
kubectl get nodes                 # List nodes
kubectl version                   # kubectl and cluster versions
kubectl config view               # View kubeconfig
kubectl config use-context <ctx>  # Switch context
```

### Working with Pods
```powershell
kubectl get pods                      # List pods in default namespace
kubectl get pods -A                   # List ALL pods in all namespaces
kubectl get pods -n <namespace>       # List pods in specific namespace
kubectl describe pod <pod-name>       # Detailed pod info
kubectl logs <pod-name>               # View pod logs
kubectl logs <pod-name> -f            # Follow/stream logs
kubectl logs <pod-name> --previous    # Logs from previous container
kubectl exec -it <pod-name> -- /bin/sh  # Shell into pod
kubectl delete pod <pod-name>         # Delete a pod
```

### Working with Deployments
```powershell
kubectl get deployments               # List deployments
kubectl create deployment <name> --image=<image>  # Create deployment
kubectl scale deployment <name> --replicas=3      # Scale deployment
kubectl set image deployment/<name> <container>=<new-image>  # Update image
kubectl rollout status deployment/<name>          # Check rollout status
kubectl rollout undo deployment/<name>            # Rollback deployment
kubectl delete deployment <name>                  # Delete deployment
```

### Working with Services
```powershell
kubectl get services                  # List services
kubectl get svc                       # Short form
kubectl expose deployment <name> --type=NodePort --port=80  # Expose deployment
kubectl describe service <name>       # Service details
kubectl delete service <name>         # Delete service
```

### Namespaces
```powershell
kubectl get namespaces                # List namespaces
kubectl create namespace <name>       # Create namespace
kubectl delete namespace <name>       # Delete namespace
kubectl config set-context --current --namespace=<name>  # Set default namespace
```

### Debugging
```powershell
kubectl describe pod <pod-name>       # Detailed info + events
kubectl logs <pod-name>               # Container logs
kubectl get events                    # Cluster events
kubectl get events --sort-by=.metadata.creationTimestamp  # Sorted events
kubectl top nodes                     # Node resource usage
kubectl top pods                      # Pod resource usage
```

### Quick Operations
```powershell
kubectl get all                       # Get all resources
kubectl get all -A                    # Get all resources in all namespaces
kubectl apply -f <file.yaml>          # Apply configuration from file
kubectl delete -f <file.yaml>         # Delete resources from file
kubectl run <name> --image=<image>    # Quick pod creation
```

---

## ⚓ Helm Commands

### Repository Management
```powershell
helm repo add <name> <url>            # Add a repository
helm repo list                        # List repositories
helm repo update                      # Update repository info
helm repo remove <name>               # Remove repository
helm search repo <keyword>            # Search for charts
helm search hub <keyword>             # Search Helm Hub
```

**Popular Repositories:**
```powershell
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

### Chart Management
```powershell
helm install <name> <chart>           # Install a chart
helm list                             # List installed releases
helm list -A                          # List all releases in all namespaces
helm status <name>                    # Show release status
helm upgrade <name> <chart>           # Upgrade a release
helm rollback <name>                  # Rollback to previous version
helm uninstall <name>                 # Uninstall a release
helm get values <name>                # Get values of a release
```

### Examples
```powershell
# Install WordPress
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-wordpress bitnami/wordpress

# Install with custom values
helm install my-release bitnami/nginx --set service.type=NodePort

# Upgrade release
helm upgrade my-wordpress bitnami/wordpress --set wordpressUsername=admin2
```

---

## 🤖 kagent Commands

### Check kagent Status
```powershell
kubectl get pods -n kagent            # List kagent pods
kubectl logs -n kagent -l app=kagent-controller  # View controller logs
kubectl get agents                    # List AI agents (if CRD installed)
```

### Access kagent UI
```powershell
minikube service kagent-ui -n kagent --url  # Get UI URL
```

### Manage kagent
```powershell
# Reinstall kagent
helm uninstall kagent -n kagent
helm install kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent \
  --namespace kagent \
  --set providers.default=anthropic \
  --set providers.anthropic.apiKey=$env:ANTHROPIC_API_KEY
```

---

## 🔧 Troubleshooting

### Minikube Issues

**Problem: "VT-X is not available"**
```
Solution: Enable virtualization in BIOS
1. Restart computer
2. Enter BIOS (F2/Del/F12)
3. Enable "Virtualization Technology" or "VT-X"
4. Save and exit
```

**Problem: Minikube won't start**
```powershell
# Delete and recreate cluster
minikube delete
minikube start

# Check driver
minikube start --driver=docker  # If Hyper-V fails
```

**Problem: Cluster is slow**
```powershell
# Increase resources
minikube delete
minikube start --memory=4096 --cpus=2
```

### kubectl Issues

**Problem: "Unable to connect to server"**
```powershell
# Check minikube status
minikube status

# Start minikube
minikube start

# Update context
kubectl config use-context minikube
```

**Problem: "Command not found"**
```powershell
# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Or restart PowerShell
```

### Pod Issues

**Problem: Pod stuck in "Pending"**
```powershell
# Check pod events
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes
```

**Problem: Pod in "ImagePullBackOff"**
```powershell
# Check image name
kubectl describe pod <pod-name>

# Use correct image
kubectl set image deployment/<name> <container>=<correct-image>
```

**Problem: Pod in "CrashLoopBackOff"**
```powershell
# Check logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# Check pod events
kubectl describe pod <pod-name>
```

---

## 📊 Useful One-Liners

```powershell
# Get all pods sorted by restart count
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount' -A

# Get all pods sorted by age
kubectl get pods --sort-by=.metadata.creationTimestamp -A

# Watch pods in real-time
kubectl get pods -w

# Get pod IP addresses
kubectl get pods -o wide

# Get all images used in cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u

# Delete all failed pods
kubectl delete pods --field-selector status.phase=Failed -A

# Port forward to a pod
kubectl port-forward <pod-name> 8080:80

# Copy file from pod
kubectl cp <pod-name>:/path/to/file ./local-file

# Get resource usage
kubectl top nodes
kubectl top pods -A

# Get events sorted by time
kubectl get events --sort-by=.metadata.creationTimestamp -A
```

---

## 🎯 Common Workflows

### Deploy a Simple App
```powershell
# Create deployment
kubectl create deployment nginx --image=nginx

# Expose as service
kubectl expose deployment nginx --type=NodePort --port=80

# Get URL
minikube service nginx --url

# Visit URL in browser

# Clean up
kubectl delete service nginx
kubectl delete deployment nginx
```

### Install an App with Helm
```powershell
# Add repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repos
helm repo update

# Install chart
helm install my-app bitnami/nginx

# Check status
helm status my-app
kubectl get pods

# Get service URL
minikube service my-app-nginx --url

# Clean up
helm uninstall my-app
```

### Debug a Failing Pod
```powershell
# Check pod status
kubectl get pods

# Get detailed info
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# If restarting, check previous logs
kubectl logs <pod-name> --previous

# Shell into pod (if running)
kubectl exec -it <pod-name> -- /bin/sh

# Check events
kubectl get events --field-selector involvedObject.name=<pod-name>
```

---

## 🔐 Environment Variables for kagent

```powershell
# Set Anthropic API key
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."

# Set OpenAI API key (alternative)
$env:OPENAI_API_KEY = "sk-..."

# Verify
echo $env:ANTHROPIC_API_KEY
```

---

## 📚 Documentation Links

- **Minikube**: https://minikube.sigs.k8s.io/docs/
- **kubectl**: https://kubernetes.io/docs/reference/kubectl/
- **Helm**: https://helm.sh/docs/
- **kagent**: https://github.com/kagent-dev/kagent
- **Kubernetes**: https://kubernetes.io/docs/

---

## 💡 Pro Tips

1. **Use aliases** (add to PowerShell profile):
   ```powershell
   Set-Alias -Name k -Value kubectl
   ```

2. **Enable kubectl autocomplete** (PowerShell):
   ```powershell
   kubectl completion powershell | Out-String | Invoke-Expression
   ```

3. **Use shorter commands**:
   - `kubectl get po` instead of `kubectl get pods`
   - `kubectl get svc` instead of `kubectl get services`
   - `kubectl get deploy` instead of `kubectl get deployments`

4. **Watch resources in real-time**:
   ```powershell
   kubectl get pods -w
   ```

5. **Use labels for organization**:
   ```powershell
   kubectl get pods -l app=nginx
   ```

6. **Export resources to YAML**:
   ```powershell
   kubectl get deployment nginx -o yaml > nginx-deployment.yaml
   ```

---

**Need more help?** See `KUBERNETES_SETUP_GUIDE.md` for detailed installation and troubleshooting.
