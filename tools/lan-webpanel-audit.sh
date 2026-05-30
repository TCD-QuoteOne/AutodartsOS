#!/usr/bin/env bash
set -uo pipefail

VERSION="1.0"
TARGET="${1:-}"
DEFAULT_OUT="./autodarts-lan-webpanel-audit-$(date +%Y%m%d-%H%M%S).txt"
OUT="${2:-${AUDIT_OUT:-$DEFAULT_OUT}}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
LAST_RESULT=""

usage() {
  cat <<'EOF'
Usage:
  ./tools/lan-webpanel-audit.sh <pi-url-or-host> [output-file]

Run this from a computer in the same network as the Raspberry Pi.
From Windows PowerShell with Git Bash installed:

  bash ./tools/lan-webpanel-audit.sh http://autodarts-pi.local
  bash ./tools/lan-webpanel-audit.sh http://192.168.1.124

The script is read-only. It checks whether the develop-security webpanel
changes are visible from the local network and writes a result file that can
be shared for review.
EOF
}

if [[ -z "$TARGET" || "$TARGET" == "-h" || "$TARGET" == "--help" ]]; then
  usage
  exit 1
fi

if [[ "$TARGET" != http://* && "$TARGET" != https://* ]]; then
  TARGET="http://${TARGET}"
fi
TARGET="${TARGET%/}"

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

need_cmd() {
  if ! have "$1"; then
    fail "Required command missing: $1"
    return 1
  fi
  return 0
}

safe_name() {
  printf '%s' "$1" | sed 's#[^A-Za-z0-9._-]#_#g'
}

fetch() {
  local path="$1"
  local name="$2"
  local url="${TARGET}${path}"
  local base="/tmp/autodarts-lan-audit-$(safe_name "$name")"
  local body="${base}.body"
  local headers="${base}.headers"
  local meta="${base}.meta"

  curl -ksS \
    --connect-timeout 4 \
    --max-time 10 \
    --location \
    --max-redirs 3 \
    --dump-header "$headers" \
    --output "$body" \
    --write-out 'http_code=%{http_code}\nremote_ip=%{remote_ip}\nurl_effective=%{url_effective}\ncontent_type=%{content_type}\nsize_download=%{size_download}\n' \
    "$url" > "$meta" 2>> "$OUT"

  printf '%s\n' "$body|$headers|$meta|$url"
}

meta_value() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key {print $2; exit}' "$file" 2>/dev/null
}

contains() {
  local file="$1"
  local pattern="$2"
  grep -Eiq "$pattern" "$file" 2>/dev/null
}

assert_http() {
  local path="$1"
  local name="$2"
  local expected_regex="$3"
  local result body headers meta url code ctype effective
  result="$(fetch "$path" "$name")"
  IFS='|' read -r body headers meta url <<< "$result"
  code="$(meta_value http_code "$meta")"
  ctype="$(meta_value content_type "$meta")"
  effective="$(meta_value url_effective "$meta")"

  blank
  log "Check: $name"
  log "URL: $url"
  log "HTTP: ${code:-none}"
  log "Content-Type: ${ctype:-unknown}"
  log "Effective URL: ${effective:-unknown}"

  if [[ "$code" =~ $expected_regex ]]; then
    ok "$name returned expected HTTP code ($code)."
  elif [[ "$code" == "000" || -z "$code" ]]; then
    fail "$name is not reachable."
  else
    warn "$name returned unexpected HTTP code ($code)."
  fi

  log "Body preview:"
  sed -n '1,35p' "$body" 2>/dev/null | sed 's/^/  /' | tee -a "$OUT" >/dev/null
  LAST_RESULT="$body|$headers|$meta|$url"
}

assert_body() {
  local file="$1"
  local label="$2"
  local pattern="$3"
  if contains "$file" "$pattern"; then
    ok "$label found."
  else
    fail "$label missing."
  fi
}

assert_body_warn() {
  local file="$1"
  local label="$2"
  local pattern="$3"
  if contains "$file" "$pattern"; then
    ok "$label found."
  else
    warn "$label missing."
  fi
}

extract_body() {
  local result="$1"
  IFS='|' read -r body _headers _meta _url <<< "$result"
  printf '%s' "$body"
}

extract_meta() {
  local result="$1"
  IFS='|' read -r _body _headers meta _url <<< "$result"
  printf '%s' "$meta"
}

log "Autodarts Pi OS LAN Webpanel Audit"
log "Version: $VERSION"
log "Date: $(date -Is 2>/dev/null || date)"
log "Runner: $(hostname 2>/dev/null || echo unknown)"
log "Target: $TARGET"
log "Output: $OUT"
blank
log "This script is read-only. It does not log in and does not change the Raspberry Pi."
log "It checks whether the develop-security webpanel and toolbar routes are visible in the local network."

section "Preflight"
need_cmd curl || true
if ! have curl; then
  section "Summary"
  log "OK:   $PASS_COUNT"
  log "WARN: $WARN_COUNT"
  log "FAIL: $FAIL_COUNT"
  exit 2
fi

if have getent; then
  host="${TARGET#http://}"
  host="${host#https://}"
  host="${host%%/*}"
  host="${host%%:*}"
  resolved="$(getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ')"
  [[ -n "$resolved" ]] && info "Resolved $host to: $resolved" || warn "Could not resolve $host via getent."
fi

section "Core pages"
assert_http "/" "root redirect or page" "^(200|301|302|303)$"
root_result="$LAST_RESULT"
root_body="$(extract_body "$root_result")"
root_meta="$(extract_meta "$root_result")"
root_effective="$(meta_value url_effective "$root_meta")"
info "Root effective URL: ${root_effective:-unknown}"

assert_http "/setup" "setup page" "^(200|301|302|303)$"
setup_result="$LAST_RESULT"
setup_body="$(extract_body "$setup_result")"
assert_body_warn "$setup_body" "Autodarts Pi OS branding on setup/login" "Autodarts Pi OS|Setup-Passwort|Admin-Passwort|Einloggen"
assert_body_warn "$setup_body" "Ko-fi support link uses app wrapper" "/app\\?target=kofi"

assert_http "/kiosk" "kiosk page" "^(200|301|302|303)$"
kiosk_result="$LAST_RESULT"
kiosk_body="$(extract_body "$kiosk_result")"
if contains "$kiosk_body" "Autodarts Pi OS ist bereit|/app\\?target=manager|/app\\?target=config"; then
  ok "Kiosk overview or redirect target looks correct."
else
  warn "Kiosk page does not show the configured overview. Device may still be in setup mode."
fi

section "Toolbar wrapper routes"
for target in manager config play kofi health log-kiosk log-network log-firstboot log-install; do
  assert_http "/app?target=${target}" "toolbar target ${target}" "^(200)$"
  result="$LAST_RESULT"
  body="$(extract_body "$result")"
  assert_body "$body" "Toolbar shell for ${target}" "<nav class=\"bar\">"
  assert_body "$body" "Home button for ${target}" "href=\"/kiosk\""
  assert_body "$body" "Manager button for ${target}" "href=\"/app\\?target=manager\""
  assert_body "$body" "Kamera-Setup button for ${target}" "href=\"/app\\?target=config\""
  assert_body "$body" "Play button for ${target}" "href=\"/app\\?target=play\""
  assert_body "$body" "Ko-fi button for ${target}" "href=\"/app\\?target=kofi\""
done

section "Wrapped utility content"
assert_http "/app?target=health" "health wrapper" "^(200)$"
health_shell="$LAST_RESULT"
health_shell_body="$(extract_body "$health_shell")"
assert_body "$health_shell_body" "health iframe source" "iframe src=\"/health.json\""

assert_http "/app?target=log-kiosk" "kiosk log wrapper" "^(200)$"
kiosk_log_shell="$LAST_RESULT"
kiosk_log_shell_body="$(extract_body "$kiosk_log_shell")"
assert_body "$kiosk_log_shell_body" "kiosk log iframe source" "iframe src=\"/logs/kiosk\""

assert_http "/app?target=play" "Autodarts Play wrapper" "^(200)$"
play_shell="$LAST_RESULT"
play_shell_body="$(extract_body "$play_shell")"
assert_body "$play_shell_body" "Autodarts Play iframe source" "iframe src=\"https://play.autodarts.io"

assert_http "/app?target=kofi" "Ko-fi wrapper" "^(200)$"
kofi_shell="$LAST_RESULT"
kofi_shell_body="$(extract_body "$kofi_shell")"
assert_body "$kofi_shell_body" "Ko-fi local support frame iframe source" "iframe src=\"/support-frame\""

assert_http "/support-frame" "Ko-fi support frame" "^(200)$"
support_result="$LAST_RESULT"
support_body="$(extract_body "$support_result")"
assert_body "$support_body" "Ko-fi outbound link" "https://ko-fi.com/autodartsos"

section "Raw API and log endpoints"
assert_http "/health.json" "raw health.json" "^(200|301|302|303)$"
health_result="$LAST_RESULT"
health_body="$(extract_body "$health_result")"
if contains "$health_body" "\"config\"|\"network\"|\"services\""; then
  ok "Raw health.json returns JSON-like diagnostics."
else
  warn "Raw health.json did not return expected diagnostics. Login or setup mode may affect output."
fi

for path in "/logs/kiosk" "/logs/network" "/logs/firstboot" "/logs/install"; do
  assert_http "$path" "raw ${path}" "^(200|301|302|303)$"
  result="$LAST_RESULT"
  meta="$(extract_meta "$result")"
  code="$(meta_value http_code "$meta")"
  if [[ "$code" == "200" ]]; then
    warn "Raw ${path} is directly readable. This may be expected after local authentication, but UI should use toolbar wrapper."
  else
    ok "Raw ${path} is not directly dumped without redirect/status handling."
  fi
done

section "Mobile menu markers"
page_for_mobile="$setup_body"
if contains "$kiosk_body" "mobile-nav"; then
  page_for_mobile="$kiosk_body"
fi
assert_body_warn "$page_for_mobile" "Mobile dropdown navigation markup" "class=\"mobile-nav\""
assert_body_warn "$page_for_mobile" "Desktop tab navigation still present" "class=\"tabs\""

section "Manual interpretation"
log "- If toolbar targets show '<nav class=\"bar\">', the taskbar wrapper is active."
log "- If /app?target=kofi contains iframe src=\"/support-frame\", Ko-fi stays inside the toolbar flow."
log "- If /health.json is raw JSON directly, that is OK; UI links should point to /app?target=health."
log "- If /kiosk redirects to /setup, the Pi is still in setup mode. The wrapper checks can still be valid."
log "- Send this full output file back for analysis if anything is WARN or FAIL."

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
