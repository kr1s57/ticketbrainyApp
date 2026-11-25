#!/usr/bin/env bash
# TicketBrainy — installs the host-side update service (run once, as root).
#
#   sudo ./scripts/install-updater.sh
#
# What it does (idempotent, safe to re-run):
#   0. refuses if a required host tool is missing or if this is not a
#      published install (no pinned ghcr.io web image in docker-compose.yml);
#   1. moves a SearXNG secret_key edited into searxng/settings.yml to
#      SEARXNG_SECRET in .env and restores the tracked file (generates a key
#      if none exists), so `git pull` is never blocked by it;
#   2. refuses to go on if docker-compose.yml has local modifications (they
#      belong in docker-compose.override.yml);
#   3. creates the exchange folder (updater/ root:root 0755, updater/requests/
#      owned by the web container's uid 1001, 0700) and the systemd units
#      that run scripts/tb-updater.sh when the web app drops
#      updater/requests/request; a leftover request is removed first, so
#      that installing never triggers an update;
#   4. creates updater-backups/ (root:root 0700), where tb-updater.sh writes
#      a database export before every update; it is NOT under updater/, so
#      no container ever sees the exports.
#
# No container gets the Docker socket or write access to this folder: the
# web container can only create a file in updater/requests/, whose content
# the host never reads.
#
# Test-only environment: TB_DIR, TB_SYSTEMD_DIR, TB_SYSTEMCTL,
# TB_SKIP_ROOT_CHECK=1, TB_SYSTEMD_RUNDIR.
set -uo pipefail
umask 022

SYSTEMD_DIR="${TB_SYSTEMD_DIR:-/etc/systemd/system}"
SYSTEMCTL="${TB_SYSTEMCTL:-systemctl}"
SYSTEMD_RUNDIR="${TB_SYSTEMD_RUNDIR:-/run/systemd/system}"
WEB_UID=1001
UNIT=ticketbrainy-updater
DEFAULT_SEARXNG_KEY="tb-rag-searxng-replace-on-deploy"

info() { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# ── 1. Preconditions ──────────────────────────────────────────────────────
if [ "${TB_SKIP_ROOT_CHECK:-}" != 1 ] && [ "$(id -u)" -ne 0 ]; then
  die "run as root: sudo $0"
fi
if [ ! -d "$SYSTEMD_RUNDIR" ]; then
  warn "systemd is not running on this host: the in-app update service is NOT installed."
  warn "Updates keep working from the command line (git pull && docker compose pull && docker compose up -d)."
  exit 0
fi

# Host tools used here and by scripts/tb-updater.sh.
missing=()
for tool in git flock timeout curl docker gzip; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [ "${#missing[@]}" -gt 0 ]; then
  die "required command(s) not found on this host: ${missing[*]} (install them, then re-run)"
fi
unset missing tool

TB_DIR="${TB_DIR:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
TB_DIR="$(cd "$TB_DIR" 2>/dev/null && pwd -P)" || die "install directory not found"
# The path is written verbatim into unit files: spaces, quotes or '%'
# (systemd specifiers) would change their meaning.
[[ "$TB_DIR" =~ ^/[A-Za-z0-9._/-]+$ ]] \
  || die "unsupported install path '$TB_DIR' (allowed: letters, digits, . _ - /)"
cd -- "$TB_DIR" || die "cannot enter $TB_DIR"

git_() { git -c safe.directory="$TB_DIR" -C "$TB_DIR" "$@"; }
git_ rev-parse --git-dir >/dev/null 2>&1 || die "$TB_DIR is not a git checkout"
[ -f "$TB_DIR/scripts/tb-updater.sh" ] || die "scripts/tb-updater.sh is missing (run git pull first)"
# Only a published install pins the web image: never install the service on
# a development checkout (an update would pull its branch and restart it).
grep -q 'ghcr\.io/kr1s57/ticketbrainy-web:' "$TB_DIR/docker-compose.yml" 2>/dev/null \
  || die "ce dossier n'est pas une installation TicketBrainy publiée (no pinned ghcr.io/kr1s57/ticketbrainy-web image in docker-compose.yml)"

SETTINGS=searxng/settings.yml
ENV_FILE="$TB_DIR/.env"
[ -L "$ENV_FILE" ] && die ".env is a symbolic link; refusing to edit it"
BACKUPS="${TB_DIR:?}/updater-backups"
if [ -L "$BACKUPS" ] || { [ -e "$BACKUPS" ] && [ ! -d "$BACKUPS" ]; }; then
  die "$BACKUPS is not a directory (symbolic link?); refusing to continue"
fi

# ── 2. Read-only checks first: nothing is changed if one of them fails ────
# Prints the diff of a tracked file vs HEAD with secret_key values masked.
masked_diff() {
  git_ --no-pager diff --no-color --no-ext-diff HEAD -- "$1" \
    | sed -E 's/^([+-][[:space:]]*secret_key:).*/\1 <hidden>/'
}

if ! git_ diff --quiet HEAD -- docker-compose.yml; then
  info "docker-compose.yml has local modifications:"
  info ""
  masked_diff docker-compose.yml
  info ""
  info "Local settings must not live in docker-compose.yml: updates replace it."
  info "Move these lines to docker-compose.override.yml (read automatically by"
  info "Docker Compose, ignored by git), or drop them, then re-run this script."
  exit 1
fi

migrate_key=""
if ! git_ diff --quiet HEAD -- "$SETTINGS"; then
  # Changed lines (+/-), file headers excluded: all must be secret_key lines,
  # exactly one of them added.
  changed="$(git_ diff -U0 --no-color --no-ext-diff HEAD -- "$SETTINGS" | grep -E '^[+-]' | grep -vE '^(\+\+\+|---) ')"
  if grep -qvE '^[+-][[:space:]]*secret_key:' <<< "$changed" \
     || [ "$(grep -c '^+' <<< "$changed")" -ne 1 ]; then
    info "$SETTINGS has local modifications other than secret_key:"
    info ""
    masked_diff "$SETTINGS"
    info ""
    info "Restore the file (git checkout -- $SETTINGS) after saving what you need, then re-run."
    exit 1
  fi
  migrate_key="$(sed -nE 's/^[[:space:]]*secret_key:[[:space:]]*//p' "$SETTINGS" | head -n 1 \
    | tr -d '\r' | sed -E 's/[[:space:]]+$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')"
  # The tracked example value is not a secret worth keeping.
  [ "$migrate_key" = "$DEFAULT_SEARXNG_KEY" ] && migrate_key=""
  # Must survive .env + Compose interpolation unchanged (no $, quotes, spaces, #).
  if [ -n "$migrate_key" ] && ! [[ "$migrate_key" =~ ^[A-Za-z0-9._+/=-]{1,256}$ ]]; then
    die "the secret_key in $SETTINGS uses characters that cannot be moved to .env safely; set SEARXNG_SECRET in .env by hand, then run: git checkout -- $SETTINGS"
  fi
fi

# ── 3. SearXNG secret → .env ──────────────────────────────────────────────
# RELEASE RULE: never edit searxng/settings.yml in a release while installs
# may still carry the secret_key written into it by the old
# generate-secrets.sh. That line is a local modification on those servers:
# any upstream change to the file (even a comment near secret_key) makes
# `git pull` refuse ("local changes would be overwritten") BEFORE this script
# exists on disk, so the migration below would never be reached.
env_has_key() {
  local v
  v="$(grep -E '^SEARXNG_SECRET=' "$ENV_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '"'"'"' \r')"
  [ -n "$v" ]
}

# Writes SEARXNG_SECRET=<value> in .env, replacing empty definitions. The
# new content is built in a temp file next to .env, verified (line count,
# last line), given .env's owner and mode, then renamed over .env: on any
# failure .env is left byte-identical (only the temp file is removed). A new
# .env is created 0600. The value is never printed.
ENV_TMP=""
trap 'if [ -n "$ENV_TMP" ]; then rm -f -- "${ENV_TMP:?}"; fi' EXIT
env_set_key() {
  local value="$1" rc expected actual last
  if [ ! -e "$ENV_FILE" ]; then
    (umask 077 && : > "$ENV_FILE") || die "cannot create .env"
  fi
  ENV_TMP="$(mktemp "$TB_DIR/.env.tmp.XXXXXX")" || die "cannot write a temporary file in $TB_DIR"
  grep -vE '^SEARXNG_SECRET=' "$ENV_FILE" > "$ENV_TMP"
  rc=$?
  [ "$rc" -le 1 ] || die "cannot copy .env (grep exit $rc); .env left unchanged"
  if [ -s "$ENV_TMP" ] && [ -n "$(tail -c 1 "$ENV_TMP")" ]; then
    echo >> "$ENV_TMP" || die "cannot write the temporary copy of .env; .env left unchanged"
  fi
  printf 'SEARXNG_SECRET=%s\n' "$value" >> "$ENV_TMP" \
    || die "cannot write the temporary copy of .env; .env left unchanged"
  # grep -c '' counts lines, including a last line without newline.
  expected=$(( $(grep -c '' "$ENV_FILE") - $(grep -c '^SEARXNG_SECRET=' "$ENV_FILE") + 1 ))
  actual="$(grep -c '' "$ENV_TMP")"
  last="$(tail -n 1 "$ENV_TMP")"
  if [ "$actual" != "$expected" ] || [ "$last" != "SEARXNG_SECRET=$value" ]; then
    die "the temporary copy of .env is incomplete (disk full?); .env left unchanged"
  fi
  chown --reference="$ENV_FILE" -- "$ENV_TMP" && chmod --reference="$ENV_FILE" -- "$ENV_TMP" \
    || die "cannot copy the owner/mode of .env; .env left unchanged"
  mv -fT -- "$ENV_TMP" "$ENV_FILE" || die "cannot replace .env; .env left unchanged"
  ENV_TMP=""
}

if ! git_ diff --quiet HEAD -- "$SETTINGS"; then
  # Only the secret_key line differs (checked above).
  if [ -n "$migrate_key" ] && env_has_key; then
    info "SEARXNG_SECRET already set in .env: kept."
  elif [ -n "$migrate_key" ]; then
    env_set_key "$migrate_key"
    info "SearXNG secret_key moved from $SETTINGS to SEARXNG_SECRET in .env."
  fi
  # From HEAD, not the index: a staged edit must not survive.
  git_ checkout HEAD -- "$SETTINGS" || die "cannot restore $SETTINGS"
  git_ diff --quiet HEAD -- "$SETTINGS" || die "$SETTINGS still differs from HEAD after restore"
fi
if ! env_has_key; then
  new_key="$(openssl rand -hex 32 2>/dev/null)"
  [[ "$new_key" =~ ^[0-9a-f]{64}$ ]] || die "openssl rand failed: cannot generate SEARXNG_SECRET"
  env_set_key "$new_key"
  unset new_key
  info "SEARXNG_SECRET generated in .env."
fi
unset migrate_key

# ── 4. Exchange folder (ownership/modes re-asserted on every run) ─────────
UPD="${TB_DIR:?}/updater"
[ -L "$UPD" ] && die "$UPD is a symbolic link; refusing to continue"
mkdir -p -- "$UPD" || die "cannot create $UPD"
chown root:root "$UPD" && chmod 0755 "$UPD" || die "cannot set ownership of $UPD"
if [ -L "$UPD/requests" ] || { [ -e "$UPD/requests" ] && [ ! -d "$UPD/requests" ]; }; then
  rm -f -- "${UPD:?}/requests"
fi
mkdir -p -- "$UPD/requests" || die "cannot create $UPD/requests"
chown "$WEB_UID:$WEB_UID" "$UPD/requests" && chmod 0700 "$UPD/requests" \
  || die "cannot set ownership of $UPD/requests"
# A request left over while the service was down must not start an
# unattended update when the .path unit is (re)started below. Removed
# without following links and without reading it (same as tb-updater.sh).
REQ="$UPD/requests/request"
if [ -d "$REQ" ] && [ ! -L "$REQ" ]; then
  rm -rf --one-file-system -- "${REQ:?}"
else
  rm -f -- "${REQ:?}"
fi
{ [ -e "$REQ" ] || [ -L "$REQ" ]; } && die "cannot remove $REQ"
# Database exports made before each update (checked above: not a link).
(umask 077 && mkdir -p -- "$BACKUPS") || die "cannot create $BACKUPS"
[ -L "$BACKUPS" ] && die "$BACKUPS is a symbolic link; refusing to continue"
chown root:root -- "$BACKUPS" && chmod 0700 -- "$BACKUPS" || die "cannot set ownership of $BACKUPS"

# ── 5. systemd units ──────────────────────────────────────────────────────
write_unit() {
  local name="$1" tmp
  tmp="$(mktemp "$SYSTEMD_DIR/.$name.XXXXXX")" || die "cannot write in $SYSTEMD_DIR"
  cat > "$tmp" && chmod 0644 "$tmp" || { rm -f -- "${tmp:?}"; die "cannot write $SYSTEMD_DIR/$name"; }
  mv -fT -- "$tmp" "$SYSTEMD_DIR/$name" || die "cannot install $SYSTEMD_DIR/$name"
}

write_unit "$UNIT.path" <<EOF
# Installed by $TB_DIR/scripts/install-updater.sh — do not edit.
[Unit]
Description=TicketBrainy: watch for update requests from the web app

[Path]
PathExists=$TB_DIR/updater/requests/request
Unit=$UNIT.service

[Install]
WantedBy=multi-user.target
EOF

# Start limit: hitting it puts the .path unit in "failed" and stops the
# watch until reboot. 30 starts / 120 s is far above human clicks (e.g. an
# admin retrying "Update" on a modified tree, each run failing in < 1 s) but
# still stops a real spin (a future script failing before it removes
# `request`); the .path trigger limit only exists from systemd 250.
# /bin/bash: does not depend on the exec bit of the pulled script.
write_unit "$UNIT.service" <<EOF
# Installed by $TB_DIR/scripts/install-updater.sh — do not edit.
[Unit]
Description=TicketBrainy: update requested from the web app
After=network-online.target docker.service
Wants=network-online.target
StartLimitIntervalSec=120
StartLimitBurst=30

[Service]
Type=oneshot
WorkingDirectory=$TB_DIR
ExecStart=/bin/bash $TB_DIR/scripts/tb-updater.sh
# Backstop above the sum of the script's own step timeouts; on expiry systemd
# sends SIGTERM and the script records a failure for the current step.
TimeoutStartSec=90min
EOF

write_unit "$UNIT-init.service" <<EOF
# Installed by $TB_DIR/scripts/install-updater.sh — do not edit.
[Unit]
Description=TicketBrainy: reset the update status at boot
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash $TB_DIR/scripts/tb-updater.sh --init

[Install]
WantedBy=multi-user.target
EOF

"$SYSTEMCTL" daemon-reload || die "systemctl daemon-reload failed"
"$SYSTEMCTL" enable "$UNIT.path" || die "cannot enable $UNIT.path"
# restart (not enable --now): a unit changed by a re-run applies at once.
"$SYSTEMCTL" restart "$UNIT.path" || die "cannot start $UNIT.path"
"$SYSTEMCTL" enable "$UNIT-init.service" || die "cannot enable $UNIT-init.service"

bash "$TB_DIR/scripts/tb-updater.sh" --init || die "tb-updater.sh --init failed"

# ── 6. Done ───────────────────────────────────────────────────────────────
info ""
info "In-app update service installed ($UNIT.path)."
info "Database exports made before each update: $BACKUPS (3 most recent kept)."
info "Now run once: docker compose up -d   (mounts the exchange folder in the web container)"
