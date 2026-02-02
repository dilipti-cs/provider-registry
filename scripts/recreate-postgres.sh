#!/bin/bash
# Fix PostgreSQL password mismatch issue

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     PostgreSQL Password Fix - Recreate Database       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${RED}⚠️  WARNING: This will DELETE your PostgreSQL database!${NC}"
echo -e "${RED}⚠️  All data will be lost and database will be recreated.${NC}"
echo ""
echo -e "${YELLOW}This is safe for initial setup, but NOT for production!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi
echo ""

# Step 1: Ensure secrets exist
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1: Ensuring Secrets Exist${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if kubectl get secret provider-registry-secrets -n provider-registry &>/dev/null; then
    echo -e "${GREEN}✓ Secrets already exist${NC}"
else
    echo -e "${YELLOW}⚠ Secrets not found, creating...${NC}"
    kubectl apply -f k8s/secrets.yaml
    echo -e "${GREEN}✓ Secrets created${NC}"
fi
echo ""

# Step 2: Delete existing PostgreSQL
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2: Deleting Existing PostgreSQL${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if kubectl get statefulset postgres -n provider-registry &>/dev/null; then
    echo "Deleting PostgreSQL StatefulSet..."
    kubectl delete statefulset postgres -n provider-registry --wait=true
    echo -e "${GREEN}✓ StatefulSet deleted${NC}"
else
    echo -e "${YELLOW}⚠ No PostgreSQL StatefulSet found${NC}"
fi
echo ""

# Step 3: Delete PVC to clear old data
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 3: Deleting Persistent Volume Claim${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

PVC_NAME=$(kubectl get pvc -n provider-registry -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$PVC_NAME" ]; then
    echo "Deleting PVC: $PVC_NAME"
    kubectl delete pvc "$PVC_NAME" -n provider-registry --wait=true
    echo -e "${GREEN}✓ PVC deleted${NC}"
else
    # Try the default name
    if kubectl get pvc postgres-storage-postgres-0 -n provider-registry &>/dev/null; then
        echo "Deleting PVC: postgres-storage-postgres-0"
        kubectl delete pvc postgres-storage-postgres-0 -n provider-registry --wait=true
        echo -e "${GREEN}✓ PVC deleted${NC}"
    else
        echo -e "${YELLOW}⚠ No PVC found${NC}"
    fi
fi
echo ""

# Step 4: Recreate PostgreSQL
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 4: Creating PostgreSQL with Correct Credentials${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

kubectl apply -f k8s/postgres-statefulset.yaml
echo -e "${GREEN}✓ PostgreSQL StatefulSet created${NC}"
echo ""

# Step 5: Wait for PostgreSQL to be ready
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 5: Waiting for PostgreSQL to be Ready${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo "Waiting for pod to be created..."
sleep 5

echo "Waiting for PostgreSQL to be ready (timeout: 120 seconds)..."
if kubectl wait --for=condition=ready pod -l app=postgres -n provider-registry --timeout=120s 2>/dev/null; then
    echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
else
    echo -e "${RED}✗ PostgreSQL did not become ready in time${NC}"
    echo ""
    echo "Check pod status:"
    kubectl get pods -n provider-registry -l app=postgres
    echo ""
    echo "Check logs:"
    POSTGRES_POD=$(kubectl get pods -n provider-registry -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$POSTGRES_POD" ]; then
        kubectl logs -n provider-registry "$POSTGRES_POD" --tail=30
    fi
    exit 1
fi
echo ""

# Step 6: Verify credentials
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 6: Verifying Database Credentials${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

POSTGRES_POD=$(kubectl get pods -n provider-registry -l app=postgres -o jsonpath='{.items[0].metadata.name}')

echo "Testing database connection..."
if kubectl exec -n provider-registry "$POSTGRES_POD" -- psql -U medplum -d medplum -c "SELECT 1" &>/dev/null; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
    echo -e "${GREEN}✓ Credentials are correct${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo "This shouldn't happen. Check PostgreSQL logs:"
    kubectl logs -n provider-registry "$POSTGRES_POD" --tail=30
    exit 1
fi
echo ""

# Success
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✓ PostgreSQL Successfully Recreated!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Now fix and restart Medplum:"
echo -e "   ${BLUE}./scripts/fix-medplum-crashloop.sh${NC}"
echo ""
echo "2. Once Medplum is running, initialize the database:"
echo -e "   ${BLUE}./scripts/init-medplum.sh${NC}"
echo ""
echo "3. Check overall status:"
echo -e "   ${BLUE}./scripts/check-status.sh${NC}"
echo ""
