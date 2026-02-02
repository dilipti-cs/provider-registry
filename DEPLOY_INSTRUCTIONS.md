# 🚀 Deploy to GCP - Execute Now

This guide will deploy your Provider Registry application to GCP in **one command**.

## Prerequisites

Before running the deployment, ensure you have:

1. **Google Cloud Account** with billing enabled
2. **gcloud CLI** installed on your local machine
3. **kubectl** installed (comes with gcloud)
4. **GCP Project** created

## Quick Setup (5 minutes)

### Step 1: Install gcloud CLI (if needed)

```bash
# Linux/macOS
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Windows
# Download from: https://cloud.google.com/sdk/docs/install

# Verify installation
gcloud version
```

### Step 2: Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
```

### Step 3: Set Environment Variables

```bash
# Set your GCP project ID
export GCP_PROJECT_ID="your-gcp-project-id"

# Optional: customize region
export GCP_REGION="us-central1"
export CLUSTER_NAME="provider-registry-cluster"
```

## 🎯 One-Command Deployment

From the root of this repository, run:

```bash
./scripts/deploy-from-local.sh
```

This single script will:
1. ✅ Enable required GCP APIs
2. ✅ Create GKE cluster (if doesn't exist)
3. ✅ Build and push Docker image to Google Container Registry
4. ✅ Deploy PostgreSQL database
5. ✅ Deploy Redis cache
6. ✅ Deploy Medplum FHIR server
7. ✅ Initialize Medplum database
8. ✅ Create admin user
9. ✅ Deploy React frontend
10. ✅ Configure all services

**Estimated time**: 15-20 minutes
**Estimated cost**: ~$160/month (production) or ~$30/month (dev)

## What Happens During Deployment

### Phase 1: Infrastructure (5-10 min)
- Creates a GKE cluster with 2 nodes (e2-standard-4)
- Configures autoscaling (1-10 nodes)
- Sets up networking and firewall rules

### Phase 2: Build (3-5 min)
- Builds Docker image
- Pushes to Google Container Registry

### Phase 3: Deployment (5-10 min)
- Deploys PostgreSQL (StatefulSet)
- Deploys Redis (Deployment)
- Deploys Medplum Server (2 replicas)
- Deploys Frontend (3 replicas)
- Initializes database and creates admin

### Phase 4: Verification (1 min)
- Waits for all pods to be ready
- Verifies health checks
- Displays access instructions

## Accessing Your Application

After deployment completes, the script will show you the access instructions:

### Via Port Forwarding (Immediate)

```bash
# Terminal 1 - Frontend
kubectl port-forward -n provider-registry service/frontend-service 3001:80

# Terminal 2 - Medplum API
kubectl port-forward -n provider-registry service/medplum-service 8103:8103
```

Then open:
- **Frontend**: http://localhost:3001
- **API**: http://localhost:8103

### Via Load Balancer (Production)

If you want to expose via a public URL:

```bash
# Deploy ingress
kubectl apply -f k8s/ingress.yaml

# Get the load balancer IP
kubectl get ingress -n provider-registry

# Wait for IP assignment (5-10 minutes)
```

Point your DNS records to the Load Balancer IP.

## Deployment Options

### Option 1: Full Automated Deployment (Recommended)

```bash
./scripts/deploy-from-local.sh
```

Uses default configuration, creates everything automatically.

### Option 2: Custom Configuration

```bash
# Edit configuration first
nano terraform/terraform.tfvars
nano k8s/configmap.yaml
nano k8s/secrets.yaml

# Then deploy
./scripts/deploy-from-local.sh
```

### Option 3: Step-by-Step Manual

Follow the detailed guide in [GCP_DEPLOYMENT.md](./GCP_DEPLOYMENT.md)

## Monitoring Your Deployment

### Check Status

```bash
# All resources
kubectl get all -n provider-registry

# Pods
kubectl get pods -n provider-registry

# Services
kubectl get services -n provider-registry
```

### View Logs

```bash
# Frontend logs
kubectl logs -n provider-registry -l app=provider-registry-frontend -f

# Medplum logs
kubectl logs -n provider-registry -l app=medplum-server -f

# PostgreSQL logs
kubectl logs -n provider-registry -l app=postgres -f
```

### Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n provider-registry
```

## Troubleshooting

### Deployment Fails

```bash
# Check pod status
kubectl get pods -n provider-registry

# Describe failing pod
kubectl describe pod <pod-name> -n provider-registry

# View events
kubectl get events -n provider-registry --sort-by='.lastTimestamp'
```

### Can't Access Application

```bash
# Verify pods are running
kubectl get pods -n provider-registry

# Check services
kubectl get services -n provider-registry

# Restart port-forward
kubectl port-forward -n provider-registry service/frontend-service 3001:80
```

### Database Issues

```bash
# Check PostgreSQL
kubectl exec -n provider-registry -it <postgres-pod> -- pg_isready -U medplum

# View Medplum logs
kubectl logs -n provider-registry -l app=medplum-server --tail=100
```

## Cost Management

### Development Environment

For testing/development, reduce costs:

```bash
# After initial deployment, scale down
kubectl scale deployment medplum-server -n provider-registry --replicas=1
kubectl scale deployment provider-registry-frontend -n provider-registry --replicas=1

# This reduces cost to ~$50-70/month
```

### Cleanup When Not In Use

```bash
# Delete application (keep cluster)
./scripts/cleanup.sh

# Delete cluster (removes everything)
gcloud container clusters delete provider-registry-cluster --region us-central1
```

## What Gets Created

### GCP Resources

- **GKE Cluster**: 2-node cluster (autoscaling 1-10)
- **Container Registry**: Docker images stored in GCR
- **Load Balancer**: (if ingress is deployed)
- **Persistent Disks**: For PostgreSQL and Redis data

### Kubernetes Resources

In namespace `provider-registry`:
- **StatefulSet**: PostgreSQL (1 replica, 10GB volume)
- **Deployment**: Redis (1 replica, 5GB volume)
- **Deployment**: Medplum Server (2 replicas)
- **Deployment**: Frontend (3 replicas)
- **Services**: ClusterIP for all components
- **ConfigMap**: Application configuration
- **Secrets**: Database passwords
- **Ingress**: (optional) Load balancer configuration

## Security Notes

1. **Secrets**: The script generates random passwords automatically
2. **Never commit secrets** to Git
3. For production, use **Google Secret Manager**
4. The default admin password should be changed after first login
5. Enable **Cloud Armor** for DDoS protection (production)

## Production Checklist

Before going live:
- [ ] Change admin password
- [ ] Setup custom domain with SSL
- [ ] Configure Cloud SQL (instead of in-cluster PostgreSQL)
- [ ] Configure Cloud Memorystore (instead of in-cluster Redis)
- [ ] Enable monitoring and alerting
- [ ] Setup automated backups
- [ ] Review and adjust resource limits
- [ ] Enable audit logging
- [ ] Perform security audit
- [ ] Load testing
- [ ] Disaster recovery plan

## Support

### Documentation
- **Quick Start**: This file (DEPLOY_INSTRUCTIONS.md)
- **Detailed Guide**: [GCP_DEPLOYMENT.md](./GCP_DEPLOYMENT.md)
- **Kubernetes Guide**: [k8s/README.md](./k8s/README.md)

### Get Help
- Check logs: `kubectl logs -n provider-registry <pod-name>`
- Check events: `kubectl get events -n provider-registry`
- GCP Console: https://console.cloud.google.com

### Estimated Costs

| Configuration | Monthly Cost |
|--------------|--------------|
| Development (1 small node) | $30-50 |
| Staging (1-2 medium nodes) | $80-120 |
| Production (2-3 large nodes + LB) | $160-200 |

Use the [GCP Pricing Calculator](https://cloud.google.com/products/calculator) for accurate estimates.

---

## 🎯 Quick Command Reference

```bash
# Deploy everything
./scripts/deploy-from-local.sh

# Access application
kubectl port-forward -n provider-registry service/frontend-service 3001:80

# View logs
kubectl logs -n provider-registry -l app=provider-registry-frontend -f

# Check status
kubectl get pods -n provider-registry

# Scale up/down
kubectl scale deployment provider-registry-frontend -n provider-registry --replicas=5

# Cleanup
./scripts/cleanup.sh

# Delete cluster
gcloud container clusters delete provider-registry-cluster --region us-central1
```

---

**Ready to Deploy?**

```bash
export GCP_PROJECT_ID="your-project-id"
./scripts/deploy-from-local.sh
```

🚀 Let's go!
