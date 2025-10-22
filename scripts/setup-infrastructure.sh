#!/bin/bash
# Infrastructure setup script using Terraform
# This creates the GKE cluster and required GCP resources

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}GCP Infrastructure Setup${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    echo "Install it from: https://www.terraform.io/downloads"
    exit 1
fi

cd terraform

# Check if tfvars file exists
if [ ! -f terraform.tfvars ]; then
    echo -e "${YELLOW}terraform.tfvars not found${NC}"
    echo "Copying from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${RED}IMPORTANT: Edit terraform/terraform.tfvars with your GCP project details${NC}"
    echo "Press any key to open the file..."
    read -n 1
    ${EDITOR:-nano} terraform.tfvars
fi

# Initialize Terraform
echo -e "${GREEN}Initializing Terraform...${NC}"
terraform init

# Validate configuration
echo -e "${GREEN}Validating Terraform configuration...${NC}"
terraform validate

# Plan infrastructure
echo -e "${GREEN}Planning infrastructure changes...${NC}"
terraform plan -out=tfplan

# Ask for confirmation
echo ""
read -p "Do you want to apply these changes? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Infrastructure setup cancelled"
    exit 0
fi

# Apply infrastructure
echo -e "${GREEN}Creating GCP infrastructure...${NC}"
terraform apply tfplan

# Output cluster information
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Infrastructure Created Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

terraform output

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Wait a few minutes for the cluster to be fully ready"
echo "2. Run: gcloud container clusters get-credentials <cluster-name> --region <region>"
echo "3. Run: ./scripts/deploy.sh to deploy the application"

cd ..
