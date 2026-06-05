# Database Setup Guide

## Issue: Database Migration Failing

The migration container is failing to connect to your Supabase PostgreSQL database.

## Troubleshooting

### 1. Verify Database Credentials

```bash
# Check your DATABASE_URL
grep "DATABASE_URL=" .env.prod

# Should look like:
# DATABASE_URL=postgresql://username:password@host:5432/dbname?sslmode=require
```

### 2. Test Connection from Your Machine

```bash
# Extract the connection string
DB_URL=$(grep "^DATABASE_URL=" .env.prod | cut -d= -f2-)

# Test if you can connect (requires psql installed)
psql "$DB_URL" -c "SELECT version();"

# If successful, you'll see PostgreSQL version
# If failed, check:
# - Credentials are correct
# - IP whitelist includes your server IP
# - Database server is accessible
```

### 3. Check Supabase Configuration

If using Supabase:
1. Go to https://app.supabase.com/
2. Select your project
3. Go to **Settings > Database**
4. Verify credentials match DATABASE_URL
5. Check **Network > Firewall** - add your server's IP

### 4. Quick Fix: Skip Migration on First Run

If the database already has your schema, you can skip the migration:

```bash
# Create a docker-compose override to skip migration
docker compose -f docker-compose-prod.yml up -d --no-deps redis api frontend admin

# This starts services without waiting for migration
# (Only works if database schema is already set up)
```

### 5. Manual Migration

```bash
# Run migration container independently
docker compose -f docker-compose-prod.yml run --rm migrate

# Watch the output for errors
# Once successful, start remaining services:
docker compose -f docker-compose-prod.yml up -d api frontend admin
```

## If Migration Keeps Failing

**Option A: Disable Migration (Temporary)**

Edit `.env.prod` and change the migrate service restart:
```yaml
# In docker-compose-prod.yml, change:
restart: "no"     # Change to:
restart: "on-failure:3"
```

**Option B: Setup Database Manually**

1. Connect directly to Supabase
2. Run the schema file manually from project repository
3. Then start services without migration

**Option C: Check Container Logs**

```bash
# View detailed migration error
docker compose -f docker-compose-prod.yml logs -f migrate

# Common errors:
# - "connection refused" → Database unreachable
# - "permission denied" → User lacks privileges  
# - "does not exist" → Wrong database name
```

## Connection String Format

Your Supabase connection string should be:
```
postgresql://[user]:[password]@[host]:5432/[database]?sslmode=require&prefer_simple_protocol=true
```

Parts:
- **user**: Usually `postgres` (from Supabase dashboard)
- **password**: From Supabase Settings > Database > Password
- **host**: From Supabase Settings > Database > Host (usually contains `pooler.supabase.com`)
- **database**: Usually `postgres`

## Getting Connection String from Supabase

1. Go to your Supabase project
2. Click **Settings** (gear icon)
3. Click **Database**
4. Look for **Connection string**
5. Copy the **PostgreSQL** one
6. Update DATABASE_URL and MIGRATIONS_DATABASE_URL in `.env.prod`

## Verify Setup Works

Once database connects:

```bash
# Restart services
make restart

# Check logs
make logs

# All services should start successfully
make health
```

## Next Steps

1. Fix your DATABASE_URL in `.env.prod`
2. Test connection: `psql "$DB_URL" -c "SELECT 1;"`
3. Restart services: `make restart`
4. Monitor: `make logs`
5. Check health: `make health`
