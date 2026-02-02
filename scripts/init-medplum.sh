#!/bin/bash
# Medplum Initialization Script
# Run this AFTER Medplum pods are running to initialize the database and create admin user

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Medplum Database Initialization                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Medplum pod is running
echo -e "${YELLOW}Checking if Medplum Server is running...${NC}"
MEDPLUM_POD=$(kubectl get pods -n provider-registry -l app=medplum-server --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$MEDPLUM_POD" ]; then
    echo -e "${RED}✗ No running Medplum pods found${NC}"
    echo ""
    echo "Make sure Medplum is running first:"
    echo "  kubectl get pods -n provider-registry -l app=medplum-server"
    echo ""
    echo "If pods are in CrashLoopBackOff, run:"
    echo "  ./scripts/fix-medplum-crashloop.sh"
    exit 1
fi

echo -e "${GREEN}✓ Found running Medplum pod: $MEDPLUM_POD${NC}"
echo ""

# Step 1: Run database migration
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1: Running Database Migration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "This will create all necessary tables and schemas in PostgreSQL..."
echo ""

if kubectl exec -n provider-registry "$MEDPLUM_POD" -- npx medplum db:migrate; then
    echo ""
    echo -e "${GREEN}✓ Database migration completed successfully${NC}"
else
    echo ""
    echo -e "${RED}✗ Database migration failed${NC}"
    echo ""
    echo "Check if PostgreSQL is running:"
    echo "  kubectl get pods -n provider-registry -l app=postgres"
    echo ""
    echo "Check database connection from Medplum pod:"
    echo "  kubectl exec -n provider-registry $MEDPLUM_POD -- env | grep DATABASE"
    exit 1
fi
echo ""

# Step 2: Create super admin user
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2: Creating Super Admin User${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Default admin credentials will be created:"
echo "  Email: admin@example.com"
echo "  Password: Admin123!"
echo ""
echo -e "${YELLOW}⚠ IMPORTANT: Change this password immediately after first login!${NC}"
echo ""

if kubectl exec -n provider-registry "$MEDPLUM_POD" -- \
    npx medplum create-super-admin \
    --email admin@example.com \
    --password "Admin123!" \
    --firstName Admin \
    --lastName User; then
    echo ""
    echo -e "${GREEN}✓ Super admin user created successfully${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠ Super admin creation may have failed${NC}"
    echo ""
    echo "This could mean:"
    echo "1. Admin user already exists (not an error)"
    echo "2. Database migration didn't complete"
    echo "3. Database connection issue"
    echo ""
    echo "Check Medplum logs:"
    echo "  kubectl logs -n provider-registry $MEDPLUM_POD --tail=50"
fi
echo ""

# Step 3: Verify Medplum health
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 3: Verifying Medplum Health${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Port forward in background briefly to test healthcheck
echo "Testing healthcheck endpoint..."
kubectl port-forward -n provider-registry "service/medplum-service" 8103:8103 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!

# Wait for port forward to establish
sleep 3

# Test healthcheck
if curl -s -f http://localhost:8103/healthcheck >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Medplum healthcheck endpoint is responding${NC}"
    HEALTH_OK=true
else
    echo -e "${YELLOW}⚠ Could not reach healthcheck endpoint${NC}"
    HEALTH_OK=false
fi

# Kill port forward
kill $PORT_FORWARD_PID 2>/dev/null || true
wait $PORT_FORWARD_PID 2>/dev/null || true

echo ""

# Final summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✓ Medplum Initialization Complete            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Admin Credentials (SAVE THESE):${NC}"
echo "  Email:    admin@example.com"
echo "  Password: Admin123!"
echo ""
echo -e "${RED}⚠ SECURITY: Change the admin password immediately after first login!${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Next Steps${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "1. Access the application via port forwarding:"
echo ""
echo "   Terminal 1 (Frontend):"
echo -e "   ${BLUE}kubectl port-forward -n provider-registry service/frontend-service 3001:80${NC}"
echo ""
echo "   Terminal 2 (Medplum API):"
echo -e "   ${BLUE}kubectl port-forward -n provider-registry service/medplum-service 8103:8103${NC}"
echo ""
echo "2. Open in your browser:"
echo -e "   ${GREEN}http://localhost:3001${NC}"
echo ""
echo "3. Login with admin credentials above"
echo ""
echo "4. Create your first Organization and start adding Practitioners!"
echo ""
echo "5. Check overall status anytime:"
echo -e "   ${BLUE}./scripts/check-status.sh${NC}"
echo ""
