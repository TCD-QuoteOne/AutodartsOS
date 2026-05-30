#!/usr/bin/env bash
set -uo pipefail

VERSION="1.0"
DEFAULT_OUT="./autodarts-security-audit-$(date +%Y%m%d-%H%M%S).txt"
OUT="${1:-${AUDIT_OUT:-$DEFAULT_OUT}}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

mkdir -p "$(dirname "$OUT")" 2>/dev/null || true
: > "$OUT" || {
  echo "Cannot write audit output: $OUT" >&2
  exit 1
}

log() {
  printf '%s\n' "$*" | tee -a "$OUT"
}

blank() {
  log ""
}

section() {
  local title="$*"
  blank
  log "## $title"
  log "$(printf '%*s' "${#title}" '' | tr ' ' '-')"
}

ok() {
  PASS_COUNT=$((PASS_COUNT + 1))
  log "[OK]   $*"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  log "[WARN] $*"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  log "[FAIL] $*"
}

info() {
  log "[INFO] $*"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_cmd() {
  local title="$1"
  shift
  blank
  log "\$ $title"
  "$@" >> "$OUT" 2>&1
  local rc=$?
  if [[ "$rc" -ne 0 ]]; then
    log "(exit code: $rc)"
  fi
  return 0
}

trim() {
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

toml_value() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 1
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=$2
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "$file"
}

private_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^10\. ]] && return 0
  [[ "$ip" =~ ^192\.168\. ]] && return 0
  [[ "$ip" =~ ^172\.1[6-9]\. ]] && return 0
  [[ "$ip" =~ ^172\.2[0-9]\. ]] && return 0
  [[ "$ip" =~ ^172\.3[0-1]\. ]] && return 0
  [[ "$ip" =~ ^127\. ]] && return 0
  [[ "$ip" =~ ^169\.254\. ]] && return 0
  [[ "$ip" =~ ^10\.42\.0\. ]] && return 0
  return 1
}

private_ipv6() {
  local ip="${1,,}"
  [[ "$ip" =~ ^fe80: ]] && return 0
  [[ "$ip" =~ ^fd ]] && return 0
  [[ "$ip" =~ ^fc ]] && return 0
  [[ "$ip" == "::1" ]] && return 0
  return 1
}

file_mode() {
  local path="$1"
  stat -c '%a' "$path" 2>/dev/null || echo "unknown"
}

mode_world_readable() {
  local mode="$1"
  [[ "$mode" == "unknown" ]] && return 1
  local last="${mode: -1}"
  [[ "$last" =~ [4567] ]]
}

http_code() {
  local url="$1"
  if have curl; then
    curl -fsS --max-time 5 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true
  else
    echo ""
  fi
}

external_portcheck() {
  local url_template="${AUDIT_EXTERNAL_PORTCHECK_URL:-}"
  local host="$1"
  local port="$2"
  [[ -n "$url_template" ]] || return 2
  [[ -n "$host" ]] || return 2
  local url="${url_template//\{host\}/$host}"
  url="${url//\{port\}/$port}"
  curl -fsS --max-time 10 "$url" 2>/dev/null || true
}

CONFIG_FILE="/etc/autodarts-pi-os/config.toml"
STATUS_FILE="/var/lib/autodarts-pi-os/setup-status.json"
SETUP_STATE_FILE="/var/lib/autodarts-pi-os/setup.state"
WIFI_CREDS_FILE="/var/lib/autodarts-pi-os/wifi-credentials.json"
SESSION_FILE="/var/lib/autodarts-pi-os/session.json"

log "Autodarts Pi OS Security Audit"
log "Version: $VERSION"
log "Date: $(date -Is 2>/dev/null || date)"
log "Host: $(hostname 2>/dev/null || echo unknown)"
log "Output: $OUT"
blank
log "This script is read-only. It does not change firewall, users, passwords, services, or network settings."

section "Kurzfazit"
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  ok "Script runs as root, full local checks are available."
else
  warn "Script does not run as root. Some files, service details, and security settings may be hidden."
fi

section "System"
run_cmd "uname -a" uname -a
if [[ -r /etc/os-release ]]; then
  run_cmd "cat /etc/os-release" cat /etc/os-release
fi
run_cmd "uptime" uptime
run_cmd "hostnamectl" hostnamectl

section "Boot and first-run state"
FIRSTBOOT_DONE="/var/lib/autodarts-pi-os/firstboot.done"
BOOT_CMDLINE=""
BOOT_CONFIG=""
for candidate in /boot/firmware/cmdline.txt /boot/cmdline.txt; do
  if [[ -f "$candidate" ]]; then
    BOOT_CMDLINE="$candidate"
    break
  fi
done
for candidate in /boot/firmware/config.txt /boot/config.txt; do
  if [[ -f "$candidate" ]]; then
    BOOT_CONFIG="$candidate"
    break
  fi
done

if [[ -f "$FIRSTBOOT_DONE" ]]; then
  ok "Autodarts firstboot marker exists: $FIRSTBOOT_DONE"
else
  warn "Autodarts firstboot marker is missing. This is normal only during the first boot."
fi

active_firstrun=""
for candidate in /boot/firmware/firstrun.sh /boot/firstrun.sh; do
  if [[ -f "$candidate" ]]; then
    active_firstrun="${active_firstrun}${candidate} "
  fi
done
if [[ -n "$active_firstrun" ]]; then
  fail "Active Raspberry Pi Imager firstrun script still exists: $active_firstrun"
else
  ok "No active Raspberry Pi Imager firstrun script found."
fi

disabled_firstrun=""
for candidate in /boot/firmware/firstrun.sh.autodarts-disabled /boot/firstrun.sh.autodarts-disabled; do
  if [[ -f "$candidate" ]]; then
    disabled_firstrun="${disabled_firstrun}${candidate} "
  fi
done
[[ -n "$disabled_firstrun" ]] && info "Disabled Imager firstrun backup found: $disabled_firstrun"

if [[ -n "$BOOT_CMDLINE" ]]; then
  ok "Boot cmdline found: $BOOT_CMDLINE"
  run_cmd "cat $BOOT_CMDLINE" cat "$BOOT_CMDLINE"
  cmdline_text="$(cat "$BOOT_CMDLINE" 2>/dev/null || true)"
  if printf '%s' "$cmdline_text" | grep -Eq 'systemd\.run=|firstrun|kernel-command-line\.target'; then
    fail "Boot cmdline still contains Raspberry Pi Imager first-run trigger."
  else
    ok "Boot cmdline does not contain Imager first-run trigger."
  fi
  for arg in quiet splash logo.nologo vt.global_cursor_default=0 systemd.show_status=false rd.systemd.show_status=false; do
    if printf '%s' "$cmdline_text" | grep -qw "$arg"; then
      ok "Boot cmdline contains $arg."
    else
      warn "Boot cmdline is missing $arg."
    fi
  done
else
  warn "Boot cmdline file was not found."
fi

if [[ -n "$BOOT_CONFIG" ]]; then
  ok "Boot config found: $BOOT_CONFIG"
  run_cmd "grep disable_splash $BOOT_CONFIG" sh -c "grep -nE '^[#[:space:]]*disable_splash=' '$BOOT_CONFIG' || true"
  if grep -qE '^disable_splash=1$' "$BOOT_CONFIG"; then
    ok "Raspberry Pi firmware splash is disabled with disable_splash=1."
  else
    warn "disable_splash=1 is missing. The Raspberry Pi firmware splash may appear before Plymouth."
  fi
else
  warn "Boot config file was not found."
fi

section "Autodarts Pi OS configuration"
if [[ -f "$CONFIG_FILE" ]]; then
  ok "Config file exists: $CONFIG_FILE"
  local_mode="$(file_mode "$CONFIG_FILE")"
  if mode_world_readable "$local_mode"; then
    warn "Config file is world-readable (mode $local_mode). This is acceptable only if it contains no secrets."
  else
    ok "Config file permissions are not world-readable (mode $local_mode)."
  fi

  allow_public="$(toml_value "$CONFIG_FILE" "allow_public_webpanel")"
  setup_password="$(toml_value "$CONFIG_FILE" "setup_admin_password")"
  setup_hash="$(toml_value "$CONFIG_FILE" "setup_admin_password_hash")"
  hotspot_password="$(toml_value "$CONFIG_FILE" "setup_hotspot_password")"
  remote_fallback="$(toml_value "$CONFIG_FILE" "autodarts_installer_remote_fallback")"
  webpanel_port="$(toml_value "$CONFIG_FILE" "webpanel_port")"

  [[ "$allow_public" == "false" ]] && ok "Public webpanel access is disabled." || fail "allow_public_webpanel is not false."
  if [[ "$setup_password" == "autodarts" && -z "$setup_hash" ]]; then
    fail "Default admin/setup password is still active. Set a custom admin password."
  elif [[ -n "$setup_hash" ]]; then
    ok "Admin/setup password is stored as a hash."
  else
    warn "Admin/setup password state could not be classified."
  fi
  if [[ "$hotspot_password" == "autodarts" ]]; then
    warn "Setup hotspot still uses the factory password. This is OK only before first setup."
  elif [[ -n "$hotspot_password" ]]; then
    ok "Setup hotspot uses a custom password."
  else
    warn "Setup hotspot password is empty or not readable."
  fi
  [[ "$remote_fallback" == "true" ]] && warn "Remote Autodarts installer fallback is enabled." || ok "Remote Autodarts installer fallback is disabled."
  info "Configured webpanel port: ${webpanel_port:-unknown}"
else
  fail "Config file missing: $CONFIG_FILE"
fi

if [[ -f "$SETUP_STATE_FILE" ]]; then
  setup_state="$(cat "$SETUP_STATE_FILE" 2>/dev/null | trim)"
  info "Setup state: ${setup_state:-empty}"
else
  warn "Setup state file missing: $SETUP_STATE_FILE"
fi

for sensitive in "$WIFI_CREDS_FILE" "$SESSION_FILE"; do
  if [[ -e "$sensitive" ]]; then
    mode="$(file_mode "$sensitive")"
    if mode_world_readable "$mode"; then
      fail "Sensitive file is world-readable: $sensitive (mode $mode)"
    else
      ok "Sensitive file permissions look restricted: $sensitive (mode $mode)"
    fi
  fi
done

if [[ -f "$STATUS_FILE" ]]; then
  ok "Setup status file exists."
  run_cmd "sanitized setup status" sh -c "sed -E 's/(password|passwort|secret|token|hash)[^,}]*/\\1: ***MASKED***/Ig' '$STATUS_FILE' | head -c 12000"
else
  warn "Setup status file missing: $STATUS_FILE"
fi

section "Users and authentication"
if getent passwd autodarts >/dev/null 2>&1; then
  ok "User 'autodarts' exists."
  run_cmd "id autodarts" id autodarts
else
  fail "User 'autodarts' is missing."
fi

if [[ -r /etc/shadow ]]; then
  root_shadow="$(awk -F: '$1=="root"{print $2}' /etc/shadow)"
  autodarts_shadow="$(awk -F: '$1=="autodarts"{print $2}' /etc/shadow)"
  [[ "$root_shadow" == "!"* || "$root_shadow" == "*"* || -z "$root_shadow" ]] && ok "Root password login appears locked." || warn "Root has a password hash. Check whether direct root login is intended."
  [[ "$autodarts_shadow" == "!"* || "$autodarts_shadow" == "*"* || -z "$autodarts_shadow" ]] && ok "Autodarts user password login appears locked." || warn "Autodarts user has a password hash. Check whether password login is intended."
else
  warn "Cannot read /etc/shadow. Run as root for password-lock checks."
fi

section "SSH"
if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
  warn "SSH service is active. This is OK for maintenance, but should use keys only."
  if have sshd; then
    ssh_effective="$(sshd -T 2>/dev/null || true)"
    if printf '%s\n' "$ssh_effective" | grep -qi '^passwordauthentication no$'; then
      ok "SSH password authentication is disabled."
    else
      fail "SSH password authentication is not disabled."
    fi
    if printf '%s\n' "$ssh_effective" | grep -Eqi '^permitrootlogin (no|prohibit-password)$'; then
      ok "SSH root login is disabled or key-only."
    else
      fail "SSH root login policy is too open."
    fi
  else
    warn "sshd command is unavailable; cannot inspect effective SSH config."
  fi
else
  ok "SSH service is not active."
fi

section "Systemd services"
for svc in autodarts-webpanel autodarts-network autodarts-runtime autodarts-install autodarts-watchdog autodarts-kiosk; do
  if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
    state="$(systemctl is-active "${svc}.service" 2>/dev/null || true)"
    enabled="$(systemctl is-enabled "${svc}.service" 2>/dev/null || true)"
    case "$state" in
      active) ok "${svc}.service is active (${enabled})." ;;
      activating) warn "${svc}.service is still activating (${enabled})." ;;
      inactive) warn "${svc}.service is inactive (${enabled})." ;;
      failed) fail "${svc}.service is failed (${enabled})." ;;
      *) warn "${svc}.service state: ${state:-unknown} (${enabled})." ;;
    esac
    run_cmd "systemctl status ${svc}.service" systemctl --no-pager --full status "${svc}.service"
    if systemctl cat "${svc}.service" 2>/dev/null | grep -q '^NoNewPrivileges=true'; then
      ok "${svc}.service uses NoNewPrivileges."
    else
      warn "${svc}.service does not declare NoNewPrivileges."
    fi
  else
    warn "${svc}.service is not installed."
  fi
done

section "Network interfaces and routes"
have ip && run_cmd "ip -brief address" ip -brief address
have ip && run_cmd "ip route" ip route
have nmcli && run_cmd "nmcli device status" nmcli device status
have nmcli && run_cmd "nmcli connection show --active" nmcli connection show --active

if have ip; then
  public_ipv4_found=0
  while read -r ipaddr; do
    ipaddr="${ipaddr%%/*}"
    [[ -z "$ipaddr" ]] && continue
    if private_ipv4 "$ipaddr"; then
      ok "IPv4 address is private/local: $ipaddr"
    else
      fail "Interface has a public IPv4 address: $ipaddr. Do not expose the appliance directly to the internet."
      public_ipv4_found=1
    fi
  done < <(ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}')
  [[ "$public_ipv4_found" -eq 0 ]] && ok "No directly assigned public IPv4 address found."

  public_ipv6_found=0
  while read -r ipaddr; do
    ipaddr="${ipaddr%%/*}"
    [[ -z "$ipaddr" ]] && continue
    if private_ipv6 "$ipaddr"; then
      ok "IPv6 address is link-local/private: $ipaddr"
    else
      warn "Interface has a global IPv6 address: $ipaddr. Ensure router firewall blocks inbound access."
      public_ipv6_found=1
    fi
  done < <(ip -o -6 addr show scope global 2>/dev/null | awk '{print $4}')
  [[ "$public_ipv6_found" -eq 0 ]] && ok "No global IPv6 address found."
fi

section "Listening ports"
if have ss; then
  run_cmd "ss -lntup" ss -lntup
  run_cmd "ss -lnup" ss -lnup
  listeners="$(ss -H -lntup 2>/dev/null || true)"
  for port in 80 3180 22 53 67; do
    if printf '%s\n' "$listeners" | grep -Eq "[:.]${port}[[:space:]]"; then
      info "Port $port is listening."
    fi
  done
  unknown_public="$(printf '%s\n' "$listeners" | awk '
    /0\.0\.0\.0:|\[::\]:|\*:/{print}
  ' | grep -Ev ':(22|53|67|80|3180)[[:space:]]' || true)"
  if [[ -n "$unknown_public" ]]; then
    warn "Unknown service listens on all interfaces:"
    printf '%s\n' "$unknown_public" | tee -a "$OUT" >/dev/null
  else
    ok "No unknown all-interface TCP listeners found."
  fi
else
  warn "ss command missing; cannot inspect listening ports."
fi

section "Local web checks"
if have curl; then
  code="$(http_code "http://127.0.0.1/health.json")"
  if [[ "$code" == "200" ]]; then
    ok "Webpanel health endpoint is reachable locally."
  elif [[ -n "$code" ]]; then
    warn "Webpanel health endpoint returned HTTP $code."
  else
    fail "Webpanel health endpoint is not reachable locally."
  fi

  code="$(http_code "http://127.0.0.1/setup")"
  if [[ "$code" =~ ^(200|303|302)$ ]]; then
    ok "Setup page responds locally."
  else
    warn "Setup page returned HTTP ${code:-no response}."
  fi

  code="$(http_code "http://127.0.0.1:3180")"
  if [[ "$code" =~ ^(200|301|302|303|401|403)$ ]]; then
    ok "Autodarts local service responds on port 3180."
  else
    warn "Autodarts local service on port 3180 returned ${code:-no response}."
  fi
else
  warn "curl missing; cannot run local HTTP checks."
fi

section "Hotspot and DNS"
if have nmcli; then
  if nmcli -t -f NAME connection show 2>/dev/null | grep -qx "Autodarts-Setup"; then
    ok "Setup hotspot connection profile exists."
  else
    warn "Setup hotspot connection profile was not found."
  fi
  if nmcli -t -f NAME connection show --active 2>/dev/null | grep -qx "Autodarts-Setup"; then
    setup_state="${setup_state:-unknown}"
    if [[ "$setup_state" == "configured" ]]; then
      warn "Setup hotspot is active although setup state is configured. This may be recovery mode or a network fallback."
    else
      ok "Setup hotspot is active during setup/recovery."
    fi
  else
    ok "Setup hotspot is not active."
  fi
fi
if [[ -f /etc/NetworkManager/dnsmasq-shared.d/autodarts-setup.conf || -f /etc/NetworkManager/dnsmasq.d/autodarts-setup.conf ]]; then
  ok "Setup DNS override config exists for auto.setup.go."
else
  warn "Setup DNS override config for auto.setup.go was not found."
fi

section "Firewall"
if have ufw; then
  run_cmd "ufw status verbose" ufw status verbose
  ufw_status="$(ufw status 2>/dev/null | head -n 1 || true)"
  [[ "$ufw_status" == *active* ]] && ok "ufw is active." || warn "ufw is not active."
elif have nft; then
  run_cmd "nft list ruleset" nft list ruleset
  if nft list ruleset 2>/dev/null | grep -q "hook input"; then
    ok "nftables input rules exist."
  else
    warn "nftables is available, but no input hook was detected."
  fi
elif have iptables; then
  run_cmd "iptables -S" iptables -S
  warn "iptables is available, but no higher-level firewall state could be verified."
else
  warn "No ufw, nft, or iptables command found."
fi

section "External exposure checks"
public_ip=""
if have curl; then
  public_ip="$(curl -fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)"
  if [[ -n "$public_ip" ]]; then
    info "Detected public IPv4 via outbound internet: $public_ip"
  else
    warn "Could not detect public IPv4 via api.ipify.org. Internet may be offline or blocked."
  fi
else
  warn "curl missing; cannot detect external public IP."
fi

if [[ -n "${AUDIT_EXTERNAL_PORTCHECK_URL:-}" ]]; then
  if [[ -n "$public_ip" ]]; then
    for port in 22 80 3180; do
      result="$(external_portcheck "$public_ip" "$port")"
      if [[ -z "$result" ]]; then
        warn "External portcheck for $public_ip:$port returned no data."
      else
        info "External portcheck $public_ip:$port => $result"
        if printf '%s' "$result" | grep -Eiq 'open|reachable|true'; then
          fail "External checker reports port $port as reachable from the internet."
        fi
      fi
    done
  else
    warn "External portcheck configured, but public IP is unknown."
  fi
else
  warn "No external portcheck URL configured. From inside the Pi, inbound internet reachability cannot be proven."
  info "Optional: set AUDIT_EXTERNAL_PORTCHECK_URL to a service URL containing {host} and {port} placeholders."
fi

section "Package and integrity hints"
if have apt-get; then
  run_cmd "apt-get -s upgrade" apt-get -s upgrade
fi
if have dpkg; then
  run_cmd "dpkg -l autodarts related packages" sh -c "dpkg -l | grep -Ei 'autodarts|chromium|network-manager|openssh|python3|raspi' || true"
fi

section "Writable and privileged file checks"
for path in /etc/autodarts-pi-os /var/lib/autodarts-pi-os /usr/local/bin; do
  if [[ -d "$path" ]]; then
    run_cmd "world writable files under $path" find "$path" -xdev -type f -perm -0002 -print
  fi
done
run_cmd "SUID/SGID files outside common system paths" sh -c "find / -xdev \\( -perm -4000 -o -perm -2000 \\) -type f 2>/dev/null | sort | head -n 200"

section "Recommendations"
log "- Keep the Pi behind a router/NAT and do not forward ports 80, 3180, or 22."
log "- Use the setup flow to replace the default admin password immediately."
log "- Keep SSH disabled unless needed; if enabled, use SSH keys and no password login."
log "- If global IPv6 is present, verify the router firewall blocks inbound connections."
log "- Treat the setup hotspot as temporary or recovery-only after setup."
log "- Re-run this audit after every release image and after network changes."

section "Summary"
log "OK:   $PASS_COUNT"
log "WARN: $WARN_COUNT"
log "FAIL: $FAIL_COUNT"
log "Output file: $OUT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 2
fi
if [[ "$WARN_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
