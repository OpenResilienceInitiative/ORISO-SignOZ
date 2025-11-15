# SignOZ - Quick Deployment Guide

## 🚀 Production Deployment

### Prerequisites
- Kubernetes cluster (k3s)
- Helm 3.x installed
- 4GB+ RAM available
- 20GB+ storage for ClickHouse

### Step 1: Install Helm (if not already installed)
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Step 2: Add SignOZ Helm Repository
```bash
helm repo add signoz https://charts.signoz.io
helm repo update
```

### Step 3: Create Namespace
```bash
kubectl create namespace platform
```

### Step 4: Deploy SignOZ
```bash
cd /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-SignOZ

helm install signoz signoz/signoz \
  --namespace platform \
  --values signoz-values-current.yaml
```

### Step 5: Wait for Deployment
```bash
# Watch pods until all are Running
kubectl get pods -n platform --watch

# Should see:
# - signoz-frontend
# - signoz-backend
# - signoz-otel-collector
# - clickhouse-0
# - zookeeper-0
```

### Step 6: Access SignOZ
```bash
# Port forward (temporary)
kubectl port-forward -n platform svc/signoz-frontend 3001:3301

# Open browser: http://localhost:3001
```

### Step 7: Configure Permanent Access
Create NodePort service or Nginx proxy (see below).

## 🔐 First-Time Setup

### Create Admin Account
1. Open http://localhost:3001
2. Click "Sign Up"
3. Email: caritas@gmail.com
4. Password: @Caritas1234
5. Organization: Caritas Online Beratung

### Initial Configuration
1. Go to **Settings** → **Organization**
2. Set up notification channels (email, Slack, etc.)
3. Create first dashboard
4. Set up alerts

## 🌐 Production Access Methods

### Method 1: NodePort (Simple)
```bash
kubectl patch svc signoz-frontend -n platform -p '{"spec":{"type":"NodePort","ports":[{"port":3301,"nodePort":30301}]}}'
```
Access: http://91.99.219.182:30301

### Method 2: Nginx Proxy (Recommended)
Add to Nginx configuration:
```nginx
location /signoz/ {
    proxy_pass http://signoz-frontend.platform.svc.cluster.local:3301/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```
Access: http://91.99.219.182/signoz/

### Method 3: Port Forward (Development)
```bash
kubectl port-forward -n platform svc/signoz-frontend 3001:3301
```
Access: http://localhost:3001

## 📊 Setting Up Service Monitoring

### Option 1: Health Check Monitor (Lightweight)
```bash
# Install systemd service
cd monitoring
sudo cp caritas-signoz-monitor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable caritas-signoz-monitor.service
sudo systemctl start caritas-signoz-monitor.service

# Check status
sudo systemctl status caritas-signoz-monitor.service

# View logs
tail -f monitoring/monitor.log
```

### Option 2: OpenTelemetry Auto-Instrumentation (Detailed)
Add to each service deployment:

```yaml
spec:
  template:
    spec:
      containers:
      - name: service
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
          path: /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-SignOZ/opentelemetry-javaagent.jar
          type: File
        name: otel-agent
```

## 📈 Creating First Dashboard

### Step 1: Login to SignOZ
http://91.99.219.182:3001

### Step 2: Create Dashboard
1. Click **Dashboards** → **New Dashboard**
2. Name: "Caritas Services Health"
3. Click **Add Panel**

### Step 3: Add Service Health Panel
```
Query: service.health.status{service="userservice"}
Visualization: Stat
Title: UserService Health
Color: Green if 1, Red if 0
```

### Step 4: Add Response Time Panel
```
Query: service.health.response_time{service="userservice"}
Visualization: Time Series
Title: UserService Response Time
Unit: milliseconds
```

### Step 5: Add All Services Table
```
Query: service.health.status
Group By: service
Visualization: Table
Title: All Services Status
```

## 🚨 Setting Up Alerts

### Example: Service Down Alert
1. Go to **Alerts** → **New Alert**
2. **Name:** Service Down - Critical
3. **Condition:** `service.health.status{service="userservice"} < 1`
4. **Duration:** 1 minute
5. **Severity:** Critical
6. **Notification:** Email/Slack

### Example: High Response Time Alert
1. **Name:** Slow Response Warning
2. **Condition:** `service.health.response_time{service="userservice"} > 5000`
3. **Duration:** 5 minutes
4. **Severity:** Warning

## ✅ Verification Checklist

- [ ] All SignOZ pods are Running
- [ ] Frontend accessible at port 3001/30301
- [ ] Admin account created
- [ ] Health check monitor running (if using)
- [ ] At least one dashboard created
- [ ] At least one alert configured
- [ ] Notification channel configured
- [ ] Services sending metrics

## 🔧 Configuration Files

### signoz-values-current.yaml
Main configuration file for SignOZ Helm chart.

**Key Settings:**
- Frontend service port: 3301
- ClickHouse storage: 20Gi
- OTEL collector resources
- Data retention policies

### signoz-values-original.yaml
Backup of original values for reference.

## 🔄 Updates

### Update SignOZ
```bash
# Update Helm repo
helm repo update

# Upgrade installation
helm upgrade signoz signoz/signoz \
  --namespace platform \
  --values signoz-values-current.yaml
```

### Restart SignOZ
```bash
# Restart all components
kubectl rollout restart deployment -n platform
kubectl rollout restart statefulset -n platform
```

## 🚨 Troubleshooting

### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n platform

# Describe problematic pod
kubectl describe pod <pod-name> -n platform

# Check logs
kubectl logs <pod-name> -n platform
```

### Frontend Not Accessible
```bash
# Check service
kubectl get svc -n platform signoz-frontend

# Test internally
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://signoz-frontend.platform.svc.cluster.local:3301
```

### No Metrics Appearing
1. Check OTEL collector is running
2. Verify services can reach collector
3. Check collector logs: `kubectl logs -n platform -l app=otel-collector`
4. Verify OpenTelemetry agent configuration

### High Resource Usage
```bash
# Check resource usage
kubectl top pods -n platform

# If ClickHouse using too much memory:
kubectl edit statefulset clickhouse -n platform
# Reduce memory limits
```

## 💾 Backup

### Backup SignOZ Configuration
```bash
# Backup Helm values
kubectl get configmap -n platform -o yaml > signoz-config-backup.yaml

# Backup ClickHouse data
kubectl exec -n platform clickhouse-0 -- \
  clickhouse-client --query="BACKUP DATABASE signoz TO Disk('backups', 'signoz-$(date +%Y%m%d)')"
```

## 🗑️ Uninstall

```bash
# Remove SignOZ
helm uninstall signoz --namespace platform

# Delete namespace
kubectl delete namespace platform

# Clean up PVCs (⚠️ deletes data!)
kubectl delete pvc -n platform --all
```

## 📚 Resources

- **SignOZ Docs:** https://signoz.io/docs/
- **Helm Chart:** https://github.com/SigNozHQ/charts
- **OpenTelemetry:** https://opentelemetry.io/

## 🎯 Production Checklist

- [ ] SignOZ deployed in `platform` namespace
- [ ] Persistent storage configured
- [ ] Access method configured (NodePort/Nginx)
- [ ] Admin account secured
- [ ] Services instrumented
- [ ] Dashboards created
- [ ] Alerts configured
- [ ] Notification channels set up
- [ ] Backup strategy in place
- [ ] Resource limits appropriate

---

**Namespace:** platform  
**Access:** http://91.99.219.182:3001  
**Credentials:** caritas@gmail.com / @Caritas1234  
**OTEL Endpoint:** signoz-otel-collector.platform.svc.cluster.local:4317

