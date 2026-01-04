#!/usr/bin/env python3
import requests
import time
import json
from datetime import datetime
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader

# Configure OpenTelemetry
resource = Resource.create({"service.name": "caritas-health-monitor"})

# Get OTEL Collector endpoint from Kubernetes service
OTEL_ENDPOINT = "http://10.43.196.88:4317"

# Setup Tracing
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)
otlp_trace_exporter = OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True)
trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(otlp_trace_exporter))

# Setup Metrics
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=OTEL_ENDPOINT, insecure=True),
    export_interval_millis=10000
)
metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))
meter = metrics.get_meter(__name__)

# Create metrics
uptime_counter = meter.create_counter("service.uptime", description="Service uptime checks")
response_time = meter.create_histogram("service.response_time", unit="ms", description="Service response time")
status_gauge = meter.create_up_down_counter("service.status", description="Service status (1=up, 0=down)")

SERVICES = {
    "tenantservice": {"url": "http://127.0.0.1:8081/actuator/health", "port": "8081"},
    "userservice": {"url": "http://127.0.0.1:8082/actuator/health", "port": "8082"},
    "consultingtypeservice": {"url": "http://127.0.0.1:8083/actuator/health", "port": "8083"},
    "agencyservice": {"url": "http://127.0.0.1:8084/actuator/health", "port": "8084"},
    "liveservice": {"url": "http://127.0.0.1:8086/actuator/health", "port": "8086"},
    "matrix-synapse": {"url": "http://127.0.0.1:8008/_matrix/client/versions", "port": "8008"}
}

def check_service(name, config):
    with tracer.start_as_current_span(f"health_check_{name}") as span:
        span.set_attribute("service.name", name)
        span.set_attribute("service.port", config["port"])
        
        try:
            start = time.time()
            response = requests.get(config["url"], timeout=5)
            duration = (time.time() - start) * 1000
            
            is_healthy = response.status_code == 200
            span.set_attribute("http.status_code", response.status_code)
            span.set_attribute("service.healthy", is_healthy)
            
            # Record metrics
            response_time.record(duration, {"service": name, "port": config["port"]})
            status_gauge.add(1 if is_healthy else 0, {"service": name})
            uptime_counter.add(1, {"service": name, "status": "up" if is_healthy else "down"})
            
            print(f"✅ {name}: {response.status_code} ({duration:.0f}ms)")
            return True
            
        except Exception as e:
            span.set_attribute("error", True)
            span.set_attribute("error.message", str(e))
            status_gauge.add(0, {"service": name})
            uptime_counter.add(1, {"service": name, "status": "down"})
            print(f"❌ {name}: {str(e)}")
            return False

print("🚀 Caritas Service Monitor → SigNoz")
print("=" * 50)
print(f"Monitoring {len(SERVICES)} services every 10 seconds...")
print(f"Sending data to SigNoz at {OTEL_ENDPOINT}")
print("=" * 50)

while True:
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    print(f"\n[{timestamp}] Checking services...")
    
    for service_name, service_config in SERVICES.items():
        check_service(service_name, service_config)
    
    time.sleep(10)
