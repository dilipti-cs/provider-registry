# Database Credentials Fix - URGENT

## Problem Identified ✓

Your logs revealed **TWO separate issues**:

### Issue 1: Config File Missing (Old Pod) ✅ FIXED
```
Error: ENOENT: no such file or directory, open '/usr/src/medplum/packages/server/medplum.config.json'
```
- **Pod**: medplum-server-d97bd7bfd-qs774 (30m old)
- **Status**: CrashLoopBackOff
- **Fix**: Already applied in previous commits

### Issue 2: Database Credentials Missing (New Pods) ✅ FIXED NOW
```
error: no PostgreSQL user name specified in startup packet
```
- **Pods**: medplum-server-588d5d76f-hz8l9, medplum-server-58db6c487-cxpn4
- **Status**: Running but Not Ready (0/1)
- **Root Cause**: Config file was missing `username` and `password` in database section
- **Fix**: Just committed in 7e91d06

## What Was Wrong?

The `medplum.config.json` had:
```json
"database": {
  "host": "postgres-service",
  "port": 5432,
  "dbname": "medplum"
  ❌ Missing: username, password
}
```

Medplum Server started successfully but couldn't connect to PostgreSQL because no credentials were provided.

## What's Been Fixed?

### 1. Added Database Credentials (k8s/medplum-config.yaml)

```json
"database": {
  "host": "postgres-service",
  "port": 5432,
  "dbname": "medplum",
  "username": "medplum",                    ✅ ADDED
  "password": "CHANGE_ME_IN_PRODUCTION"     ✅ ADDED
}
```

### 2. Increased Health Check Delays (k8s/medplum-deployment.yaml)

```yaml
readinessProbe:
  initialDelaySeconds: 60   # Was 30
  timeoutSeconds: 10        # Was 5
  failureThreshold: 3       # NEW

livenessProbe:
  initialDelaySeconds: 90   # Was 60
  failureThreshold: 5       # NEW
```

This gives Medplum more time to:
- Connect to PostgreSQL
- Connect to Redis
- Run database migrations
- Start the HTTP server

### 3. Enhanced Fix Script (scripts/fix-medplum-crashloop.sh)

Now checks and creates secrets if missing:
```bash
Step 2: Checking database credentials (secrets)...
```

### 4. New Diagnostic Tool (scripts/diagnose-medplum.sh)

Comprehensive diagnostics for "Running but not Ready" pods:
- Checks config file mount
- Analyzes logs for errors
- Tests database connectivity
- Verifies dependencies
- Provides specific recommendations

---

## Apply The Fix NOW (3 Commands)

### Step 1: Pull Latest Changes

```bash
cd provider-registry
git pull origin claude/dev-011CUMiHag3oEPq5d1uXfCPN
```

### Step 2: Run the Fix Script

```bash
./scripts/fix-medplum-crashloop.sh
```

This will:
1. ✅ Check namespace exists
2. ✅ Create secrets if missing (database credentials)
3. ✅ Apply updated config with username/password
4. ✅ Apply deployment with longer health check delays
5. ✅ Restart Medplum pods
6. ✅ Wait for pods to become ready (up to 5 minutes)
7. ✅ Verify success

**Expected Success Message:**
```
╔════════════════════════════════════════════════════════╗
║               ✓ SUCCESS - Medplum is Running!         ║
╚════════════════════════════════════════════════════════╝
```

### Step 3: Clean Up Old Crashed Pods

After the fix succeeds, delete the old crashed pod:

```bash
kubectl delete pod medplum-server-d97bd7bfd-qs774 -n provider-registry
```

Then verify all pods are healthy:

```bash
kubectl get pods -n provider-registry -l app=medplum-server
```

**Expected Output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
medplum-server-xxxxx-yyyyy        1/1     Running   0          2m
medplum-server-xxxxx-zzzzz        1/1     Running   0          2m
```

---

## If Fix Script Shows Errors

### Option A: Use Diagnostic Tool

```bash
./scripts/diagnose-medplum.sh
```

This will:
- Show detailed pod status
- Check if config file is mounted
- Analyze logs for specific errors
- Test database connectivity
- Provide specific next steps

### Option B: Manual Checks

#### Check PostgreSQL is Running

```bash
kubectl get pods -n provider-registry -l app=postgres
```

If not running:
```bash
kubectl apply -f k8s/postgres-statefulset.yaml
```

#### Check Redis is Running

```bash
kubectl get pods -n provider-registry -l app=redis
```

If not running:
```bash
kubectl apply -f k8s/redis-deployment.yaml
```

#### Check Secrets Exist

```bash
kubectl get secret provider-registry-secrets -n provider-registry
```

If not found:
```bash
kubectl apply -f k8s/secrets.yaml
```

#### View Real-Time Logs

```bash
# Get newest pod name
NEWEST_POD=$(kubectl get pods -n provider-registry -l app=medplum-server --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

# Watch logs live
kubectl logs -n provider-registry $NEWEST_POD -f
```

**Look for:**
- ✅ `"msg":"Starting Medplum Server..."` - Good start
- ✅ `"msg":"Server started"` or `"listening"` - Success!
- ❌ `"ENOENT"` - Config file issue (shouldn't happen now)
- ❌ `"no PostgreSQL user name"` - Database credentials issue (shouldn't happen now)
- ❌ `"connection refused"` - PostgreSQL not running
- ❌ `"redis.*error"` - Redis not running

---

## After Successful Fix

Once pods show `1/1 Running`:

### 1. Initialize Database

```bash
./scripts/init-medplum.sh
```

This will:
- Run database migrations
- Create super admin user
- Verify Medplum health

**Admin Credentials:**
- Email: admin@example.com
- Password: Admin123!

### 2. Access Application

**Terminal 1 - Frontend:**
```bash
kubectl port-forward -n provider-registry service/frontend-service 3001:80
```

**Terminal 2 - Medplum API:**
```bash
kubectl port-forward -n provider-registry service/medplum-service 8103:8103
```

**Browser:**
- Open: http://localhost:3001
- Login with admin credentials above
- **CHANGE PASSWORD IMMEDIATELY!**

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `git pull origin claude/dev-011CUMiHag3oEPq5d1uXfCPN` | Get latest fixes |
| `./scripts/fix-medplum-crashloop.sh` | Apply the fix |
| `./scripts/diagnose-medplum.sh` | Diagnose issues |
| `./scripts/init-medplum.sh` | Initialize database |
| `kubectl get pods -n provider-registry -l app=medplum-server` | Check pod status |
| `kubectl logs -n provider-registry <POD_NAME> -f` | Watch logs |
| `kubectl describe pod <POD_NAME> -n provider-registry` | Detailed pod info |
| `kubectl delete pod <POD_NAME> -n provider-registry` | Delete crashed pod |

---

## Technical Details

### Why Environment Variables Weren't Enough?

Medplum Server v3.2.21 requires the base configuration structure in the config file. While environment variables can **override** values, they cannot **replace** the config file structure entirely.

The proper hierarchy is:
1. **Config file** provides base structure
2. **Environment variables** override specific values
3. Both are needed for complete configuration

### What About Security?

The credentials in the config file (`medplum` / `CHANGE_ME_IN_PRODUCTION`) match those in `k8s/secrets.yaml`. For production:

1. Change the password in secrets:
   ```bash
   kubectl create secret generic provider-registry-secrets \
     --from-literal=DATABASE_USERNAME=medplum \
     --from-literal=DATABASE_PASSWORD=your-strong-password \
     -n provider-registry \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

2. Update the config file with the same password

3. Or use Google Secret Manager with Workload Identity for production-grade secret management

---

## Success Indicators

You'll know it's working when:

1. ✅ Fix script shows: `✓ SUCCESS - Medplum is Running!`
2. ✅ All pods show: `1/1 Running` (not `0/1`)
3. ✅ Logs show: `Server started` or `listening on port 8103`
4. ✅ No restart counts increasing
5. ✅ Health check endpoint responds: `curl http://localhost:8103/healthcheck`

---

## Still Having Issues?

If problems persist:

1. **Run diagnostics**: `./scripts/diagnose-medplum.sh`
2. **Check overall status**: `./scripts/check-status.sh`
3. **View events**: `kubectl get events -n provider-registry --sort-by='.lastTimestamp' | tail -20`
4. **Share the output** so I can provide more specific guidance

---

**Ready to fix this? Run the 3 commands above!** 🚀
