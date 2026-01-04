#!/bin/bash

SIGNOZ_COLLECTOR="http://10.43.196.88:4318"  # HTTP endpoint (caritas namespace)

echo "🚀 Caritas Service Monitor → SigNoz (ORISO)"
echo "=================================================="
echo "Monitoring 6 ORISO services every 10 seconds..."
echo "Sending data to SigNoz at $SIGNOZ_COLLECTOR"
echo "=================================================="

while true; do
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo ""
    echo "[$(date +"%H:%M:%S")] Checking ORISO services..."
    
    # Check each service
    for service_info in "8081:tenantservice:/actuator/health" "8082:userservice:/actuator/health" "8083:consultingtypeservice:/actuator/health" "8084:agencyservice:/actuator/health" "8086:liveservice:/actuator/health" "8008:matrix-synapse:/_matrix/client/versions"; do
        IFS=":" read -r port name path <<< "$service_info"
        
        # Measure response time
        start_ms=$(date +%s%3N)
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 http://127.0.0.1:$port$path 2>/dev/null || echo "000")
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
        "value": {"stringValue": "$name"}
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
