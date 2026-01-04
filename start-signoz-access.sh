#!/bin/bash
echo "🚀 Starting SigNoz access on port 3001..."
echo "SigNoz will be available at: http://91.99.219.182:3001"
echo "Press Ctrl+C to stop"
sudo k3s kubectl port-forward -n platform svc/signoz 3001:8080 --address=0.0.0.0
