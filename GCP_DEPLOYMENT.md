# GCP Deployment Guide for Provider Registry

This guide will walk you through deploying the Provider Registry application to Google Cloud Platform (GCP) using Google Kubernetes Engine (GKE).

## Architecture Overview

The deployment uses the following GCP services:

- **Google Kubernetes Engine (GKE)**: Container orchestration
- **Google Container Registry (GCR)**: Docker image storage
- **Cloud Build**: CI/CD pipeline
- **Cloud Load Balancing**: Traffic distribution and SSL termination
- **Persistent Disks**: Data storage for PostgreSQL and Redis

### Application Components

1. **PostgreSQL 16**: FHIR data storage (StatefulSet)
2. **Redis 7**: Caching and session storage
3. **Medplum Server**: FHIR R4 API backend
4. **Provider Registry Frontend**: React application

## Prerequisites

### 1. Install Required Tools

```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Install kubectl
gcloud components install kubectl

# Install Terraform (for infrastructure setup)
# Visit: https://www.terraform.io/downloads
```

### 2. GCP Account Setup

```bash
# Login to GCP
gcloud auth login

# Set your project (replace with your project ID)
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### 3. Set Environment Variables

```bash
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"
export CLUSTER_NAME="provider-registry-cluster"
```

## Deployment Options

You can deploy using either:
- **Option A**: Automated deployment with Terraform + Scripts (Recommended)
- **Option B**: Manual deployment with kubectl

---

## Option A: Automated Deployment (Recommended)

### Step 1: Setup GCP Infrastructure with Terraform

```bash
# Navigate to terraform directory
cd terraform

# Copy and edit the variables file
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Update with your GCP project details

# Or use the setup script
cd ..
./scripts/setup-infrastructure.sh
```

This will create:
- GKE cluster with autoscaling node pool
- VPC network and subnets
- Service accounts with appropriate IAM roles
- Firewall rules

**Wait 5-10 minutes** for the cluster to be fully provisioned.

### Step 2: Configure kubectl

```bash
# Get cluster credentials
gcloud container clusters get-credentials provider-registry-cluster \
  --region us-central1 \
  --project YOUR_PROJECT_ID

# Verify connection
kubectl cluster-info
```

### Step 3: Update Configuration

Before deploying, update the following files with your actual values:

#### k8s/configmap.yaml
```yaml
# Update these URLs with your actual domains
BASE_URL: "https://api.your-domain.com"
ISSUER: "https://api.your-domain.com"
APP_URL: "https://app.your-domain.com"
```

#### k8s/secrets.yaml
```yaml
# Generate strong passwords
POSTGRES_PASSWORD: "your-strong-password-here"
DATABASE_PASSWORD: "your-strong-password-here"
```

**IMPORTANT**: For production, use Google Secret Manager instead of committing secrets to Git:

```bash
# Create secrets using kubectl
kubectl create secret generic provider-registry-secrets \
  -n provider-registry \
  --from-literal=POSTGRES_PASSWORD='your-strong-password' \
  --from-literal=DATABASE_PASSWORD='your-strong-password'
```

#### k8s/ingress.yaml
```yaml
# Update domain names
- host: app.your-domain.com  # Frontend
- host: api.your-domain.com  # Medplum API
```

### Step 4: Deploy Application

```bash
# Run the automated deployment script
./scripts/deploy.sh
```

This script will:
1. Build and push Docker image to GCR
2. Create Kubernetes namespace
3. Deploy PostgreSQL and Redis
4. Deploy Medplum server
5. Deploy frontend application
6. Setup ingress (optional)

### Step 5: Initialize Medplum Database

**On first deployment only:**

```bash
# Run the initialization script
./scripts/init-medplum.sh
```

Or manually:

```bash
# Get Medplum pod name
kubectl get pods -n provider-registry -l app=medplum-server

# Run database migration
kubectl exec -it -n provider-registry <medplum-pod-name> -- \
  npx medplum db:migrate

# Create super admin user
kubectl exec -it -n provider-registry <medplum-pod-name> -- \
  npx medplum create-super-admin \
  --email admin@example.com \
  --password Admin123! \
  --firstName Admin \
  --lastName User
```

### Step 6: Configure DNS

Get the Load Balancer IP:

```bash
kubectl get ingress -n provider-registry
```

Create DNS A records pointing to the Load Balancer IP:
- `app.your-domain.com` → Load Balancer IP
- `api.your-domain.com` → Load Balancer IP

### Step 7: Access Your Application

Once DNS propagates (can take up to 48 hours), access:
- **Frontend**: https://app.your-domain.com
- **API**: https://api.your-domain.com

**For immediate access (via port-forward):**

```bash
# Frontend
kubectl port-forward -n provider-registry service/frontend-service 3001:80

# Medplum API
kubectl port-forward -n provider-registry service/medplum-service 8103:8103

# Access at:
# http://localhost:3001 (frontend)
# http://localhost:8103 (API)
```

---

## Option B: Manual Deployment

### Step 1: Create GKE Cluster Manually

```bash
gcloud container clusters create provider-registry-cluster \
  --region us-central1 \
  --num-nodes 2 \
  --machine-type e2-standard-4 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 10 \
  --enable-autorepair \
  --enable-autoupgrade
```

### Step 2: Build and Push Docker Image

```bash
# Build the image
docker build -t gcr.io/$GCP_PROJECT_ID/provider-registry-frontend:latest .

# Push to GCR
docker push gcr.io/$GCP_PROJECT_ID/provider-registry-frontend:latest
```

### Step 3: Deploy to Kubernetes

```bash
# Apply Kubernetes manifests in order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/postgres-statefulset.yaml
kubectl apply -f k8s/redis-deployment.yaml

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n provider-registry --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n provider-registry --timeout=300s

# Deploy application services
kubectl apply -f k8s/medplum-deployment.yaml

# Wait for Medplum to be ready
kubectl wait --for=condition=ready pod -l app=medplum-server -n provider-registry --timeout=300s

# Update frontend image reference
sed "s|gcr.io/YOUR_PROJECT_ID|gcr.io/$GCP_PROJECT_ID|g" k8s/frontend-deployment.yaml | kubectl apply -f -

# Deploy ingress
kubectl apply -f k8s/ingress.yaml
```

---

## CI/CD with Cloud Build

### Setup Automated Builds

1. **Connect your repository to Cloud Build:**

```bash
# Navigate to Cloud Build in GCP Console
# Connect your GitHub/GitLab/Bitbucket repository
```

2. **Create a trigger:**

```bash
gcloud builds triggers create github \
  --repo-name=provider-registry \
  --repo-owner=your-github-username \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

3. **Manual build:**

```bash
gcloud builds submit --config cloudbuild.yaml .
```

Now, every push to the `main` branch will automatically:
- Build the Docker image
- Push to GCR
- Deploy to GKE
- Perform rolling update

---

## Monitoring and Maintenance

### View Logs

```bash
# Application logs
kubectl logs -n provider-registry -l app=provider-registry-frontend --tail=100 -f

# Medplum logs
kubectl logs -n provider-registry -l app=medplum-server --tail=100 -f

# PostgreSQL logs
kubectl logs -n provider-registry -l app=postgres --tail=100 -f
```

### Check Resource Status

```bash
# All resources
kubectl get all -n provider-registry

# Pods
kubectl get pods -n provider-registry

# Services
kubectl get services -n provider-registry

# Ingress
kubectl get ingress -n provider-registry

# Persistent volumes
kubectl get pvc -n provider-registry
```

### Scaling

```bash
# Scale frontend
kubectl scale deployment provider-registry-frontend -n provider-registry --replicas=5

# Scale Medplum server
kubectl scale deployment medplum-server -n provider-registry --replicas=3
```

### Update Application

```bash
# Build new image
gcloud builds submit --tag gcr.io/$GCP_PROJECT_ID/provider-registry-frontend:v2

# Update deployment
kubectl set image deployment/provider-registry-frontend \
  frontend=gcr.io/$GCP_PROJECT_ID/provider-registry-frontend:v2 \
  -n provider-registry

# Check rollout status
kubectl rollout status deployment/provider-registry-frontend -n provider-registry
```

### Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/provider-registry-frontend -n provider-registry

# Rollback to specific revision
kubectl rollout undo deployment/provider-registry-frontend -n provider-registry --to-revision=2
```

---

## Backup and Disaster Recovery

### Backup PostgreSQL

```bash
# Get PostgreSQL pod name
PG_POD=$(kubectl get pods -n provider-registry -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Create backup
kubectl exec -n provider-registry $PG_POD -- \
  pg_dump -U medplum medplum | gzip > backup-$(date +%Y%m%d).sql.gz

# Upload to GCS
gsutil cp backup-$(date +%Y%m%d).sql.gz gs://your-backup-bucket/
```

### Restore PostgreSQL

```bash
# Copy backup to pod
kubectl cp backup.sql.gz provider-registry/$PG_POD:/tmp/backup.sql.gz

# Restore
kubectl exec -n provider-registry $PG_POD -- \
  bash -c "gunzip < /tmp/backup.sql.gz | psql -U medplum medplum"
```

### Automated Backups with CronJob

See `k8s/backup-cronjob.yaml` (create this for production use).

---

## Cost Optimization

### Development Environment

For development/testing, use smaller resources:

```bash
# Update terraform/main.tf
machine_type = "e2-medium"  # Instead of e2-standard-4
node_count = 1              # Instead of 2

# Reduce replicas
kubectl scale deployment medplum-server -n provider-registry --replicas=1
kubectl scale deployment provider-registry-frontend -n provider-registry --replicas=1
```

### Use Preemptible Nodes

In `terraform/main.tf`:
```hcl
preemptible = true  # In node_config
```

**Note**: Preemptible nodes can be shut down at any time. Use only for non-critical workloads.

---

## Security Best Practices

1. **Use Google Secret Manager** instead of Kubernetes secrets for sensitive data
2. **Enable Workload Identity** for service account access
3. **Use private GKE cluster** for production
4. **Enable Binary Authorization** to ensure only trusted images are deployed
5. **Regular security scans** of Docker images
6. **Use Cloud Armor** for DDoS protection
7. **Enable audit logging**

### Example: Using Secret Manager

```bash
# Create secret in Secret Manager
echo -n "super-secret-password" | gcloud secrets create postgres-password --data-file=-

# Grant GKE service account access
gcloud secrets add-iam-policy-binding postgres-password \
  --member="serviceAccount:your-gke-sa@your-project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n provider-registry

# Check events
kubectl get events -n provider-registry --sort-by='.lastTimestamp'
```

### Database connection issues

```bash
# Check if PostgreSQL is ready
kubectl exec -n provider-registry -it <postgres-pod> -- pg_isready -U medplum

# Check Medplum server logs
kubectl logs -n provider-registry -l app=medplum-server
```

### Ingress not working

```bash
# Check ingress status
kubectl describe ingress provider-registry-ingress -n provider-registry

# Check managed certificate status
kubectl describe managedcertificate provider-registry-cert -n provider-registry
```

### Out of resources

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -n provider-registry
```

---

## Cleanup

### Delete Application Only

```bash
./scripts/cleanup.sh
```

### Delete Entire Infrastructure

```bash
# Using Terraform
cd terraform
terraform destroy

# Or manually
gcloud container clusters delete provider-registry-cluster --region us-central1
```

---

## Support and Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Medplum Documentation](https://www.medplum.com/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## Estimated Costs

**Production environment** (rough estimates, varies by region):
- GKE cluster (2 x e2-standard-4 nodes): ~$140/month
- Load Balancer: ~$18/month
- Persistent disks (15GB total): ~$2/month
- Egress traffic: Varies
- **Total**: ~$160-200/month

**Development environment** (optimized):
- GKE cluster (1 x e2-medium node): ~$25/month
- No load balancer (use port-forward): $0
- Persistent disks: ~$2/month
- **Total**: ~$30/month

Use the [GCP Pricing Calculator](https://cloud.google.com/products/calculator) for accurate estimates.

---

## Next Steps After Deployment

1. ✅ Configure custom domain and SSL
2. ✅ Setup monitoring and alerting
3. ✅ Configure automated backups
4. ✅ Setup CI/CD pipeline
5. ✅ Implement proper secret management
6. ✅ Configure resource limits and requests
7. ✅ Setup horizontal pod autoscaling
8. ✅ Enable logging aggregation
9. ✅ Implement disaster recovery plan
10. ✅ Performance testing and optimization
