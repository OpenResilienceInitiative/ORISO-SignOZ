# ORISO SignOZ - Observability Platform

## Overview
Complete observability solution for Online Beratung platform. SignOZ provides distributed tracing, metrics, and logs in a single platform - an open-source alternative to DataDog/New Relic.

## What is SignOZ?
SignOZ is an open-source Application Performance Monitoring (APM) tool that helps you monitor and troubleshoot applications. It provides:
- 📊 **Metrics** - Track service performance, response times, error rates
- 🔍 **Distributed Tracing** - Follow requests across microservices
- 📝 **Logs** - Centralized log management
- 🚨 **Alerts** - Get notified when things go wrong
- 📈 **Dashboards** - Beautiful visualizations

## Current Setup

### Access Information
- **URL:** http://91.99.219.182:3001
- **Email:** caritas@gmail.com
- **Password:** @Caritas1234

### What's Being Monitored
1. ✅ TenantService (port 8081)
2. ✅ UserService (port 8082)
3. ✅ ConsultingTypeService (port 8083)
4. ✅ AgencyService (port 8084)
5. ✅ VideoService (port 8090)
6. ✅ LiveService (port 8085)

### Metrics Collected
- **Service Health Status** - UP/DOWN (1/0)
- **HTTP Response Codes** - 200, 401, 500, etc.
- **Response Times** - Milliseconds
- **Uptime** - Continuous availability tracking
- **Error Rates** - Failed requests percentage

## Architecture

### Components
1. **SignOZ Backend** - Data collection and storage
2. **SignOZ Frontend** - Web UI dashboard
3. **OTEL Collector** - OpenTelemetry collector for metrics/traces
4. **ClickHouse** - Time-series database for metrics
5. **Service Monitor** - Custom health check exporter

### How It Works
```
Services → OpenTelemetry Agent → OTEL Collector → SignOZ Backend → ClickHouse
                                                                        ↓
                                                                   SignOZ UI
```

## Installation

### Prerequisites
- Kubernetes cluster (k3s)
- Helm 3.x
- 4GB+ RAM available
- Persistent storage

### Deploy SignOZ
```bash
# Add SignOZ Helm repo
helm repo add signoz https://charts.signoz.io
helm repo update

# Create namespace
kubectl create namespace platform

# Install SignOZ
helm install signoz signoz/signoz \
  --namespace platform \
  --values signoz-values-current.yaml

# Wait for pods to be ready
kubectl get pods -n platform --watch
```

### Verify Installation
```bash
# Check all pods are running
kubectl get pods -n platform

# Access SignOZ UI
kubectl port-forward -n platform svc/signoz-frontend 3001:3301
# Open http://localhost:3001
```

## Service Monitoring Setup

### Method 1: Health Check Exporter (Current)
A custom script checks service health endpoints and exports metrics to SignOZ.

**Location:** `monitoring/monitor-services.sh`

**Setup:**
```bash
# Make executable
chmod +x monitoring/monitor-services.sh

# Run as systemd service
sudo systemctl enable caritas-signoz-monitor.service
sudo systemctl start caritas-signoz-monitor.service

# Check status
sudo systemctl status caritas-signoz-monitor.service

# View logs
tail -f monitoring/monitor.log
```

**What it monitors:**
- `/actuator/health` endpoints
- HTTP status codes
- Response times
- Service availability

### Method 2: OpenTelemetry Auto-Instrumentation
For detailed application metrics, use OpenTelemetry Java agent.

**Add to service deployment:**
```yaml
env:
- name: MAVEN_OPTS
  value: >-
    -javaagent:/opt/otel/opentelemetry-javaagent.jar
    -Dotel.service.name=userservice
    -Dotel.exporter.otlp.endpoint=http://signoz-otel-collector.platform.svc.cluster.local:4317
    -Dotel.exporter.otlp.protocol=grpc
    -Dotel.metrics.exporter=otlp
    -Dotel.logs.exporter=otlp
    -Dotel.traces.exporter=otlp
volumeMounts:
- mountPath: /opt/otel/opentelemetry-javaagent.jar
  name: otel-agent
volumes:
- hostPath:
    path: /home/caritas/Desktop/online-beratung/signoz/opentelemetry-javaagent.jar
    type: File
  name: otel-agent
```

**Download OpenTelemetry Agent:**
```bash
wget https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar
```

## Creating Dashboards

### Step 1: Login to SignOZ
1. Go to http://91.99.219.182:3001
2. Login with caritas@gmail.com / @Caritas1234

### Step 2: Create Dashboard
1. Click **"Dashboards"** in left menu
2. Click **"+ New Dashboard"**
3. Give it a name: "Caritas Services Health"

### Step 3: Add Panels

#### Service Health Status Panel
```
Query: service.health.status{service="userservice"}
Visualization: Stat/Single Value
Thresholds: 
  - Green if value = 1 (UP)
  - Red if value = 0 (DOWN)
```

#### Response Time Panel
```
Query: service.health.response_time{service="userservice"}
Visualization: Time Series
Unit: milliseconds
```

#### All Services Status
```
Query: service.health.status
Group By: service
Visualization: Table
```

### Pre-Built Queries

#### Service Uptime Percentage
```
(count_over_time(service.health.status{service="userservice"}[1h]) 
  - 
count_over_time((service.health.status{service="userservice"} == 0)[1h]))
/
count_over_time(service.health.status{service="userservice"}[1h])
* 100
```

#### Average Response Time (Last Hour)
```
avg_over_time(service.health.response_time{service="userservice"}[1h])
```

#### Error Rate
```
sum(rate(http_requests_total{status=~"5.."}[5m])) 
/ 
sum(rate(http_requests_total[5m])) 
* 100
```

## Setting Up Alerts

### Step 1: Create Alert Rule
1. Go to **"Alerts"** in left menu
2. Click **"+ New Alert"**
3. Configure alert

### Step 2: Alert Examples

#### Service Down Alert
```yaml
Name: Service Down - UserService
Condition: service.health.status{service="userservice"} < 1
Duration: 1 minute
Severity: Critical
Message: UserService is DOWN! Immediate attention required.
```

#### High Response Time Alert
```yaml
Name: Slow Response - UserService
Condition: service.health.response_time{service="userservice"} > 5000
Duration: 5 minutes
Severity: Warning
Message: UserService response time exceeds 5 seconds
```

#### Multiple Services Down Alert
```yaml
Name: Multiple Services Down
Condition: count(service.health.status == 0) > 2
Duration: 2 minutes
Severity: Critical
Message: More than 2 services are down!
```

### Step 3: Configure Notifications
1. Go to **"Alerts"** → **"Notification Channels"**
2. Add channels:
   - **Email** - Get email alerts
   - **Slack** - Send to Slack channel
   - **Webhook** - Custom HTTP endpoint
   - **PagerDuty** - On-call escalation

## Monitoring Scripts

### Service Health Monitor
**File:** `monitoring/monitor-services.sh`

**Features:**
- Checks all services every 10 seconds
- Exports metrics to SignOZ
- Logs to `monitoring/monitor.log`
- Runs as systemd service

**Start/Stop:**
```bash
# Start
sudo systemctl start caritas-signoz-monitor.service

# Stop
sudo systemctl stop caritas-signoz-monitor.service

# Restart
sudo systemctl restart caritas-signoz-monitor.service

# Status
sudo systemctl status caritas-signoz-monitor.service

# Logs
journalctl -u caritas-signoz-monitor.service -f
```

### Manual Health Check
```bash
# Check all services
./monitoring/monitor-services.sh

# Check single service
curl -s http://localhost:8081/actuator/health | jq
```

## Configuration Files

### signoz-values-current.yaml
Current Helm values for SignOZ deployment.

**Key Settings:**
```yaml
frontend:
  service:
    type: ClusterIP
    port: 3301

clickhouse:
  persistence:
    size: 20Gi

otelCollector:
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
```

### signoz-values-original.yaml
Backup of original SignOZ values.

## Accessing SignOZ

### Method 1: Port Forward (Development)
```bash
kubectl port-forward -n platform svc/signoz-frontend 3001:3301
# Access: http://localhost:3001
```

### Method 2: NodePort (Production)
Configure service as NodePort:
```yaml
service:
  type: NodePort
  nodePort: 30301
```
Access: http://91.99.219.182:30301

### Method 3: Nginx Proxy (Recommended)
Add to Nginx config:
```nginx
location /signoz/ {
    proxy_pass http://signoz-frontend.platform.svc.cluster.local:3301/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```
Access: http://91.99.219.182/signoz/

## Troubleshooting

### SignOZ Not Loading
```bash
# Check pods
kubectl get pods -n platform

# Check logs
kubectl logs -n platform -l app=signoz-frontend
kubectl logs -n platform -l app=signoz-backend
```

### No Metrics Showing
1. Check OTEL collector is running
2. Verify services have OpenTelemetry agent
3. Check collector endpoint: `signoz-otel-collector.platform.svc.cluster.local:4317`
4. View collector logs: `kubectl logs -n platform -l app=otel-collector`

### Service Monitor Not Running
```bash
# Check systemd service
sudo systemctl status caritas-signoz-monitor.service

# Check logs
tail -f monitoring/monitor.log

# Restart service
sudo systemctl restart caritas-signoz-monitor.service
```

### High Memory Usage
SignOZ (especially ClickHouse) can use significant memory:
```bash
# Check resource usage
kubectl top pods -n platform

# Scale down if needed
kubectl scale deployment signoz-backend --replicas=0 -n platform
```

## Data Retention

### Default Retention
- **Metrics:** 30 days
- **Traces:** 7 days
- **Logs:** 7 days

### Configure Retention
Edit `signoz-values-current.yaml`:
```yaml
clickhouse:
  persistence:
    size: 50Gi  # Increase storage
  ttl:
    metrics: 2592000  # 30 days in seconds
    traces: 604800    # 7 days in seconds
```

## Backup & Restore

### Backup SignOZ Data
```bash
# Backup ClickHouse data
kubectl exec -n platform clickhouse-0 -- clickhouse-client --query="BACKUP DATABASE signoz TO Disk('backups', 'signoz-backup')"
```

### Restore SignOZ Data
```bash
# Restore from backup
kubectl exec -n platform clickhouse-0 -- clickhouse-client --query="RESTORE DATABASE signoz FROM Disk('backups', 'signoz-backup')"
```

## Performance Tuning

### For Low-Resource Environments
```yaml
# signoz-values-current.yaml
otelCollector:
  resources:
    limits:
      cpu: 500m
      memory: 1Gi

clickhouse:
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi
```

### For High-Traffic Environments
```yaml
otelCollector:
  replicas: 3
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi

clickhouse:
  shards: 2
  replicas: 2
```

## Integration with Services

### Spring Boot Integration
Add OpenTelemetry agent to service startup:
```bash
java -javaagent:/path/to/opentelemetry-javaagent.jar \
     -Dotel.service.name=userservice \
     -Dotel.exporter.otlp.endpoint=http://signoz-otel-collector:4317 \
     -jar userservice.jar
```

### Node.js Integration
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://signoz-otel-collector.platform.svc.cluster.local:4317',
  }),
  serviceName: 'frontend-service',
});

sdk.start();
```

## Important Notes
- **Resource Requirements:** SignOZ needs 4GB+ RAM
- **Storage:** Plan for long-term metric storage
- **Network:** Ensure services can reach OTEL collector
- **Security:** SignOZ has built-in authentication
- **Updates:** Check for SignOZ updates regularly

## Useful Commands
```bash
# View all SignOZ pods
kubectl get pods -n platform

# Access ClickHouse CLI
kubectl exec -it -n platform clickhouse-0 -- clickhouse-client

# View OTEL collector config
kubectl get configmap -n platform signoz-otel-collector-config -o yaml

# Restart SignOZ
kubectl rollout restart deployment/signoz-frontend -n platform
kubectl rollout restart deployment/signoz-backend -n platform
```

## Resources
- **SignOZ Docs:** https://signoz.io/docs/
- **OpenTelemetry:** https://opentelemetry.io/
- **GitHub:** https://github.com/SigNozHQ/signoz

---

**Status:** Production Ready ✅  
**Access:** http://91.99.219.182:3001  
**Credentials:** caritas@gmail.com / @Caritas1234
