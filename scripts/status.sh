#!/usr/bin/env bash
echo "--- Lab Status ---"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo "docker no adisponible"
curl -s http://127.0.0.1:3080/v2/version | jq . || echo "GNS3 down"
