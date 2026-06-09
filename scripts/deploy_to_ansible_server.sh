#!/bin/bash
# =============================================================================
# deploy_to_ansible_server.sh
# Copies the Oracle DBA Ansible project to the Ansible control server.
#
# Usage:
#   ./scripts/deploy_to_ansible_server.sh
#   ./scripts/deploy_to_ansible_server.sh <target_server>
#   ./scripts/deploy_to_ansible_server.sh <target_server> <target_path>
#
# Examples:
#   ./scripts/deploy_to_ansible_server.sh
#   ./scripts/deploy_to_ansible_server.sh ansible-ctrl01
#   ./scripts/deploy_to_ansible_server.sh ansible-ctrl01 /opt/ansible/oracle-dba
# =============================================================================

set -e

# --- Configuration (override via args or env vars) --------------------------
ANSIBLE_SERVER="${1:-${ANSIBLE_SERVER:-ansible-ctrl01}}"
REMOTE_PATH="${2:-${REMOTE_PATH:-/opt/ansible/oracle-dba}}"
REMOTE_USER="${REMOTE_USER:-oracle}"
SSH_KEY="${SSH_KEY:-~/.ssh/id_rsa}"

# Script must be run from project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "============================================================"
echo "  Oracle DBA Ansible - Deploy to Control Server"
echo "============================================================"
echo "  Source : ${PROJECT_ROOT}"
echo "  Target : ${REMOTE_USER}@${ANSIBLE_SERVER}:${REMOTE_PATH}"
echo "============================================================"

# --- Create remote directory structure first ---------------------------------
echo "[1/3] Creating remote directory structure..."
ssh -i "${SSH_KEY}" "${REMOTE_USER}@${ANSIBLE_SERVER}" \
  "mkdir -p ${REMOTE_PATH}/{playbooks,roles,reports,scripts,library}"

# --- Rsync only what is needed -----------------------------------------------
# Excluded: .git, .vscode, tests/, ansible-oracle-modules-master/
echo "[2/3] Syncing files..."
rsync -avz --delete \
  --exclude='.git' \
  --exclude='.vscode' \
  --exclude='tests/' \
  --exclude='ansible-oracle-modules-master/' \
  --exclude='reports/' \
  --exclude='*.pyc' \
  --exclude='__pycache__/' \
  --include='playbooks/***' \
  --include='roles/oracle_partitioning/***' \
  --include='roles/oracle_security_check/***' \
  --include='roles/oracle_monitor/***' \
  --include='roles/oracle_compliance/***' \
  --include='roles/oracle_tablespace/***' \
  --include='roles/oracle_wait_events/***' \
  --include='roles/oracle_backup/***' \
  --include='roles/oracle_patch/***' \
  --include='roles/oracle_user/***' \
  --include='library/***' \
  --include='scripts/***' \
  --include='ansible.cfg' \
  --include='inv_key.yml' \
  --include='inv_pas.yml' \
  --include='inv_var.yml' \
  --include='README.md' \
  --exclude='roles/*' \
  -e "ssh -i ${SSH_KEY}" \
  "${PROJECT_ROOT}/" \
  "${REMOTE_USER}@${ANSIBLE_SERVER}:${REMOTE_PATH}/"

# --- Set permissions on scripts ----------------------------------------------
echo "[3/3] Setting script permissions..."
ssh -i "${SSH_KEY}" "${REMOTE_USER}@${ANSIBLE_SERVER}" \
  "chmod +x ${REMOTE_PATH}/scripts/*.sh 2>/dev/null || true"

echo ""
echo "============================================================"
echo "  Deploy complete!"
echo ""
echo "  To run on the server:"
echo "    ssh ${REMOTE_USER}@${ANSIBLE_SERVER}"
echo "    cd ${REMOTE_PATH}"
echo "    ./scripts/run_part.sh all"
echo "    ./scripts/run_part.sh eu-linux"
echo "    ./scripts/run_part.sh host crlnxp316"
echo "============================================================"
