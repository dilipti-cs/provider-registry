#!/bin/bash
# Complete Deployment Script - Run from your local machine with gcloud installed
# This script will deploy the entire Provider Registry application to GCP

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Provider Registry - Complete GCP Deployment         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration - UPDATE THESE VALUES
GCP_PROJECT_ID="${GCP_PROJECT_ID:-}"
GCP_REGION="${GCP_REGION:-us-central1}"
GCP_ZONE="${GCP_ZONE:-us-central1-a}"
CLUSTER_NAME="${CLUSTER_NAME:-provider-registry-cluster}"

# Step 0: Get Project ID if not set
if [ -z "$GCP_PROJECT_ID" ]; then
    echo -e "${YELLOW}GCP Project ID not set${NC}"
    echo "Available projects:"
    gcloud projects list --format="table(projectId,name)"
    echo ""
    read -p "Enter your GCP Project ID: " GCP_PROJECT_ID
    export GCP_PROJECT_ID
fi

echo -e "${GREEN}Using Configuration:${NC}"
echo "  Project ID: $GCP_PROJECT_ID"
echo "  Region: $GCP_REGION"
echo "  Zone: $GCP_ZONE"
echo "  Cluster: $CLUSTER_NAME"
echo ""

read -p "Is this correct? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Please set environment variables and try again:"
    echo "  export GCP_PROJECT_ID='your-project-id'"
    echo "  export GCP_REGION='us-central1'"
    echo "  export CLUSTER_NAME='provider-registry-cluster'"
    exit 1
fi

# Set project
echo -e "${BLUE}Setting GCP project...${NC}"
gcloud config set project $GCP_PROJECT_ID

# Step 1: Enable APIs
echo ""
echo -e "${BLUE}Step 1: Enabling required GCP APIs...${NC}"
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable containerregistry.googleapis.com
echo -e "${GREEN}✓ APIs enabled${NC}"

# Step 2: Check if cluster exists
echo ""
echo -e "${BLUE}Step 2: Checking for existing GKE cluster...${NC}"
if gcloud container clusters describe $CLUSTER_NAME --region $GCP_REGION &>/dev/null; then
    echo -e "${GREEN}✓ Cluster already exists: $CLUSTER_NAME${NC}"
    CLUSTER_EXISTS=true
else
    echo -e "${YELLOW}Cluster does not exist${NC}"
    CLUSTER_EXISTS=false
fi

# Step 3: Create cluster if needed
if [ "$CLUSTER_EXISTS" = false ]; then
    echo ""
    echo -e "${BLUE}Step 3: Creating GKE cluster...${NC}"
    echo -e "${YELLOW}This will take 5-10 minutes...${NC}"

    gcloud container clusters create $CLUSTER_NAME \
        --region $GCP_REGION \
        --num-nodes 2 \
        --machine-type e2-standard-4 \
        --disk-size 100 \
        --enable-autoscaling \
        --min-nodes 1 \
        --max-nodes 10 \
        --enable-autorepair \
        --enable-autoupgrade \
        --enable-ip-alias \
        --network "projects/$GCP_PROJECT_ID/global/networks/default" \
        --subnetwork "projects/$GCP_PROJECT_ID/regions/$GCP_REGION/subnetworks/default" \
        --logging=SYSTEM,WORKLOAD \
        --monitoring=SYSTEM \
        --addons HorizontalPodAutoscaling,HttpLoadBalancing \
        --workload-pool=$GCP_PROJECT_ID.svc.id.goog

    echo -e "${GREEN}✓ Cluster created successfully${NC}"
else
    echo -e "${BLUE}Step 3: Skipping cluster creation (already exists)${NC}"
fi

# Step 4: Get cluster credentials
echo ""
echo -e "${BLUE}Step 4: Getting cluster credentials...${NC}"
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region $GCP_REGION \
    --project $GCP_PROJECT_ID
echo -e "${GREEN}✓ Credentials configured${NC}"

# Step 5: Update configuration files
echo ""
echo -e "${BLUE}Step 5: Updating configuration files...${NC}"

# Update frontend deployment with project ID
if [ -f "k8s/frontend-deployment.yaml" ]; then
    sed -i.bak "s|gcr.io/YOUR_PROJECT_ID|gcr.io/$GCP_PROJECT_ID|g" k8s/frontend-deployment.yaml
    echo -e "${GREEN}✓ Updated frontend-deployment.yaml${NC}"
fi

# Update ConfigMap with project-specific URLs (keeping localhost for now)
echo -e "${YELLOW}  Note: Using localhost URLs for now. Update k8s/configmap.yaml with your domain later.${NC}"

# Step 6: Build and push Docker image
echo ""
echo -e "${BLUE}Step 6: Building and pushing Docker image...${NC}"
echo -e "${YELLOW}This will take 3-5 minutes...${NC}"

gcloud builds submit --tag gcr.io/$GCP_PROJECT_ID/provider-registry-frontend:latest .

echo -e "${GREEN}✓ Image built and pushed to GCR${NC}"

# Step 7: Create namespace
echo ""
echo -e "${BLUE}Step 7: Creating Kubernetes namespace...${NC}"
kubectl apply -f k8s/namespace.yaml
echo -e "${GREEN}✓ Namespace created${NC}"

# Step 8: Create secrets
echo ""
echo -e "${BLUE}Step 8: Creating secrets...${NC}"
if kubectl get secret provider-registry-secrets -n provider-registry &>/dev/null; then
    echo -e "${YELLOW}Secrets already exist, skipping...${NC}"
else
    # Generate random passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    DATABASE_PASSWORD=$POSTGRES_PASSWORD

    kubectl create secret generic provider-registry-secrets \
        -n provider-registry \
        --from-literal=POSTGRES_USER=medplum \
        --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
        --from-literal=DATABASE_USERNAME=medplum \
        --from-literal=DATABASE_PASSWORD=$DATABASE_PASSWORD

    echo -e "${GREEN}✓ Secrets created${NC}"
    echo -e "${YELLOW}  PostgreSQL Password: $POSTGRES_PASSWORD${NC}"
    echo -e "${YELLOW}  Save this password securely!${NC}"
fi

# Step 9: Apply ConfigMap
echo ""
echo -e "${BLUE}Step 9: Applying ConfigMap...${NC}"
kubectl apply -f k8s/configmap.yaml
echo -e "${GREEN}✓ ConfigMap applied${NC}"

# Step 10: Deploy PostgreSQL
echo ""
echo -e "${BLUE}Step 10: Deploying PostgreSQL...${NC}"
kubectl apply -f k8s/postgres-statefulset.yaml
echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=postgres -n provider-registry --timeout=300s
echo -e "${GREEN}✓ PostgreSQL deployed${NC}"

# Step 11: Deploy Redis
echo ""
echo -e "${BLUE}Step 11: Deploying Redis...${NC}"
kubectl apply -f k8s/redis-deployment.yaml
echo -e "${YELLOW}Waiting for Redis to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=redis -n provider-registry --timeout=300s
echo -e "${GREEN}✓ Redis deployed${NC}"

# Step 12: Deploy Medplum Server
echo ""
echo -e "${BLUE}Step 12: Deploying Medplum Server...${NC}"
kubectl apply -f k8s/medplum-deployment.yaml
echo -e "${YELLOW}Waiting for Medplum to be ready (this may take 2-3 minutes)...${NC}"
kubectl wait --for=condition=ready pod -l app=medplum-server -n provider-registry --timeout=300s
echo -e "${GREEN}✓ Medplum Server deployed${NC}"

# Step 13: Initialize Medplum Database
echo ""
echo -e "${BLUE}Step 13: Initializing Medplum database...${NC}"
MEDPLUM_POD=$(kubectl get pods -n provider-registry -l app=medplum-server -o jsonpath='{.items[0].metadata.name}')

echo "Running database migration..."
kubectl exec -n provider-registry $MEDPLUM_POD -- npx medplum db:migrate

echo ""
echo -e "${YELLOW}Creating super admin user...${NC}"
read -p "Admin Email [admin@example.com]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

read -sp "Admin Password [Admin123!]: " ADMIN_PASSWORD
echo ""
ADMIN_PASSWORD=${ADMIN_PASSWORD:-Admin123!}

read -p "First Name [Admin]: " FIRST_NAME
FIRST_NAME=${FIRST_NAME:-Admin}

read -p "Last Name [User]: " LAST_NAME
LAST_NAME=${LAST_NAME:-User}

kubectl exec -n provider-registry $MEDPLUM_POD -- \
    npx medplum create-super-admin \
    --email "$ADMIN_EMAIL" \
    --password "$ADMIN_PASSWORD" \
    --firstName "$FIRST_NAME" \
    --lastName "$LAST_NAME"

echo -e "${GREEN}✓ Medplum database initialized${NC}"
echo -e "${YELLOW}Admin Credentials:${NC}"
echo "  Email: $ADMIN_EMAIL"
echo "  Password: [hidden]"
echo -e "${YELLOW}  Save these credentials securely!${NC}"

# Step 14: Deploy Frontend
echo ""
echo -e "${BLUE}Step 14: Deploying Frontend...${NC}"
kubectl apply -f k8s/frontend-deployment.yaml
echo -e "${YELLOW}Waiting for Frontend to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=provider-registry-frontend -n provider-registry --timeout=300s
echo -e "${GREEN}✓ Frontend deployed${NC}"

# Step 15: Display status
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Deployment Completed Successfully!            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}Deployment Summary:${NC}"
kubectl get pods -n provider-registry

echo ""
echo -e "${BLUE}Services:${NC}"
kubectl get services -n provider-registry

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Access Your Application:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Run these commands in separate terminals:"
echo ""
echo -e "${GREEN}# Terminal 1 - Frontend${NC}"
echo "kubectl port-forward -n provider-registry service/frontend-service 3001:80"
echo ""
echo -e "${GREEN}# Terminal 2 - Medplum API${NC}"
echo "kubectl port-forward -n provider-registry service/medplum-service 8103:8103"
echo ""
echo "Then access:"
echo -e "${BLUE}  Frontend:${NC} http://localhost:3001"
echo -e "${BLUE}  API:${NC}      http://localhost:8103"
echo ""
echo -e "${YELLOW}Login with:${NC}"
echo "  Email: $ADMIN_EMAIL"
echo "  Password: [the password you entered]"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Setup custom domain (optional)"
echo "2. Configure ingress with SSL (optional)"
echo "3. Setup monitoring and alerts"
echo "4. Configure automated backups"
echo ""
echo -e "${BLUE}To view logs:${NC}"
echo "kubectl logs -n provider-registry -l app=provider-registry-frontend -f"
echo "kubectl logs -n provider-registry -l app=medplum-server -f"
echo ""
echo -e "${BLUE}To check resource usage:${NC}"
echo "kubectl top pods -n provider-registry"
echo "kubectl top nodes"
echo ""
echo -e "${GREEN}Deployment complete! 🎉${NC}"
