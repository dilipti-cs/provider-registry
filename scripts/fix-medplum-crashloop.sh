#!/bin/bash
# Script to fix Medplum CrashLoopBackOff by applying the config file fix
# This applies the Medplum configuration and restarts the deployment

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Medplum CrashLoopBackOff Fix - Applying Config      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if namespace exists
echo -e "${YELLOW}Step 1: Checking namespace...${NC}"
if ! kubectl get namespace provider-registry &>/dev/null; then
    echo -e "${RED}✗ Namespace 'provider-registry' not found${NC}"
    echo "Please run the initial deployment first."
    exit 1
fi
echo -e "${GREEN}✓ Namespace exists${NC}"
echo ""

# Check and apply secrets
echo -e "${YELLOW}Step 2: Checking database credentials (secrets)...${NC}"
if ! kubectl get secret provider-registry-secrets -n provider-registry &>/dev/null; then
    echo -e "${YELLOW}⚠ Secrets not found, creating with default values...${NC}"
    echo ""
    echo "IMPORTANT: Using default credentials for development."
    echo "For production, change these values!"
    echo ""
    kubectl apply -f k8s/secrets.yaml
    echo -e "${GREEN}✓ Secrets created${NC}"
else
    echo -e "${GREEN}✓ Secrets already exist${NC}"
fi
echo ""

# Apply the Medplum config ConfigMap
echo -e "${YELLOW}Step 3: Applying Medplum configuration file (with database credentials)...${NC}"
kubectl apply -f k8s/medplum-config.yaml
echo -e "${GREEN}✓ ConfigMap applied${NC}"
echo ""

# Apply the updated Medplum deployment
echo -e "${YELLOW}Step 4: Updating Medplum deployment with config volume mount...${NC}"
kubectl apply -f k8s/medplum-deployment.yaml
echo -e "${GREEN}✓ Deployment updated${NC}"
echo ""

# Wait a moment for the rollout to start
sleep 3

# Check current pod status
echo -e "${YELLOW}Step 5: Checking current pod status...${NC}"
kubectl get pods -n provider-registry -l app=medplum-server
echo ""

# Restart the deployment to pick up changes
echo -e "${YELLOW}Step 6: Restarting Medplum deployment...${NC}"
kubectl rollout restart deployment/medplum-server -n provider-registry
echo -e "${GREEN}✓ Restart initiated${NC}"
echo ""

# Wait for rollout
echo -e "${YELLOW}Step 7: Waiting for rollout to complete (timeout: 5 minutes)...${NC}"
if kubectl rollout status deployment/medplum-server -n provider-registry --timeout=300s; then
    echo -e "${GREEN}✓ Rollout completed successfully${NC}"
else
    echo -e "${RED}✗ Rollout did not complete within 5 minutes${NC}"
    echo ""
    echo "Checking pod status..."
    kubectl get pods -n provider-registry -l app=medplum-server
    echo ""
    echo "Checking recent events..."
    kubectl get events -n provider-registry --sort-by='.lastTimestamp' | tail -n 10
    echo ""
    echo "Run this to check logs:"
    echo "  kubectl logs -n provider-registry -l app=medplum-server --tail=50"
    exit 1
fi
echo ""

# Verify pods are running
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Final Pod Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl get pods -n provider-registry -l app=medplum-server
echo ""

# Check if pods are running
RUNNING_COUNT=$(kubectl get pods -n provider-registry -l app=medplum-server --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

if [ "$RUNNING_COUNT" -ge 1 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║               ✓ SUCCESS - Medplum is Running!         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo ""
    echo "1. Check the logs to ensure no errors:"
    echo -e "   ${BLUE}kubectl logs -n provider-registry -l app=medplum-server --tail=50${NC}"
    echo ""
    echo "2. Initialize the Medplum database (first time only):"
    echo -e "   ${BLUE}./scripts/init-medplum.sh${NC}"
    echo ""
    echo "3. Check overall deployment status:"
    echo -e "   ${BLUE}./scripts/check-status.sh${NC}"
    echo ""
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║            ✗ Pods are not yet running                 ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Check logs for errors:"
    MEDPLUM_POD=$(kubectl get pods -n provider-registry -l app=medplum-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$MEDPLUM_POD" ]; then
        echo ""
        echo -e "${YELLOW}Recent logs from $MEDPLUM_POD:${NC}"
        kubectl logs -n provider-registry "$MEDPLUM_POD" --tail=30 2>/dev/null || \
        kubectl logs -n provider-registry "$MEDPLUM_POD" --previous --tail=30 2>/dev/null || \
        echo "Cannot retrieve logs"
    fi
    echo ""
    echo "Describe pod for more details:"
    echo "  kubectl describe pod -n provider-registry -l app=medplum-server"
fi
