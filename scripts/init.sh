#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# ─── 1. Check .env exists ───
if [[ ! -f .env ]]; then
  echo " .env not found."
  echo "   Run: cp .env.example .env && nano .env"
  exit 1
fi

# ─── 2. Load env ───
set -a
source .env
set +a

echo "════════════════════════════════════════════════════"
echo "  Redis Sentinel Cluster — Init"
echo "════════════════════════════════════════════════════"
echo "  Host:      ${REDIS_HOST}"
echo "  Master:    ${REDIS_HOST}:6379"
echo "  Replicas:  ${REDIS_HOST}:6380, ${REDIS_HOST}:6381"
echo "  Sentinels: ${REDIS_HOST}:26379, ${REDIS_HOST}:26380, ${REDIS_HOST}:26381"
echo "════════════════════════════════════════════════════"
echo ""

# ─── 3. Start containers ───
echo " Starting containers..."
docker compose up -d

# ─── 4. Wait for readiness ───
echo ""
echo "⏳ Waiting for containers to be healthy..."
for i in $(seq 1 30); do
  healthy=$(docker compose ps --format json | grep -c '"Health":"healthy"' || true)
  if [[ "$healthy" -ge 3 ]]; then
    echo " All Redis nodes healthy"
    break
  fi
  sleep 2
  echo -n "."
done
echo ""

# ─── 5. Wait for Sentinels to converge ───
echo "⏳ Waiting for sentinels to discover each other (15s)..."
sleep 15

# ─── 6. Run health check ───
echo ""
./scripts/health-check.sh

# ─── 7. Success summary ───
echo ""
echo "════════════════════════════════════════════════════"
echo " Redis Sentinel Cluster is READY"
echo "════════════════════════════════════════════════════"
echo ""
echo "  Spring Boot connection:"
echo "    spring.data.redis.sentinel.master=mymaster"
echo "    spring.data.redis.sentinel.nodes=${REDIS_HOST}:26379,${REDIS_HOST}:26380,${REDIS_HOST}:26381"
echo "    spring.data.redis.sentinel.password=<your-REDIS_PASSWORD>"
echo ""
echo "  Manual tests:"
echo "    docker exec redis-master redis-cli -a \$REDIS_PASSWORD --no-auth-warning SET k v"
echo "    docker exec redis-replica-1 redis-cli -a \$REDIS_PASSWORD --no-auth-warning GET k"
echo ""
echo "  Failover test:"
echo "    make failover"
echo ""