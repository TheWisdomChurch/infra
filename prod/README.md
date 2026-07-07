# WisdomChurch — Production Infrastructure

Docker Compose stack for `api`, `frontend`, `admin`, and `redis`, routed
through an externally-managed Traefik instance on the `traefik-public`
network.

## Setup

Copy `.env.example` to `.env.prod` and fill in real values. `.env.prod` is
git-ignored — never commit it.

## Deploying a new release

```
./scripts/deploy.sh
```

Pulls the latest `api`/`frontend`/`admin` images, runs `migrate` to
completion (the deploy aborts if migrations fail — nothing is rolled out
against an unmigrated schema), then rolls out `redis`, `api`, `frontend`,
and `admin`.

## Maintenance page

```
./scripts/maintenance.sh on      # show the branded maintenance page
./scripts/maintenance.sh off     # restore normal routing
./scripts/maintenance.sh status  # check whether it's currently active
```

The maintenance page (`docker-compose-maintenance.yml`) is a standalone
nginx container with its own Traefik routers registered at priority 1000
— higher than the normal `wisdom-frontend`/`wisdom-admin`/`wisdom-api`
routers. While it's running, it wins routing for all three domains
regardless of whether `frontend`/`admin`/`api` are healthy, starting, or
stopped outright, so it's safe to enable before a risky deploy or an
outage. It returns HTTP 503 with a `Retry-After` header, not a bare 200/404.

Page content lives in `maintenance/html/index.html`; edit it directly to
change the message or branding.

## Manual commands

```
docker compose -f docker-compose-prod.yml --env-file .env.prod up -d
docker compose -f docker-compose-prod.yml --env-file .env.prod logs -f api
docker compose -f docker-compose-prod.yml --env-file .env.prod ps
```
