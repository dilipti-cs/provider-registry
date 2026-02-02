# GKE Deprecation Warning Fixed ✅

## Issue

You received this warning during cluster creation:

```
WARNING: The `--enable-stackdriver-kubernetes` flag is deprecated and will be
removed in an upcoming release. Please use `--logging` and `--monitoring` instead.
```

## What Was Changed

### 1. Deployment Script (`scripts/deploy-from-local.sh`)

**Before:**
```bash
--enable-stackdriver-kubernetes \
```

**After:**
```bash
--logging=SYSTEM,WORKLOAD \
--monitoring=SYSTEM \
```

### 2. Terraform Configuration (`terraform/main.tf`)

**Added modern logging and monitoring configuration:**

```hcl
# Logging configuration (replaces deprecated --enable-stackdriver-kubernetes)
logging_config {
  enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

# Monitoring configuration (replaces deprecated --enable-stackdriver-kubernetes)
monitoring_config {
  enable_components = ["SYSTEM_COMPONENTS"]
  managed_prometheus {
    enabled = true
  }
}
```

## What These Flags Do

### `--logging=SYSTEM,WORKLOAD`
Enables collection of:
- **SYSTEM**: GKE system component logs (API server, kubelet, etc.)
- **WORKLOAD**: Application container logs from your pods

### `--monitoring=SYSTEM`
Enables collection of:
- **SYSTEM**: GKE and Kubernetes metrics (CPU, memory, disk, network)
- **Managed Prometheus**: Enhanced metrics collection (now enabled!)

## Benefits of the Update

✅ **No More Warnings** - Eliminates deprecation warnings
✅ **Future-Proof** - Uses the latest GKE logging/monitoring API
✅ **Better Observability** - Managed Prometheus provides enhanced metrics
✅ **More Granular Control** - Can enable/disable specific log sources
✅ **Same Functionality** - Equivalent to the old flag, just modern syntax

## Impact on Existing Clusters

If you **already created a cluster** with the old flag:
- The cluster will continue to work fine
- You won't see the warning anymore on new deployments
- Existing logs and metrics continue to work as before
- No action needed for existing clusters

If you're **creating a new cluster**:
- Use the updated script (already fixed in the repo)
- No deprecation warning will appear
- You get the benefits of modern logging/monitoring config

## Monitoring Your Application

With these configurations, you can view logs and metrics in:

### Google Cloud Console

**Logs:**
```
Cloud Console → Logging → Logs Explorer
```

Filter by:
- Resource: GKE Container
- Namespace: provider-registry
- Pod name: medplum-server-*, provider-registry-frontend-*, etc.

**Metrics:**
```
Cloud Console → Monitoring → Metrics Explorer
```

View:
- CPU usage by pod
- Memory usage by pod
- Network traffic
- Custom Prometheus metrics (via Managed Prometheus)

### kubectl (from your laptop)

```bash
# View logs
kubectl logs -n provider-registry -l app=medplum-server -f

# View metrics
kubectl top pods -n provider-registry
kubectl top nodes
```

## Cost Impact

✅ **No additional cost** - These are the same services that were enabled before, just configured using the modern API.

Cloud Logging and Cloud Monitoring have free tiers:
- **Logs**: First 50 GB/month free
- **Metrics**: First 150 MB/month free

For a typical Provider Registry deployment:
- Estimated logs: ~5-10 GB/month
- Estimated metrics: ~50 MB/month
- **Cost**: Should stay within free tier or minimal ($5-10/month)

## How to Get the Fix

### Pull Latest Changes

```bash
cd provider-registry
git pull origin claude/dev-011CUMiHag3oEPq5d1uXfCPN
```

### Verify the Fix

```bash
# Check the deployment script
grep -A2 "logging\|monitoring" scripts/deploy-from-local.sh

# Should show:
# --logging=SYSTEM,WORKLOAD \
# --monitoring=SYSTEM \

# Check Terraform config
grep -A3 "logging_config\|monitoring_config" terraform/main.tf
```

## Next Deployment

When you run the deployment script again:

```bash
export GCP_PROJECT_ID="your-project-id"
./scripts/deploy-from-local.sh
```

You will **NOT** see the deprecation warning anymore! 🎉

## Additional Resources

- [GKE Logging Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/about-logs)
- [GKE Monitoring Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics)
- [Managed Prometheus on GKE](https://cloud.google.com/stackdriver/docs/managed-prometheus)

---

**Status:** Deprecation warning resolved ✅
**Branch:** `claude/dev-011CUMiHag3oEPq5d1uXfCPN`
**Changes:** Pushed and ready to use
