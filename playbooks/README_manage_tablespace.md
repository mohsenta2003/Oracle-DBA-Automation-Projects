# 📂 Oracle Tablespace Management

[![Ansible](https://img.shields.io/badge/Ansible-2.9+-ee0000.svg?style=flat-square&logo=ansible)](https://www.ansible.com/)
[![Oracle](https://img.shields.io/badge/Oracle-12c--19c-F80000.svg?style=flat-square&logo=oracle)](https://www.oracle.com/database/)

A comprehensive management playbook for Oracle tablespaces. It automates creation, resizing, and proactive monitoring of storage metrics to prevent "Out of Space" scenarios.

---

## 🌟 Key Features

*   **🆕 Automated Provisioning**: Creates tablespaces with standardized datafile locations, auto-extend settings, and local management.
*   **📏 On-the-Fly Resizing**: Quickly adjust datafile sizes to meet growing application demands.
*   **🚨 Utilization Guard**: Real-time monitoring with automated alerts when tablespaces exceed 85% capacity.
*   **🛡️ Disk-Level Prechecks**: Validates that at least 5GB of free space is available on the target mount point before starting operations.

---

## 🚀 Usage

```bash
# Provision or Resize tablespaces on specific hosts
ansible-playbook playbooks/manage_tablespace.yml -i inv_key.yml -l crlnxd2201
```

---

## 📋 Core Parameters

| Variable | Description | Default |
| :--- | :--- | :--- |
| `tablespace_name` | Name of the tablespace to manage | `APP_DATA` |
| `datafile_path` | Full path for the primary datafile | `/u02/oradata/{{ db_sid }}/...` |
| `tablespace_size` | Initial or Target size (e.g., 500M, 1G) | `100M` |
| `db_sid` | Target Oracle SID | *Required* |

---

## 🛠️ Operations Workflow

1.  **Capacity Check**: Verifies `/u02` (or configured mount) for sufficient free space using `df -h`.
2.  **State Management**: Safely executes `CREATE TABLESPACE` or `ALTER DATABASE DATAFILE` via SQLPlus.
3.  **Validation**: Queries `dba_data_files` and `dba_tablespace_usage_metrics` to confirm successful expansion and current utilization.

---

## 👨‍💻 Author
**DBA Automation Team**  
*Enterprise Database Engineering*
