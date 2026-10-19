.PHONY: help up down restart ps logs test failover cleanup shell-master shell-sentinel

help:
	@echo "════════════════════════════════════════════"
	@echo "  Redis Sentinel Cluster — Commands"
	@echo "════════════════════════════════════════════"
	@echo "  make up              Start cluster"
	@echo "  make down            Stop cluster"
	@echo "  make restart         Restart all"
	@echo "  make ps              Show status"
	@echo "  make logs            Tail all logs"
	@echo "  make test            Health check"
	@echo "  make failover        Trigger failover"
	@echo "  make shell-master    Redis-cli on master"
	@echo "  make shell-sentinel  Redis-cli on sentinel"
	@echo "  make cleanup         Stop + remove volumes"
	@echo "════════════════════════════════════════════"

up:
	@./scripts/init.sh

down:
	docker compose down

restart:
	docker compose restart

ps:
	docker compose ps

logs:
	docker compose logs -f --tail=100

test:
	@./scripts/health-check.sh

failover:
	@./scripts/failover-test.sh

shell-master:
	@set -a; source .env; set +a; \
	docker exec -it redis-master redis-cli -a $$REDIS_PASSWORD --no-auth-warning

shell-sentinel:
	docker exec -it sentinel-1 redis-cli -p 26379

cleanup:
	@read -p "  This deletes ALL Redis data. Continue? [y/N] " ans; \
	[[ "$$ans" == "y" ]] && docker compose down -v || echo "Aborted."