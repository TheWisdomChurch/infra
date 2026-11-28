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

## Application email delivery

The API is the only service that should send application email. Its default
primary provider is Mailcow. Configure `APP_SMTP_HOST` to the Mailcow server's
public mail FQDN, `APP_SMTP_PORT=587`, and `APP_SMTP_TLS=true`. Port 587 uses
SMTP submission with STARTTLS; the certificate presented by Mailcow must be
valid for that FQDN. Use a dedicated Mailcow mailbox and set
`APP_SMTP_USERNAME` and `APP_SMTP_PASSWORD`. Set `BREVO_API_KEY`,
`BREVO_FROM_EMAIL`, and `BREVO_FROM_NAME` to enable Brevo as the fallback.
`EMAIL_PRIMARY_PROVIDER=brevo` supports a planned provider switch. Do not add
the application host to Mailcow's unauthenticated relay networks: an incorrect
`mynetworks` entry can create an open relay. Mailcow documents submission on
587 and warns about the risks of unauthenticated relaying
([ports](https://docs.mailcow.email/getstarted/prerequisite-system/),
[unauthenticated relaying](https://docs.mailcow.email/manual-guides/Postfix/u_e-postfix-unauthenticated-relaying/)).

Mailcow must have working outbound TCP/25, a stable public IP with matching
PTR/rDNS and forward DNS, and published SPF, DKIM, and DMARC records for the
sender domain. Publish Mailcow's generated DKIM key exactly as shown in its
admin UI. Keep the sender domain aligned with SPF or DKIM for DMARC. Also
check the receiving provider's reputation and bounce reports before increasing
volume. SMTP acceptance means queued for delivery, not guaranteed inbox
placement.

### Verify the deployed route

From the production host, first check the Mailcow submission endpoint and
certificate (replace the example FQDN):

```sh
openssl s_client -starttls smtp -connect mail.wisdomchurchhq.org:587 \
  -servername mail.wisdomchurchhq.org -verify_return_error
```

Then send a controlled message through the application's real email flow to a
mailbox you control. Confirm the API logs report a successful SMTP submission,
Mailcow's Postfix logs show the queue ID and remote delivery, and the message
arrives with SPF, DKIM, and DMARC passing in its headers. Test the account
recovery/OTP flow from the admin portal as well as any other email action
exposed there. Never use real member addresses for a delivery test.

### Brevo fallback behavior

The API attempts Brevo only when Mailcow definitively rejects a message or
fails before submission, such as a connection or authentication failure. It
does not switch providers after a network failure during submission or an
ambiguous server error, because the first provider may already have accepted
the message. In that case the API returns an error to the existing retry path
instead of risking duplicate delivery. When both providers reject the message,
the API error retains both provider errors. Provider credentials and message
bodies are not added to delivery logs.

The admin portal's existing send and campaign flows use the API's shared mail
service, so they inherit this routing without provider-specific UI changes.
The portal does not currently expose live provider health or fallback
diagnostics; use the API and Mailcow logs when investigating delivery failures.

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
