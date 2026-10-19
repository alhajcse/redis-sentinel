#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
set -a
source .env
set +a

echo "═══════════════════════════════════════════════════"
echo "  Redis Sentinel — Failover Test"
echo "═══════════════════════════════════════════════════"

echo ""
echo "📍 Current master:"
docker exec sentinel-1 redis-cli -p 26379 sentinel get-master-addr-by-name mymaster

echo ""
echo " Triggering manual failover..."
docker exec sentinel-1 redis-cli -p 26379 sentinel failover mymaster

echo ""
echo "⏳ Waiting 12 seconds for failover..."
sleep 12

echo ""
echo "📍 New master:"
docker exec sentinel-1 redis-cli -p 26379 sentinel get-master-addr-by-name mymaster

echo ""
echo "📊 Replication status (from new master):"
new_master_port=$(docker exec sentinel-1 redis-cli -p 26379 sentinel get-master-addr-by-name mymaster \
  | tail -1)
echo "   New master is on port: $new_master_port"

echo ""
echo " Failover complete — verify the port changed above!"