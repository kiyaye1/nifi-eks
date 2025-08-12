#!/usr/bin/env bash
set -euo pipefail
NS="${1:-nifi}"
SVC="${2:-nifi}"
echo "Waiting for LoadBalancer hostname for ${NS}/${SVC} ..."
for i in {1..60}; do
  host=$(kubectl -n "$NS" get svc "$SVC" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [ -n "$host" ]; then
    echo "ELB Hostname: $host"
    echo "NiFi URL: http://$host:8080/nifi"
    exit 0
  fi
  sleep 10
done
echo "Timed out waiting for ELB hostname."
exit 1
