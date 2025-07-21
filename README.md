# OpenShift Local O11y 🚀

Complete observability stack for OpenShift Local with one-command deployment. 

[![OpenShift](https://img.shields.io/badge/OpenShift-Local-red?style=flat-square&logo=redhat)](https://developers.redhat.com/products/codeready-containers)
[![Prometheus](https://img.shields.io/badge/Prometheus-Metrics-orange?style=flat-square&logo=prometheus)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Dashboards-blue?style=flat-square&logo=grafana)](https://grafana.com/)
[![Loki](https://img.shields.io/badge/Loki-Logs-yellow?style=flat-square)](https://grafana.com/oss/loki/)
[![K6](https://img.shields.io/badge/K6-Load%20Testing-purple?style=flat-square&logo=k6)](https://k6.io/)

## 🎯 What is this repo?

This repo contains a complete observability stack (Logs and metrics, traces not yet) that runs on OpenShift Local (CRC), providing enterprise-grade monitoring, logging, and metrics in a single laptop deployment. Perfect for development, testing, and learning observability best practices.

### ✨ Features

- **🚀 One-command deployment** - `make setup` and you're ready
- **📊 Real-time metrics** - Prometheus + custom Apache dashboard
- **📝 Centralized logging** - Loki with intelligent log filtering
- **📈 Beautiful dashboards** - Pre-configured Grafana with golden metrics
- **⚡ Auto-scaling** - HPA with CPU/memory based scaling (1-20 pods)
- **🔥 Load testing** - Integrated K6 scenarios for validation
- **🔧 Full automation** - Makefile with 20+ commands

### 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   K6 Load Test  │───▶│  Apache + HPA   │───▶│  Log & Metrics  │
│   (11K req/s)   │    │  (1-20 pods)    │    │   Generation    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                 │
                                 ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Grafana      │◀───│   Prometheus    │◀───│ Apache Exporter │
│  (Dashboards)   │    │   (Metrics)     │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       
         │              ┌─────────────────┐    ┌─────────────────┐
         └──────────────│      Loki       │◀───│    Promtail     │
                        │    (Logs)       │    │ (Log Collector) │
                        └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- [OpenShift Local (CRC)](https://developers.redhat.com/products/codeready-containers) installed
- [K6](https://k6.io/docs/getting-started/installation/) for load testing
- 18GB+ RAM available for CRC
- `make` and `curl` installed

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/openshift-local-o11y
cd openshift-local-o11y

# Deploy everything with one command
make setup

# Open Grafana dashboard
make grafana/open
# Login: admin/admin
```

That's it! 🎉 Your observability stack is ready.

### 🔥 Load Testing

```bash
# Light load test (50 VUs, 2 minutes)
make load-test/light

# Full torture test (200 VUs, 6.5 minutes) 
make load-test

# Watch HPA scaling in action
make hpa/watch
```

## 📊 What You Get

### Dashboards
- **Apache Metrics Dashboard** - Request rates, worker status, CPU load
- **Golden Metrics Dashboard** - SRE golden signals WIP
- **HPA Status** - Real-time scaling metrics
- **Log Volume** - Visual log ingestion rates

### Metrics Collected
- HTTP request rates and response times
- Apache worker states (busy/idle)
- CPU and memory utilization
- Network I/O and data transfer
- HPA scaling events
- Pod resource consumption

### Log Processing
- Real-time Apache access logs
- K6 load test requests
- Health check filtering (server-status excluded)


## 🛠️ Makefile Commands

### Setup & Management
```bash
make setup          # Complete setup from scratch
make deploy         # Deploy stack only
make clean          # Remove all resources
make redeploy       # Clean + deploy + health check
```

### Authentication
```bash
make login/admin    # Login as cluster admin
make login/dev      # Login as developer
```

### Monitoring
```bash
make health         # Health check all pods
make status         # Show pod status
make urls           # Display all service URLs
```

### Testing
```bash
make load-test      # Run K6 torture test
make verify         # Verify log ingestion
make smoke-test     # Basic connectivity test
```

### Troubleshooting
```bash
make rollout/all    # Restart all monitoring pods
make rollout/loki   # Restart Loki
make rollout/grafana # Restart Grafana
make rollout/promtail # Restart Promtail
make rollout/prometheus # Restart Prometheus
```

## 📁 Project Structure

```
openshift-local-o11y/
├── Makefile                 # Automation commands
├── README.md               # This file
├── yaml/                   # Kubernetes manifests
│   ├── namespaces.yaml     # Namespace definitions
│   ├── prometheus.yaml     # Prometheus setup
│   ├── grafana.yaml        # Grafana with dashboards
│   ├── loki-stack.yaml     # Loki + Promtail
│   ├── httpd-app.yaml      # Sample app + HPA
│   └── metrics-server.yaml # HPA metrics provider
├── k6/                     # Load testing scenarios
│   ├── load-test.js        # Standard load test
│   └── torture-test.js     # High-intensity test
└── docs/                   # Additional documentation
    ├── TROUBLESHOOTING.md  # Common issues & solutions
    ├── ARCHITECTURE.md     # Detailed architecture
    └── PERFORMANCE.md      # Performance tuning guide
```

## 🔧 Configuration

### Resource Requirements

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Prometheus | 1024m | 1Gi | 2048m | 2Gi |
| Grafana | 1024m | 1Gi | 2048m | 2Gi |
| Loki | No limit | No limit | No limit | No limit |
| Apache | 100m | 128Mi | 500m | 256Mi |

### HPA Configuration
- **Target CPU:** 50%
- **Target Memory:** 70% 
- **Min Replicas:** 1
- **Max Replicas:** 20
- **Scale Down:** 30s stabilization

## 📈 Performance Benchmarks

### Load Test Results
```
🚀 Sustained Performance:
├── Request Rate: 11,111+ req/s
├── Concurrent Users: 200 VUs
├── Test Duration: 6m30s
├── Total Requests: 4.33M+
├── Success Rate: 100%
├── Avg Response Time: 10.92ms
└── Data Transferred: 4.4GB

📊 Log Processing:
├── Total Logs Processed: 9.23M+
├── Peak Log Rate: 800K logs/interval
├── Processing Latency: Near real-time
├── Storage Backend: UTC (Loki)
└── Display Timezone: CEST (Grafana)
```

### Resource Utilization During Peak Load
- **Grafana:** 309% CPU, 132MB Memory
- **Loki:** 227% CPU, 533MB Memory  
- **Prometheus:** 3% CPU, 108MB Memory
- **Apache Pods:** Auto-scaled 1→20 replicas

## 🛡️ Security

### OpenShift Security Context Constraints
- Promtail runs with `privileged` SCC for log access
- All other components use `restricted` SCC
- Non-root containers where possible
- ReadOnlyRootFilesystem for secure containers

### Network Policies
- Default deny-all traffic
- Explicit allow rules for component communication
- External access only through OpenShift Routes

## 🔍 Troubleshooting

### Common Issues

**HPA shows `<unknown>` metrics:**
```bash
# Check metrics-server status
kubectl top nodes
make rollout/metrics-server
```

**Logs not appearing in Grafana:**
```bash
# Verify Promtail is reading logs
make logs/promtail
# Check Loki ingestion
curl "http://loki-monitoring.apps-crc.testing/loki/api/v1/labels"
```

**Timezone issues:**
```bash
# Fix CRC node timezone
make bootstrap  # Includes timezone fix
```

**Performance issues:**
```bash
# Check resource usage
make status
kubectl top pods --all-namespaces
```

### Debug Commands
```bash
# Component logs
oc logs -f deployment/loki -n monitoring
oc logs -f deployment/promtail -n monitoring
oc logs -f deployment/grafana -n monitoring

# Pod shell access
oc exec -it deployment/loki -n monitoring -- sh
oc exec -it deployment/grafana -n monitoring -- bash
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes with `make setup && make smoke-test`
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Development Workflow
```bash
# Make changes to manifests
# Test deployment
make deploy

# Run full test suite
make health && make smoke-test && make load-test/light

# Verify logs and metrics
make verify
```

## 📚 Learning Resources

### Observability Concepts
- [The Three Pillars of Observability](https://peter.bourgon.org/blog/2017/02/21/metrics-tracing-and-logging.html)
- [SRE Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)

### OpenShift Documentation
- [OpenShift Local Setup](https://developers.redhat.com/products/codeready-containers)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏆 Acknowledgments

- **Grafana Labs** for Grafana, Loki, and Promtail
- **Prometheus Community** for monitoring excellence  
- **Red Hat** for OpenShift Local
- **K6 Team** for load testing tools
- **Apache Foundation** for the web server

---

**⭐ Star this repo if it helped you build better observability!**
│