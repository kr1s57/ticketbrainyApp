#!/usr/bin/env bash
# TicketBrainy — host-side update sequence.
#
# Started AS ROOT by the systemd unit (ticketbrainy-updater.path/.service,
# installed by scripts/install-updater.sh) when the web app creates
# updater/requests/request. The content of `request` is NEVER read: no
# parameter comes from the web app. Progress goes to updater/status.json
# (read-only for the web container) and updater/update.log.
#
#   tb-updater.sh            run an update (lock, git fetch, release signature check,
#                            fast-forward, compose pull/up, health)
#   tb-updater.sh --init     write an "idle" status.json and nothing else (installer, boot)
#   tb-updater.sh --resume OLD STARTED
#                            internal: re-exec on the freshly pulled version of this script
#
# FORWARD-COMPATIBILITY CONTRACT: when a pull changes this file, the OLD
# version execs the NEW one as `tb-updater.sh --resume OLD STARTED` with the
# lock held on fd 9. Every future version of this script MUST keep accepting
# exactly that call (OLD = 40-hex commit before the pull, STARTED = ISO-8601
# start time), or updates from older installs will break mid-way.
#
# RELEASE SIGNATURE: nothing fetched is merged (nor executed) before every
# new commit has been verified against scripts/tb-release-signers AS RECORDED
# IN THE COMMIT ALREADY INSTALLED — never the fetched copy. Each verified
# commit then supplies the list for the next one, so a key is added or
# retired by a commit signed with a key that is trusted at that point.
# Every commit published to the release branch must therefore be signed.
#
# Environment (all optional, for tests): TB_DIR, TB_DOCKER, TB_HEALTH_CMD,
# TB_HEALTH_TIMEOUT, TB_STEP_TIMEOUT_GIT/PULL/BACKUP/UP (seconds), TB_BACKUP_DIR.
# Never sources .env; local modifications are never overwritten.
set -uo pipefail
umask 022
export GIT_TERMINAL_PROMPT=0

TB_DIR="${TB_DIR:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
TB_DIR="$(cd "$TB_DIR" && pwd -P)" || exit 1
TB_DOCKER="${TB_DOCKER:-docker}"

num_or() { if [[ "${1:-}" =~ ^[0-9]+$ ]]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }
TB_HEALTH_TIMEOUT="$(num_or "${TB_HEALTH_TIMEOUT:-}" 240)"
T_GIT="$(num_or "${TB_STEP_TIMEOUT_GIT:-}" 300)"
T_PULL="$(num_or "${TB_STEP_TIMEOUT_PULL:-}" 1800)"
T_UP="$(num_or "${TB_STEP_TIMEOUT_UP:-}" 900)"
T_BACKUP="$(num_or "${TB_STEP_TIMEOUT_BACKUP:-}" 1800)"

UPD_DIR="${TB_DIR:?}/updater"
STATUS="$UPD_DIR/status.json"
LOG="$UPD_DIR/update.log"
LOCK="$UPD_DIR/.lock"
REQUEST="$UPD_DIR/requests/request"
# Commit before the first pull of an update that has not succeeded yet: a
# retry after a failure AFTER the pull (compose pull/up, health) must diff
# from it, not from the already-pulled HEAD, or the bind-mount services
# would not be force-recreated. Removed on success only.
PENDING="$UPD_DIR/.pending-from"
# Database exports made before `compose up`: OUTSIDE updater/ (mounted in the
# web container), root-only 0700, files 0600, never logged.
BACKUP_DIR="${TB_BACKUP_DIR:-$TB_DIR/updater-backups}"
BACKUP_KEEP=3
BACKUP_TMP=""
# Allowed release signers (ssh-keygen "allowed signers" format, namespace
# "git"), read from git objects only — never from the working tree.
SIGNERS_PATH='scripts/tb-release-signers'
SIGNERS_TMP=""

STATE="idle" STEP="" STARTED="" FINISHED="" FROM_V="" TO_V="" ERR="" DETAIL=""
PROFILE=()
GIT=(git -c safe.directory="$TB_DIR" -C "$TB_DIR")

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

json_escape() {
  local s="${1:0:400}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  # newlines/tabs/CR -> space, other control characters dropped
  s="$(printf '%s' "$s" | tr '\n\r\t' '   ' | tr -d '\000-\037')"
  printf '%s' "$s"
}

# Children never inherit the lock fd 9 (only the --resume re-exec keeps it).
git_() { "${GIT[@]}" "$@" 9>&-; }

head_sha() { git_ rev-parse HEAD 2>/dev/null; }

# Version pinned for the web image in a docker-compose.yml given on stdin.
compose_version() {
  grep -o 'ticketbrainy-web:[A-Za-z0-9._-]*' | head -n 1 | cut -d: -f2
}

# updater/ is root-only (installer), but never follow a planted link anyway.
unlink_if_symlink() { if [ -L "${1:?}" ]; then rm -f -- "${1:?}"; fi; }

# Prints the validated commit in .pending-from (40 hex, known to git, ancestor
# of HEAD), or nothing; an invalid or symlinked file is removed.
read_pending() {
  local c
  unlink_if_symlink "$PENDING"
  [ -f "$PENDING" ] || return 0
  c="$(head -c 41 -- "$PENDING" 2>/dev/null | tr -d '\n')"
  if [[ "$c" =~ ^[0-9a-f]{40}$ ]] && git_ cat-file -e "$c^{commit}" 2>/dev/null \
     && git_ merge-base --is-ancestor "$c" HEAD 2>/dev/null; then
    printf '%s' "$c"
  else
    rm -f -- "${PENDING:?}"
  fi
}

# pending_base CANDIDATE: the base to diff from — the recorded commit if
# valid, otherwise CANDIDATE, recorded (only when no valid file exists).
pending_base() {
  local c tmp
  c="$(read_pending)"
  if [ -n "$c" ]; then printf '%s' "$c"; return 0; fi
  tmp="$(mktemp "$UPD_DIR/.pending.XXXXXX")" || { printf '%s' "$1"; return 0; }
  printf '%s\n' "$1" > "$tmp" && chmod 0644 "$tmp" && mv -fT -- "$tmp" "$PENDING" || rm -f -- "${tmp:?}"
  printf '%s' "$1"
}

write_status() {
  local tmp
  tmp="$(mktemp "$UPD_DIR/.status.XXXXXX")" || return 1
  printf '{"updater":1,"state":"%s","step":"%s","startedAt":"%s","finishedAt":"%s","fromVersion":"%s","toVersion":"%s","installedCommit":"%s","errorCode":"%s","detail":"%s"}\n' \
    "$STATE" "$STEP" "$STARTED" "$FINISHED" \
    "$(json_escape "$FROM_V")" "$(json_escape "$TO_V")" "$(head_sha)" \
    "$ERR" "$(json_escape "$DETAIL")" > "$tmp"
  chmod 0644 "$tmp"
  unlink_if_symlink "$STATUS"
  # -T: replace the name itself, never move into a directory it points to.
  mv -fT -- "$tmp" "$STATUS"
}

log() { printf '[%s] %s\n' "$(now)" "$*" >> "$LOG"; }

step() { STEP="$1"; write_status; log "== $1"; }

fail() {
  if [ -n "$BACKUP_TMP" ]; then rm -f -- "${BACKUP_TMP:?}"; BACKUP_TMP=""; fi
  if [ -n "$SIGNERS_TMP" ]; then rm -f -- "${SIGNERS_TMP:?}"; SIGNERS_TMP=""; fi
  STATE="failed" ERR="$1" DETAIL="$2" FINISHED="$(now)"
  log "ECHEC [$1] $2"
  write_status
  exit 1
}

# SIGTERM (systemd stop/timeout) or SIGINT: record a failure for the step in
# progress instead of leaving "running" forever. The errorCode set is fixed.
on_signal() {
  local code
  trap - TERM INT
  if [ "$STATE" = running ]; then
    case "$STEP" in
      pull) code=compose_pull ;;
      backup) code=backup ;;
      up) code=compose_up ;;
      health) code=health ;;
      *) code=git_pull ;;
    esac
    fail "$code" "interrompu par le signal $1 pendant l'etape ${STEP:-?}"
  fi
  exit 1
}

# Run a command, its output going to update.log only; on failure, LAST_ERR is
# the last non-empty output line.
LAST_ERR=""
run_logged() {
  local out rc
  out="$(mktemp "$UPD_DIR/.out.XXXXXX")" || return 1
  "$@" > "$out" 2>&1 9>&-
  rc=$?
  cat -- "$out" >> "$LOG"
  LAST_ERR="$(grep -v '^[[:space:]]*$' "$out" | tail -n 1)"
  rm -f -- "${out:?}"
  return "$rc"
}

# run_timed SECONDS CMD...: run_logged under coreutils timeout (KILL 30 s
# after TERM if the command ignores it).
run_timed() {
  local t="$1" rc
  shift
  run_logged timeout -k 30 "$t" "$@"
  rc=$?
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
    LAST_ERR="delai depasse (${t}s) : $1 ${*:2}"
    log "$LAST_ERR"
  fi
  return "$rc"
}

# verify_chain BASE TARGET: every commit of BASE..TARGET (first parent, oldest
# first) must carry an SSH signature made by a key listed in SIGNERS_PATH of
# the commit before it (BASE for the first one). Any doubt -> fail, before
# anything is merged. Never returns on failure.
verify_chain() {
  local cur="$1" target="$2" list c hdr gv last=""
  command -v ssh-keygen >/dev/null 2>&1 \
    || fail signature "verification de la signature impossible : ssh-keygen introuvable sur l'hote (paquet openssh-client)"
  # SSH signatures need git >= 2.34 (2021); say so instead of a vague refusal.
  gv="$(git --version 2>/dev/null 9>&- | grep -oE '[0-9]+\.[0-9]+' | head -n 1)"
  if [[ "$gv" =~ ^([0-9]+)\.([0-9]+)$ ]] && [ $(( BASH_REMATCH[1] * 1000 + BASH_REMATCH[2] )) -lt 2034 ]; then
    fail signature "verification de la signature impossible : git $gv trop ancien sur l'hote (2.34 minimum)"
  fi
  list="$(git_ rev-list --reverse --first-parent "$cur..$target" 2>>"$LOG")" \
    || fail signature "verification de la signature impossible : liste des commits illisible"
  [ -n "$list" ] || fail signature "verification de la signature impossible : aucun commit a verifier"
  SIGNERS_TMP="$(mktemp "$UPD_DIR/.signers.XXXXXX")" \
    || { SIGNERS_TMP=""; fail signature "verification de la signature impossible : fichier temporaire"; }
  while IFS= read -r c; do
    [[ "$c" =~ ^[0-9a-f]{40}$ ]] || fail signature "verification de la signature impossible : commit invalide"
    if ! git_ show "$cur:$SIGNERS_PATH" > "$SIGNERS_TMP" 2>>"$LOG" || ! grep -q '[^[:space:]]' "$SIGNERS_TMP"; then
      fail signature "liste des cles de publication absente du commit ${cur:0:12} : mise a jour refusee"
    fi
    # Only an SSH signature is ever verified: a PGP/X.509 one would be judged
    # by root's own keyring, which is not ours to trust.
    hdr="$(git_ cat-file commit "$c" 2>>"$LOG")" || fail signature "commit ${c:0:12} illisible"
    if ! grep -qx 'gpgsig -----BEGIN SSH SIGNATURE-----' <<< "${hdr%%$'\n\n'*}"; then
      fail signature "commit ${c:0:12} non signe : mise a jour refusee"
    fi
    if ! run_logged "${GIT[@]}" -c gpg.format=ssh -c gpg.ssh.program=ssh-keygen \
         -c gpg.ssh.allowedSignersFile="$SIGNERS_TMP" -c gpg.program=/bin/false \
         -c gpg.x509.program=/bin/false verify-commit "$c"; then
      fail signature "commit ${c:0:12} : signature refusee, cle de publication inconnue (${LAST_ERR:-voir update.log})"
    fi
    cur="$c" last="$c"
  done <<< "$list"
  rm -f -- "${SIGNERS_TMP:?}"; SIGNERS_TMP=""
  [ "$last" = "$target" ] || fail signature "verification de la signature incomplete"
  log "signature : $(wc -l <<< "$list") commit(s) verifie(s) jusqu'a ${target:0:12}"
}

compose() { "$TB_DOCKER" compose "${PROFILE[@]}" "$@" 9>&-; }

# Last line of a complete pg_dump (followed only by a few trailer lines,
# e.g. "\unrestrict <key>" since PostgreSQL 16.10/17.6).
DUMP_END='-- PostgreSQL database dump complete'

# Keep the BACKUP_KEEP most recent exports (the one just made, NEW, always
# kept); only regular files named like our exports are ever considered.
prune_backups() {
  local new="$1" f b
  local -a others=()
  for f in "${BACKUP_DIR:?}"/pre-update-*.sql.gz; do
    b="${f##*/}"
    [[ "$b" =~ ^pre-update-[A-Za-z0-9._-]+\.sql\.gz$ ]] || continue
    [ -f "$f" ] && [ ! -L "$f" ] && [ "$b" != "$new" ] || continue
    others+=("$(stat -c '%Y' -- "$f") $b")
  done
  [ "${#others[@]}" -gt 0 ] || return 0
  printf '%s\n' "${others[@]}" | sort -rn -k1,1 | tail -n +"$BACKUP_KEEP" | cut -d' ' -f2- \
    | while IFS= read -r b; do
        [ -n "$b" ] || continue
        rm -f -- "${BACKUP_DIR:?}/${b:?}" && log "ancienne sauvegarde supprimee : $b"
      done
}

# Export the database (pg_dump in the running db container, with the
# container's own POSTGRES_USER/POSTGRES_DB: no secret is read here) to
# BACKUP_DIR/pre-update-<fromVersion>-<UTC time>.sql.gz. Any doubt -> fail
# before `compose up` (which runs the schema migrations).
backup_db() {
  local ver name final errf rc tail_lines size stale
  ver="$FROM_V"
  [[ "$ver" =~ ^[0-9][0-9.]{0,63}$ ]] || ver=inconnue
  name="pre-update-$ver-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
  final="${BACKUP_DIR:?}/$name"

  if [ -L "$BACKUP_DIR" ] || { [ -e "$BACKUP_DIR" ] && [ ! -d "$BACKUP_DIR" ]; }; then
    fail backup "export de la base impossible : $BACKUP_DIR n'est pas un dossier (lien symbolique ?)"
  fi
  (umask 077 && mkdir -p -- "$BACKUP_DIR") \
    || fail backup "export de la base impossible : creation de $BACKUP_DIR"
  if [ -L "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    fail backup "export de la base impossible : $BACKUP_DIR n'est pas un dossier (lien symbolique ?)"
  fi
  chown 0:0 -- "$BACKUP_DIR" && chmod 0700 -- "$BACKUP_DIR" \
    || fail backup "export de la base impossible : droits de $BACKUP_DIR"

  # Leftovers of a run killed mid-export (one updater at a time: flock).
  for stale in "${BACKUP_DIR:?}"/.pre-update.??????; do
    [ -f "$stale" ] && [ ! -L "$stale" ] && rm -f -- "${stale:?}"
  done
  BACKUP_TMP="$(mktemp "$BACKUP_DIR/.pre-update.XXXXXX")" \
    || { BACKUP_TMP=""; fail backup "export de la base impossible : fichier temporaire"; }
  chmod 0600 -- "$BACKUP_TMP"
  errf="$(mktemp "$UPD_DIR/.out.XXXXXX")" || fail backup "export de la base impossible : fichier temporaire"
  # stderr (pg_dump / docker / gzip messages) goes to the log; stdout (the dump)
  # only to the gzip file. $POSTGRES_* are expanded INSIDE the container.
  # shellcheck disable=SC2016
  timeout -k 30 "$T_BACKUP" "$TB_DOCKER" compose "${PROFILE[@]}" exec -T db \
    sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' 2>> "$errf" 9>&- \
    | gzip -c > "$BACKUP_TMP" 2>> "$errf" 9>&-
  rc=$?
  cat -- "$errf" >> "$LOG"
  LAST_ERR="$(grep -v '^[[:space:]]*$' "$errf" | tail -n 1)"
  rm -f -- "${errf:?}"
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
    LAST_ERR="delai depasse (${T_BACKUP}s) : pg_dump"
    log "$LAST_ERR"
  fi
  if [ "$rc" -ne 0 ]; then
    fail backup "export de la base impossible : ${LAST_ERR:-code $rc}"
  fi
  if ! gzip -t -- "$BACKUP_TMP" 2>>"$LOG" 9>&-; then
    fail backup "export de la base impossible : archive gzip invalide"
  fi
  tail_lines="$(gzip -dc -- "$BACKUP_TMP" 2>/dev/null 9>&- | tail -n 20)"
  if ! grep -qxF -- "$DUMP_END" <<< "$tail_lines"; then
    fail backup "export de la base impossible : export incomplet (fin de pg_dump absente)"
  fi
  tail_lines=""
  # -T: replace the name itself, never follow a link planted at that name.
  mv -fT -- "$BACKUP_TMP" "$final" || fail backup "export de la base impossible : renommage"
  BACKUP_TMP=""
  size="$(stat -c '%s' -- "$final" 2>/dev/null)"
  log "sauvegarde : $final (${size:-?} octets)"
  prune_backups "$name"
}

health_loop() {
  local hc deadline port bind left
  if [ -n "${TB_HEALTH_CMD:-}" ]; then
    read -r -a hc <<< "$TB_HEALTH_CMD"
  else
    # Only the APP_PORT line is extracted; .env is never sourced nor logged.
    port="$(grep -E '^APP_PORT=' "$TB_DIR/.env" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '"'"'"' \r')"
    [[ "$port" =~ ^[0-9]{1,5}$ ]] || port=3000
    # Same for WEB_BIND (the host address the web port is published on, see
    # docker-compose.yml): an IPv4 literal only; 0.0.0.0 / absent -> loopback.
    bind="$(grep -E '^WEB_BIND=' "$TB_DIR/.env" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '"'"'"' \r')"
    if ! [[ "$bind" =~ ^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}$ ]] \
       || [ "$bind" = 0.0.0.0 ]; then
      bind=127.0.0.1
    fi
    hc=(curl -fsS -o /dev/null --max-time 5 "http://$bind:$port/login")
  fi
  log "attente de la sante : ${hc[*]} (max ${TB_HEALTH_TIMEOUT}s)"
  deadline=$(( $(date +%s) + TB_HEALTH_TIMEOUT ))
  while :; do
    run_logged "${hc[@]}" && return 0
    left=$(( deadline - $(date +%s) ))
    [ "$left" -le 0 ] && return 1
    sleep "$(( left < 5 ? left : 5 ))"
  done
}

# Steps after the pull; OLD = commit before the pull.
after_pull() {
  local old="$1" new changed svc existing
  local -a wanted=() recreate=()
  new="$(head_sha)"
  FROM_V="$(git_ show "$old:docker-compose.yml" 2>/dev/null | compose_version)"
  TO_V="$(compose_version < "$TB_DIR/docker-compose.yml")"
  log "version : ${FROM_V:-?} -> ${TO_V:-?} ($old -> $new)"

  if [ -n "$("$TB_DOCKER" compose --profile with-proxy ps -a -q caddy 2>>"$LOG" 9>&-)" ]; then
    PROFILE=(--profile with-proxy)
    log "profil with-proxy actif"
  fi

  step pull
  run_timed "$T_PULL" "$TB_DOCKER" compose "${PROFILE[@]}" pull || fail compose_pull "$LAST_ERR"

  step backup
  backup_db

  step up
  run_timed "$T_UP" "$TB_DOCKER" compose "${PROFILE[@]}" up -d || fail compose_up "$LAST_ERR"

  # Bind-mounted files are not refreshed by `up -d`: force-recreate the
  # existing services whose mounted files changed in this pull.
  changed="$(git_ diff --name-only "$old" "$new" 2>>"$LOG")"
  grep -q '^keycloak/' <<< "$changed" && wanted+=(keycloak keycloak-init)
  grep -q '^proxy/' <<< "$changed" && wanted+=(caddy)
  grep -q '^searxng/' <<< "$changed" && wanted+=(searxng)
  if [ "${#wanted[@]}" -gt 0 ]; then
    existing="$(compose ps -a --services 2>>"$LOG")"
    for svc in "${wanted[@]}"; do
      grep -qxF -- "$svc" <<< "$existing" && recreate+=("$svc")
    done
    if [ "${#recreate[@]}" -gt 0 ]; then
      log "recreation forcee : ${recreate[*]}"
      run_timed "$T_UP" "$TB_DOCKER" compose "${PROFILE[@]}" up -d --force-recreate --no-deps "${recreate[@]}" \
        || fail compose_up "$LAST_ERR"
    fi
  fi

  step health
  health_loop || fail health "le service web ne repond pas apres ${TB_HEALTH_TIMEOUT}s"

  STATE="success" STEP="" FINISHED="$(now)"
  log "SUCCES ${FROM_V} -> ${TO_V}"
  unlink_if_symlink "$PENDING"
  rm -f -- "${PENDING:?}"
  write_status
  exit 0
}

# Take the lock on fd 9 without following a planted link; exit 0 if busy.
take_lock() {
  unlink_if_symlink "$LOCK"
  exec 9>>"$LOCK" || exit 1
  flock -n 9 || exit 0
}

main() {
  local old dirty cur target
  mkdir -p -- "$UPD_DIR" || exit 1
  cd -- "$TB_DIR" || exit 1
  trap 'on_signal TERM' TERM
  trap 'on_signal INT' INT

  case "${1:-}" in
  --init)
    take_lock
    write_status
    exit 0
    ;;
  --resume)
    # Re-exec'd by the previous version of this script: the lock is held
    # through the inherited fd 9 (flock on the same open file succeeds).
    flock -n 9 2>/dev/null || exit 0
    old="${2:-}"
    [[ "$old" =~ ^[0-9a-f]{40}$ ]] || exit 1
    git_ cat-file -e "$old^{commit}" 2>/dev/null || exit 1
    [[ "${3:-}" =~ ^[0-9T:Z-]+$ ]] && STARTED="$3"
    STATE="running"
    unlink_if_symlink "$LOG"
    log "reprise sur la nouvelle version de tb-updater.sh"
    # An older script passed its own pre-pull commit and wrote no
    # .pending-from: record it now so that a retry keeps the right base.
    after_pull "$(pending_base "$old")"
    ;;
  "") ;;
  *) echo "usage: $0 [--init]" >&2; exit 2 ;;
  esac

  # The request file is in a folder writable by the web container: remove it
  # without following links and without reading it — BEFORE the lock, so that
  # a run that finds the lock busy does not leave it behind (the PathExists=
  # unit would re-trigger at once).
  if [ -d "$REQUEST" ] && [ ! -L "$REQUEST" ]; then
    rm -rf --one-file-system -- "${REQUEST:?}"
  else
    rm -f -- "${REQUEST:?}"
  fi
  if [ -e "$REQUEST" ] || [ -L "$REQUEST" ]; then
    # Unreachable from the container in practice (root removes anything it
    # can create); throttle so the unit can never spin.
    echo "tb-updater: cannot remove $REQUEST" >&2
    sleep 10
    exit 1
  fi

  take_lock

  unlink_if_symlink "$LOG"
  : > "$LOG"
  STATE="running" STARTED="$(now)"
  FROM_V="$(compose_version < "$TB_DIR/docker-compose.yml" 2>/dev/null)"
  step check
  # Never on a development checkout: only a published install pins the web
  # image (checked before any git or docker command).
  if ! grep -q 'ghcr\.io/kr1s57/ticketbrainy-web:' "$TB_DIR/docker-compose.yml" 2>/dev/null; then
    fail git_pull "installation non publiée (pas d'image épinglée)"
  fi
  if ! dirty="$(git_ status --porcelain --untracked-files=no 2>>"$LOG")"; then
    fail git_pull "git status a echoue (depot illisible ?) : voir update.log"
  fi
  if [ -n "$dirty" ]; then
    fail dirty_tree "modifications locales : $(cut -c4- <<< "$dirty" | paste -sd ' ' -)"
  fi

  step git
  old="$(pending_base "$(head_sha)")"
  # Fetch only; the working tree moves after the signature check, and to
  # the exact commit that was checked.
  run_timed "$T_GIT" "${GIT[@]}" fetch || fail git_pull "$LAST_ERR"
  target="$(git_ rev-parse --verify -q '@{upstream}^{commit}' 2>>"$LOG")" \
    || fail git_pull "aucune branche distante suivie par la branche courante"
  cur="$(head_sha)"
  if [ "$target" != "$cur" ] && ! git_ merge-base --is-ancestor "$target" "$cur" 2>>"$LOG"; then
    git_ merge-base --is-ancestor "$cur" "$target" 2>>"$LOG" \
      || fail git_pull "l'historique local a diverge du depot : avance rapide impossible"
    verify_chain "$cur" "$target"
    run_timed "$T_GIT" "${GIT[@]}" merge --ff-only "$target" || fail git_pull "$LAST_ERR"
  fi

  if git_ diff --name-only "$old" HEAD 2>>"$LOG" | grep -qxF 'scripts/tb-updater.sh'; then
    log "tb-updater.sh a change : relance sur la nouvelle version"
    exec bash "$TB_DIR/scripts/tb-updater.sh" --resume "$old" "$STARTED"
  fi
  after_pull "$old"
}

main "$@"
