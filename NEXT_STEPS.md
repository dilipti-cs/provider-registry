# Next Steps - Medplum CrashLoopBackOff Resolution

## Current Status

The Medplum CrashLoopBackOff issue has been analyzed and fixed. The solution is ready to deploy.

### What Was the Problem?

Medplum Server requires a configuration file at `/usr/src/medplum/packages/server/medplum.config.json`. The error was:

```
Error: ENOENT: no such file or directory, open '/usr/src/medplum/packages/server/medplum.config.json'
```

### What's Been Fixed?

1. ✅ Created `k8s/medplum-config.yaml` - ConfigMap with required config file
2. ✅ Updated `k8s/medplum-deployment.yaml` - Mounts config at correct path
3. ✅ Created `scripts/fix-medplum-crashloop.sh` - Automated fix application
4. ✅ Enhanced `scripts/init-medplum.sh` - Database initialization
5. ✅ Created `MEDPLUM_CRASHLOOP_FIX.md` - Detailed documentation

All changes have been committed and pushed to branch: `claude/dev-011CUMiHag3oEPq5d1uXfCPN`

---

## How to Apply the Fix (3 Simple Steps)

### Step 1: Pull the Latest Changes

On your Windows laptop (in WSL/Ubuntu terminal):

```bash
cd provider-registry
git pull origin claude/dev-011CUMiHag3oEPq5d1uXfCPN
```

### Step 2: Apply the Fix

Run the automated fix script:

```bash
./scripts/fix-medplum-crashloop.sh
```

This script will:
- Apply the Medplum configuration ConfigMap
- Update the deployment with correct volume mount
- Restart Medplum pods
- Wait for them to become ready (up to 5 minutes)
- Verify they're running successfully

**Expected output:**
```
╔════════════════════════════════════════════════════════╗
║               ✓ SUCCESS - Medplum is Running!         ║
╚════════════════════════════════════════════════════════╝
```

### Step 3: Initialize Medplum Database

Once Medplum pods are running (Step 2 succeeded):

```bash
./scripts/init-medplum.sh
```

This will:
- Run database migrations to create all tables
- Create a super admin user
- Verify Medplum health

**Default admin credentials** (change after first login):
- Email: `admin@example.com`
- Password: `Admin123!`

---

## Access Your Application

After initialization, access the Provider Registry:

### Option 1: Port Forwarding (Recommended)

Open **two separate terminal windows** in WSL:

**Terminal 1 - Frontend:**
```bash
kubectl port-forward -n provider-registry service/frontend-service 3001:80
```

**Terminal 2 - Medplum API:**
```bash
kubectl port-forward -n provider-registry service/medplum-service 8103:8103
```

Keep both terminals open while using the application.

### Option 2: Open in Browser

Once port forwarding is active, open in your **Windows browser**:

- **Frontend**: http://localhost:3001
- **API**: http://localhost:8103/healthcheck (should show `{"ok":true}`)

### Login

1. Navigate to http://localhost:3001
2. Login with:
   - Email: `admin@example.com`
   - Password: `Admin123!`
3. **IMPORTANT**: Change the password immediately after first login!

---

## Verification Checklist

Use these commands to verify everything is working:

### ✓ Check All Pods Are Running

```bash
kubectl get pods -n provider-registry
```

**Expected**: All pods should show `Running` status with `1/1` or `2/2` ready.

### ✓ Check Medplum Specifically

```bash
kubectl get pods -n provider-registry -l app=medplum-server
```

**Expected**: Should show 2 pods, both `Running 1/1`.

### ✓ Check Medplum Logs (No Errors)

```bash
kubectl logs -n provider-registry -l app=medplum-server --tail=30
```

**Expected**: Should NOT see "ENOENT" or "Error" messages. Should see successful startup logs.

### ✓ Overall Deployment Status

```bash
./scripts/check-status.sh
```

**Expected**: Should show all components as Running and ready.

---

## Troubleshooting

### If Fix Script Fails

If `fix-medplum-crashloop.sh` reports failure:

1. **Check the error message** in the script output
2. **View pod status**:
   ```bash
   kubectl get pods -n provider-registry -l app=medplum-server
   ```
3. **Check logs**:
   ```bash
   kubectl logs -n provider-registry -l app=medplum-server --tail=50
   ```
4. **Run comprehensive troubleshooting**:
   ```bash
   ./scripts/troubleshoot-medplum.sh
   ```
5. **Check the documentation**:
   - Read `MEDPLUM_CRASHLOOP_FIX.md` for detailed troubleshooting
   - Check `DEPLOYMENT_TIMEOUT_RECOVERY.md` for general deployment issues

### If Initialization Fails

If `init-medplum.sh` fails:

1. **Ensure Medplum pods are running**:
   ```bash
   kubectl get pods -n provider-registry -l app=medplum-server
   ```
2. **Check PostgreSQL is running**:
   ```bash
   kubectl get pods -n provider-registry -l app=postgres
   ```
3. **Test database connection**:
   ```bash
   POSTGRES_POD=$(kubectl get pods -n provider-registry -l app=postgres -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n provider-registry $POSTGRES_POD -- pg_isready -U medplum
   ```

### If Frontend Won't Load

1. **Verify frontend pods are running**:
   ```bash
   kubectl get pods -n provider-registry -l app=provider-registry-frontend
   ```
2. **If not deployed yet**, apply the frontend deployment:
   ```bash
   kubectl apply -f k8s/frontend-deployment.yaml
   ```
3. **Check frontend logs**:
   ```bash
   kubectl logs -n provider-registry -l app=provider-registry-frontend --tail=30
   ```

---

## What to Do After Successful Deployment

Once everything is running and you've logged in:

### 1. Change Admin Password

1. Click on your profile (top right)
2. Go to Settings
3. Change password from `Admin123!` to something secure

### 2. Create Your First Organization

1. Navigate to "Organizations"
2. Click "New Organization"
3. Fill in:
   - Name: Your organization name
   - NPI: Your organization NPI (if applicable)
   - Type: Select appropriate type
   - Address: Full address details
4. Save

### 3. Add Practitioners

1. Navigate to "Practitioners"
2. Click "New Practitioner"
3. Fill in practitioner details
4. Assign to the organization you created

### 4. Test the Application

- Create a few test Practitioners
- Create Organizations
- Assign PractitionerRoles
- Verify search functionality works
- Test filtering and pagination

### 5. Setup Production Features (Optional)

For production readiness:

- **Custom Domain**: Configure DNS and update ingress
- **SSL Certificates**: Setup managed certificates
- **Monitoring**: Enable Cloud Monitoring and logging
- **Backups**: Setup automated PostgreSQL backups
- **Resource Limits**: Adjust pod resources based on usage

---

## Quick Command Reference

| Task | Command |
|------|---------|
| Pull latest changes | `git pull origin claude/dev-011CUMiHag3oEPq5d1uXfCPN` |
| Apply Medplum fix | `./scripts/fix-medplum-crashloop.sh` |
| Initialize database | `./scripts/init-medplum.sh` |
| Check status | `./scripts/check-status.sh` |
| View all pods | `kubectl get pods -n provider-registry` |
| View all services | `kubectl get services -n provider-registry` |
| Port forward frontend | `kubectl port-forward -n provider-registry service/frontend-service 3001:80` |
| Port forward API | `kubectl port-forward -n provider-registry service/medplum-service 8103:8103` |
| View Medplum logs | `kubectl logs -n provider-registry -l app=medplum-server -f` |
| Restart Medplum | `kubectl rollout restart deployment/medplum-server -n provider-registry` |
| Troubleshoot | `./scripts/troubleshoot-medplum.sh` |

---

## Need Help?

If you encounter any issues:

1. **Check the documentation**:
   - `MEDPLUM_CRASHLOOP_FIX.md` - Specific to config file issue
   - `DEPLOYMENT_TIMEOUT_RECOVERY.md` - General deployment issues
   - `README.md` - Application overview

2. **Run diagnostic scripts**:
   - `./scripts/check-status.sh` - Overall status
   - `./scripts/troubleshoot-medplum.sh` - Medplum-specific issues

3. **Check pod logs** for specific error messages

4. **Describe the failing resource**:
   ```bash
   kubectl describe pod <pod-name> -n provider-registry
   ```

---

## Summary Timeline

1. ✅ **Analyzed** - Identified root cause: missing config file
2. ✅ **Fixed** - Created config file and proper volume mount
3. ✅ **Documented** - Comprehensive guides and scripts
4. ✅ **Committed** - All changes pushed to branch
5. 🔄 **Your turn** - Apply the fix using steps above
6. ⏭️ **Next** - Initialize database and access application

---

**You're almost there!** Just run the three commands:

```bash
git pull origin claude/dev-011CUMiHag3oEPq5d1uXfCPN
./scripts/fix-medplum-crashloop.sh
./scripts/init-medplum.sh
```

Then access http://localhost:3001 after port forwarding! 🚀
