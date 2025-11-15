#!/bin/bash

while true; do
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Check all services
  for service_info in "8081:tenantservice" "8082:userservice" "8083:consultingtypeservice" "8084:agencyservice" "8086:liveservice"; do
    IFS=":" read -r port name <<< "$service_info"
    
    start_time=$(date +%s%N)
    response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:$port/actuator/health 2>/dev/null)
    end_time=$(date +%s%N)
    
    response_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    status="up"
    [ "$response" != "200" ] && status="down"
    
    # Send to OTEL collector as custom metric
    echo "{\"timestamp\":\"$timestamp\",\"service\":\"$name\",\"port\":$port,\"status\":\"$status\",\"http_code\":$response,\"response_time_ms\":$response_time}"
  done
  
  sleep 10
done
