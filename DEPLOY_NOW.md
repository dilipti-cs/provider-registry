# 🚀 Deploy to GCP Now - Quick Start Guide

This guide will help you deploy the Provider Registry application to Google Cloud Platform in under 30 minutes.

## 📋 Prerequisites Check

Before starting, ensure you have:
- [ ] Google Cloud account with billing enabled
- [ ] `gcloud` CLI installed
- [ ] `kubectl` installed
- [ ] `terraform` installed (optional, for automated setup)
- [ ] A GCP project created

## 🔍 Step 0: Run Readiness Check

```bash
./scripts/check-deployment-ready.sh
```

This script will verify:
- ✓ Required tools are installed
- ✓ GCP authentication is configured
- ✓ Required APIs are enabled
- ✓ All deployment files are present

## ⚙️ Step 1: Initial GCP Setup

### 1.1 Install gcloud CLI (if not installed)

```bash
# Linux/Mac
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Or visit: https://cloud.google.com/sdk/docs/install
```

### 1.2 Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
```

### 1.3 Set Your GCP Project

```bash
# List your projects
gcloud projects list

# Set the project you want to use
export GCP_PROJECT_ID="your-project-id"
gcloud config set project $GCP_PROJECT_ID
```

### 1.4 Enable Required APIs

```bash
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

## 📝 Step 2: Configure Deployment Files

### 2.1 Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Or use your preferred editor
```

Update with your values:
```hcl
project_id   = "your-gcp-project-id"
region       = "us-central1"
zone         = "us-central1-a"
cluster_name = "provider-registry-cluster"
environment  = "production"
```

### 2.2 Update Kubernetes ConfigMap

```bash
cd ../k8s
nano configmap.yaml
```

Update these URLs (or keep localhost for testing):
```yaml
BASE_URL: "https://api.your-domain.com"
ISSUER: "https://api.your-domain.com"
APP_URL: "https://app.your-domain.com"
```

### 2.3 Generate Strong Secrets

**IMPORTANT**: Generate strong passwords for production!

```bash
# Generate random passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
echo "Generated PostgreSQL password: $POSTGRES_PASSWORD"

# Update secrets.yaml with the generated passwords
nano secrets.yaml
```

**⚠️ WARNING**: Never commit actual secrets to Git!

For production, use this instead:
```bash
# Create secrets directly with kubectl (after cluster is created)
kubectl create secret generic provider-registry-secrets \
  -n provider-registry \
  --from-literal=POSTGRES_PASSWORD='your-strong-password' \
  --from-literal=DATABASE_PASSWORD='your-strong-password'
```

### 2.4 Update Frontend Deployment

```bash
nano frontend-deployment.yaml
```

Replace `YOUR_PROJECT_ID` with your actual GCP project ID:
```yaml
image: gcr.io/your-actual-project-id/provider-registry-frontend:latest
```

Or use this quick command:
```bash
sed -i "s/YOUR_PROJECT_ID/$GCP_PROJECT_ID/g" frontend-deployment.yaml
```

### 2.5 Update Ingress (Optional - for custom domains)

```bash
nano ingress.yaml
```

Update domain names if you have them:
```yaml
- host: app.your-domain.com
- host: api.your-domain.com
```

## 🏗️ Step 3: Create GCP Infrastructure

### Option A: Automated Setup (Recommended)

```bash
cd ..
./scripts/setup-infrastructure.sh
```

This will:
- Initialize Terraform
- Create GKE cluster
- Setup networking
- Configure service accounts
- Create firewall rules

**Wait 5-10 minutes** for the cluster to be fully provisioned.

### Option B: Manual Terraform Setup

```bash
cd terraform
terraform init
terraform plan
terraform apply
cd ..
```

## 🚢 Step 4: Deploy the Application

### 4.1 Get Cluster Credentials

```bash
gcloud container clusters get-credentials provider-registry-cluster \
  --region us-central1 \
  --project $GCP_PROJECT_ID
```

### 4.2 Verify Connection

```bash
kubectl cluster-info
kubectl get nodes
```

### 4.3 Deploy Application

```bash
./scripts/deploy.sh
```

This automated script will:
1. ✅ Build and push Docker image to GCR
2. ✅ Create Kubernetes namespace
3. ✅ Deploy PostgreSQL
4. ✅ Deploy Redis
5. ✅ Deploy Medplum server
6. ✅ Deploy frontend
7. ✅ Setup ingress (optional)

The script will pause and ask for confirmations at key steps.

## 🔐 Step 5: Initialize Medplum Database

**Run this only on FIRST deployment:**

```bash
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

**Save these credentials securely!**

## 🌐 Step 6: Access Your Application

### Option A: Via Port Forwarding (Immediate Access)

```bash
# In one terminal - Frontend
kubectl port-forward -n provider-registry service/frontend-service 3001:80

# In another terminal - Medplum API
kubectl port-forward -n provider-registry service/medplum-service 8103:8103
```

Access at:
- **Frontend**: http://localhost:3001
- **Medplum API**: http://localhost:8103

### Option B: Via Load Balancer (Production)

```bash
# Get the Load Balancer IP
kubectl get ingress -n provider-registry

# Wait for the IP to be assigned (may take 5-10 minutes)
watch kubectl get ingress -n provider-registry
```

Once you have the IP address:
1. Create DNS A records pointing to the Load Balancer IP
2. Wait for DNS propagation (up to 48 hours)
3. Access via your domain: https://app.your-domain.com

## ✅ Step 7: Verify Deployment

### Check All Resources

```bash
# All resources
kubectl get all -n provider-registry

# Pods status
kubectl get pods -n provider-registry

# Services
kubectl get services -n provider-registry

# Persistent volumes
kubectl get pvc -n provider-registry
```

### Check Application Health

```bash
# Frontend logs
kubectl logs -n provider-registry -l app=provider-registry-frontend --tail=50

# Medplum logs
kubectl logs -n provider-registry -l app=medplum-server --tail=50

# PostgreSQL logs
kubectl logs -n provider-registry -l app=postgres --tail=50
```

### Test the Application

1. Navigate to http://localhost:3001 (via port-forward)
2. Login with the admin credentials you created
3. Try creating an Organization
4. Try creating a Practitioner
5. Try creating a Patient

## 🎉 Success! Your Application is Deployed

Your Provider Registry is now running on GCP with:
- ✅ Kubernetes orchestration (GKE)
- ✅ PostgreSQL for data storage
- ✅ Redis for caching
- ✅ Medplum FHIR R4 API
- ✅ React frontend
- ✅ Auto-scaling enabled
- ✅ Health checks configured

## 📊 Monitor Your Deployment

### View Logs

```bash
# Follow frontend logs
kubectl logs -n provider-registry -l app=provider-registry-frontend -f

# Follow Medplum logs
kubectl logs -n provider-registry -l app=medplum-server -f
```

### Check Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n provider-registry
```

### GCP Console

Visit: https://console.cloud.google.com/
- Kubernetes Engine → Clusters
- Kubernetes Engine → Workloads
- Kubernetes Engine → Services & Ingress

## 🔄 Update/Redeploy

### Update Frontend Code

```bash
# Build new image
gcloud builds submit --tag gcr.io/$GCP_PROJECT_ID/provider-registry-frontend:v2

# Update deployment
kubectl set image deployment/provider-registry-frontend \
  frontend=gcr.io/$GCP_PROJECT_ID/provider-registry-frontend:v2 \
  -n provider-registry

# Watch rollout
kubectl rollout status deployment/provider-registry-frontend -n provider-registry
```

### Trigger CI/CD (Automated)

Once you setup Cloud Build triggers:
```bash
git commit -am "Update application"
git push origin dev
# Automatically builds and deploys!
```

## 🛑 Stop/Cleanup

### Stop Application (Keep Infrastructure)

```bash
# Scale down to zero
kubectl scale deployment --all --replicas=0 -n provider-registry
```

### Delete Application (Keep Cluster)

```bash
./scripts/cleanup.sh
```

### Delete Everything

```bash
cd terraform
terraform destroy
```

## 💰 Cost Management

Your deployment costs approximately:
- **Development**: ~$30-50/month
  - 1 x e2-medium node
  - Small persistent disks
  - No load balancer (use port-forward)

- **Production**: ~$160-200/month
  - 2-3 x e2-standard-4 nodes
  - Load balancer with SSL
  - Persistent disks

### Reduce Costs

```bash
# Use smaller nodes (dev environment)
# Update terraform/main.tf:
machine_type = "e2-medium"

# Reduce replicas
kubectl scale deployment medplum-server -n provider-registry --replicas=1
kubectl scale deployment provider-registry-frontend -n provider-registry --replicas=1

# Use preemptible nodes (can be shut down anytime)
# Update terraform/main.tf:
preemptible = true
```

## 🆘 Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n provider-registry
kubectl get events -n provider-registry --sort-by='.lastTimestamp'
```

### Database Connection Errors

```bash
# Check PostgreSQL is ready
kubectl exec -n provider-registry -it <postgres-pod> -- pg_isready -U medplum

# Check Medplum can connect
kubectl logs -n provider-registry -l app=medplum-server | grep -i "database\|connection"
```

### Ingress Not Working

```bash
kubectl describe ingress provider-registry-ingress -n provider-registry
kubectl describe managedcertificate provider-registry-cert -n provider-registry
```

### Out of Resources

```bash
# Check what's using resources
kubectl top nodes
kubectl top pods -n provider-registry --sort-by=memory
```

## 📚 Additional Resources

- **Full Documentation**: [GCP_DEPLOYMENT.md](./GCP_DEPLOYMENT.md)
- **Kubernetes Config**: [k8s/README.md](./k8s/README.md)
- **Medplum Docs**: https://www.medplum.com/docs
- **GKE Docs**: https://cloud.google.com/kubernetes-engine/docs

## 🎯 Production Checklist

Before going to production:
- [ ] Use Cloud SQL instead of in-cluster PostgreSQL
- [ ] Use Cloud Memorystore instead of in-cluster Redis
- [ ] Setup automated backups
- [ ] Enable monitoring and alerting
- [ ] Use Google Secret Manager for secrets
- [ ] Setup custom domain with SSL
- [ ] Configure proper resource limits
- [ ] Enable audit logging
- [ ] Setup CI/CD pipeline
- [ ] Implement disaster recovery plan
- [ ] Performance testing
- [ ] Security audit

---

**Need Help?**
- Check [GCP_DEPLOYMENT.md](./GCP_DEPLOYMENT.md) for detailed troubleshooting
- Review logs: `kubectl logs -n provider-registry <pod-name>`
- Check GCP Console for more details

**Happy Deploying! 🚀**
