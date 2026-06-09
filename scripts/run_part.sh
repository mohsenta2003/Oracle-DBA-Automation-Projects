#!/bin/bash
# =============================================================================
# run_part.sh  —  Short-command wrapper for check_partitioning playbook
#
# Usage:
#   ./scripts/run_part.sh <target> [db_sid] [extra-ansible-args...]
#
# Targets (short names → inventory group or host):
#   all             All hosts in the estate
#   eu              All EU Linux + AIX
#   eu-linux        All EU Linux (NL + UK)
#   eu-nl           EU Netherlands Linux only
#   eu-uk           EU United Kingdom Linux only
#   eu-aix          All EU AIX servers
#   us              All US Linux servers
#   aix             All AIX servers (EU + TLP)
#   tlp             All TLP AIX servers
#   prod            All production servers
#   nonprod         All non-production servers
#   host <name>     Single specific host (e.g.: host crlnxp316)
#   hosts <a,b,...> Comma-separated list of hosts
#
# Optional:
#   Second arg (after non-host target): limits to a specific SID
#   Any remaining args are passed directly to ansible-playbook
#
# Examples:
#   ./scripts/run_part.sh all
#   ./scripts/run_part.sh eu-linux
#   ./scripts/run_part.sh eu-aix
#   ./scripts/run_part.sh host crlnxp316
#   ./scripts/run_part.sh host crlnxd2201 MYDB
#   ./scripts/run_part.sh hosts crlnxp316,uklnxpuk1015
#   ./scripts/run_part.sh eu-linux "" -v
#   ./scripts/run_part.sh eu-linux "" --check
#   ./scripts/run_part.sh us "" -e "oracle_user=svcorap"
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

PLAYBOOK="playbooks/check_partitioning.yml"
INVENTORY="${INVENTORY:-inv_key.yml}"

# Pick inventory based on group (TLP needs password auth)
TARGET="${1:-all}"
SID_ARG=""
LIMIT_ARG=""
EXTRA_ARGS=()

# --- Map short name to inventory group or host ---
case "${TARGET}" in
  all)         LIMIT_ARG="all" ;;
  eu)          LIMIT_ARG="all_eu_linux:all_eu_aix" ;;
  eu-linux)    LIMIT_ARG="all_eu_linux" ;;
  eu-nl)       LIMIT_ARG="eu_nl_lnx_prod:eu_nl_lnx_nonprod" ;;
  eu-uk)       LIMIT_ARG="eu_uk_lnx_prod:eu_uk_lnx_nonprod" ;;
  eu-aix)      LIMIT_ARG="all_aix_prod:all_aix_nonprod" ;;
  us)          LIMIT_ARG="all_us" ;;
  aix)         LIMIT_ARG="all_aix_prod:all_aix_nonprod:all_tlp" ;;
  tlp)         LIMIT_ARG="all_tlp"; INVENTORY="inv_pas.yml" ;;
  prod)        LIMIT_ARG="eu_nl_lnx_prod:eu_uk_lnx_prod:all_aix_prod:us_lnx_prod:tlp_aix_prod" ;;
  nonprod)     LIMIT_ARG="eu_nl_lnx_nonprod:eu_uk_lnx_nonprod:all_aix_nonprod:us_lnx_test:tlp_aix_nonprod" ;;
  host)
    if [ -z "$2" ]; then
      echo "ERROR: 'host' target requires a hostname. Example: ./run_part.sh host crlnxp316"
      exit 1
    fi
    LIMIT_ARG="$2"
    SID_ARG="$3"
    shift 2
    EXTRA_ARGS=("${@:2}")
    shift $((${#EXTRA_ARGS[@]} + 0))
    ;;
  hosts)
    if [ -z "$2" ]; then
      echo "ERROR: 'hosts' target requires hostnames. Example: ./run_part.sh hosts host1,host2"
      exit 1
    fi
    LIMIT_ARG="$2"
    shift 2
    EXTRA_ARGS=("$@")
    ;;
  *)
    # Treat unknown as a direct host/group name
    LIMIT_ARG="${TARGET}"
    ;;
esac

# For non-host/hosts targets, second arg is optional SID, rest are extra args
if [[ "${TARGET}" != "host" && "${TARGET}" != "hosts" ]]; then
  SID_ARG="${2:-}"
  shift 2 2>/dev/null || shift $# 2>/dev/null || true
  EXTRA_ARGS=("$@")
fi

# --- Build command ---
CMD=("ansible-playbook" "${PLAYBOOK}" "-i" "${INVENTORY}" "-l" "${LIMIT_ARG}")

if [ -n "${SID_ARG}" ]; then
  CMD+=("-e" "db_sid=${SID_ARG}")
fi

CMD+=("${EXTRA_ARGS[@]}")

# --- Print and run ---
echo "============================================================"
echo "  Oracle DBA - Partitioning Check"
echo "  Target  : ${LIMIT_ARG}"
echo "  SID     : ${SID_ARG:-auto-detect all}"
echo "  Inventory: ${INVENTORY}"
echo "  Command :"
echo "    ${CMD[*]}"
echo "============================================================"
echo ""

exec "${CMD[@]}"
