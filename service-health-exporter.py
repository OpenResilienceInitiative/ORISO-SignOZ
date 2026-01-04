#!/usr/bin/env python3
"""
Caritas Service Health Monitor - Exports to SigNoz
Monitors services via health checks and sends metrics to OTEL Collector
"""
import requests
import time
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource

# Configure OTEL
resource = Resource.create({"service.name": "caritas-health-monitor"})
exporter = OTLPMetricExporter(endpoint="http://10.43.140.5:4317", insecure=True)
reader = PeriodicExportingMetricReader(exporter, export_interval_millis=10000)
provider = MeterProvider(resource=resource, metric_readers=[reader])
metrics.set_meter_provider(provider)

meter = metrics.get_meter("caritas.monitoring")

# Create metrics
service_up = meter.create_up_down_counter(
    "service.up",
    description="Service availability (1=up, 0=down)"
)
response_time = meter.create_histogram(
    "service.response_time",
    unit="ms",
    description="Service response time"
)

SERVICES = {
    "tenantservice": {"url": "http://91.99.219.182:8081/actuator/health", "port": 8081},
    "userservice": {"url": "http://91.99.219.182:8082/actuator/health", "port": 8082},
    "consultingtypeservice": {"url": "http://91.99.219.182:8083/actuator/health", "port": 8083},
    "agencyservice": {"url": "http://91.99.219.182:8084/actuator/health", "port": 8084},
    "liveservice": {"url": "http://91.99.219.182:8086/actuator/health", "port": 8086}
}

def check_service(name, config):
    try:
        start = time.time()
        response = requests.get(config["url"], timeout=5)
        duration = (time.time() - start) * 1000
        
        status = 1 if response.status_code == 200 else 0
        
        attributes = {
            "service.name": name,
            "service.port": str(config["port"]),
            "http.status_code": str(response.status_code)
        }
        
        service_up.add(status, attributes)
        response_time.record(duration, attributes)
        
        print(f"✓ {name}: {response.status_code} ({duration:.2f}ms)")
        
    except Exception as e:
        attributes = {
            "service.name": name,
            "service.port": str(config["port"]),
            "error": "true"
        }
        service_up.add(0, attributes)
        print(f"✗ {name}: DOWN ({str(e)})")

print("🔍 Caritas Health Monitor for SigNoz")
print("Monitoring 5 services and sending to SigNoz OTEL Collector...")
print("=" * 60)

while True:
    for service_name, service_config in SERVICES.items():
        check_service(service_name, service_config)
    print("-" * 60)
    time.sleep(10)
