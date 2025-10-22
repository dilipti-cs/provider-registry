#!/bin/bash
# Cleanup script - removes all Kubernetes resources
# WARNING: This will delete all data!

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}========================================${NC}"
echo -e "${RED}WARNING: Cleanup Script${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${RED}This will DELETE all provider-registry resources including:${NC}"
echo -e "${RED}- All Kubernetes resources${NC}"
echo -e "${RED}- All data in PostgreSQL${NC}"
echo -e "${RED}- All data in Redis${NC}"
echo ""

read -p "Are you absolutely sure you want to continue? (type 'DELETE' to confirm): " -r
if [[ $REPLY != "DELETE" ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
read -p "Final confirmation - this cannot be undone. Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo -e "${YELLOW}Starting cleanup...${NC}"

# Delete all resources in the namespace
echo -e "${YELLOW}Deleting all resources in provider-registry namespace...${NC}"
kubectl delete all --all -n provider-registry

# Delete PVCs (this will delete all data!)
echo -e "${YELLOW}Deleting Persistent Volume Claims...${NC}"
kubectl delete pvc --all -n provider-registry

# Delete configmaps and secrets
echo -e "${YELLOW}Deleting ConfigMaps and Secrets...${NC}"
kubectl delete configmap --all -n provider-registry
kubectl delete secret --all -n provider-registry

# Delete ingress
echo -e "${YELLOW}Deleting Ingress...${NC}"
kubectl delete ingress --all -n provider-registry 2>/dev/null || true

# Delete the namespace
echo -e "${YELLOW}Deleting namespace...${NC}"
kubectl delete namespace provider-registry

echo -e "${GREEN}Cleanup completed!${NC}"
echo ""
echo -e "${YELLOW}To destroy the GKE cluster and GCP infrastructure:${NC}"
echo "cd terraform && terraform destroy"
