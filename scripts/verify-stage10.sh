#!/usr/bin/env bash
# verify-stage10.sh — PERF01: 30 min medidos, result en evidence/
set -Eeuo pipefail
DUR="${DUR:-1800}"   # 30 min
OUT="evidence/PERF01-$(date -u +%Y%m%dT%H%M%SZ).csv"
mkdir -p evidence
echo "ts,container,cpu%,mem" > "$OUT"
END=$((SECONDS + DUR))
while [ $SECONDS -lt $END ]; do
  ts=$(date -u +%H:%M:%S)
  docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" \
    | sed "s/^/$ts,/" >> "$OUT"
  sleep 30
done
echo "medición completa → $OUT"
