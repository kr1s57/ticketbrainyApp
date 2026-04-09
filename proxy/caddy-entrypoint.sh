#!/bin/sh
# v1.10.11 — Caddy entrypoint wrapper that widens perms on public cert
# files so the web container (uid 1001 `nextjs`) can read them through
# the read-only `caddy-data:/data/caddy` mount in Settings → Security.
#
# Caddy writes every file it creates in 600 mode (`-rw-------` root:root)
# and every directory in 700. That blocks any non-root reader, including
# our web container — `listCaddyCerts()` hit `Permission denied` on
# `/data/caddy/caddy/certificates/...` and the UI rendered a misleading
# "No Caddy certificates detected" even when a Let's Encrypt cert was
# live.
#
# We ONLY widen the PUBLIC certificates:
#   - directories under /data/caddy/certificates get `o+rx` so readdir
#     works from the web container,
#   - `*.crt` files get `o+r`,
#   - `*.key` (PRIVATE KEYS) and `*.json` metadata stay in 600.
#
# The private keys are NEVER exposed outside the caddy container.
#
# Caddy renews certs in the background and re-writes them in 600, so
# we run the chmod sweep every 60s in a background loop.

widen_cert_perms() {
    [ -d /data/caddy/certificates ] || return 0
    # Directory traversal: r+x for "others" so the web container can
    # enter and readdir. Using + form of -exec for efficiency.
    find /data/caddy/certificates -type d -exec chmod o+rx {} + 2>/dev/null || true
    # Public certificates only. Keys and metadata stay 600.
    find /data/caddy/certificates -type f -name '*.crt' -exec chmod o+r {} + 2>/dev/null || true
}

# Initial sweep (sync) so the first save after boot already shows the
# cert, then start a background loop to keep up with renewals.
widen_cert_perms
(
    while true; do
        sleep 60
        widen_cert_perms
    done
) &

# Hand off to Caddy's default run command. Matches the upstream
# `caddy:2-alpine` base image CMD:
#   CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
