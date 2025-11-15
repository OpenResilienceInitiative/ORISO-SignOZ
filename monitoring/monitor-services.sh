#!/bin/bash

SIGNOZ_COLLECTOR="http://10.43.219.37:4318"  # HTTP endpoint (caritas namespace)

echo "🚀 Caritas Service Monitor → SigNoz (ORISO)"
echo "=================================================="
echo "Monitoring 4 ORISO services every 10 seconds..."
echo "Sending data to SigNoz at $SIGNOZ_COLLECTOR"
echo "=================================================="

while true; do
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo ""
    echo "[$(date +"%H:%M:%S")] Checking ORISO services..."
    
    # Check each service (removed liveservice)
    for service_info in "8081:tenantservice" "8082:userservice" "8083:consultingtypeservice" "8084:agencyservice"; do
        IFS=":" read -r port name <<< "$service_info"
        
        # Measure response time
        start_ms=$(date +%s%3N)
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 http://127.0.0.1:$port/actuator/health 2>/dev/null || echo "000")
        end_ms=$(date +%s%3N)
        response_time=$((end_ms - start_ms))
        
        # Determine status
        if [ "$http_code" = "200" ]; then
            status="up"
            emoji="✅"
        else
            status="down"
            emoji="❌"
        fi
        
        echo "$emoji $name: $http_code (${response_time}ms)"
        
        # Send metrics to SigNoz (OTLP HTTP format)
        cat << EOF | curl -s -X POST "$SIGNOZ_COLLECTOR/v1/metrics" \
            -H "Content-Type: application/json" \
            -d @- > /dev/null 2>&1
{
  "resourceMetrics": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "caritas-monitor"}
      }]
    },
    "scopeMetrics": [{
      "metrics": [
        {
          "name": "service.health.status",
          "gauge": {
            "dataPoints": [{
              "asInt": $([ "$status" = "up" ] && echo "1" || echo "0"),
              "timeUnixNano": $(date +%s)000000000,
              "attributes": [
                {"key": "service", "value": {"stringValue": "$name"}},
                {"key": "port", "value": {"stringValue": "$port"}},
                {"key": "http_code", "value": {"stringValue": "$http_code"}}
              ]
            }]
          }
        },
        {
          "name": "service.health.response_time",
          "gauge": {
            "dataPoints": [{
              "asInt": $response_time,
              "timeUnixNano": $(date +%s)000000000,
              "attributes": [
                {"key": "service", "value": {"stringValue": "$name"}},
                {"key": "port", "value": {"stringValue": "$port"}}
              ]
            }]
          }
        }
      ]
    }]
  }]
}
EOF
        
    done
    
    sleep 10
done
