# WisdomChurch Infrastructure - Deployment Guide

## Current Status

✅ **Infrastructure as Code**: Fully configured
✅ **Environment Management**: Automated setup
✅ **Service Configuration**: Docker Compose ready
✅ **Reverse Proxy**: Traefik configured
✅ **Health Checks**: Implemented for all services

## Pre-Deployment Checklist

### Prerequisites
- [ ] Docker daemon running and accessible
- [ ] Docker Compose v2.x or higher
- [ ] OpenSSL or Python3 (for secret generation)
- [ ] Traefik network: `traefik-public` (auto-created)
- [ ] Domain DNS records pointing to server

### Environment Requirements

1. **Database Connection**
   ```bash
   # Verify DATABASE_URL in .env.prod
   grep "DATABASE_URL=" .env.prod
   
   # Test connection
   psql "$(grep DATABASE_URL .env.prod | cut -d= -f2-)"
   ```

2. **Redis Configuration**
   ```bash
   # Check Redis password is set
   grep "REDIS_PASSWORD=" .env.prod
   # Should show: REDIS_PASSWORD=<value> (not empty)
   ```

3. **Docker Registry Authentication**
   ```bash
   # For GitHub Container Registry (GHCR)
   echo $PAT_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

4. **Domain/DNS Setup**
   ```bash
   # Verify DNS records are set for:
   # - wisdomchurchhq.org → your-server-ip
   # - admin.wisdomchurchhq.org → your-server-ip
   # - api.wisdomchurchhq.org → your-server-ip
   
   nslookup wisdomchurchhq.org
   nslookup admin.wisdomchurchhq.org
   nslookup api.wisdomchurchhq.org
   ```

## Step 1: Initial Setup

```bash
# Navigate to infrastructure directory
cd /root/Tech_projects_000/Frontend/infra/prod

# Run setup script to generate secrets and validate
./setup-env.sh

# Output should show:
# ✓ Generated REDIS_PASSWORD (if needed)
# ✓ traefik-public network exists
# ✓ Configuration is valid
```

### What setup-env.sh Does:
1. Generates secure credentials for missing variables
2. Creates `.env` symlink to `.env.prod`
3. Creates `traefik-public` Docker network
4. Validates entire docker-compose configuration

## Step 2: Review Configuration

```bash
# Review your environment variables
cat .env.prod | grep -E "^(DOMAIN|TAG|PASSWORD|URL)" | sort

# Expected output should show all critical values are set:
API_DOMAIN=api.wisdomchurchhq.org
API_TAG=main
ADMIN_DOMAIN=admin.wisdomchurchhq.org
# ... (etc)
```

## Step 3: Start Services

```bash
# Option A: Using Make
make start

# Option B: Using shell script
./start.sh start

# Option C: Manual Docker Compose
docker compose -f docker-compose-prod.yml up -d
```

### Startup Sequence:
1. **Redis** starts first (initialization)
2. **Database Migration** runs (one-time schema update)
3. **API** waits for Redis healthy + Migration complete
4. **Frontend & Admin** wait for API healthy
5. All services register with Traefik

### Expected Output:
```
Starting services...
Pulling latest images...
Starting services...

Waiting for services to be healthy...

Service Status:
NAME              IMAGE                                       STATUS
wisdom_redis      redis:7-alpine                             Up 3s (healthy)
wisdom_migrate    ghcr.io/thewisdomchurch/wisdom-api:main   Exited (0)
wisdom_api        ghcr.io/thewisdomchurch/wisdom-api:main   Up 2s (starting)
wisdom_frontend   ghcr.io/thewisdomchurch/wisdom-frontend   Up 1s (starting)
wisdom_admin      ghcr.io/thewisdomchurch/wisdom-admin      Up 1s (starting)

✓ Services started! Check logs with: make logs
```

## Step 4: Verify Services

```bash
# Check all services are running
make status

# Check service health
make health

# Expected: All services should show "Up" status
# Health checks may show "starting" initially, will move to "healthy"
```

## Step 5: Test Access

Once all services show healthy status:

```bash
# Test API health endpoint
curl -k https://api.wisdomchurchhq.org/health

# Expected response:
# {"status":"ok","timestamp":"2026-06-05T12:00:00Z"}

# Test Frontend (should redirect or show 200)
curl -I https://wisdomchurchhq.org

# Test Admin
curl -I https://admin.wisdomchurchhq.org
```

## Troubleshooting Deployment

### Issue: Services won't start

**Check Docker daemon**:
```bash
docker ps
# If this fails, Docker daemon is not running
docker system prune  # Clean up and restart if needed
```

**Check configuration**:
```bash
make validate
# Should show: ✓ Configuration is valid
```

**Check environment**:
```bash
# Missing critical variables?
grep "^REDIS_PASSWORD=" .env.prod
# Should NOT be empty

grep "^API_TAG=" .env.prod
# Should be: API_TAG=main
```

### Issue: Services start but won't become healthy

**Check logs**:
```bash
make logs-api
# Look for error messages about database connection, Redis, etc.

make logs-redis
# Check if Redis initialized properly

make logs migrate
# Check if database migration succeeded
```

**Common problems**:
- DATABASE_URL invalid or database unreachable
- REDIS_PASSWORD mismatch
- API_TAG image doesn't exist in registry
- Network connectivity issues

### Issue: 404 errors when accessing service

**Check Traefik routing**:
```bash
# Verify DNS is resolving
nslookup api.wisdomchurchhq.org

# Check if Traefik is running
docker ps | grep traefik
# Note: Traefik should be running separately (not in this compose file)

# Verify service is exposed on traefik-public network
docker inspect wisdom_api | grep -A5 Networks
```

**Check service is listening**:
```bash
# Test API internally
docker exec wisdom_api curl http://127.0.0.1:8080/health

# Test Frontend
docker exec wisdom_frontend curl http://127.0.0.1:2000
```

### Issue: Database migration fails

```bash
# Check migration container logs
docker compose -f docker-compose-prod.yml logs migrate

# Common causes:
# 1. DATABASE_URL is invalid
# 2. Database server unreachable
# 3. User doesn't have permission to create tables
# 4. Network connectivity issue

# Fix and retry:
make restart
```

## Post-Deployment

### Monitoring

```bash
# Watch logs in real-time
make logs

# Or for specific service
make logs-api

# Press Ctrl+C to exit
```

### Health Checks

Services have built-in health checks:
- **Redis**: PING every 10s
- **API**: TCP port check every 15s
- **Frontend**: HTTP status check every 15s
- **Admin**: HTTP status check every 15s

Failed health checks trigger service restart via Docker restart policy.

### Updating Services

```bash
# Pull latest images
make pull

# Restart to use new images
make restart

# Or update specific service
docker compose -f docker-compose-prod.yml pull api
docker compose -f docker-compose-prod.yml up -d api
```

### Maintenance Mode

For maintenance, use the maintenance compose file overlay:

```bash
# Enable maintenance mode
docker compose -f docker-compose-prod.yml -f docker-compose-maintenance.yml up -d

# This routes all traffic to maintenance pages
# Check docker-compose-maintenance.yml for details
```

### Backup Strategy

**Redis Data**:
```bash
# Backup Redis data
docker exec wisdom_redis redis-cli --rdb /data/dump-$(date +%s).rdb

# Restore from backup
docker cp dump.rdb wisdom_redis:/data/dump.rdb
docker exec wisdom_redis redis-cli BGSAVE
```

**Database**:
```bash
# Backup PostgreSQL (Supabase)
# Use Supabase dashboard or:
pg_dump "$DATABASE_URL" > backup.sql

# Restore
psql "$DATABASE_URL" < backup.sql
```

## Security Checklist

- [ ] REDIS_PASSWORD is strong (generated or set)
- [ ] JWT_SECRET is strong (64+ characters)
- [ ] AUTH_SECRET_KEY is strong (64+ characters)
- [ ] DATABASE_URL uses SSL (sslmode=require)
- [ ] .env.prod file permissions: 600 (read-write only)
- [ ] Never commit .env.prod to Git
- [ ] Use .env.example for templates
- [ ] Rotate secrets regularly
- [ ] Enable 2FA on GHCR and other registries

## Scaling Considerations

For production deployments, consider:

1. **Load Balancing**: Use Traefik with multiple API instances
2. **Redis Cluster**: For high availability
3. **Database Replication**: Supabase handles this
4. **Container Orchestration**: Move to Kubernetes for enterprise
5. **Monitoring**: Add Prometheus/Grafana
6. **Log Aggregation**: ELK Stack or CloudWatch

## Support

For issues:
1. Check logs: `make logs`
2. Verify configuration: `make validate`
3. Check health: `make health`
4. Review README.md for architecture overview
5. Check individual service containers: `docker inspect <container>`

## Next Steps

1. ✅ Run `./setup-env.sh`
2. ✅ Run `make start`
3. ✅ Run `make health` until all services are healthy
4. ✅ Test `curl https://api.wisdomchurchhq.org/health`
5. ✅ Access https://wisdomchurchhq.org in browser
6. ✅ Access https://admin.wisdomchurchhq.org in browser

---

**Last Updated**: 2026-06-05
**Infrastructure**: Docker Compose + Traefik
**Status**: Production Ready
