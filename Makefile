# OpenShift Local O11y - Complete Automation Makefile
# One-command observability stack deployment

# Configuration
CRC_USER_ADMIN = kubeadmin
CRC_USER_DEV = developer
CRC_PASS_DEV = developer
CRC_API = https://api.crc.testing:6443

# Auto-extract admin password from CRC
define get_admin_pass
$(shell crc console --credentials | grep "oc login -u kubeadmin" | sed -n 's/.*-p \([^ ]*\).*/\1/p')
endef

# Auto-extract service URLs
define grafana_url
$(shell oc get route grafana -n monitoring -o jsonpath='{.spec.host}' 2>/dev/null)
endef

define prometheus_url
$(shell oc get route prometheus -n monitoring -o jsonpath='{.spec.host}' 2>/dev/null)
endef

define loki_url
$(shell oc get route loki -n monitoring -o jsonpath='{.spec.host}' 2>/dev/null)
endef

.PHONY: help setup bootstrap deploy clean health status urls
.PHONY: login/admin login/dev logout
.PHONY: load-test load-test/light load-test/torture verify smoke-test
.PHONY: rollout/all rollout/loki rollout/grafana rollout/prometheus rollout/promtail rollout/metrics-server
.PHONY: logs/loki logs/promtail logs/grafana logs/apache
.PHONY: hpa/watch hpa/status grafana/open nuke demo backup redeploy

# Default target
help:
	@echo "🚀 OpenShift Local O11y - Observability Stack"
	@echo ""
	@echo "📋 Setup Commands:"
	@echo "  setup          Complete setup from scratch (bootstrap + deploy + test)"
	@echo "  demo           Full demo deployment with smoke test"
	@echo "  bootstrap      Initialize CRC environment only"
	@echo "  deploy         Deploy observability stack"
	@echo "  redeploy       Clean + deploy + health check"
	@echo ""
	@echo "🔐 Authentication:"
	@echo "  login/admin    Login as cluster admin"
	@echo "  login/dev      Login as developer"
	@echo "  logout         Logout from cluster"
	@echo ""
	@echo "📊 Monitoring & Testing:"
	@echo "  health         Health check all components"
	@echo "  status         Show pod status across namespaces"
	@echo "  smoke-test     Basic connectivity test"
	@echo "  load-test      Run K6 torture test (200 VUs, 6m30s)"
	@echo "  load-test/light Light load test (50 VUs, 2m)"
	@echo "  verify         Verify log ingestion"
	@echo ""
	@echo "🌐 URLs & Access:"
	@echo "  urls           Display all service URLs"
	@echo "  grafana/open   Open Grafana in browser"
	@echo ""
	@echo "🔧 Management:"
	@echo "  rollout/all    Restart all monitoring components"
	@echo "  hpa/watch      Watch HPA scaling in real-time"
	@echo "  clean          Remove stack (keep CRC running)"
	@echo "  nuke           💣 Destroy CRC completely"
	@echo "  backup         Backup current configurations"
	@echo ""
	@echo "📝 Logs:"
	@echo "  logs/loki      Follow Loki logs"
	@echo "  logs/grafana   Follow Grafana logs"
	@echo "  logs/promtail  Follow Promtail logs"
	@echo "  logs/apache    Follow Apache application logs"

# Complete setup from scratch
setup: bootstrap deploy health smoke-test 
	@echo "🎉 Setup complete!"
	@echo "🌐 Grafana: http://$(call grafana_url) (admin/admin)"
	@echo "📊 Run load test: make load-test"

# Demo mode - full deployment with validation
demo: setup urls
	@echo "🎬 DEMO READY!"
	@echo "🚀 Stack deployed and tested"
	@echo "🌐 Access URLs above ⬆️"
	@echo "🔥 Ready for load testing: make load-test"

# Bootstrap CRC environment
bootstrap:
	@echo "🚀 Bootstrapping CRC environment..."
	crc config set enable-cluster-monitoring false
	crc config set memory 18900
	crc start
	@eval $$(crc oc-env)
	@echo "✅ CRC bootstrap complete"
	@echo "🔐 Login with: make login/admin or make login/dev"

# Deploy observability stack
deploy:
	@echo "🚀 Deploying observability stack..."
	oc apply -f yaml/namespaces.yaml
	oc apply -f yaml/.
	@echo "✅ Stack deployed"

# Clean deployment (keep CRC running)
clean:
	@echo "🧹 Cleaning up stack..."
	-oc delete -f yaml/. --ignore-not-found=true
	-oc delete -f yaml/namespaces.yaml --ignore-not-found=true
	@echo "✅ Cleanup complete"

# Quick redeploy
redeploy: clean deploy health
	@echo "🔄 Redeployment complete"

# Health check with detailed output
health:
	@echo "🏥 Health Check:"
	@echo "📊 Waiting for pods to be ready..."
	@oc wait --for=condition=ready pod -l app=loki -n monitoring --timeout=60s && echo "✅ Loki ready" || echo "❌ Loki not ready"
	@oc wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=60s && echo "✅ Grafana ready" || echo "❌ Grafana not ready"
	@oc wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=60s && echo "✅ Prometheus ready" || echo "❌ Prometheus not ready"
	@oc wait --for=condition=ready pod -l app=httpd-simple -n my-app-project --timeout=60s && echo "✅ Apache ready" || echo "❌ Apache not ready"
	@echo "🎯 Health check complete"

# Comprehensive status check
status:
	@echo "📊 Stack Status:"
	@echo ""
	@echo "🔍 Monitoring Namespace:"
	@oc get pods -n monitoring
	@echo ""
	@echo "🔍 Application Namespace:"
	@oc get pods -n my-app-project
	@echo ""
	@echo "📈 HPA Status:"
	@oc get hpa -n my-app-project
	@echo ""
	@echo "🌐 Routes:"
	@oc get routes -n monitoring

# Authentication commands
login/admin:
	@echo "🔐 Logging in as admin..."
	@oc login -u $(CRC_USER_ADMIN) -p $(call get_admin_pass) $(CRC_API)
	@echo "✅ Logged in as admin"

login/dev:
	@echo "🔐 Logging in as developer..."
	@oc login -u $(CRC_USER_DEV) -p $(CRC_PASS_DEV) $(CRC_API)
	@echo "✅ Logged in as developer"

logout:
	@oc logout
	@echo "👋 Logged out"

# Service URLs
urls:
	@echo "🌐 Service URLs:"
	@echo "📊 Grafana:    http://$(call grafana_url)"
	@echo "🔥 Prometheus: http://$(call prometheus_url)"
	@echo "📝 Loki:       http://$(call loki_url)"
	@echo ""
	@echo "🔐 Grafana Login: admin/admin"

# Open Grafana in browser
grafana/open:
	@if [ "$(call grafana_url)" != "" ]; then \
		echo "🌐 Opening Grafana..."; \
		open http://$(call grafana_url) || xdg-open http://$(call grafana_url) || echo "❌ Could not open browser. URL: http://$(call grafana_url)"; \
	else \
		echo "❌ Grafana route not found. Run 'make deploy' first."; \
	fi

# Load testing
load-test:
	@echo "🔥 Running K6 torture test (200 VUs, 6m30s)..."
	@if command -v k6 >/dev/null 2>&1; then \
		k6 run k6/load-test.js; \
	else \
		echo "❌ K6 not installed. Install from: https://k6.io/docs/getting-started/installation/"; \
	fi

load-test/light:
	@echo "🔥 Running K6 light test (50 VUs, 2m)..."
	@if command -v k6 >/dev/null 2>&1; then \
		K6_VUS=50 K6_DURATION=2m k6 run k6/load-test.js; \
	else \
		echo "❌ K6 not installed. Install from: https://k6.io/docs/getting-started/installation/"; \
	fi

load-test/torture:
	@echo "💀 Running K6 TORTURE test (200 VUs, 6m30s)..."
	@if command -v k6 >/dev/null 2>&1; then \
		K6_VUS=200 K6_DURATION=6m30s k6 run k6/torture-test.js; \
	else \
		echo "❌ K6 not installed"; \
	fi

# Verification and smoke tests
verify:
	@echo "🔍 Verifying log ingestion..."
	@if curl -s "http://loki-monitoring.apps-crc.testing/loki/api/v1/labels" | grep -q "apache-logs"; then \
		echo "✅ Logs ingestion verified"; \
	else \
		echo "❌ Log ingestion failed"; \
	fi

smoke-test:
	@echo "🔥 Running smoke tests..."
	@echo "🏥 Testing Grafana..."
	@if curl -s http://$(call grafana_url)/api/health | grep -q "ok"; then \
		echo "✅ Grafana OK"; \
	else \
		echo "❌ Grafana FAIL"; \
	fi
	@echo "📝 Testing Loki..."
	@if curl -s "http://loki-monitoring.apps-crc.testing/ready" | grep -q "ready"; then \
		echo "✅ Loki OK"; \
	else \
		echo "❌ Loki FAIL"; \
	fi
	@echo "🔥 Testing Prometheus..."
	@if curl -s "http://prometheus-monitoring.apps-crc.testing/-/ready" | grep -q "ready"; then \
		echo "✅ Prometheus OK"; \
	else \
		echo "❌ Prometheus FAIL"; \
	fi
	@echo "🎯 Smoke test complete"

# Component rollouts
rollout/all: rollout/loki rollout/grafana rollout/prometheus rollout/promtail
	@echo "🔄 All components restarted"

rollout/loki:
	@echo "🔄 Restarting Loki..."
	@oc rollout restart deployment/loki -n monitoring

rollout/grafana:
	@echo "🔄 Restarting Grafana..."
	@oc rollout restart deployment/grafana -n monitoring

rollout/prometheus:
	@echo "🔄 Restarting Prometheus..."
	@oc rollout restart deployment/prometheus -n monitoring

rollout/promtail:
	@echo "🔄 Restarting Promtail..."
	@oc rollout restart deployment/promtail -n monitoring

rollout/metrics-server:
	@echo "🔄 Restarting Metrics Server..."
	@oc rollout restart deployment/metrics-server -n kube-system

# Log following
logs/loki:
	@oc logs -f deployment/loki -n monitoring

logs/grafana:
	@oc logs -f deployment/grafana -n monitoring

logs/promtail:
	@oc logs -f deployment/promtail -n monitoring

logs/apache:
	@oc logs -f deployment/httpd-simple-metrics -n my-app-project

# HPA monitoring
hpa/watch:
	@echo "📈 Watching HPA scaling (Ctrl+C to stop)..."
	@watch oc get hpa httpd-hpa -n my-app-project

hpa/status:
	@oc get hpa -n my-app-project
	@oc describe hpa httpd-hpa -n my-app-project

# Backup configurations
backup:
	@echo "💾 Creating backup..."
	@mkdir -p backup/$$(date +%Y%m%d_%H%M%S)
	@oc get -o yaml all -n monitoring > backup/$$(date +%Y%m%d_%H%M%S)/monitoring.yaml
	@oc get -o yaml all -n my-app-project > backup/$$(date +%Y%m%d_%H%M%S)/app.yaml
	@echo "✅ Backup created in backup/$$(date +%Y%m%d_%H%M%S)/"

# Nuclear option
nuke:
	@echo "💣 NUCLEAR OPTION - This will destroy CRC completely!"
	@echo "🚨 Are you sure? This cannot be undone!"
	@read -p "Type 'NUKE' to confirm: " confirm && [ "$$confirm" = "NUKE" ] || exit 1
	@echo "☢️ Destroying CRC..."
	@crc delete -f
	@echo "💀 CRC obliterated"

# Metrics check
metrics:
	@echo "📊 Node metrics:"
	@kubectl top nodes || echo "❌ Metrics server not ready"
	@echo ""
	@echo "📊 Pod metrics:"
	@kubectl top pods -n my-app-project || echo "❌ Metrics server not ready"
	@kubectl top pods -n monitoring || echo "❌ Metrics server not ready"
