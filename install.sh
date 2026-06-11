#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[x]${NC} $1"; }



check_prereqs() {
  if ! command -v docker &>/dev/null; then
    err "Docker is not installed. Please install Docker Desktop from https://www.docker.com/products/docker-desktop/"
    exit 1
  fi
  ok "Docker found: $(docker --version)"

  if ! docker compose version &>/dev/null 2>&1; then
    if ! docker-compose --version &>/dev/null 2>&1; then
      err "Docker Compose is not available. Please upgrade Docker Desktop."
      exit 1
    fi
  fi
  ok "Docker Compose found"
}

ensure_dirs() {
  local profile="$1"
  local dirs=()
  [[ "$profile" == "all" || "$profile" == "bots1" ]] && dirs+=(botsv1)
  [[ "$profile" == "all" || "$profile" == "bots2" ]] && dirs+=(botsv2)
  [[ "$profile" == "all" || "$profile" == "bots3" ]] && dirs+=(botsv3)
  for ver in "${dirs[@]}"; do
    mkdir -p "$SCRIPT_DIR/apps/$ver"
  done
  ok "Directory structure ready"
}

# BOTSv1 apps
BOTS1_APPS=(
  "fortinet-fortigate-add-on-for-splunk_13.tgz"
  "splunk-add-on-for-microsoft-sysmon_810.tgz"
  "splunk-add-on-for-microsoft-windows_800.tgz"
  "splunk-app-for-stream_720-stripped.tgz"
  "splunk-ta-for-suricata_233.tgz"
  "url-toolbox_192.tgz"
  "splunk-add-on-for-tenable_514.tgz"
  "boss-of-the-soc-bots-investigation-workshop-for-splunk_122.tgz"
)

# BOTSv2 apps
BOTS2_APPS=(
  "base64_11.tgz"
  "jellyfisher_101.tgz"
  "palo-alto-networks-add-on-for-splunk_811.tgz"
  "sa-investigator-for-enterprise-security_400.tgz"
  "splunk-add-on-for-apache-web-server_210.tgz"
  "splunk-add-on-for-microsoft-cloud-services_522.tgz"
  "splunk-add-on-for-microsoft-sysmon_810.tgz"
  "splunk-add-on-for-microsoft-windows_880.tgz"
  "splunk-add-on-for-symantec-endpoint-protection_341.tgz"
  "splunk-add-on-for-unix-and-linux_850.tgz"
  "splunk-app-for-osquery_10.tgz"
  "splunk-app-for-stream_720-stripped.tgz"
  "splunk-common-information-model-cim_4180.tgz"
  "splunk-security-essentials_371.tgz"
  "splunk-ta-for-suricata_233.tgz"
  "ssl-certificate-checker_420.tgz"
  "url-toolbox_192.tgz"
  "website-monitoring_294.tgz"
  "boss-of-the-soc-bots-advanced-apt-hunting-companion-app-for-splunk_11.tgz"
  "splunk-add-on-for-microsoft-iis_130.tgz"
)

# BOTSv3 apps
BOTS3_APPS=(
  "amazon-guardduty-add-on-for-splunk_104.tgz"
  "cisco-endpoint-security-analytics-cesa_406.tgz"
  "code42-for-splunk-legacy_3012.tgz"
  "decrypt_231.tgz"
  "microsoft-365-app-for-splunk_331.tgz"
  "osquery-app-for-splunk_060.tgz"
  "sa-cim_vladiator_200.tgz"
  "splunk-add-on-for-amazon-web-services-aws_730.tgz"
  "splunk-add-on-for-cisco-asa_511.tgz"
  "splunk-add-on-for-microsoft-azure_403.tgz"
  "splunk-add-on-for-microsoft-cloud-services_522.tgz"
  "splunk-add-on-for-microsoft-office-365_430.tgz"
  "splunk-add-on-for-microsoft-office-365-reporting-web-service_201.tgz"
  "splunk-add-on-for-microsoft-sysmon_1062.tgz"
  "splunk-add-on-for-microsoft-windows_880.tgz"
  "splunk-add-on-for-symantec-endpoint-protection_341.tgz"
  "splunk-add-on-for-tenable_514.tgz"
  "splunk-add-on-for-unix-and-linux_850.tgz"
  "splunk-app-for-stream_811.tgz"
  "splunk-common-information-model-cim_4180.tgz"
  "splunk-es-content-update_4300.tgz"
  "splunk-security-essentials_371.tgz"
  "ta-for-code42-app-for-splunk_3012.tgz"
  "url-toolbox_192.tgz"
  "virustotal-workflow-actions-for-splunk_020.tgz"
)

verify_apps() {
  local ver="$1"
  shift
  local apps=("$@")
  local dest="$SCRIPT_DIR/apps/$ver"
  local count=0

  for app in "${apps[@]}"; do
    local filepath="$dest/$app"
    if [[ -f "$filepath" ]]; then
      echo -e "  ${GREEN}✓${NC} $app"
      count=$((count + 1))
    else
      echo -e "  ${RED}✗${NC} $app (missing — re-clone the repo)"
    fi
  done
  echo ""
  info "Found $count/${#apps[@]} apps for $ver"
  if [[ "$count" -ne "${#apps[@]}" ]]; then
    err "Missing apps — please re-clone the repository to get all files."
    exit 1
  fi
}

configure_password() {
  if grep -q "^SPLUNK_PASSWORD=changeme" "$SCRIPT_DIR/.env" 2>/dev/null; then
    echo ""
    warn "Default password is 'changeme'"
    read -r -p "Enter a new admin password (leave blank to keep 'changeme'): " pw
    if [[ -n "$pw" ]]; then
      if [[ ${#pw} -lt 8 ]]; then
        err "Password must be at least 8 characters"
        configure_password
        return
      fi
      if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s/^SPLUNK_PASSWORD=.*/SPLUNK_PASSWORD=$pw/" "$SCRIPT_DIR/.env"
      else
        sed -i "s/^SPLUNK_PASSWORD=.*/SPLUNK_PASSWORD=$pw/" "$SCRIPT_DIR/.env"
      fi
      ok "Password updated in .env"
    fi
  fi
}

start_containers() {
  local profile="${1:-all}"
  echo ""
  info "Pulling Splunk image (this may take a while on ARM Macs)..."
  docker pull splunk/splunk:8.2.3 --platform linux/amd64
  echo ""
  info "Starting containers..."
  case "$profile" in
    all)     docker compose up -d ;;
    bots1)   docker compose up -d bots1 ;;
    bots2)   docker compose up -d bots2 ;;
    bots3)   docker compose up -d bots3 ;;
    *)
      err "Unknown profile: $profile. Use all, bots1, bots2, or bots3."
      exit 1
      ;;
  esac
}

show_summary() {
  local profile="${1:-all}"
  local pw p1 p2 p3
  pw=$(grep -o 'SPLUNK_PASSWORD=[^ ]*' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2 || echo 'changeme')
  p1=$(grep -o 'BOTS1_PORT=[^ ]*' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "8080")
  p2=$(grep -o 'BOTS2_PORT=[^ ]*' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "8081")
  p3=$(grep -o 'BOTS3_PORT=[^ ]*' "$SCRIPT_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "8082")

  echo ""
  echo -e "${CYAN}══════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  BOSS of the SOC - Docker Setup Complete${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════${NC}"
  echo ""
  if [[ "$profile" == "all" || "$profile" == "bots1" ]]; then
    echo "  BOTSv1: http://localhost:${p1}"
  fi
  if [[ "$profile" == "all" || "$profile" == "bots2" ]]; then
    echo "  BOTSv2: http://localhost:${p2}"
  fi
  if [[ "$profile" == "all" || "$profile" == "bots3" ]]; then
    echo "  BOTSv3: http://localhost:${p3}"
  fi
  echo ""
  echo "  Username: admin"
  echo "  Password: $pw"
  echo ""
  echo -e "  ${YELLOW}Note: First boot takes 5-15 minutes to download${NC}"
  echo -e "  ${YELLOW}datasets and install apps on initial startup.${NC}"
  echo ""
  echo -e "  ${YELLOW}Containers have a 30-day trial license. To reset,${NC}"
  echo -e "  ${YELLOW}run: docker compose down && docker compose up -d${NC}"
  echo ""
  echo -e "  ${CYAN}To stop:   docker compose down${NC}"
  echo -e "  ${CYAN}To view logs: docker compose logs -f <service>${NC}"
  echo ""
}

main() {
  local profile="${1:-all}"

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  BOSS of the SOC - Docker Installer         ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo ""

  info "Checking prerequisites..."
  check_prereqs

  info "Setting up directories..."
  ensure_dirs "$profile"

  if [[ "$profile" == "all" || "$profile" == "bots1" ]]; then
    info "Verifying BOTSv1 apps..."
    verify_apps "botsv1" "${BOTS1_APPS[@]}"
  fi
  if [[ "$profile" == "all" || "$profile" == "bots2" ]]; then
    info "Verifying BOTSv2 apps..."
    verify_apps "botsv2" "${BOTS2_APPS[@]}"
  fi
  if [[ "$profile" == "all" || "$profile" == "bots3" ]]; then
    info "Verifying BOTSv3 apps..."
    verify_apps "botsv3" "${BOTS3_APPS[@]}"
  fi

  configure_password

  start_containers "$profile"

  show_summary "$profile"
}

main "$@"
