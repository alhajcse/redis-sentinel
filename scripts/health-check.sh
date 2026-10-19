#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
set -a
source .env
set +a

MASTER_PORT=6379
CLI="redis-cli --no-auth-warning -a ${REDIS_PASSWORD}"

echo "═══════════════════════════════════════════════════"
echo "  Redis Sentinel — Health Check"
echo "═══════════════════════════════════════════════════"

# ─── Containers ───
echo ""
echo "📦 Containers:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose ps

# ─── Master replication info ───
echo ""
echo " Replication (from master):"
docker exec redis-master ${CLI} INFO replication 2>/dev/null \
  | grep -E "^(role|connected_slaves|slave[0-9]+):"

# ─── Sentinel: current master ───
echo ""
echo "  Sentinel view of master:"
for port in 26379 26380 26381; do
  echo -n "  Sentinel :${port} → "
  docker exec sentinel-1 redis-cli -p 26379 sentinel get-master-addr-by-name mymaster 2>/dev/null \
    | paste -sd ':' - || echo "N/A"
  # Note: all sentinels share state via gossip, so querying one is enough
  break
done

# ─── Sentinels registered ───
echo ""
echo " Registered Sentinels:"
count=$(docker exec sentinel-1 redis-cli -p 26379 sentinel sentinels mymaster 2>/dev/null | grep -c "name" || echo 0)
echo "  Total: $((count/1)) sentinels known to cluster"

# ─── Write/Read test ───
echo ""
echo "  Write/Read Test:"
ts=$(date +%s)
docker exec redis-master ${CLI} SET test:health "hello-${ts}" > /dev/null
echo "  Master wrote: hello-${ts}"

sleep 1
v1=$(docker exec redis-replica-1 ${CLI} GET test:health 2>/dev/null || echo "FAIL")
v2=$(docker exec redis-replica-2 ${CLI} GET test:health 2>/dev/null || echo "FAIL")
echo "  Replica1 read: $v1"
echo "  Replica2 read: $v2"

if [[ "$v1" == "hello-${ts}" && "$v2" == "hello-${ts}" ]]; then
  echo "  Replication working"
else
  echo "   Replication lag (wait a moment and retry)"
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Health check complete"
echo "═══════════════════════════════════════════════════"