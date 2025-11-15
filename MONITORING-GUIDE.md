# 📊 Caritas Service Monitoring with SigNoz

## ✅ What's Set Up

### External Monitoring System (NO CHANGES TO YOUR SERVICES!)
- **Monitor Service**: `caritas-signoz-monitor.service`
- **Status**: Running and auto-starts on boot
- **What it does**: Checks all 5 services every 10 seconds
- **Data sent to**: SigNoz at http://91.99.219.182:3001

### Services Being Monitored
1. ✅ TenantService (port 8081)
2. ✅ UserService (port 8082)
3. ✅ ConsultingTypeService (port 8083)
4. ✅ AgencyService (port 8084)
5. ✅ LiveService (port 8086)

### Metrics Collected
- **Service Status**: Up/Down (1 or 0)
- **HTTP Response Code**: 200, 401, 500, etc.
- **Response Time**: Milliseconds
- **Uptime**: Continuous monitoring

---

## 🌐 Viewing in SigNoz Dashboard

### Step 1: Open SigNoz
Go to: **http://91.99.219.182:3001**

Login with:
- Email: caritas@gmail.com
- Password: @Caritas1234

### Step 2: View Service Metrics

1. **Click "Dashboards"** in the left menu
2. **Click "New Dashboard"**
3. **Add Panel** and use these queries:

#### Service Health Status:
```
service.health.status{service="userservice"}
service.health.status{service="tenantservice"}
service.health.status{service="agencyservice"}
service.health.status{service="consultingtypeservice"}
service.health.status{service="liveservice"}
```

#### Service Response Times:
```
service.health.response_time{service="userservice"}
```

### Step 3: Create Alerts

1. Go to **Alerts** → **New Alert**
2. Set conditions like:
   - If `service.health.status < 1` for 1 minute
   - If `service.health.response_time > 5000` (5 seconds)

---

## 🔧 Managing the Monitor

### Check Monitor Status
```bash
sudo systemctl status caritas-signoz-monitor.service
```

### View Live Logs
```bash
tail -f ~/Desktop/online-beratung/signoz/monitoring/monitor.log
```

### Restart Monitor
```bash
sudo systemctl restart caritas-signoz-monitor.service
```

### Stop Monitor
```bash
sudo systemctl stop caritas-signoz-monitor.service
```

### Start Monitor
```bash
sudo systemctl start caritas-signoz-monitor.service
```

---

## 📁 Files Location

All monitoring files are in:
```
~/Desktop/online-beratung/signoz/monitoring/
```

Files:
- `monitor-services.sh` - Main monitoring script
- `monitor.log` - Live monitoring logs
- `/etc/systemd/system/caritas-signoz-monitor.service` - System service

---

## 🎯 What You'll See

### Current Service Status (Every 10 seconds):
```
[23:56:18] Checking services...
✅ tenantservice: 200 (26ms)
✅ userservice: 200 (21ms)
✅ consultingtypeservice: 200 (20ms)
✅ agencyservice: 200 (22ms)
❌ liveservice: 401 (17ms)
```

### In SigNoz Dashboard:
- Real-time service health graphs
- Response time trends
- Uptime percentage
- Alert notifications when services go down

---

## 💡 Benefits

✅ **No Service Changes**: Your microservices are untouched
✅ **Real-time Monitoring**: Updates every 10 seconds
✅ **Historical Data**: SigNoz stores all metrics
✅ **Alerting**: Get notified when services fail
✅ **Visualization**: Beautiful dashboards
✅ **Auto-start**: Monitoring starts automatically on server boot

---

## 🚨 Troubleshooting

### Monitor Not Running?
```bash
sudo systemctl status caritas-signoz-monitor.service
sudo journalctl -u caritas-signoz-monitor.service -f
```

### No Data in SigNoz?
1. Check if monitor is running (see above)
2. Check logs: `tail -f ~/Desktop/online-beratung/signoz/monitoring/monitor.log`
3. Verify SigNoz is running: `sudo k3s kubectl get pods -n platform`

### Services Showing as Down?
- Check if services are actually running
- Test manually: `curl http://localhost:8081/actuator/health`

---

**Setup Date**: October 15, 2025
**Monitor Service**: caritas-signoz-monitor.service
**SigNoz Dashboard**: http://91.99.219.182:3001
