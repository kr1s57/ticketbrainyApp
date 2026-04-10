#!/usr/bin/env bash
# TicketBrainy — Time Configuration
# Run on the Docker HOST (not inside a container).
# Requires: sudo access, systemd (timedatectl)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

header() {
  echo ""
  echo -e "${CYAN}${BOLD}TicketBrainy — Time Configuration${NC}"
  echo -e "${CYAN}──────────────────────────────────${NC}"
  echo ""
}

show_status() {
  local now tz offset
  now=$(date '+%Y-%m-%d %H:%M:%S %Z')
  tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
  offset=$(date '+%z')

  echo -e "  ${BOLD}Current time:${NC} $now"
  echo -e "  ${BOLD}Timezone:${NC}     $tz (UTC${offset:0:3}:${offset:3:2})"

  # NTP status
  if command -v chronyc &>/dev/null; then
    local leap
    leap=$(chronyc tracking 2>/dev/null | grep "Leap status" | awk '{print $NF}')
    if [[ "$leap" == "Normal" ]]; then
      echo -e "  ${BOLD}NTP:${NC}          ${GREEN}synchronized (chrony)${NC}"
    else
      echo -e "  ${BOLD}NTP:${NC}          ${YELLOW}not synchronized (chrony: $leap)${NC}"
    fi
  elif timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q "yes"; then
    echo -e "  ${BOLD}NTP:${NC}          ${GREEN}synchronized (systemd-timesyncd)${NC}"
  else
    echo -e "  ${BOLD}NTP:${NC}          ${RED}not synchronized or NTP not installed${NC}"
  fi
  echo ""
}

option_detailed_status() {
  echo -e "\n${BOLD}Detailed NTP Status${NC}\n"
  if command -v chronyc &>/dev/null; then
    chronyc tracking
    echo ""
    chronyc sources -v
  elif command -v timedatectl &>/dev/null; then
    timedatectl timesync-status 2>/dev/null || timedatectl status
  elif command -v ntpq &>/dev/null; then
    ntpq -p
  else
    echo -e "${RED}No NTP client found. Install chrony:${NC}"
    echo "  sudo apt install chrony"
  fi
}

option_change_timezone() {
  echo -e "\n${BOLD}Change Timezone${NC}\n"
  echo "Current: $(timedatectl show -p Timezone --value 2>/dev/null)"
  echo ""

  if command -v fzf &>/dev/null; then
    local tz
    tz=$(timedatectl list-timezones | fzf --prompt="Select timezone: ")
  else
    echo "Available timezones (filtered — type part of your timezone):"
    read -rp "Filter (e.g. Europe, America, Asia): " filter
    timedatectl list-timezones | grep -i "${filter:-}" | head -30
    echo ""
    read -rp "Enter timezone (e.g. Europe/Paris): " tz
  fi

  if [[ -z "$tz" ]]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    return
  fi

  echo -e "Setting timezone to ${BOLD}$tz${NC}..."
  sudo timedatectl set-timezone "$tz"
  echo -e "${GREEN}Timezone changed to $tz${NC}"
  echo ""
  echo -e "${YELLOW}Restarting Docker containers to pick up new timezone...${NC}"

  # Find the docker-compose directory
  local compose_dir=""
  for d in /opt/ticketbrainyApp /opt/aidesk; do
    if [[ -f "$d/docker-compose.yml" ]]; then
      compose_dir="$d"
      break
    fi
  done

  if [[ -n "$compose_dir" ]]; then
    read -rp "Restart containers in $compose_dir? [y/N]: " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      cd "$compose_dir"
      docker compose restart
      echo -e "${GREEN}Containers restarted.${NC}"
    fi
  else
    echo -e "${YELLOW}Could not find docker-compose.yml. Restart containers manually.${NC}"
  fi
}

option_sync_ntp() {
  echo -e "\n${BOLD}Force NTP Sync${NC}\n"
  echo "Before: $(date '+%Y-%m-%d %H:%M:%S.%N %Z')"

  if command -v chronyc &>/dev/null; then
    sudo chronyc makestep
  elif command -v ntpdate &>/dev/null; then
    sudo ntpdate -u pool.ntp.org
  else
    sudo timedatectl set-ntp true
    sleep 2
  fi

  echo "After:  $(date '+%Y-%m-%d %H:%M:%S.%N %Z')"
  echo -e "${GREEN}NTP sync forced.${NC}"
}

option_configure_ntp() {
  echo -e "\n${BOLD}Configure NTP Server${NC}\n"

  read -rp "NTP server address [pool.ntp.org]: " ntp_server
  ntp_server="${ntp_server:-pool.ntp.org}"

  if command -v chronyc &>/dev/null; then
    local conf="/etc/chrony/chrony.conf"
    if [[ ! -f "$conf" ]]; then
      conf="/etc/chrony.conf"
    fi
    echo -e "Editing ${BOLD}$conf${NC}..."
    # Comment out existing server/pool lines and add the new one
    sudo sed -i 's/^server /#server /' "$conf"
    sudo sed -i 's/^pool /#pool /' "$conf"
    echo "server $ntp_server iburst" | sudo tee -a "$conf" >/dev/null
    sudo systemctl restart chronyd 2>/dev/null || sudo systemctl restart chrony
    echo -e "${GREEN}Chrony reconfigured with server $ntp_server${NC}"
  elif [[ -f /etc/systemd/timesyncd.conf ]]; then
    echo -e "Editing ${BOLD}/etc/systemd/timesyncd.conf${NC}..."
    sudo sed -i "s/^#*NTP=.*/NTP=$ntp_server/" /etc/systemd/timesyncd.conf
    sudo sed -i "s/^#*FallbackNTP=.*/FallbackNTP=pool.ntp.org/" /etc/systemd/timesyncd.conf
    sudo systemctl restart systemd-timesyncd
    echo -e "${GREEN}systemd-timesyncd reconfigured with server $ntp_server${NC}"
  else
    echo -e "${RED}No supported NTP client found.${NC}"
    echo "Install chrony: sudo apt install chrony"
  fi
}

# ── Main menu ─────────────────────────────────────────────

header
show_status

while true; do
  echo "  1) Show detailed NTP status"
  echo "  2) Change timezone"
  echo "  3) Force NTP sync now"
  echo "  4) Configure NTP server"
  echo "  5) Exit"
  echo ""
  read -rp "  Choice [1-5]: " choice

  case "$choice" in
    1) option_detailed_status ;;
    2) option_change_timezone ;;
    3) option_sync_ntp ;;
    4) option_configure_ntp ;;
    5) echo -e "\n${GREEN}Done.${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid choice.${NC}" ;;
  esac

  echo ""
  show_status
done
