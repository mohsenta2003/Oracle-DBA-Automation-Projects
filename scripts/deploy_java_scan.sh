#!/bin/bash
# Deploy + run Java scan end-to-end (EE-extra style workflow)
#
# Steps:
#   1) Setup/upgrade repository tables and views
#   2) Run Java scan collection on target hosts
#   3) Generate simple final report from repository
#
# Usage:
#   bash scripts/deploy_java_scan.sh -i inv_key.yml
#   bash scripts/deploy_java_scan.sh -i inv_key.yml -l crlnxp1086
#   bash scripts/deploy_java_scan.sh -i inv_key.yml -e "run_label=Java-Weekly"
#
# Required:
#   - ansible-playbook command available
#   - sqlplus available on controller
#   - repo_password provided via env REPO_PASSWORD or prompted interactively

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

INV_FILE=""
LIMIT_ARG=""
EXTRA_VARS=""

while getopts "i:l:e:h" opt; do
  case "$opt" in
    i) INV_FILE="$OPTARG" ;;
    l) LIMIT_ARG="$OPTARG" ;;
    e) EXTRA_VARS="$OPTARG" ;;
    h)
      cat <<'USAGE'
Usage: bash scripts/deploy_java_scan.sh -i <inventory> [-l <limit>] [-e "k=v ..."]

Examples:
  bash scripts/deploy_java_scan.sh -i inv_key.yml
  bash scripts/deploy_java_scan.sh -i inv_key.yml -l crlnxp1086
  bash scripts/deploy_java_scan.sh -i inv_key.yml -e "run_label=Java-Weekly"
USAGE
      exit 0
      ;;
    *)
      echo "Invalid option. Use -h for help."
      exit 1
      ;;
  esac
done

if [ -z "$INV_FILE" ]; then
  echo "ERROR: inventory file is required. Use -i <inventory>."
  exit 1
fi

if [ ! -f "$INV_FILE" ]; then
  echo "ERROR: inventory file not found: $INV_FILE"
  exit 1
fi

if [ -z "${REPO_PASSWORD:-}" ]; then
  read -r -s -p "Repository password (repo_password): " REPO_PASSWORD
  echo ""
fi

if [ -z "$REPO_PASSWORD" ]; then
  echo "ERROR: repo_password cannot be empty."
  exit 1
fi

declare -a EXTRA_ARGS
if [ -n "$EXTRA_VARS" ]; then
  EXTRA_ARGS=(-e "$EXTRA_VARS")
else
  EXTRA_ARGS=()
fi

echo "================================================"
echo "STEP 1/3: Setup/upgrade repository schema"
echo "================================================"
ansible-playbook playbooks/_setup_java_scan_tables.yml -i "localhost," -c local \
  -e "repo_password=${REPO_PASSWORD}" \
  "${EXTRA_ARGS[@]}"

echo "================================================"
echo "STEP 2/3: Run Java scan collection"
echo "================================================"
declare -a COLLECT_CMD
COLLECT_CMD=(ansible-playbook playbooks/collect_java_footprint.yml -i "$INV_FILE" -e "repo_password=${REPO_PASSWORD}")
if [ -n "$LIMIT_ARG" ]; then
  COLLECT_CMD+=( -l "$LIMIT_ARG" )
fi
if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
  COLLECT_CMD+=( "${EXTRA_ARGS[@]}" )
fi
"${COLLECT_CMD[@]}"

echo "================================================"
echo "STEP 3/3: Generate final report"
echo "================================================"
ansible-playbook playbooks/report_java_scan_run.yml -i "$INV_FILE" \
  -e "repo_password=${REPO_PASSWORD}" \
  "${EXTRA_ARGS[@]}"

echo "================================================"
echo "DONE: Java scan deploy workflow completed"
echo "================================================"
