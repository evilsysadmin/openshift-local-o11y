# Architecture Overview

Detailed technical architecture of the OpenShift Local O11y stack.

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        OpenShift Local (CRC)                   │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │   Application       │    │       Monitoring                │ │
│  │   Namespace         │    │       Namespace                 │ │
│  │  my-app-project     │    │      monitoring                 │ │
│  │                     │    │                                 │ │
│  │  ┌───────────────┐  │    │  ┌─────────────────────────────┐ │ │
│  │  │ Apache HTTPd  │  │    │  │       Grafana               │ │ │
│  │  │   + Exporter  │◄─┼────┼──┤    (Dashboards)            │ │ │
│  │  │               │  │    │  └─────────────────────────────┘ │ │
│  │  └───────────────┘  │    │  ┌─────────────────────────────┐ │ │
│  │         │           │    │  │      Prometheus             │ │ │
│  │         ▼           │    │  │     (Metrics)               │ │ │
│  │  ┌───────────────┐  │    │  └─────────────────────────────┘ │ │
│  │  │      HPA      │  │    │  ┌─────────────────────────────┐ │ │
│  │  │  (1-20 pods)  │  │    │  │        Loki                 │ │ │
│  │  └───────────────┘  │    │  │      (Logs)                 │ │ │
│  └─────────────────────┘    │  └─────────────────────────────┘ │ │
│                             │  ┌─────────────────────────────┐ │ │
│  ┌─────────────────────┐    │  │      Promtail               │ │ │
│  │    System           │    │  │   (Log Collector)           │ │ │
│  │   kube-system       │    │  └─────────────────────────────┘ │ │
│  │                     │    └─────────────────────────────────┘ │
│  │ ┌─────────────────┐ │                                        │
│  │ │ Metrics Server  │ │    ┌─────────────────────────────────┐ │
│  │ │ Kube-State-Mets │ │    │       External Load             │ │
│  │ │ Time Sync Job   │ │    │                                 │ │
│  │ └─────────────────┘ │    │  ┌─────────────────────────────┐ │ │
│  └─────────────────────┘    │  │         K6                  │ │ │
└─────────────────────────────┼──┤    (Load Testing)           │ │
                              │  └─────────────────────────────┘ │
                              └─────────────────────────────────┘
```

## 📊 Data Flow Architecture

### Metrics Flow
```
Apache HTTPd ──► Apache Exporter ──► Prometheus ──► Grafana
     │               (9117/metrics)       │
     └── Resource ──► Metrics Server ──── │
         Usage         (API)             │
                                         │
Kubernetes ────► Kube-State-Metrics ────┘
Objects          (8080/metrics)
```

### Logs Flow
```
Apache HTTPd ──► Container Logs ──► Promtail ──► Loki ──► Grafana
                 (/var/log/pods)    (Filter)  (Store) (Query)
```

### Scaling Flow
```
K6 Load ──► Apache HTTPd ──► Metrics Server ──► HPA ──► Pod Scaling
               (CPU/Memory)     (Aggregation)   (Decision) (1-20 pods)
```

## 🔧 Component Details

### Application Layer

#### Apache HTTPd
- **Image:** `httpd:2.4`
- **Purpose:** Sample web application for monitoring
- **Resources:** 100m CPU, 128Mi Memory (requests)
- **Scaling:** Managed by HPA (1-20 replicas)
- **Endpoints:**
  - `:80` - Web server
  - `:80/server-status?auto` - Metrics endpoint

#### Apache Exporter
- **Image:** `lusotycoon/apache-exporter`
- **Purpose:** Convert Apache metrics to Prometheus format
- **Port:** `9117/metrics`
- **Metrics:** Request rates, response times, worker status

#### Horizontal Pod Autoscaler (HPA)
- **Targets:** CPU 50%, Memory 70%
- **Range:** 1-20 replicas
- **Metrics Source:** metrics-server
- **Stabilization:** 30s scale-down window

### Monitoring Layer

#### Prometheus
- **Image:** `prom/prometheus:latest`
- **Purpose:** Metrics collection and storage
- **Storage:** EmptyDir (ephemeral)
- **Scrape Interval:** 15s
- **Retention:** 15 days
- **Resources:** 1 CPU, 1Gi Memory (requests)
- **Targets:**
  - Apache Exporter (9117)
  - Kube-state-metrics (8080)
  - Self-monitoring (9090)

#### Grafana
- **Image:** `grafana/grafana:latest`
- **Purpose:** Visualization and dashboards
- **Authentication:** admin/admin
- **Timezone:** Browser timezone (configurable)
- **Resources:** 1 CPU, 1Gi Memory (requests)
- **Datasources:**
  - Prometheus (metrics)
  - Loki (logs)

#### Loki
- **Image:** `grafana/loki:2.9.0`
- **Purpose:** Log aggregation and storage
- **Storage:** Filesystem (EmptyDir)
- **Retention:** Configurable via limits_config
- **Schema:** v11 with boltdb-shipper
- **Limits:**
  - Ingestion: 128MB/s
  - Burst: 256MB

#### Promtail
- **Image:** `grafana/promtail:2.6.1`
- **Purpose:** Log collection from Kubernetes pods
- **Security:** Privileged (for log file access)
- **Log Path:** `/var/log/pods/my-app-project_httpd-simple-metrics*`
- **Pipeline:** Drop server-status logs
- **Resources:** 500m CPU, 512Mi Memory (requests)

### System Layer

#### Metrics Server
- **Image:** `registry.k8s.io/metrics-server/metrics-server:v0.6.4`
- **Purpose:** Resource metrics for HPA
- **API:** `/apis/metrics.k8s.io/v1beta1/`
- **Security:** TLS verification disabled for CRC
- **RBAC:** Custom permissions for cluster metrics

#### Kube-State-Metrics
- **Purpose:** Kubernetes object metrics
- **Metrics:** Pod status, deployments, HPA status
- **Port:** `8080/metrics`
- **RBAC:** Read access to cluster objects

#### Time Sync CronJob
- **Image:** `registry.redhat.io/ubi8/ubi:latest`
- **Schedule:** Every 15 minutes (`*/15 * * * *`)
- **Purpose:** Fix CRC clock drift
- **Security:** Privileged with host access
- **Action:** Restart chronyd service

## 🌐 Network Architecture

### Service Discovery
```
prometheus.monitoring.svc.cluster.local:9090
grafana.monitoring.svc.cluster.local:3000
loki.monitoring.svc.cluster.local:3100
httpd-simple-service.my-app-project.svc.cluster.local:80
```

### External Access (Routes)
```
grafana-monitoring.apps-crc.testing
prometheus-monitoring.apps-crc.testing
loki-monitoring.apps-crc.testing
```

### Port Mapping
| Component | Internal Port | Service Port | External Access |
|-----------|---------------|--------------|-----------------|
| Grafana | 3000 | 3000 | Route |
| Prometheus | 9090 | 9090 | Route |
| Loki | 3100 | 3100 | Route |
| Apache | 80 | 80 | LoadBalancer |
| Apache Exporter | 9117 | 9117 | ClusterIP |
| Promtail | 9080 | 9080 | ClusterIP |

## 🔒 Security Architecture

### RBAC Configuration

#### Service Accounts
- `prometheus` - Metrics collection
- `grafana` - Dashboard access
- `loki` - Log storage
- `promtail` - Log collection
- `metrics-server` - System metrics
- `time-sync` - System time operations

#### Cluster Roles
- `prometheus` - Read metrics from all namespaces
- `promtail` - Read pods and logs
- `metrics-server` - Node and pod metrics access
- `time-sync` - Node system operations

#### Security Context Constraints (SCC)
- `privileged` - Promtail (log file access)
- `privileged` - Time sync (system operations)
- `restricted` - All other components

### Pod Security
- **Non-root containers** where possible
- **ReadOnlyRootFilesystem** for secure components
- **Resource limits** to prevent resource exhaustion
- **SecurityContext** with minimal privileges

## 📈 Performance Characteristics

### Resource Requirements
| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Prometheus | 1024m | 1Gi | 2048m | 2Gi |
| Grafana | 1024m | 1Gi | 2048m | 2Gi |
| Loki | - | - | - | - |
| Promtail | 500m | 512Mi | 1000m | 1Gi |
| Apache | 100m | 128Mi | 500m | 256Mi |
| Metrics Server | 100m | 200Mi | - | - |

### Scaling Characteristics
- **Apache HPA:** 1-20 pods based on CPU/Memory
- **Load Testing:** Sustained 11K+ req/s
- **Log Processing:** 9M+ logs battle-tested
- **Memory Usage:** ~6Gi total stack footprint

### Storage Architecture
- **Prometheus:** EmptyDir (ephemeral)
- **Loki:** EmptyDir with filesystem backend
- **Grafana:** EmptyDir for dashboards and config

## 🔄 Deployment Architecture

### Namespace Strategy
```
monitoring/          # Core observability components
my-app-project/      # Sample application
kube-system/         # System-level components
```

### Configuration Management
- **ConfigMaps:** Component configurations
- **Secrets:** Authentication credentials / Not used yet
- **Environment Variables:** Runtime configuration

### Update Strategy
- **Rolling Updates:** Zero-downtime deployments
- **Readiness Probes:** Health checking
- **Resource Quotas:** Namespace isolation

## 🎯 Design Principles

### Observability Stack
1. **Three Pillars:** Metrics (Prometheus), Logs (Loki), Traces (planned)
2. **Golden Signals:** Traffic, Latency, Errors, Saturation
3. **Real-time Processing:** Near real-time log ingestion
4. **Timezone Handling:** UTC storage, local display

### Cloud-Native Patterns
1. **Microservices:** Loosely coupled components
2. **Service Discovery:** Kubernetes DNS
3. **Configuration as Code:** GitOps-ready with ArgoCD
4. **Horizontal Scaling:** HPA for demand scaling

### Operational Excellence
1. **Health Checks:** Comprehensive readiness/liveness probes
2. **Resource Management:** Requests and limits
3. **Security:** RBAC and least privilege
4. **Automation:** Infrastructure as Code

## 🚀 Future Architecture Considerations

### Planned Enhancements
- **Helm Charts:** Package management
- **ArgoCD:** GitOps deployment
- **Jaeger:** Distributed tracing
- **AlertManager:** Alert routing
- **Persistent Storage:** Data retention
- **Multi-environment:** Dev/staging/prod

### Scalability Improvements
- **Distributed Loki:** Multiple instances
- **Prometheus Federation:** Multi-cluster
- **External Storage:** S3/GCS backends
- **Resource Optimization:** Vertical pod autoscaling
