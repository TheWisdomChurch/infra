# WisdomChurch Infrastructure - Quick Start

## TL;DR - Get Running in 3 Commands

```bash
cd /root/Tech_projects_000/Frontend/infra/prod

# 1. Setup (generates secrets, creates network)
./setup-env.sh

# 2. Start all services
make start

# 3. Check status (wait until all show healthy)
make health
```

## Essential Commands

| Task | Command |
|------|---------|
| Setup | `./setup-env.sh` |
| Start | `make start` |
| Stop | `make stop` |
| Status | `make status` |
| Health | `make health` |
| Logs | `make logs` |
| Restart | `make restart` |
| Cleanup | `make clean` |

## View Logs

```bash
make logs              # All services
make logs-api         # API only
make logs-frontend    # Frontend only
make logs-admin       # Admin only
make logs-redis       # Redis only
```

## Access Services

Once healthy:
- Frontend: https://wisdomchurchhq.org
- Admin: https://admin.wisdomchurchhq.org
- API: https://api.wisdomchurchhq.org/health

## Troubleshoot

```bash
# Check service status
make status

# Check health
make health

# Check logs for errors
make logs

# Validate configuration
make validate

# Restart all services
make restart
```

## Environment

- **File**: `.env.prod` (never commit!)
- **Setup**: Run `./setup-env.sh` to generate secrets
- **Backup**: Keep a copy of .env.prod in secure storage

## Common Issues

**404 Errors**:
1. Check `make health` - all services must be healthy
2. Wait 30-60s for startup
3. Check logs: `make logs`

**Services won't start**:
1. Run `make validate`
2. Check environment: `grep REDIS_PASSWORD .env.prod`
3. Check Docker: `docker ps`

**Slow startup**:
- First start pulls images (5-10 min)
- Subsequent starts are faster
- Watch logs: `make logs`

## Files in This Directory

| File | Purpose |
|------|---------|
| `docker-compose-prod.yml` | Main service configuration |
| `docker-compose-maintenance.yml` | Maintenance mode overlay |
| `.env.prod` | Environment variables (secret!) |
| `.env.example` | Template for env vars |
| `Makefile` | Easy command shortcuts |
| `start.sh` | Advanced startup script |
| `setup-env.sh` | One-time setup script |
| `README.md` | Full architecture documentation |
| `DEPLOYMENT.md` | Detailed deployment guide |

## Next Steps

1. Edit `.env.prod` if needed (domains, API keys, etc.)
2. Run `./setup-env.sh`
3. Run `make start`
4. Monitor with `make logs`
5. Check `make health` until all services healthy
6. Access your domains in browser

## Need Help?

- Full docs: `README.md`
- Deployment guide: `DEPLOYMENT.md`
- Make help: `make help`
- Script help: `./start.sh help`
- Script help (setup): `./setup-env.sh --help`
