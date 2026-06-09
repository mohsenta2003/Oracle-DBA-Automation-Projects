# 🛡️ Oracle Advanced Security Check

[![Ansible](https://img.shields.io/badge/Ansible-2.9+-ee0000.svg?style=flat-square&logo=ansible)](https://www.ansible.com/)
[![Oracle](https://img.shields.io/badge/Oracle-12c--19c-F80000.svg?style=flat-square&logo=oracle)](https://www.oracle.com/database/)

This playbook audits **Oracle Advanced Security Options (ASO)** license usage across your estate. It automatically discovers all running instances and checks for **Transparent Data Encryption (TDE)**, **Data Redaction**, **Backup Encryption**, and **SecureFiles Encryption**.

---

## 🌟 Key Features

*   **🔍 Zero-Touch Discovery**: Automatically detects Oracle users and SIDs from the process list.
*   **🌍 Global Support**: Specialized handling for EU servers with long usernames (e.g., `svcorapeu`) and ASM/Grid Infrastructure exclusion.
*   **📊 Multi-Format Reporting**: Generates beautiful HTML Dashboards, CSV for analysis, and Text summaries.
*   **🛡️ License Guard**: Instantly identifies instances requiring Advanced Security licenses.

---

## 🚀 Usage

### Simple Audit
Detect ASO usage on specific servers or groups:
```bash
# Audit a single host
ansible-playbook playbooks/check_advanced_security.yml -i inv_key.yml -l uklnxagt0107

# Audit all production servers
ansible-playbook playbooks/check_advanced_security.yml -i inv_key.yml -l all_prod_linux
```

---

## 📋 Features Audited

| Feature | Description | License Requirement |
| :--- | :--- | :--- |
| **TDE** | Transparent Data Encryption (Tablespace/Column) | Advanced Security Option |
| **Data Redaction** | Dynamic data masking policies | Advanced Security Option |
| **Backup Encryption** | RMAN Backup set encryption | Advanced Security Option |
| **SecureFiles** | SecureFiles LOB Encryption | Advanced Security Option |

---

## 📊 Output & Reports

Reports are generated locally at `reports/<date>/<hostname>/`.

*   **🌐 HTML Dashboard**: `security_check_report_<timestamp>.html` - A high-level view with status badges.
*   **📄 Consolidated Text**: `security_check_consolidated_<timestamp>.txt` - Cross-host summary.
*   **📈 CSV Data**: `security_check_results_<timestamp>.csv` - Best for Excel integration.

---

## ⚙️ Configuration

| Variable | Default | Description |
| :--- | :--- | :--- |
| `oracle_user` | *Auto-detected* | OS User for Oracle (svcorap, oracle) |
| `db_sid` | *All Instances* | Pass a specific SID to limit the search |

---

## 🛠️ How it Works

1.  **Identity Discovery**: Uses `ps -eo user:32,args` to find full Oracle usernames (preventing truncation on EU servers).
2.  **Process Filter**: Targets `ora_pmon_` while intelligently excluding `asm_pmon_`.
3.  **Environment Mapping**: Looks up `ORACLE_HOME` in `/etc/oratab`.
4.  **Security Audit**: Connects via SQLPlus and queries `dba_feature_usage_statistics` and several dynamic views for real-time status.

---

## 👨‍💻 Author
**DBA Automation Team**  
*Enterprise Database Engineering*
