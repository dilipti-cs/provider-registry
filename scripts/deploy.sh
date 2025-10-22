#!/bin/bash
# Deployment script for Provider Registry to GCP
# This script automates the deployment process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-provider-registry-cluster}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Provider Registry GCP Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    echo "Install it with: gcloud components install kubectl"
    exit 1
fi

# Get project ID if not set
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        echo -e "${RED}Error: GCP Project ID not set${NC}"
        echo "Set it with: export GCP_PROJECT_ID=your-project-id"
        echo "Or: gcloud config set project your-project-id"
        exit 1
    fi
fi

echo -e "${YELLOW}Using Project: ${PROJECT_ID}${NC}"
echo -e "${YELLOW}Region: ${REGION}${NC}"
echo -e "${YELLOW}Cluster: ${CLUSTER_NAME}${NC}"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with deployment? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Step 1: Build and push Docker image
echo -e "${GREEN}Step 1: Building and pushing Docker image...${NC}"
gcloud builds submit --tag gcr.io/${PROJECT_ID}/provider-registry-frontend:latest .

# Step 2: Get GKE credentials
echo -e "${GREEN}Step 2: Getting GKE cluster credentials...${NC}"
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}

# Step 3: Create namespace if it doesn't exist
echo -e "${GREEN}Step 3: Setting up Kubernetes namespace...${NC}"
kubectl apply -f k8s/namespace.yaml

# Step 4: Create secrets (if they don't exist)
echo -e "${GREEN}Step 4: Checking secrets...${NC}"
if ! kubectl get secret provider-registry-secrets -n provider-registry &> /dev/null; then
    echo -e "${YELLOW}Creating secrets...${NC}"
    echo -e "${YELLOW}IMPORTANT: Update the secrets in k8s/secrets.yaml before deploying to production!${NC}"
    kubectl apply -f k8s/secrets.yaml
else
    echo -e "${GREEN}Secrets already exist, skipping...${NC}"
fi

# Step 5: Apply ConfigMaps
echo -e "${GREEN}Step 5: Applying ConfigMaps...${NC}"
kubectl apply -f k8s/configmap.yaml

# Step 6: Deploy PostgreSQL
echo -e "${GREEN}Step 6: Deploying PostgreSQL...${NC}"
kubectl apply -f k8s/postgres-statefulset.yaml

# Step 7: Deploy Redis
echo -e "${GREEN}Step 7: Deploying Redis...${NC}"
kubectl apply -f k8s/redis-deployment.yaml

# Wait for databases to be ready
echo -e "${YELLOW}Waiting for databases to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=postgres -n provider-registry --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n provider-registry --timeout=300s

# Step 8: Initialize Medplum database (only on first deployment)
echo -e "${GREEN}Step 8: Checking Medplum database initialization...${NC}"
read -p "Is this the first deployment? Do you need to initialize the Medplum database? (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Deploy Medplum server first, then run:${NC}"
    echo "kubectl exec -it -n provider-registry deployment/medplum-server -- npx medplum db:migrate"
    echo "kubectl exec -it -n provider-registry deployment/medplum-server -- npx medplum create-super-admin --email admin@example.com --password Admin123! --firstName Admin --lastName User"
fi

# Step 9: Deploy Medplum Server
echo -e "${GREEN}Step 9: Deploying Medplum Server...${NC}"
kubectl apply -f k8s/medplum-deployment.yaml

# Wait for Medplum to be ready
echo -e "${YELLOW}Waiting for Medplum server to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=medplum-server -n provider-registry --timeout=300s

# Step 10: Update frontend deployment with correct image
echo -e "${GREEN}Step 10: Updating frontend deployment image...${NC}"
sed "s|gcr.io/YOUR_PROJECT_ID|gcr.io/${PROJECT_ID}|g" k8s/frontend-deployment.yaml | kubectl apply -f -

# Wait for frontend to be ready
echo -e "${YELLOW}Waiting for frontend to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=provider-registry-frontend -n provider-registry --timeout=300s

# Step 11: Apply Ingress (optional)
echo -e "${GREEN}Step 11: Setting up Ingress...${NC}"
read -p "Do you want to deploy the Ingress? (requires domain setup) (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    kubectl apply -f k8s/ingress.yaml
    echo -e "${YELLOW}Remember to update the domain names in k8s/ingress.yaml${NC}"
fi

# Step 12: Display deployment status
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "${YELLOW}Pods:${NC}"
kubectl get pods -n provider-registry

echo -e "${YELLOW}Services:${NC}"
kubectl get services -n provider-registry

echo -e "${YELLOW}Ingress:${NC}"
kubectl get ingress -n provider-registry 2>/dev/null || echo "No ingress configured"

echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. If this is first deployment, initialize Medplum database (see Step 8 output above)"
echo "2. Update domain names in k8s/configmap.yaml and k8s/ingress.yaml"
echo "3. Configure DNS to point to the Load Balancer IP"
echo "4. Monitor the deployment: kubectl get pods -n provider-registry -w"
echo ""
echo -e "${YELLOW}To access the application locally (port-forward):${NC}"
echo "kubectl port-forward -n provider-registry service/frontend-service 3001:80"
echo "kubectl port-forward -n provider-registry service/medplum-service 8103:8103"
