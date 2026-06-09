# 🚀 Oracle DBA Automation Projects

[![Ansible](https://img.shields.io/badge/Ansible-2.9+-ee0000.svg?style=for-the-badge&logo=ansible)](https://www.ansible.com/)
[![Oracle](https://img.shields.io/badge/Oracle-19c-F80000.svg?style=for-the-badge&logo=oracle)](https://www.oracle.com/database/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20AIX-lightgrey.svg?style=for-the-badge)](https://www.linux.org/)

A comprehensive suite of Ansible playbooks designed for enterprise-grade automation of Oracle 19c database administration. This project streamlines complex tasks like environment setup, patching, compliance, and multi-instance monitoring.

---

## 🌟 Key Features

*   **🛡️ Security Compliance Dashboard**: Detailed auditing of Advanced Security Options (TDE, Redaction) with beautiful HTML reports.
*   **🤖 Smart Auto-Detection**: Zero-configuration required—automatically detects Oracle users, `ORACLE_HOME`, and all running SIDs.
*   **🏢 Enterprise Multi-Instance Support**: Simultaneously manages multiple database instances on a single host.
*   **🌍 Global Ready (EU/US)**: Specialized handling for long usernames and complex process structures (e.g., ASM/Grid Infrastructure exclusion).
*   **⚡ Optimized Performance**: High-speed discovery and feature usage sampling with integrated session-level tuning.
*   **📊 Unified Reporting**: Consolidated HTML, CSV, and Text reports for license analysis and health checks.

---

## 🔝 Recent Updates

### 🚀 EU Server Support & Username Fixes (Feb 2026)
- **Non-Truncated Detection**: New `ps -eo user:32` logic ensures long Oracle usernames (e.g., `svcorapeu`) are captured without truncation.
- **ASM/Grid Exclusion**: Refined pmon detection specifically targets database instances (`ora_pmon_`) while intelligently excluding ASM processes (`asm_pmon_`).
- **Enhanced Connection Resilience**: Added detailed debug logging for `sqlplus` connection failures to provide immediate visibility into configuration issues.

---

## 📂 Project Structure

| Area | Description |
| :--- | :--- |
| **`playbooks/`** | Entry-point YAML files for all DBA operations. |
| **`roles/`** | Modular, reusable automation logic for monitoring, security, and more. |
| **`library/`** | 29+ native [cx_Oracle modules](https://github.com/oravirt/ansible-oracle-modules) for idempotent DDL. |
| **`reports/`** | Auto-generated timestamped reports in HTML, CSV, and Text formats. |

---

## 🛠️ Main Playbooks

| Playbook | Purpose | Core Feature | Documentation |
| :--- | :--- | :--- | :--- |
| **`collect_oracle_options.yml`** | Enterprise License Audit | Full EE License Compliance & Feature Usage | [README](roles/oracle_options_audit/README.md) |
| **`check_advanced_security.yml`** | Security Compliance Audit | TDE/Redaction Stats | [README](playbooks/README_check_advanced_security.md) |
| **`check_partitioning.yml`** | Partitioning License Audit | 11g–19c, Per-instance + Consolidated HTML | [README](playbooks/README_check_partitioning.md) |
| **`monitor_oracle.yml`** | Health Monitoring | Auto-instance Status | [README](playbooks/README_monitor_oracle.md) |
| **`manage_tablespace.yml`** | Storage Management | GB/TB Scaling | [README](playbooks/README_manage_tablespace.md) |
| **`manage_users.yml`** | User Administration | Lock/Unlock, Provision | [README](playbooks/README_manage_users.md) |
| **`detect_wait_events.yml`** | Performance Tuning | Wait Event Analysis | [README](playbooks/README_detect_wait_events.md) |

---

## 🚀 Quick Start

### 1. Security Compliance Audit
Detect TDE and Data Redaction usage across your estate:
```bash
# Check all EU servers
ansible-playbook playbooks/check_advanced_security.yml -i inv_key.yml -l all_eu_linux
```

### 2. Database Health Check
```bash
ansible-playbook playbooks/monitor_oracle.yml --limit crlnxd2201
```

### 3. Java Footprint Audit (US/EU)
```bash
# US: scan + report
ansible-playbook playbooks/collect_java_footprint.yml -i ansibleInventory/inv_key.yml -e "repo_password=<repo-password-us>"
ansible-playbook playbooks/report_java_scan_run.yml -e "repo_password=<repo-password-us>"

# EU: scan + report
ansible-playbook playbooks/collect_java_footprint.yml -i ansibleInventory/inv_key.yml -e "@vars/java_scanner_config_eu.yml" -e "repo_password=<repo-password-eu>"
ansible-playbook playbooks/report_java_scan_run.yml -e "@vars/java_scanner_config_eu.yml" -e "repo_password=<repo-password-eu>"
```

For full runbook (rules refresh, subset reports, safe remediation), see:
`roles/java_scanner/REMEDIATION_STRATEGY.md`

---

## ⚙️ Configuration

Customization can be done via `defaults/main.yml` or passed as extra variables:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `oracle_user` | *Auto-detected* | OS User running Oracle (svcorap, oracle, etc.) |
| `db_sid` | *All Instances* | Pass a specific SID to limit execution |

---

## 👨‍💻 Author
**DBA Automation Team**  
*Enterprise Database Engineering*

## 📜 License
Internal Use - Proprietary and Confidential
