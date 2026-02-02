#!/bin/bash
# Pre-deployment checklist and validation script
# Run this before deploying to GCP

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GCP Deployment Readiness Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check 1: gcloud CLI
echo -n "Checking gcloud CLI... "
if command -v gcloud &> /dev/null; then
    echo -e "${GREEN}✓ Installed${NC}"
    GCLOUD_VERSION=$(gcloud version --format="value(version)")
    echo "  Version: $GCLOUD_VERSION"
else
    echo -e "${RED}✗ Not installed${NC}"
    echo -e "${YELLOW}  Install from: https://cloud.google.com/sdk/docs/install${NC}"
    exit 1
fi

# Check 2: kubectl
echo -n "Checking kubectl... "
if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✓ Installed${NC}"
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | grep "Client" || kubectl version --client 2>/dev/null | head -1)
    echo "  $KUBECTL_VERSION"
else
    echo -e "${RED}✗ Not installed${NC}"
    echo -e "${YELLOW}  Install with: gcloud components install kubectl${NC}"
    exit 1
fi

# Check 3: Terraform
echo -n "Checking terraform... "
if command -v terraform &> /dev/null; then
    echo -e "${GREEN}✓ Installed${NC}"
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1)
    echo "  $TERRAFORM_VERSION"
else
    echo -e "${YELLOW}⚠ Not installed (optional)${NC}"
    echo -e "${YELLOW}  Install from: https://www.terraform.io/downloads${NC}"
    echo -e "${YELLOW}  Note: Required for automated infrastructure setup${NC}"
fi

echo ""

# Check 4: GCP Authentication
echo -n "Checking GCP authentication... "
if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
    if [ -n "$ACTIVE_ACCOUNT" ]; then
        echo -e "${GREEN}✓ Authenticated${NC}"
        echo "  Account: $ACTIVE_ACCOUNT"
    else
        echo -e "${RED}✗ Not authenticated${NC}"
        echo -e "${YELLOW}  Run: gcloud auth login${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Not authenticated${NC}"
    echo -e "${YELLOW}  Run: gcloud auth login${NC}"
    exit 1
fi

# Check 5: GCP Project
echo -n "Checking GCP project... "
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -n "$CURRENT_PROJECT" ]; then
    echo -e "${GREEN}✓ Set${NC}"
    echo "  Project: $CURRENT_PROJECT"
else
    echo -e "${RED}✗ Not set${NC}"
    echo -e "${YELLOW}  Run: gcloud config set project YOUR_PROJECT_ID${NC}"
    exit 1
fi

# Check 6: Required APIs
echo ""
echo "Checking required GCP APIs..."
REQUIRED_APIS=(
    "container.googleapis.com"
    "compute.googleapis.com"
    "cloudbuild.googleapis.com"
)

ALL_APIS_ENABLED=true
for API in "${REQUIRED_APIS[@]}"; do
    echo -n "  $API... "
    if gcloud services list --enabled --filter="name:$API" --format="value(name)" 2>/dev/null | grep -q "$API"; then
        echo -e "${GREEN}✓ Enabled${NC}"
    else
        echo -e "${RED}✗ Disabled${NC}"
        ALL_APIS_ENABLED=false
    fi
done

if [ "$ALL_APIS_ENABLED" = false ]; then
    echo ""
    echo -e "${YELLOW}Enable APIs with:${NC}"
    echo "gcloud services enable container.googleapis.com compute.googleapis.com cloudbuild.googleapis.com"
    exit 1
fi

# Check 7: Deployment files
echo ""
echo "Checking deployment files..."
REQUIRED_FILES=(
    "terraform/main.tf"
    "k8s/namespace.yaml"
    "k8s/configmap.yaml"
    "k8s/secrets.yaml"
    "scripts/deploy.sh"
    "scripts/setup-infrastructure.sh"
    "Dockerfile"
    "cloudbuild.yaml"
)

ALL_FILES_PRESENT=true
for FILE in "${REQUIRED_FILES[@]}"; do
    echo -n "  $FILE... "
    if [ -f "$FILE" ]; then
        echo -e "${GREEN}✓ Present${NC}"
    else
        echo -e "${RED}✗ Missing${NC}"
        ALL_FILES_PRESENT=false
    fi
done

if [ "$ALL_FILES_PRESENT" = false ]; then
    echo -e "${RED}Some required files are missing!${NC}"
    exit 1
fi

# Check 8: Configuration review
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Configuration Review${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "${YELLOW}Before deploying, you need to update:${NC}"
echo ""
echo "1. terraform/terraform.tfvars"
echo "   - Copy from terraform.tfvars.example"
echo "   - Set your GCP project ID and preferences"
echo ""
echo "2. k8s/configmap.yaml"
echo "   - Update BASE_URL to your actual domain"
echo "   - Update APP_URL to your frontend domain"
echo ""
echo "3. k8s/secrets.yaml"
echo "   - Generate strong passwords"
echo "   - NEVER commit actual secrets to Git!"
echo ""
echo "4. k8s/ingress.yaml"
echo "   - Update domain names"
echo ""
echo "5. k8s/frontend-deployment.yaml"
echo "   - Replace YOUR_PROJECT_ID with actual project ID"
echo ""

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$ALL_APIS_ENABLED" = true ] && [ "$ALL_FILES_PRESENT" = true ]; then
    echo -e "${GREEN}✓ System requirements met${NC}"
    echo -e "${GREEN}✓ GCP authentication configured${NC}"
    echo -e "${GREEN}✓ All deployment files present${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review and update configuration files (see above)"
    echo "2. Run: ./scripts/setup-infrastructure.sh"
    echo "3. Run: ./scripts/deploy.sh"
    echo "4. Run: ./scripts/init-medplum.sh (first time only)"
    echo ""
    echo -e "${GREEN}You're ready to deploy to GCP!${NC}"
else
    echo -e "${RED}✗ Prerequisites not met${NC}"
    echo "Please fix the issues above before deploying."
    exit 1
fi
