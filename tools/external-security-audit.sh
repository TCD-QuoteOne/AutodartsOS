#!/usr/bin/env bash
set -uo pipefail

VERSION="1.0"
TARGET="${1:-}"
DEFAULT_OUT="./autodarts-external-security-audit-$(date +%Y%m%d-%H%M%S).txt"
OUT="${2:-${AUDIT_OUT:-$DEFAULT_OUT}}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<'EOF'
Usage:
  ./tools/external-security-audit.sh <public-ip-or-hostname> [output-file]

Run this from outside the customer's network, for example from a VPS,
mobile hotspot, or another internet connection. The script is read-only and
checks whether Autodarts Pi OS services are reachable from the internet.

Examples:
  ./tools/external-security-audit.sh 203.0.113.10
  ./tools/external-security-audit.sh darts.example.com audit.txt

Expected secure result:
  Ports 22, 80, 3180 and setup endpoints should not be reachable from the
  public internet. A HTTP 403 from the webpanel is better than open access,
  but still means traffic is reaching the device/router.
EOF
}

if [[ -z "$TARGET" || "$TARGET" == "-h" || "$TARGET" == "--help" ]]; then
  usage
  exit 1
fi

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

is_private_target() {
  local host="$1"
  [[ "$host" =~ ^10\. ]] && return 0
  [[ "$host" =~ ^192\.168\. ]] && return 0
  [[ "$host" =~ ^172\.1[6-9]\. ]] && return 0
  [[ "$host" =~ ^172\.2[0-9]\. ]] && return 0
  [[ "$host" =~ ^172\.3[0-1]\. ]] && return 0
  [[ "$host" =~ ^127\. ]] && return 0
  [[ "$host" =~ ^169\.254\. ]] && return 0
  [[ "$host" =~ ^10\.42\.0\. ]] && return 0
  [[ "${host,,}" == localhost ]] && return 0
  [[ "${host,,}" == *.local ]] && return 0
  return 1
}

resolve_target() {
  if have getent; then
    getent ahosts "$TARGET" 2>/dev/null | awk '{print $1}' | sort -u
  elif have dig; then
    dig +short "$TARGET" A "$TARGET" AAAA 2>/dev/null | sort -u
  elif have nslookup; then
    nslookup "$TARGET" 2>/dev/null | awk '/^Address: /{print $2}' | sort -u
  fi
}

port_open() {
  local host="$1"
  local port="$2"
  if have nc; then
    nc -z -w 3 "$host" "$port" >/dev/null 2>&1
    return $?
  fi
  if have timeout; then
    timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" >/dev/null 2>&1
    return $?
  fi
  bash -c "cat < /dev/null > /dev/tcp/$host/$port" >/dev/null 2>&1
}

curl_probe() {
  local url="$1"
  local body_file="$2"
  local header_file="$3"
  local meta_file="$4"
  if ! have curl; then
    echo "curl_missing" > "$meta_file"
    return 1
  fi
  curl -ksS \
    --connect-timeout 4 \
    --max-time 8 \
    --location \
    --max-redirs 2 \
    --dump-header "$header_file" \
    --output "$body_file" \
    --write-out 'http_code=%{http_code}\nremote_ip=%{remote_ip}\nurl_effective=%{url_effective}\ncontent_type=%{content_type}\n' \
    "$url" > "$meta_file" 2>> "$OUT"
}

meta_value() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key {print $2; exit}' "$file" 2>/dev/null
}

assess_http_path() {
  local scheme="$1"
  local port="$2"
  local path="$3"
  local label="$4"
  local url="${scheme}://${TARGET}:${port}${path}"
  local safe_label
  safe_label="$(printf '%s-%s-%s' "$scheme" "$port" "$path" | tr '/:?&=' '______')"
  local body="/tmp/autodarts-external-audit-${safe_label}.body"
  local headers="/tmp/autodarts-external-audit-${safe_label}.headers"
  local meta="/tmp/autodarts-external-audit-${safe_label}.meta"

  curl_probe "$url" "$body" "$headers" "$meta"
  local code
  code="$(meta_value http_code "$meta")"
  local effective
  effective="$(meta_value url_effective "$meta")"

  if [[ -z "$code" || "$code" == "000" || "$code" == "curl_missing" ]]; then
    ok "$label is not reachable at $url."
    return
  fi

  local body_hint=""
  if grep -Eiq 'Autodarts Pi OS|Autodarts-Setup|auto\.setup\.go|Setup-Passwort|Admin-Passwort|Kamera-Setup' "$body" 2>/dev/null; then
    body_hint=" Autodarts Pi OS signature detected."
  fi

  if [[ "$code" == "403" ]]; then
    warn "$label returned HTTP 403 at $url. Public filter blocks access, but traffic reaches the endpoint.${body_hint}"
  elif [[ "$code" =~ ^(401|404)$ ]]; then
    warn "$label returned HTTP $code at $url. Service appears reachable from outside.${body_hint}"
  elif [[ "$code" =~ ^(200|201|202|204|301|302|303|307|308)$ ]]; then
    fail "$label is reachable from outside: HTTP $code at $url -> ${effective:-unknown}.${body_hint}"
  else
    warn "$label returned HTTP $code at $url.${body_hint}"
  fi

  log "Headers for $url:"
  sed -n '1,20p' "$headers" 2>/dev/null | tee -a "$OUT" >/dev/null
}

log "Autodarts Pi OS External Security Audit"
log "Version: $VERSION"
log "Date: $(date -Is 2>/dev/null || date)"
log "Runner: $(hostname 2>/dev/null || echo unknown)"
log "Target: $TARGET"
log "Output: $OUT"
blank
log "This script is read-only. It performs light connectivity and HTTP checks only."
log "Run it from outside the target network for meaningful external results."

section "Target sanity"
if is_private_target "$TARGET"; then
  warn "Target looks private/local ($TARGET). This is not a true external internet test unless you intentionally use VPN or a routed private network."
else
  ok "Target does not look like a private/local address."
fi

resolved="$(resolve_target)"
if [[ -n "$resolved" ]]; then
  ok "Target resolves:"
  printf '%s\n' "$resolved" | tee -a "$OUT" >/dev/null
else
  warn "Target could not be resolved locally. Direct IP targets can still work."
fi

if have ping; then
  if ping -c 1 -W 2 "$TARGET" >/dev/null 2>&1; then
    info "ICMP ping responds. This is not a security issue by itself."
  else
    info "ICMP ping does not respond. Many routers block ping; this is normal."
  fi
fi

section "Port exposure"
declare -A port_labels=(
  [22]="SSH"
  [53]="DNS"
  [67]="DHCP"
  [80]="Webpanel HTTP"
  [443]="HTTPS"
  [8080]="Alternate HTTP"
  [3180]="Autodarts Manager"
)

for port in 22 53 67 80 443 8080 3180; do
  label="${port_labels[$port]}"
  if port_open "$TARGET" "$port"; then
    case "$port" in
      22)
        fail "Port 22 ($label) is reachable from outside. Disable router forwarding or require strict key-only maintenance access."
        ;;
      80)
        warn "Port 80 ($label) is reachable from outside. The app may still reject public IPs, but router forwarding should usually be removed."
        ;;
      3180)
        fail "Port 3180 ($label) is reachable from outside. Do not expose the Autodarts Manager directly."
        ;;
      53|67)
        fail "Port $port ($label) is reachable from outside. Setup DNS/DHCP must never be exposed to the internet."
        ;;
      *)
        warn "Port $port ($label) is reachable from outside. Confirm this is intended."
        ;;
    esac
  else
    ok "Port $port ($label) is not reachable from outside."
  fi
done

section "HTTP endpoint exposure"
assess_http_path "http" "80" "/" "Root web endpoint"
assess_http_path "http" "80" "/setup" "Setup page"
assess_http_path "http" "80" "/admin" "Admin page"
assess_http_path "http" "80" "/health.json" "Health endpoint"
assess_http_path "http" "80" "/kiosk" "Kiosk portal"
assess_http_path "http" "80" "/logs/kiosk" "Kiosk log endpoint"
assess_http_path "http" "3180" "/" "Autodarts Manager"
assess_http_path "http" "3180" "/config" "Autodarts camera config"

section "TLS and certificate hints"
if port_open "$TARGET" 443; then
  if have openssl; then
    blank
    log "\$ openssl s_client -connect ${TARGET}:443 -servername ${TARGET}"
    timeout 8 openssl s_client -connect "${TARGET}:443" -servername "$TARGET" </dev/null 2>/dev/null \
      | sed -n '/Certificate chain/,/---/p;/subject=/p;/issuer=/p;/Verify return code/p' \
      | tee -a "$OUT" >/dev/null || true
  else
    warn "openssl is missing; cannot inspect HTTPS certificate."
  fi
else
  ok "HTTPS port 443 is not reachable."
fi

section "Risk interpretation"
log "- OK: Public internet cannot reach the checked service."
log "- WARN: Something responded, but it may be blocked by application logic or may be intentionally exposed."
log "- FAIL: A sensitive service appears reachable from outside and should be fixed before release/customer use."
log "- Best target state for Autodarts Pi OS: no public access to 22, 80, 3180, 53, or 67."

section "Recommended fixes if FAIL appears"
log "- Remove router port forwarding to the Raspberry Pi."
log "- Disable UPnP port mappings on the router if they expose the Pi."
log "- Keep the Pi behind NAT/firewall and access it only from the local network or via a controlled VPN."
log "- Do not expose Autodarts Manager port 3180 directly."
log "- Keep SSH disabled unless needed; if needed, use key-only access and restrict source IPs."

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
