# WisdomChurch — Production Infrastructure

Docker Compose stack for `api`, `frontend`, `admin`, and `redis`, routed
through an externally-managed Traefik instance on the `traefik-public`
network. All day-to-day operations go through the `Makefile` in this
directory — run `make help` on the server to see every target.

## Setup

Copy `.env.example` to `.env.prod` and fill in real values. `.env.prod` is
git-ignored — never commit it, and `git pull` will never touch it.

## Deploying a new release

```
make deploy
```

One command, in this order:

1. `git pull --ff-only` this infra checkout (fails rather than clobbering
   local changes if the server has diverged).
2. Puts the branded maintenance page up.
3. Pulls the latest `api`/`frontend`/`admin` images.
4. Runs `migrate` to completion — the pipeline stops here if migrations
   fail, so nothing is ever rolled out against an unmigrated schema.
5. Rolls out `redis`, `api`, `frontend`, `admin`.
6. Waits (up to 180s) for all three app containers to report `healthy`.
7. Only once they're healthy: takes the maintenance page back down.
8. Prunes dangling images left behind by the old deploy.

**If any step fails, the pipeline stops immediately and the maintenance
page stays up.** Visitors never see a crash or a bare 404 — worst case
they see "under maintenance" until you fix the problem and re-run
`make deploy`. Check what went wrong with `make logs` or `make ps`.

## Maintenance page

```
make maintenance-on       # show the branded maintenance page
make maintenance-off      # restore normal routing
make maintenance-status   # check whether it's currently active
```

The maintenance page (`docker-compose-maintenance.yml`) is a standalone
nginx container with its own Traefik routers registered at priority 1000
— higher than the normal `wisdom-frontend`/`wisdom-admin`/`wisdom-api`
routers. While it's running, it wins routing for all three domains
regardless of whether `frontend`/`admin`/`api` are healthy, starting, or
stopped outright. It returns HTTP 503 with a `Retry-After` header, not a
bare 200 or a stray 404.

Page content lives in `maintenance/html/index.html`; edit it directly to
change the message or branding.

## Other targets

```
make up                   # start/recreate redis, api, frontend, admin (no pull, no migrate)
make down                 # stop the stack (volumes are untouched)
make pull                 # pull latest images only
make migrate              # run migrations only
make ps                   # container status
make logs                 # tail logs for the whole stack
make clean                # remove dangling images from old deploys
```

`make clean` only ever removes this project's dangling images. It
deliberately never runs a host-wide `docker system prune` or
`docker volume prune` — this host also runs Traefik with its Let's
Encrypt certificate storage, and a blanket prune could take that out.
`redis_data` and the `traefik-public` network are never touched by any
target here either.
