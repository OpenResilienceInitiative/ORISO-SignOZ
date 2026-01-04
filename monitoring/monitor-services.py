#!/usr/bin/env python3
import requests
import time
import json
from datetime import datetime

SERVICES = {
    "tenantservice": "http://localhost:8081/actuator/health",
    "userservice": "http://localhost:8082/actuator/health",
    "consultingtypeservice": "http://localhost:8083/actuator/health",
    "agencyservice": "http://localhost:8084/actuator/health",
    "liveservice": "http://localhost:8086/actuator/health"
}

def check_service(name, url):
    try:
        start = time.time()
        response = requests.get(url, timeout=5)
        duration = (time.time() - start) * 1000  # milliseconds
        
        return {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "service": name,
            "status": "up" if response.status_code == 200 else "down",
            "http_code": response.status_code,
            "response_time_ms": round(duration, 2)
        }
    except Exception as e:
        return {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "service": name,
            "status": "down",
            "http_code": 0,
            "response_time_ms": 0,
            "error": str(e)
        }

print("🔍 Caritas Service Monitor Started")
print("Monitoring 5 services every 10 seconds...")

while True:
    for service_name, service_url in SERVICES.items():
        result = check_service(service_name, service_url)
        print(json.dumps(result))
    time.sleep(10)
