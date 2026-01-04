#!/bin/bash

# Caritas Service Monitor - External health checker
# Runs separately, sends logs to SigNoz

SIGNOZ_COLLECTOR="http://signoz-otel-collector.platform.svc.cluster.local:8082"

log_to_signoz() {
    local service=$1
    local port=$2
    local status=$3
    local http_code=$4
    local response_time=$5
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create JSON log
    local log_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "severity": "INFO",
  "body": "Service health check",
  "attributes": {
    "service.name": "$service",
    "service.port": "$port",
    "health.status": "$status",
    "http.status_code": $http_code,
    "response.time_ms": $response_time,
    "monitor.type": "external_health_check"
  }
}
EOF
)
    
    echo "$log_entry"
}

echo "🔍 Caritas Service Monitor Started"
echo "Monitoring services at: $(date)"

while true; do
    # Monitor each service
    for service_info in "tenantservice:8081" "userservice:8082" "consultingtypeservice:8083" "agencyservice:8084" "liveservice:8086"; do
        IFS=: read -r service port <<< "$service_info"
        
        start=$(date +%s%N)
        http_code=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:$port/actuator/health 2>/dev/null)
        end=$(date +%s%N)
        
        response_time=$(( (end - start) / 1000000 ))
        
        if [ "$http_code" = "200" ]; then
            status="up"
        else
            status="down"
        fi
        
        log_to_signoz "$service" "$port" "$status" "$http_code" "$response_time"
    done
    
    sleep 10
done
