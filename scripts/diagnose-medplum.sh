#!/bin/bash
# Quick diagnostic script for Medplum "Running but not Ready" issue

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Medplum Pod Diagnostics - Running but Not Ready   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get all Medplum pods
echo -e "${YELLOW}Current Medplum Pod Status:${NC}"
kubectl get pods -n provider-registry -l app=medplum-server
echo ""

# Get the newest pod
NEWEST_POD=$(kubectl get pods -n provider-registry -l app=medplum-server --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)

if [ -z "$NEWEST_POD" ]; then
    echo -e "${RED}✗ No Medplum pods found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Diagnosing pod: $NEWEST_POD${NC}"
echo ""

# 1. Check if config file is mounted
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. Checking Config File Mount${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if kubectl exec -n provider-registry "$NEWEST_POD" -- test -f /usr/src/medplum/packages/server/medplum.config.json 2>/dev/null; then
    echo -e "${GREEN}✓ Config file exists${NC}"
    echo ""
    echo "Config file contents:"
    kubectl exec -n provider-registry "$NEWEST_POD" -- cat /usr/src/medplum/packages/server/medplum.config.json 2>/dev/null | head -20
else
    echo -e "${RED}✗ Config file NOT found${NC}"
    echo ""
    echo "This is the problem! Apply the config:"
    echo "  kubectl apply -f k8s/medplum-config.yaml"
    echo "  kubectl rollout restart deployment/medplum-server -n provider-registry"
    exit 1
fi
echo ""

# 2. Check recent logs
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. Recent Application Logs${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

LOGS=$(kubectl logs -n provider-registry "$NEWEST_POD" --tail=50 2>&1)
echo "$LOGS"
echo ""

# Analyze logs for common issues
if echo "$LOGS" | grep -q "ENOENT"; then
    echo -e "${RED}✗ Config file error detected in logs${NC}"
elif echo "$LOGS" | grep -qi "database.*error\|connection.*refused\|ECONNREFUSED"; then
    echo -e "${RED}✗ Database connection error detected${NC}"
    echo ""
    echo "Check if PostgreSQL is running:"
    echo "  kubectl get pods -n provider-registry -l app=postgres"
elif echo "$LOGS" | grep -qi "redis.*error\|redis.*connection"; then
    echo -e "${RED}✗ Redis connection error detected${NC}"
    echo ""
    echo "Check if Redis is running:"
    echo "  kubectl get pods -n provider-registry -l app=redis"
elif echo "$LOGS" | grep -qi "listening\|started\|ready"; then
    echo -e "${GREEN}✓ Server appears to be starting successfully${NC}"
else
    echo -e "${YELLOW}⚠ No obvious errors, but also no success messages${NC}"
fi
echo ""

# 3. Check health probe failures
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}3. Health Probe Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

EVENTS=$(kubectl describe pod "$NEWEST_POD" -n provider-registry 2>/dev/null)

if echo "$EVENTS" | grep -q "Readiness probe failed"; then
    echo -e "${RED}✗ Readiness probe is failing${NC}"
    echo ""
    echo "Recent probe failures:"
    echo "$EVENTS" | grep "Readiness probe failed" | tail -5
    echo ""
    echo "This could mean:"
    echo "1. Server is taking longer than 30s to start"
    echo "2. Database/Redis not ready"
    echo "3. /healthcheck endpoint not responding"
elif echo "$EVENTS" | grep -q "Liveness probe failed"; then
    echo -e "${RED}✗ Liveness probe is failing${NC}"
    echo ""
    echo "$EVENTS" | grep "Liveness probe failed" | tail -5
else
    echo -e "${GREEN}✓ No probe failures detected yet${NC}"
fi
echo ""

# 4. Check dependencies
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}4. Checking Dependencies${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo "PostgreSQL:"
POSTGRES_STATUS=$(kubectl get pods -n provider-registry -l app=postgres -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Not Found")
if [ "$POSTGRES_STATUS" = "Running" ]; then
    echo -e "  ${GREEN}✓ PostgreSQL is Running${NC}"
else
    echo -e "  ${RED}✗ PostgreSQL is $POSTGRES_STATUS${NC}"
fi

echo "Redis:"
REDIS_STATUS=$(kubectl get pods -n provider-registry -l app=redis -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Not Found")
if [ "$REDIS_STATUS" = "Running" ]; then
    echo -e "  ${GREEN}✓ Redis is Running${NC}"
else
    echo -e "  ${RED}✗ Redis is $REDIS_STATUS${NC}"
fi
echo ""

# 5. Test database connectivity from Medplum pod
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}5. Testing Database Connectivity${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if kubectl exec -n provider-registry "$NEWEST_POD" -- nc -zv postgres-service 5432 2>&1 | grep -q "open\|succeeded"; then
    echo -e "${GREEN}✓ Can connect to PostgreSQL service${NC}"
else
    echo -e "${RED}✗ Cannot connect to PostgreSQL service${NC}"
fi
echo ""

# Summary and recommendations
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Recommendations                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$POSTGRES_STATUS" != "Running" ]; then
    echo -e "${YELLOW}1. Start PostgreSQL:${NC}"
    echo "   kubectl apply -f k8s/postgres-statefulset.yaml"
    echo ""
fi

if [ "$REDIS_STATUS" != "Running" ]; then
    echo -e "${YELLOW}2. Start Redis:${NC}"
    echo "   kubectl apply -f k8s/redis-deployment.yaml"
    echo ""
fi

if echo "$EVENTS" | grep -q "Readiness probe failed"; then
    echo -e "${YELLOW}3. Health probe may need more time:${NC}"
    echo "   The updated deployment with longer delays has been prepared."
    echo "   Pull latest changes and apply:"
    echo "   git pull origin claude/dev-011CUMiHag3oEPq5d1uXfCPN"
    echo "   kubectl apply -f k8s/medplum-deployment.yaml"
    echo ""
fi

echo -e "${YELLOW}4. Clean up old crashed pods:${NC}"
echo "   kubectl get pods -n provider-registry -l app=medplum-server"
echo "   kubectl delete pod <OLD_CRASHED_POD_NAME> -n provider-registry"
echo ""

echo -e "${YELLOW}5. Monitor logs in real-time:${NC}"
echo "   kubectl logs -n provider-registry $NEWEST_POD -f"
echo ""

echo -e "${YELLOW}6. Check events:${NC}"
echo "   kubectl get events -n provider-registry --sort-by='.lastTimestamp' | tail -20"
echo ""
