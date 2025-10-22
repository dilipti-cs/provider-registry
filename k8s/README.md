# Kubernetes Manifests for Provider Registry

This directory contains Kubernetes manifests for deploying Provider Registry to GKE.

## Files Overview

- **namespace.yaml**: Creates the `provider-registry` namespace
- **configmap.yaml**: Application configuration (non-sensitive)
- **secrets.yaml**: Sensitive configuration (passwords, keys) - **UPDATE BEFORE PRODUCTION**
- **postgres-statefulset.yaml**: PostgreSQL database deployment
- **redis-deployment.yaml**: Redis cache deployment
- **medplum-deployment.yaml**: Medplum FHIR server deployment
- **frontend-deployment.yaml**: React frontend deployment
- **ingress.yaml**: Ingress configuration for external access

## Quick Start

### 1. Update Configuration

Before deploying, update the following:

#### configmap.yaml
```yaml
BASE_URL: "https://your-actual-domain.com"
APP_URL: "https://your-frontend-domain.com"
```

#### secrets.yaml
```yaml
POSTGRES_PASSWORD: "generate-strong-password"
DATABASE_PASSWORD: "generate-strong-password"
```

**IMPORTANT**: For production, use proper secret management:

```bash
# Don't commit secrets to Git! Create them with kubectl:
kubectl create secret generic provider-registry-secrets \
  -n provider-registry \
  --from-literal=POSTGRES_PASSWORD='your-strong-password' \
  --from-literal=DATABASE_PASSWORD='your-strong-password'
```

#### frontend-deployment.yaml
```yaml
# Update the image reference
image: gcr.io/YOUR_PROJECT_ID/provider-registry-frontend:latest
```

#### ingress.yaml
```yaml
# Update domain names
- host: your-frontend-domain.com
- host: your-api-domain.com
```

### 2. Deploy in Order

```bash
# 1. Create namespace
kubectl apply -f namespace.yaml

# 2. Create secrets and config
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml

# 3. Deploy databases
kubectl apply -f postgres-statefulset.yaml
kubectl apply -f redis-deployment.yaml

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n provider-registry --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n provider-registry --timeout=300s

# 4. Deploy Medplum server
kubectl apply -f medplum-deployment.yaml

# Wait for Medplum to be ready
kubectl wait --for=condition=ready pod -l app=medplum-server -n provider-registry --timeout=300s

# 5. Initialize Medplum database (FIRST TIME ONLY)
POD=$(kubectl get pods -n provider-registry -l app=medplum-server -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n provider-registry $POD -- npx medplum db:migrate
kubectl exec -it -n provider-registry $POD -- npx medplum create-super-admin \
  --email admin@example.com --password Admin123! --firstName Admin --lastName User

# 6. Deploy frontend
kubectl apply -f frontend-deployment.yaml

# 7. Setup ingress (optional)
kubectl apply -f ingress.yaml
```

### 3. Verify Deployment

```bash
# Check all resources
kubectl get all -n provider-registry

# Check pods are running
kubectl get pods -n provider-registry

# Check services
kubectl get services -n provider-registry

# Check ingress
kubectl get ingress -n provider-registry
```

## Port Forwarding for Local Access

If you don't want to setup ingress immediately:

```bash
# Frontend
kubectl port-forward -n provider-registry service/frontend-service 3001:80

# Medplum API
kubectl port-forward -n provider-registry service/medplum-service 8103:8103

# Access at:
# http://localhost:3001 (frontend)
# http://localhost:8103 (API)
```

## Scaling

```bash
# Scale frontend
kubectl scale deployment provider-registry-frontend -n provider-registry --replicas=5

# Scale Medplum
kubectl scale deployment medplum-server -n provider-registry --replicas=3
```

## Updating

```bash
# Update deployment with new image
kubectl set image deployment/provider-registry-frontend \
  frontend=gcr.io/PROJECT_ID/provider-registry-frontend:v2 \
  -n provider-registry

# Check rollout status
kubectl rollout status deployment/provider-registry-frontend -n provider-registry
```

## Troubleshooting

```bash
# View logs
kubectl logs -n provider-registry -l app=provider-registry-frontend --tail=100 -f
kubectl logs -n provider-registry -l app=medplum-server --tail=100 -f

# Describe pod to see issues
kubectl describe pod <pod-name> -n provider-registry

# Get events
kubectl get events -n provider-registry --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n provider-registry
kubectl top nodes
```

## Cleanup

```bash
# Delete all resources
kubectl delete namespace provider-registry

# Or use the cleanup script
../scripts/cleanup.sh
```

## Storage Classes

The manifests use `standard-rwo` storage class (GKE default). For production, consider:

- `premium-rwo`: SSD-backed persistent disks (better performance)
- `standard-rwo`: Standard persistent disks (default)

Update `storageClassName` in the StatefulSet and PVC manifests as needed.

## Security Notes

1. **Never commit secrets to Git** - Use kubectl create secret or Secret Manager
2. **Use RBAC** - Implement proper role-based access control
3. **Network Policies** - Consider adding NetworkPolicy resources
4. **Pod Security** - Use PodSecurityPolicy or Pod Security Standards
5. **Image scanning** - Scan images for vulnerabilities before deployment

## Production Considerations

- [ ] Use managed PostgreSQL (Cloud SQL) instead of in-cluster PostgreSQL
- [ ] Use Cloud Memorystore instead of in-cluster Redis
- [ ] Enable Workload Identity for service account management
- [ ] Use Google Secret Manager for secrets
- [ ] Implement backup strategy
- [ ] Setup monitoring and alerting
- [ ] Configure autoscaling (HPA)
- [ ] Use managed SSL certificates
- [ ] Implement network policies
- [ ] Enable audit logging
