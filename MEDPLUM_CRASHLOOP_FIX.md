# Medplum CrashLoopBackOff Fix

## Problem

Medplum Server pods were crashing with the following error:

```
Error: ENOENT: no such file or directory, open '/usr/src/medplum/packages/server/medplum.config.json'
```

## Root Cause

Both Medplum Server versions (3.2.21 and latest) require a configuration file at the exact absolute path:
```
/usr/src/medplum/packages/server/medplum.config.json
```

While environment variables can override some configuration values, the base config file is mandatory for the server to start.

## Solution

The fix involves two components:

### 1. Configuration File (k8s/medplum-config.yaml)

A ConfigMap containing the required `medplum.config.json` file with base configuration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: medplum-server-config
  namespace: provider-registry
data:
  medplum.config.json: |
    {
      "port": 8103,
      "baseUrl": "http://localhost:8103",
      "issuer": "http://localhost:8103",
      "database": {
        "host": "postgres-service",
        "port": 5432,
        "dbname": "medplum"
      },
      "redis": {
        "host": "redis-service",
        "port": 6379
      },
      "logLevel": "info"
    }
```

### 2. Volume Mount (k8s/medplum-deployment.yaml)

Mount the ConfigMap at the exact path Medplum expects:

```yaml
spec:
  template:
    spec:
      containers:
      - name: medplum-server
        image: medplum/medplum-server:3.2.21
        volumeMounts:
        - name: config
          mountPath: /usr/src/medplum/packages/server/medplum.config.json
          subPath: medplum.config.json
        env:
          # Environment variables still override config values
          - name: DATABASE_HOST
            valueFrom:
              configMapKeyRef:
                name: provider-registry-config
                key: DATABASE_HOST
          # ... more env vars ...
      volumes:
      - name: config
        configMap:
          name: medplum-server-config
```

## How to Apply the Fix

### Automated Fix Script

Run the automated fix script that applies the configuration and restarts Medplum:

```bash
cd provider-registry
./scripts/fix-medplum-crashloop.sh
```

This script will:
1. Apply the Medplum configuration ConfigMap
2. Update the Medplum deployment with volume mount
3. Restart the deployment
4. Wait for pods to become ready
5. Verify the pods are running
6. Show next steps

### Manual Fix Steps

If you prefer to apply the fix manually:

```bash
# 1. Apply the configuration file
kubectl apply -f k8s/medplum-config.yaml

# 2. Apply the updated deployment
kubectl apply -f k8s/medplum-deployment.yaml

# 3. Restart the deployment
kubectl rollout restart deployment/medplum-server -n provider-registry

# 4. Watch the pods
kubectl get pods -n provider-registry -l app=medplum-server -w

# 5. Check logs if needed
kubectl logs -n provider-registry -l app=medplum-server --tail=50
```

## Verification

After applying the fix, verify Medplum is running:

```bash
# Check pod status - should show Running 1/1
kubectl get pods -n provider-registry -l app=medplum-server

# Check logs - should NOT show "ENOENT" error
kubectl logs -n provider-registry -l app=medplum-server --tail=50

# Check overall deployment
./scripts/check-status.sh
```

## Next Steps After Fix

Once Medplum pods are running successfully:

### 1. Initialize the Database

Run the initialization script to create tables and admin user:

```bash
./scripts/init-medplum.sh
```

This will:
- Run database migrations
- Create a super admin user (admin@example.com / Admin123!)
- Verify Medplum health

**IMPORTANT**: Change the default admin password immediately after first login!

### 2. Access the Application

Set up port forwarding to access the services:

**Terminal 1 - Frontend:**
```bash
kubectl port-forward -n provider-registry service/frontend-service 3001:80
```

**Terminal 2 - Medplum API:**
```bash
kubectl port-forward -n provider-registry service/medplum-service 8103:8103
```

Then open in your browser:
- Frontend: http://localhost:3001
- API: http://localhost:8103

### 3. Login and Test

1. Navigate to http://localhost:3001
2. Login with:
   - Email: admin@example.com
   - Password: Admin123!
3. Change the admin password immediately
4. Create your first Organization
5. Add Practitioners and other resources

## Troubleshooting

### Pods Still Crashing

If pods are still crashing after applying the fix:

```bash
# Check the exact error
kubectl logs -n provider-registry -l app=medplum-server --tail=100

# Check if ConfigMap was applied
kubectl get configmap medplum-server-config -n provider-registry -o yaml

# Check if volume mount is correct
kubectl describe deployment medplum-server -n provider-registry | grep -A 10 "Mounts:"

# Check for other issues
./scripts/troubleshoot-medplum.sh
```

### Database Connection Issues

If Medplum starts but can't connect to the database:

```bash
# Check PostgreSQL is running
kubectl get pods -n provider-registry -l app=postgres

# Test database connection
POSTGRES_POD=$(kubectl get pods -n provider-registry -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n provider-registry $POSTGRES_POD -- pg_isready -U medplum

# Check database exists
kubectl exec -n provider-registry $POSTGRES_POD -- psql -U medplum -lqt | grep medplum
```

### Config File Not Found

If you still see "ENOENT" errors after applying the fix:

```bash
# Verify the config file is mounted
MEDPLUM_POD=$(kubectl get pods -n provider-registry -l app=medplum-server -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n provider-registry $MEDPLUM_POD -- ls -la /usr/src/medplum/packages/server/

# Check the file contents
kubectl exec -n provider-registry $MEDPLUM_POD -- cat /usr/src/medplum/packages/server/medplum.config.json
```

## Why This Fix Works

1. **Medplum Requirements**: Medplum Server is designed to load a base configuration from a JSON file at startup
2. **File Location**: The hardcoded path is `/usr/src/medplum/packages/server/medplum.config.json` in the official Docker image
3. **Environment Variables**: While env vars can override config values, they cannot replace the config file entirely
4. **Kubernetes ConfigMap**: The cleanest way to provide this file in Kubernetes is via a ConfigMap mounted as a volume
5. **SubPath Mount**: Using `subPath` ensures we mount just the file, not the entire directory

## Version Compatibility

This fix works with:
- ✅ Medplum Server 3.2.21 (currently deployed)
- ✅ Medplum Server 5.0.13 (latest)
- ✅ Other Medplum Server versions that follow the same config file convention

## Additional Resources

- [Medplum Documentation](https://www.medplum.com/docs)
- [Medplum Configuration Guide](https://www.medplum.com/docs/self-hosting/install-on-server#configuration-file)
- [DEPLOYMENT_TIMEOUT_RECOVERY.md](./DEPLOYMENT_TIMEOUT_RECOVERY.md) - General deployment recovery guide
- [scripts/troubleshoot-medplum.sh](./scripts/troubleshoot-medplum.sh) - Comprehensive troubleshooting script
- [scripts/check-status.sh](./scripts/check-status.sh) - Deployment status checker
