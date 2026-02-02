#!/bin/bash
# Deployment Status Checker
# Run this to verify your Provider Registry deployment status

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Provider Registry - Deployment Status Check         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if kubectl is configured
echo -e "${YELLOW}Checking kubectl configuration...${NC}"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ kubectl is not configured or cannot connect to cluster${NC}"
    echo ""
    echo "Run this to configure kubectl:"
    echo "gcloud container clusters get-credentials provider-registry-cluster --region us-central1 --project \$GCP_PROJECT_ID"
    exit 1
fi
echo -e "${GREEN}✓ kubectl is configured${NC}"
echo ""

# Check if namespace exists
echo -e "${YELLOW}Checking namespace...${NC}"
if kubectl get namespace provider-registry &>/dev/null; then
    echo -e "${GREEN}✓ Namespace 'provider-registry' exists${NC}"
else
    echo -e "${RED}✗ Namespace 'provider-registry' not found${NC}"
    echo "The deployment may not have started or completed."
    exit 1
fi
echo ""

# Check all pods
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Pod Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl get pods -n provider-registry

echo ""
TOTAL_PODS=$(kubectl get pods -n provider-registry --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -n provider-registry --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
PENDING_PODS=$(kubectl get pods -n provider-registry --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
FAILED_PODS=$(kubectl get pods -n provider-registry --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)

echo -e "${YELLOW}Summary:${NC}"
echo "  Total Pods: $TOTAL_PODS"
echo "  Running: $RUNNING_PODS"
echo "  Pending: $PENDING_PODS"
echo "  Failed: $FAILED_PODS"
echo ""

# Check individual components
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Component Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

check_component() {
    local component=$1
    local label=$2
    local expected_min=$3

    local count=$(kubectl get pods -n provider-registry -l app=$label --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

    echo -n "$component: "
    if [ "$count" -ge "$expected_min" ]; then
        echo -e "${GREEN}✓ Running ($count pods)${NC}"
        return 0
    else
        echo -e "${RED}✗ Not ready ($count/$expected_min pods running)${NC}"
        return 1
    fi
}

ALL_READY=true

check_component "PostgreSQL     " "postgres" 1 || ALL_READY=false
check_component "Redis          " "redis" 1 || ALL_READY=false
check_component "Medplum Server " "medplum-server" 1 || ALL_READY=false
check_component "Frontend       " "provider-registry-frontend" 1 || ALL_READY=false

echo ""

# Check services
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Services${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl get services -n provider-registry
echo ""

# Check persistent volumes
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Persistent Volumes${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl get pvc -n provider-registry
echo ""

# Check for any errors in pods
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Recent Events (last 10)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl get events -n provider-registry --sort-by='.lastTimestamp' | tail -n 10
echo ""

# Overall status
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Overall Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

if [ "$ALL_READY" = true ] && [ "$RUNNING_PODS" -ge 4 ]; then
    echo -e "${GREEN}✓ Deployment is SUCCESSFUL!${NC}"
    echo ""
    echo -e "${YELLOW}All components are running and ready.${NC}"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           How to Access Your Application              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Run these commands in separate terminals:"
    echo ""
    echo -e "${BLUE}Terminal 1 - Frontend:${NC}"
    echo "kubectl port-forward -n provider-registry service/frontend-service 3001:80"
    echo ""
    echo -e "${BLUE}Terminal 2 - Medplum API:${NC}"
    echo "kubectl port-forward -n provider-registry service/medplum-service 8103:8103"
    echo ""
    echo "Then open in your browser:"
    echo -e "${GREEN}  Frontend: http://localhost:3001${NC}"
    echo -e "${GREEN}  API:      http://localhost:8103${NC}"
    echo ""
elif [ "$PENDING_PODS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Deployment is IN PROGRESS${NC}"
    echo ""
    echo "Some pods are still starting up. Wait a few minutes and run this script again."
    echo ""
    echo "Watch pods starting:"
    echo "  kubectl get pods -n provider-registry -w"
else
    echo -e "${RED}✗ Deployment has ISSUES${NC}"
    echo ""
    echo "Some components are not running properly."
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check pod details:"
    echo "   kubectl describe pod <pod-name> -n provider-registry"
    echo ""
    echo "2. Check pod logs:"
    echo "   kubectl logs <pod-name> -n provider-registry"
    echo ""
    echo "3. Check events for errors:"
    echo "   kubectl get events -n provider-registry --sort-by='.lastTimestamp'"
fi

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Additional Commands${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "View logs:"
echo "  kubectl logs -n provider-registry -l app=medplum-server -f"
echo "  kubectl logs -n provider-registry -l app=provider-registry-frontend -f"
echo ""
echo "Check resource usage:"
echo "  kubectl top pods -n provider-registry"
echo "  kubectl top nodes"
echo ""
echo "Restart a component:"
echo "  kubectl rollout restart deployment/medplum-server -n provider-registry"
echo "  kubectl rollout restart deployment/provider-registry-frontend -n provider-registry"
echo ""
