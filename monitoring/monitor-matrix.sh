#!/bin/bash
# Simple Matrix monitoring script for SigNoz
OTEL_ENDPOINT="http://10.43.196.88:4318/v1/metrics"
MATRIX_URL="http://127.0.0.1:8008/_matrix/client/versions"

while true; do
    timestamp=$(date -u +%s)000000000
    start=$(date +%s%N)
    
    if curl -s -f "$MATRIX_URL" > /dev/null 2>&1; then
        status=1
        http_code=200
    else
        status=0
        http_code=0
    fi
    
    duration=$((($(date +%s%N) - start) / 1000000))
    
    # Send metric to SigNoz OTEL collector
    curl -s -X POST "$OTEL_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{
            \"resourceMetrics\": [{
                \"resource\": {
                    \"attributes\": [{
                        \"key\": \"service.name\",
                        \"value\": {\"stringValue\": \"matrix-synapse\"}
                    }]
                },
                \"scopeMetrics\": [{
                    \"metrics\": [{
                        \"name\": \"service.status\",
                        \"gauge\": {
                            \"dataPoints\": [{
                                \"timeUnixNano\": \"$timestamp\",
                                \"value\": $status
                            }]
                        }
                    }, {
                        \"name\": \"service.response_time\",
                        \"histogram\": {
                            \"dataPoints\": [{
                                \"timeUnixNano\": \"$timestamp\",
                                \"count\": 1,
                                \"sum\": $duration
                            }]
                        }
                    }]
                }]
            }]
        }" > /dev/null 2>&1
    
    echo "[$(date)] matrix-synapse: status=$status, response_time=${duration}ms"
    sleep 10
done
