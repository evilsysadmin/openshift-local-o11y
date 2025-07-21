# Troubleshooting Guide

Common issues and solutions for OpenShift Local O11y stack.

## 📊 Monitoring Issues

### HPA Shows `<unknown>` Metrics

**Symptoms:**
```
NAME        REFERENCE                         TARGETS                     
httpd-hpa   Deployment/httpd-simple-metrics   cpu: <unknown>/50%, memory: <unknown>/70%
```

**Causes:**
- Metrics-server not running or not ready
- Resource requests not configured in deployment
- RBAC permissions issues

**Solutions:**

1. **Check metrics-server status:**
```bash
kubectl top nodes
kubectl top pods -n my-app-project
```

2. **Restart metrics-server:**
```bash
make rollout/metrics-server
```

3. **Verify resource requests in deployment:**
```bash
oc describe deployment httpd-simple-metrics -n my-app-project | grep -A5 -B5 requests
```

4. **Check HPA events:**
```bash
oc describe hpa httpd-hpa -n my-app-project
oc get events -n my-app-project | grep hpa
```

### Grafana Shows "No Data" in Dashboards

**Symptoms:**
- Empty panels in Grafana dashboards
- "No data" messages
- Query errors in Grafana

**Causes:**
- Prometheus not scraping metrics
- Wrong service discovery configuration
- Network connectivity issues

**Solutions:**

1. **Check Prometheus targets:**
```bash
# Access Prometheus UI
open http://$(oc get route prometheus -n monitoring -o jsonpath='{.spec.host}')
# Go to Status > Targets
```

2. **Verify service endpoints:**
```bash
oc get endpoints -n my-app-project
oc get endpoints -n monitoring
```

3. **Test metric endpoint directly:**
```bash
oc port-forward -n my-app-project svc/httpd-simple-service 9117:9117 &
curl http://localhost:9117/metrics
```

4. **Check Prometheus configuration:**
```bash
oc get configmap prometheus-config -n monitoring -o yaml
```

### Logs Not Appearing in Grafana

**Symptoms:**
- Empty log panels in Grafana
- Loki shows no data
- Promtail not collecting logs

**Causes:**
- Promtail not reading log files
- Incorrect log path configuration
- Loki ingestion issues
- Drop stages filtering all logs

**Solutions:**

1. **Check Promtail status:**
```bash
make logs/promtail
oc get pods -n monitoring -l app=promtail
```

2. **Verify log path exists:**
```bash
oc exec -it deployment/promtail -n monitoring -- ls /var/log/pods/my-app-project_httpd-simple-metrics*/
```

3. **Test Loki API:**
```bash
curl "http://loki-monitoring.apps-crc.testing/loki/api/v1/labels"
curl "http://loki-monitoring.apps-crc.testing/ready"
```

4. **Check Promtail configuration:**
```bash
oc get configmap promtail-k8s-config -n monitoring -o yaml
```

## 🕐 Time Synchronization Issues

### Logs Timestamps Incorrect

**Symptoms:**
- Logs appearing hours in the past/future
- Grafana timeline jumps
- Inconsistent timestamps

**Causes:**
- CRC clock drift
- Timezone configuration issues
- NTP synchronization failures

**Solutions:**

1. **Manual time fix:**
```bash
make fix-time
```

2. **Check time difference:**
```bash
make check-time
```

3. **Setup automatic sync:**
```bash
make setup-time-sync
make check-time-sync
```

4. **Debug chronyd:**
```bash
oc debug node/crc
chroot /host
chronyc sources -v
chronyc tracking
journalctl -u chronyd --since "10 minutes ago"
```

### CronJob Time Sync Failing

**Symptoms:**
- `kubectl get jobs` shows failed jobs
- Time continues to drift

**Causes:**
- Image pull failures
- Security context issues
- Missing nsenter command

**Solutions:**

1. **Check CronJob status:**
```bash
make check-time-sync
kubectl describe cronjob time-sync -n kube-system
```

2. **View failed job logs:**
```bash
kubectl logs -l cronjob=time-sync -n kube-system --previous
```

3. **Manually test time sync:**
```bash
kubectl create job test-time-sync --from=cronjob/time-sync -n kube-system
kubectl logs job/test-time-sync -n kube-system
```

## 🚀 Performance Issues

### High Memory Usage

**Symptoms:**
- OOM kills in pods
- CRC running out of memory
- Slow response times

**Solutions:**

1. **Check resource usage:**
```bash
make metrics
kubectl top pods --all-namespaces --sort-by=memory
```

2. **Increase CRC memory:**
```bash
crc stop
crc config set memory 20480  # 20GB
crc start
```

3. **Tune component resources:**
- Reduce Grafana memory limits
- Adjust Loki retention policies
- Optimize Prometheus scrape intervals

### Load Testing Failures

**Symptoms:**
- K6 tests failing
- High error rates
- Timeout errors

**Solutions:**

1. **Start with light load:**
```bash
make load-test/light
```

2. **Check application logs:**
```bash
make logs/apache
oc logs -f deployment/httpd-simple-metrics -n my-app-project
```

3. **Monitor resource scaling:**
```bash
make hpa/watch
```

4. **Verify network connectivity:**
```bash
oc port-forward -n my-app-project svc/httpd-simple-service 8080:80 &
curl http://localhost:8080
```

## 🔒 Authentication Issues

### Login Failures

**Symptoms:**
- Cannot login to cluster
- Authentication errors

**Solutions:**

1. **Use Makefile login:**
```bash
make login/admin
make login/dev
```

2. **Manual login with extracted password:**
```bash
crc console --credentials
# Copy the oc login command
```

3. **Reset CRC if needed:**
```bash
make nuke
make setup
```

## 🌐 Network Connectivity Issues

### Routes Not Accessible

**Symptoms:**
- Cannot access Grafana/Prometheus URLs
- Connection refused errors

**Solutions:**

1. **Check route status:**
```bash
oc get routes -n monitoring
make urls
```

2. **Verify service endpoints:**
```bash
oc get endpoints -n monitoring
```

3. **Test internal connectivity:**
```bash
oc port-forward -n monitoring svc/grafana 3000:3000 &
open http://localhost:3000
```

### DNS Resolution Issues

**Symptoms:**
- Service names not resolving
- Intermittent connectivity

**Solutions:**

1. **Check CoreDNS:**
```bash
oc get pods -n openshift-dns
oc logs -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default
```

2. **Test DNS resolution:**
```bash
oc run test-dns --image=busybox --rm -it -- nslookup grafana.monitoring.svc.cluster.local
```

## 🔧 Component-Specific Issues

### Prometheus Issues

**Common problems:**
- Targets down
- Storage issues
- Query timeouts

**Debug commands:**
```bash
oc logs -f deployment/prometheus -n monitoring
oc exec -it deployment/prometheus -n monitoring -- promtool query instant 'up'
```

### Grafana Issues

**Common problems:**
- Dashboard not loading
- Datasource errors
- Plugin issues

**Debug commands:**
```bash
make logs/grafana
oc exec -it deployment/grafana -n monitoring -- grafana-cli admin reset-admin-password admin
```

### Loki Issues

**Common problems:**
- Ingestion failures
- Query errors
- Storage limits

**Debug commands:**
```bash
make logs/loki
curl "http://loki-monitoring.apps-crc.testing/metrics"
```

## 📋 Quick Diagnostic Checklist

Run these commands for a quick health check:

```bash
# Overall status
make status
make health

# Component connectivity
make smoke-test
make verify

# Resource usage
make metrics
kubectl top pods --all-namespaces

# Recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
```

## 🆘 Getting Help

1. **Check logs:** Use `make logs/<component>` commands
2. **Run diagnostics:** Use `make health` and `make smoke-test`
3. **Check events:** Look for Kubernetes events with errors
4. **Resource usage:** Monitor with `make metrics`
5. **Nuclear option:** `make nuke && make setup` for complete reset

## 📚 Additional Resources

- [Prometheus Troubleshooting](https://prometheus.io/docs/prometheus/latest/troubleshooting/)
- [Grafana Troubleshooting](https://grafana.com/docs/grafana/latest/troubleshooting/)
- [Loki Troubleshooting](https://grafana.com/docs/loki/latest/troubleshooting/)
- [OpenShift Local Documentation](https://developers.redhat.com/products/codeready-containers)