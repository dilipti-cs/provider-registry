#!/bin/bash
# Initialize Medplum database and create super admin user
# Run this only on first deployment

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Medplum Initialization Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if medplum pod is running
echo -e "${YELLOW}Checking for Medplum server pod...${NC}"
POD=$(kubectl get pods -n provider-registry -l app=medplum-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
    echo -e "${RED}Error: No Medplum server pod found${NC}"
    echo "Make sure the Medplum server is deployed first"
    exit 1
fi

echo -e "${GREEN}Found Medplum pod: $POD${NC}"

# Run database migration
echo -e "${YELLOW}Running database migration...${NC}"
kubectl exec -it -n provider-registry $POD -- npx medplum db:migrate

echo ""
echo -e "${YELLOW}Creating super admin user...${NC}"
echo "Please provide the admin user details:"
read -p "Email: " ADMIN_EMAIL
read -s -p "Password: " ADMIN_PASSWORD
echo ""
read -p "First Name: " FIRST_NAME
read -p "Last Name: " LAST_NAME

echo -e "${YELLOW}Creating admin user...${NC}"
kubectl exec -it -n provider-registry $POD -- \
  npx medplum create-super-admin \
  --email "$ADMIN_EMAIL" \
  --password "$ADMIN_PASSWORD" \
  --firstName "$FIRST_NAME" \
  --lastName "$LAST_NAME"

echo ""
echo -e "${GREEN}Medplum initialization completed!${NC}"
echo -e "${YELLOW}Admin credentials:${NC}"
echo "Email: $ADMIN_EMAIL"
echo "Password: [hidden]"
echo ""
echo -e "${YELLOW}Save these credentials securely!${NC}"
