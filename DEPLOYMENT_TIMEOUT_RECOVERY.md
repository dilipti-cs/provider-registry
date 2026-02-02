# Deployment Timeout Recovery Guide

## What Happened?

Your deployment script timed out while waiting for Medplum Server pods to become ready:

```
timed out waiting for the condition on pods/medplum-server-7f744f875c-29f5w
timed out waiting for the condition on pods/medplum-server-7f744f875c-flq7n
```

**Don't worry!** This is common. The timeout just means the pods took longer than expected to start. They're likely still starting up or already running.

## Quick Status Check

Run this command to check if everything is actually working:

```bash
./scripts/check-status.sh
```

This will show you:
- ✓ Which pods are running
- ✓ Which services are available
- ✓ Any issues that need attention
- ✓ How to access your application

## Manual Status Check

If you don't have the script, check manually:

### 1. Check Pod Status

```bash
kubectl get pods -n provider-registry
```

**What to look for:**

✅ **Good Status:**
```
NAME                                       READY   STATUS    RESTARTS   AGE
postgres-0                                 1/1     Running   0          10m
redis-xxxxx                                1/1     Running   0          9m
medplum-server-xxxxx                       1/1     Running   0          8m
medplum-server-xxxxx                       1/1     Running   0          8m
provider-registry-frontend-xxxxx           1/1     Running   0          7m
provider-registry-frontend-xxxxx           1/1     Running   0          7m
```

⚠️ **Still Starting:**
```
NAME                                       READY   STATUS              RESTARTS   AGE
medplum-server-xxxxx                       0/1     ContainerCreating   0          2m
medplum-server-xxxxx                       0/1     Running             0          3m
```

If STATUS is `ContainerCreating` or `Running` with READY `0/1`, wait 2-5 more minutes.

❌ **Problem Status:**
```
NAME                                       READY   STATUS             RESTARTS   AGE
medplum-server-xxxxx                       0/1     CrashLoopBackOff   3          5m
medplum-server-xxxxx                       0/1     Error              1          4m
```

### 2. Watch Pods Until Ready

```bash
kubectl get pods -n provider-registry -w
```

Press `Ctrl+C` to exit when all pods show `Running` and `1/1` or `2/2` ready.

### 3. Check Specific Pod Logs

If a pod is having issues:

```bash
# Medplum Server logs
kubectl logs -n provider-registry -l app=medplum-server --tail=50

# PostgreSQL logs
kubectl logs -n provider-registry -l app=postgres --tail=50

# Frontend logs
kubectl logs -n provider-registry -l app=provider-registry-frontend --tail=50
```

## Common Issues and Solutions

### Issue 1: Medplum Pods Stuck in "Running" but not Ready

**Cause:** Medplum is waiting for database connection or initialization.

**Check:**
```bash
kubectl logs -n provider-registry -l app=medplum-server --tail=100
```

**Look for:**
- "Connected to database" - Good!
- "Cannot connect to database" - Database issue
- "Database migration needed" - Need to run migrations

**Solution:**
```bash
# Get Medplum pod name
MEDPLUM_POD=$(kubectl get pods -n provider-registry -l app=medplum-server -o jsonpath='{.items[0].metadata.name}')

# Run database migration
kubectl exec -n provider-registry $MEDPLUM_POD -- npx medplum db:migrate

# Wait 1-2 minutes and check status again
kubectl get pods -n provider-registry
```

### Issue 2: PostgreSQL Not Ready

**Check:**
```bash
kubectl logs -n provider-registry -l app=postgres --tail=50
```

**Look for:**
- "database system is ready to accept connections" - Good!
- Errors about disk space, permissions, etc. - Needs fixing

**Solution if stuck:**
```bash
# Restart PostgreSQL
kubectl rollout restart statefulset/postgres -n provider-registry

# Wait 2-3 minutes
kubectl wait --for=condition=ready pod -l app=postgres -n provider-registry --timeout=300s
```

### Issue 3: Pods Keep Restarting

**Check:**
```bash
kubectl describe pod -n provider-registry <pod-name>
```

**Common causes:**
- Out of memory (OOMKilled)
- Configuration errors
- Health check failures

**Solution:**
See the detailed error in the Events section and address accordingly.

## Initialize Medplum Database (Required First Time)

If this is your **first deployment**, you need to initialize Medplum:

### Step 1: Verify Medplum is Running

```bash
kubectl get pods -n provider-registry -l app=medplum-server
```

Wait until at least one pod shows `Running` status.

### Step 2: Run Database Migration

```bash
# Get Medplum pod name
MEDPLUM_POD=$(kubectl get pods -n provider-registry -l app=medplum-server -o jsonpath='{.items[0].metadata.name}')

# Run migration
kubectl exec -n provider-registry $MEDPLUM_POD -- npx medplum db:migrate
```

### Step 3: Create Super Admin User

```bash
kubectl exec -it -n provider-registry $MEDPLUM_POD -- \
  npx medplum create-super-admin \
  --email admin@example.com \
  --password Admin123! \
  --firstName Admin \
  --lastName User
```

**Save these credentials!**

### Alternative: Use the Init Script

```bash
./scripts/init-medplum.sh
```

## Access Your Application

Once all pods are running and ready:

### Option 1: Port Forwarding (Recommended)

Open **two terminal windows** (in WSL):

**Terminal 1 - Frontend:**
```bash
kubectl port-forward -n provider-registry service/frontend-service 3001:80
```

**Terminal 2 - Medplum API:**
```bash
kubectl port-forward -n provider-registry service/medplum-service 8103:8103
```

Then open in your **Windows browser**:
- Frontend: http://localhost:3001
- API: http://localhost:8103

### Option 2: Direct Pod Access (Troubleshooting)

```bash
# Get frontend pod name
kubectl get pods -n provider-registry -l app=provider-registry-frontend

# Port forward to specific pod
kubectl port-forward -n provider-registry <pod-name> 3001:80
```

## Verify Everything Works

### 1. Check Services

```bash
kubectl get services -n provider-registry
```

Should show:
- postgres-service
- redis-service
- medplum-service
- frontend-service

### 2. Check Endpoints

```bash
kubectl get endpoints -n provider-registry
```

Each service should have endpoints listed (IP addresses).

### 3. Test Medplum API

```bash
# From within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n provider-registry -- \
  curl http://medplum-service:8103/healthcheck

# Should return: {"ok":true}
```

### 4. Test Frontend

Access http://localhost:3001 (after port-forwarding) and:
- ✓ Page loads
- ✓ Can see login form
- ✓ Can enter credentials

## Complete Deployment Summary

### Expected Resources

**Pods (7 total):**
- 1x postgres-0 (StatefulSet)
- 1x redis-xxxxx (Deployment)
- 2x medplum-server-xxxxx (Deployment, 2 replicas)
- 3x provider-registry-frontend-xxxxx (Deployment, 3 replicas)

**Services (4 total):**
- postgres-service (ClusterIP)
- redis-service (ClusterIP)
- medplum-service (ClusterIP)
- frontend-service (ClusterIP)

**PersistentVolumeClaims (2 total):**
- postgres-storage-postgres-0 (10Gi)
- redis-pvc (5Gi)

## Need Help?

### View All Resources

```bash
kubectl get all -n provider-registry
```

### Describe a Specific Resource

```bash
kubectl describe pod <pod-name> -n provider-registry
kubectl describe service <service-name> -n provider-registry
```

### Get Events

```bash
kubectl get events -n provider-registry --sort-by='.lastTimestamp'
```

### Follow Logs in Real-Time

```bash
# Medplum
kubectl logs -n provider-registry -l app=medplum-server -f --tail=100

# Frontend
kubectl logs -n provider-registry -l app=provider-registry-frontend -f --tail=100

# All pods
kubectl logs -n provider-registry --all-containers=true -f
```

## Quick Recovery Commands

### Restart Everything

```bash
# Restart Medplum
kubectl rollout restart deployment/medplum-server -n provider-registry

# Restart Frontend
kubectl rollout restart deployment/provider-registry-frontend -n provider-registry

# Restart Redis
kubectl rollout restart deployment/redis -n provider-registry

# Check status
kubectl rollout status deployment/medplum-server -n provider-registry
```

### Scale Down and Up (Force Restart)

```bash
# Scale down
kubectl scale deployment medplum-server -n provider-registry --replicas=0
kubectl scale deployment provider-registry-frontend -n provider-registry --replicas=0

# Wait 30 seconds
sleep 30

# Scale up
kubectl scale deployment medplum-server -n provider-registry --replicas=2
kubectl scale deployment provider-registry-frontend -n provider-registry --replicas=3

# Watch them come back
kubectl get pods -n provider-registry -w
```

## Success Checklist

- [ ] All pods show `Running` status
- [ ] All pods show `1/1` or `2/2` ready
- [ ] Medplum database is migrated
- [ ] Super admin user is created
- [ ] Can port-forward to services
- [ ] Can access http://localhost:3001
- [ ] Can login with admin credentials
- [ ] Can create a test Organization

## Next Steps After Recovery

1. ✅ Test the application thoroughly
2. ✅ Create some test data (Organizations, Practitioners)
3. ✅ Setup domain and ingress (optional)
4. ✅ Configure automated backups
5. ✅ Setup monitoring alerts

---

**Remember:** Timeouts during deployment are normal! The important thing is that the pods eventually become ready. Use the commands above to verify everything is working properly.
