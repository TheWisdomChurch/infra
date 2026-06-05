# WisdomChurch Infrastructure

Production infrastructure for WisdomChurch application using Docker Compose and Traefik reverse proxy.

## Quick Start

```bash
# 1. Setup environment variables and Docker networks
./setup-env.sh

# 2. Start all services
make start

# 3. Check status
make status
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│              Traefik Reverse Proxy              │
│          (wisdomchurchhq.org routing)           │
└──────────┬──────────────────────────┬───────────┘
           │                          │
     ┌─────▼─────┐            ┌──────▼──────┐
     │  Frontend │            │  Admin      │
     │  Next.js  │            │  Next.js    │
     │  :2000    │            │  :3000      │
     └─────┬─────┘            └──────┬──────┘
           │                         │
           │      ┌──────────┐       │
           └─────►│   API    │◄──────┘
                  │   Go/Gin │
                  │  :8080   │
                  └─────┬────┘
                        │
              ┌─────────┼─────────┐
              │         │         │
         ┌────▼──┐  ┌──▼────┐ ┌─▼────┐
         │ Redis │  │  DB   │ │ S3   │
         │ Cache │  │ Postgres│        │
         └───────┘  └────────┘ └──────┘
```

## Services

### Redis
- **Container**: wisdom_redis
- **Port**: Internal (6379)
- **Purpose**: Session store, caching, job queue
- **Health Check**: Redis PING response
- **Memory**: 256MB max, 128MB reserved

### API (Go/Gin)
- **Container**: wisdom_api
- **Port**: 8080 (internal)
- **Image**: `ghcr.io/thewisdomchurch/wisdom-api:${API_TAG}`
- **Dependencies**: Redis (healthy) + Database migration
- **Health Check**: TCP port check
- **Database**: PostgreSQL (Supabase)

### Frontend (Next.js)
- **Container**: wisdom_frontend
- **Port**: 2000 (internal)
- **Image**: `ghcr.io/thewisdomchurch/wisdom-frontend:${FRONTEND_TAG}`
- **Depends On**: API service healthy
- **Environment**: `NODE_ENV=production`

### Admin (Next.js)
- **Container**: wisdom_admin
- **Port**: 3000 (internal)
- **Image**: `ghcr.io/thewisdomchurch/wisdom-admin:${ADMIN_TAG}`
- **Depends On**: API service healthy
- **Environment**: `NODE_ENV=production`

## Configuration

### Environment Variables (.env.prod)

**Critical Variables** (must be set):
```bash
API_TAG=main                    # Docker image tag
REDIS_PASSWORD=<secure-pass>    # Redis authentication
DATABASE_URL=postgresql://...   # PostgreSQL connection
JWT_SECRET=<64-char-secret>     # JWT signing key
```

**Domain Configuration**:
```bash
FRONTEND_DOMAIN=wisdomchurchhq.org
ADMIN_DOMAIN=admin.wisdomchurchhq.org
API_DOMAIN=api.wisdomchurchhq.org
```

**Port Configuration** (internal):
```bash
FRONTEND_PORT=2000
ADMIN_PORT=3000
API_PORT=8080
```

### Setup Process

1. **Environment Setup**:
   ```bash
   ./setup-env.sh
   ```
   This script:
   - Generates missing secure credentials (REDIS_PASSWORD, JWT_SECRET)
   - Creates `.env` symlink to `.env.prod`
   - Sets up `traefik-public` Docker network
   - Validates docker-compose configuration

2. **Network Requirements**:
   - `traefik-public`: External network for Traefik reverse proxy routing
   - `internal`: Internal bridge network for service-to-service communication

3. **Volume Management**:
   - `redis_data`: Redis persistent storage

## Usage

### Start Services
```bash
make start
# or
./start.sh start
```

### View Logs
```bash
# All services
make logs

# Specific service
make logs-api
make logs-frontend
make logs-admin
make logs-redis
```

### Check Status
```bash
# Service containers status
make status

# Service health checks
make health
```

### Stop Services
```bash
make stop
```

### Restart Services
```bash
make restart
```

### Access Services

Once services are running:

| Service | URL | Port |
|---------|-----|------|
| Frontend | https://wisdomchurchhq.org | 443 (HTTPS) |
| Admin | https://admin.wisdomchurchhq.org | 443 (HTTPS) |
| API | https://api.wisdomchurchhq.org | 443 (HTTPS) |

**Note**: HTTPS is handled by Traefik reverse proxy with Let's Encrypt SSL certificates.

## Troubleshooting

### Services Won't Start

1. **Check environment variables**:
   ```bash
   grep -E "^(API_TAG|REDIS_PASSWORD|DATABASE_URL)" .env.prod
   ```

2. **Validate configuration**:
   ```bash
   make validate
   ```

3. **Check Docker network**:
   ```bash
   docker network inspect traefik-public
   ```

4. **View detailed logs**:
   ```bash
   docker compose -f docker-compose-prod.yml logs -f
   ```

### Health Check Failures

```bash
# Check service health
make health

# For specific service
docker inspect wisdom_api --format='{{.State.Health.Status}}'
```

### Database Migration Failures

The `migrate` service runs once at startup. Check logs:
```bash
docker compose logs migrate
```

### Redis Connection Issues

```bash
# Test Redis connection
docker exec wisdom_redis redis-cli ping

# With password
docker exec wisdom_redis redis-cli -a "$REDIS_PASSWORD" ping
```

## Development vs Production

### Development
- Services run in foreground
- Live logs visible
- Hot reloading enabled (where applicable)
- Use `docker compose` from project root

### Production
- Services run in background (`-d` flag)
- Logging to docker daemon
- Traefik handles SSL/TLS
- Health checks ensure availability
- Restart policies handle recovery

## Maintenance

### Updating Images

```bash
# Pull latest images
make pull

# Restart with new images
make restart
```

### Cleaning Up

```bash
# Remove all containers and volumes (destructive!)
make clean
```

### Backup Strategy

**Redis Data**:
- Stored in Docker volume `redis_data`
- Backup location: `/var/lib/docker/volumes/wisdomchurch_redis_data/_data/`

**Database**:
- Managed by external PostgreSQL (Supabase)
- Backup handled by Supabase

## Performance Tuning

### Memory Limits
- Redis: 256MB max (128MB reserved)
- API: 512MB max (128MB reserved)
- Frontend: 512MB max (128MB reserved)
- Admin: 384MB max (128MB reserved)

### Connection Pooling
- Redis pool size: 10
- Min idle connections: 5

### Timeouts
- Redis dial timeout: 5s
- Redis read timeout: 3s
- Redis write timeout: 3s

## Security Considerations

1. **Environment Variables**:
   - `.env.prod` contains sensitive data
   - Keep file permissions tight (600)
   - Never commit to Git

2. **Network Isolation**:
   - Internal network isolated from external
   - Only Traefik exposed to public

3. **Database**:
   - Connection string stored in environment
   - SSL required for connections
   - Managed user with restricted permissions

4. **Secrets**:
   - JWT secrets 64+ characters
   - Redis password 32+ characters
   - Rotated regularly

## CI/CD Integration

Services should be deployed via:
1. Build container images (in main project repos)
2. Push to GHCR (GitHub Container Registry)
3. Update image tags in `.env.prod`
4. Restart services: `make restart`

## Docker Compose Files

- **docker-compose-prod.yml**: Main production configuration
- **docker-compose-maintenance.yml**: Maintenance mode routing (overlay)

## External Dependencies

- **Database**: PostgreSQL on Supabase
- **Docker Registry**: GHCR (GitHub Container Registry)
- **DNS**: Your domain registrar
- **Reverse Proxy**: Traefik (managed by this compose file)
- **SSL/TLS**: Let's Encrypt (via Traefik)

## Support & Debugging

For issues, check:
1. `.env.prod` configuration
2. Docker logs: `docker compose logs`
3. Service health: `make health`
4. Network connectivity: `docker network inspect traefik-public`
5. Volume mounts: `docker volume ls`
