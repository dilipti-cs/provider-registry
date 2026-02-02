#!/bin/bash
# Medplum Troubleshooting Script
# Checks Medplum configuration and logs

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Medplum Server Troubleshooting${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Get Medplum pod name
MEDPLUM_POD=$(kubectl get pods -n provider-registry -l app=medplum-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$MEDPLUM_POD" ]; then
    echo -e "${RED}No Medplum pods found${NC}"
    exit 1
fi

echo -e "${YELLOW}Medplum Pod: $MEDPLUM_POD${NC}"
echo ""

# Check pod description
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Pod Description (Last 20 Events)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl describe pod $MEDPLUM_POD -n provider-registry | grep -A 20 "Events:"
echo ""

# Check pod logs
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Recent Logs (Last 50 Lines)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl logs $MEDPLUM_POD -n provider-registry --tail=50
echo ""

# Check previous logs (from crashed container)
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Previous Container Logs (Before Crash)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl logs $MEDPLUM_POD -n provider-registry --previous --tail=100 2>/dev/null || echo "No previous logs available"
echo ""

# Check environment variables
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Environment Variables${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl exec -n provider-registry $MEDPLUM_POD -- env 2>/dev/null | grep -E "DATABASE|REDIS|BASE_URL|PORT" || echo "Cannot read environment (pod may be crashed)"
echo ""

# Check ConfigMap
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ConfigMap Values${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl get configmap provider-registry-config -n provider-registry -o yaml | grep -v "apiVersion\|kind\|metadata\|namespace\|resourceVersion\|uid\|creationTimestamp"
echo ""

# Check Secrets (masked)
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Secrets (Keys Only)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
kubectl get secret provider-registry-secrets -n provider-registry -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || kubectl get secret provider-registry-secrets -n provider-registry -o json | grep -o '"[^"]*":' | tr -d '":' | grep -v "apiVersion\|kind\|metadata"
echo ""

# Test database connection
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Testing Database Connection${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
POSTGRES_POD=$(kubectl get pods -n provider-registry -l app=postgres -o jsonpath='{.items[0].metadata.name}')
echo "PostgreSQL pod: $POSTGRES_POD"
kubectl exec -n provider-registry $POSTGRES_POD -- pg_isready -U medplum
echo ""

# Check database exists
echo "Checking if medplum database exists:"
kubectl exec -n provider-registry $POSTGRES_POD -- psql -U medplum -lqt | cut -d \| -f 1 | grep -w medplum && echo -e "${GREEN}✓ Database 'medplum' exists${NC}" || echo -e "${RED}✗ Database 'medplum' not found${NC}"
echo ""

# Common issues check
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Common Issues Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

echo "Checking for common error patterns in logs:"
kubectl logs $MEDPLUM_POD -n provider-registry --previous --tail=200 2>/dev/null | grep -i "error\|failed\|cannot\|refused" | head -10 || echo "No obvious errors found in previous logs"
echo ""

echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Recommendations${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Based on CrashLoopBackOff, likely causes:"
echo "1. Database connection failure"
echo "2. Missing environment variables"
echo "3. Database not initialized"
echo "4. Port conflicts"
echo ""
echo "To fix:"
echo "1. Check the logs above for specific errors"
echo "2. Verify database credentials match in secrets and configmap"
echo "3. Ensure BASE_URL is set correctly"
echo "4. Check if database migration is needed"
echo ""
