# Redis Sentinel — Install from Git (Quick Start)

> **Purpose:** Clone the repo and start the cluster in under 5 minutes.
> **Topology:** 1 Master + 2 Replicas + 3 Sentinels
> **Host:** `x.x.x.236`

---

## Prerequisites

### Docker Engine 20.10+ and Compose v2+

```bash
docker --version          # must be ≥ 20.10
docker compose version    # must be ≥ 2.0
```

If not installed:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

### Ports

| Port | Purpose |
| :--- | :--- |
| `6379` | Redis master |
| `6380` | Redis replica 1 |
| `6381` | Redis replica 2 |
| `26379` | Sentinel 1 |
| `26380` | Sentinel 2 |
| `26381` | Sentinel 3 |

---

## Step 1: Clone Repository

```bash
cd ~/Documents
git clone <your-repo-url>/redis-sentinel.git
cd redis-sentinel
```

**Expected structure:**

```
redis-sentinel/
├── docker-compose.yml
├── .env.example
├── .gitignore
├── Makefile
├── README.md
├── config/
│   ├── redis/
│   │   ├── master.conf
│   │   └── replica.conf
│   └── sentinel/
│       └── sentinel.conf
├── scripts/
│   ├── init.sh
│   ├── health-check.sh
│   └── failover-test.sh
└── docs/
    ├── redis-sentinel.md
    └── redis-sentinel-install.md
```

Verify:

```bash
tree -a
```

---

## Step 2: Configure `.env`

```bash
cp .env.example .env
nano .env
```

**`.env` content:**

```env
REDIS_PASSWORD=ChangeMe_StrongPass2026
SENTINEL_PASSWORD=ChangeMe_Sentinel2026
REDIS_HOST=x.x.x.236
SENTINEL_QUORUM=2
```

### Password rules

| Rule | Reason |
| :--- | :--- |
| Use only `[A-Za-z0-9_]` | `#` acts as comment; `!` triggers shell expansion; `@` breaks YAML |
| Minimum 16 characters | Security |
| **Never** use `! @ # $ % ^ & * ( ) ' " ` ` ~` | Breaks `.env` parsing or shell |

**Bad examples:**

```
REDIS_PASSWORD=123456!@#          # # truncates → password becomes "123456!@"
REDIS_PASSWORD="MyPass"           # quotes become part of password
```

**Good examples:**

```
REDIS_PASSWORD=ChangeMe_StrongPass2026
REDIS_PASSWORD=Redis_Sentinel_Auth_2026
```

---

## Step 3: Make Scripts Executable

```bash
chmod +x scripts/*.sh
```

Verify:

```bash
ls -la scripts/
```

Expected: `-rwxr-xr-x` permissions on all `.sh` files.

---

## Step 4: Firewall (Optional)

Skip if UFW is disabled. Check:

```bash
sudo ufw status
```

If active, open required ports:

```bash
sudo ufw allow 6379:6381/tcp
sudo ufw allow 26379:26381/tcp
sudo ufw reload
sudo ufw status numbered
```

---

## Step 5: Start Cluster

```bash
make up
```

**Or without Make:**

```bash
docker compose up -d
sleep 20
docker compose ps
```

### Expected output

```
✔ Container redis-master     Healthy    6.3s
✔ Container redis-replica-1  Healthy    11.3s
✔ Container redis-replica-2  Healthy    11.3s
✔ Container sentinel-1       Started    11.4s
✔ Container sentinel-2       Started    11.5s
✔ Container sentinel-3       Started    11.5s
 Redis Sentinel Cluster is READY
```

---

## Step 6: Verify

```bash
make test
```

**Or manually:**

```bash
./scripts/health-check.sh
```

### Expected output

```
 Containers:
redis-master      Up (healthy)
redis-replica-1   Up (healthy)
redis-replica-2   Up (healthy)
sentinel-1        Up
sentinel-2        Up
sentinel-3        Up

Replication:
role:master
connected_slaves:2
  Sentinel view: redis-master:6379

  Write/Read Test:
  Master wrote: hello-1792328126
  Replica1 read: hello-1792328126
  Replica2 read: hello-1792328126
Replication working
```

### Manual verification (3 commands)

```bash
# 1. Master sees replicas
docker exec redis-master redis-cli INFO replication | grep -E "role|connected_slaves"

# 2. Sentinel knows current master
docker exec sentinel-1 redis-cli -p 26379 sentinel get-master-addr-by-name mymaster

# 3. Write to master, read from replica
docker exec redis-master redis-cli SET test:key "hello"
docker exec redis-replica-1 redis-cli GET test:key
```

---

## Step 7: Failover Test (Optional)

```bash
make failover
```

**Or manually:**

```bash
docker exec sentinel-1 redis-cli -p 26379 sentinel failover mymaster
sleep 12
docker exec sentinel-1 redis-cli -p 26379 sentinel get-master-addr-by-name mymaster
```

**Expected:** Master port changes from `6379` to `6380` or `6381`.

Verify the old master rejoined as a replica:

```bash
sleep 30
docker exec redis-master redis-cli INFO replication | grep role
# → role:slave  (or role:replica in Redis 7)
```

---

## Daily Commands

```bash
make up              # Start cluster
make down            # Stop cluster
make restart         # Restart all
make ps              # Show status
make logs            # Tail all logs
make test            # Health check
make failover        # Trigger failover
make shell-master    # Interactive redis-cli on master
make shell-sentinel  # Interactive redis-cli on sentinel
make cleanup         # Stop + remove volumes (data loss)
```

### Fresh start

```bash
docker compose down -v
docker compose up -d
sleep 20
docker compose ps
```

---

##  Spring Boot Connection

### `application.yml`

```yaml
spring:
  data:
    redis:
      sentinel:
        master: mymaster
        nodes:
          - x.x.x.236:26379
          - x.x.x.236:26380
          - x.x.x.236:26381
        password: ${REDIS_PASSWORD}
      timeout: 3000ms
      lettuce:
        pool:
          max-active: 16
          max-idle: 8
          min-idle: 2
```

### `build.gradle`

```gradle
implementation 'org.springframework.boot:spring-boot-starter-data-redis'
```

### Environment variable

```bash
export REDIS_PASSWORD=ChangeMe_StrongPass2026
```

Or in K8s, use a Secret:

```bash
kubectl -n demo create secret generic redis-secret \
  --from-literal=password='ChangeMe_StrongPass2026'
```

---

##  Troubleshooting

### 1. Master shows `unhealthy` with `WRONGPASS`

**Diagnose:**

```bash
docker exec redis-master env | grep REDIS
```

If `REDIS_PASSWORD` is empty → env var didn't pass through.

**Fix:**

```bash
# Check .env has no special chars
cat .env

# Check docker-compose.yml has environment block
grep -A3 "environment:" docker-compose.yml | head -5

# Apply config change
docker compose down -v
docker compose up -d
sleep 20
```

### 2. `connected_slaves:0`

Master hasn't accepted replicas yet — wait 10 seconds or check replica logs:

```bash
docker compose logs redis-replica-1 --tail=20
```

### 3. `Sentinel :26379 → N/A`

Sentinels can't resolve `redis-master` hostname.

**Fix:** Ensure `config/sentinel/sentinel.conf` has:

```conf
sentinel resolve-hostnames yes
sentinel announce-hostnames yes
```

### 4. `make cleanup` → `[[: not found`

Makefile uses Bash syntax but `/bin/sh` is Dash.

**Fix:** Add at top of `Makefile`:

```makefile
SHELL := /bin/bash
```

### 5. Config changes not applied

**Golden rule:** after editing `.env`, `docker-compose.yml`, or `config/*`, always:

```bash
docker compose down -v
docker compose up -d
```

`docker compose up` alone **reuses stale containers** — config will not apply.

### 6. Port already in use

```bash
# Check what's using port 6379
sudo ss -tlnp | grep 6379

# Kill the process or change port mapping in docker-compose.yml
```

---

## Security Checklist

- [ ] `.env` is listed in `.gitignore` (never commit passwords)
- [ ] Password uses only `[A-Za-z0-9_]`, ≥ 16 chars
- [ ] Firewall restricts ports to trusted network (`10.70.16.0/21`)
- [ ] `protected-mode no` is fine for Docker network, **not** for public internet
- [ ] For production: enable TLS (`--tls-port`) and ACL users
- [ ] Enable AOF persistence (already configured)
- [ ] Schedule backups (`redis-cli BGSAVE`)

---

## Verification Checklist

| # | Check | Command | Expected |
| :---: | :--- | :--- | :--- |
| 1 | Containers up | `docker compose ps` | 6 containers running |
| 2 | Master healthy | `docker exec redis-master redis-cli ping` | `PONG` |
| 3 | Replicas connected | `docker exec redis-master redis-cli INFO replication \| grep connected_slaves` | `connected_slaves:2` |
| 4 | Sentinel knows master | `docker exec sentinel-1 redis-cli -p 26379 sentinel get-master-addr-by-name mymaster` | `redis-master:6379` |
| 5 | Replication works | Write on master, read on replica | Same value |
| 6 | Failover works | `make failover` | Master port changes |

---

## Quick Recovery

If anything goes wrong:

```bash
cd ~/Documents/redis-sentinel

# 1. Full clean
docker compose down -v
docker ps -a | grep -E 'redis|sentinel'    # should be empty
docker volume ls | grep redis-sentinel     # should be empty

# 2. Verify env
cat .env | grep REDIS_PASSWORD

# 3. Restart
docker compose up -d
sleep 20

# 4. Verify
docker exec redis-master env | grep REDIS
docker exec redis-master redis-cli ping
docker compose ps
```

If still broken, share the output of:

```bash
docker compose logs redis-master --tail=50
docker exec redis-master env | grep REDIS
```

---

## Next Steps

Once the cluster is running:

1. **Test from Spring Boot** — create a minimal `inventory-service` that connects via `spring.data.redis.sentinel`
2. **Verify failover from app** — kill master while app is running, confirm app reconnects
3. **Add Prometheus scrape** — for `redis_up`, `redis_connected_clients`, `redis_memory_used_bytes` metrics
4. **GitOps** — add `redis-sentinel` to ArgoCD applications (or manage via CI/CD)

---

**Reference:** See [`docs/redis-sentinel.md`](redis-sentinel.md) for full architecture, config files, and detailed operations guide.
