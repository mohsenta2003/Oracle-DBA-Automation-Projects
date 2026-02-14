# 👤 Oracle User Management

[![Ansible](https://img.shields.io/badge/Ansible-2.9+-ee0000.svg?style=flat-square&logo=ansible)](https://www.ansible.com/)
[![Oracle](https://img.shields.io/badge/Oracle-12c--19c-F80000.svg?style=flat-square&logo=oracle)](https://www.oracle.com/database/)

Securely automate the lifecycle of Oracle database users. This playbook handles user creation, privilege assignment, password management, and storage quotas in a standardized, enterprise-ready manner.

---

## 🌟 Key Features

*   **🔒 Standardized Provisioning**: Creates users with hardened default settings, including temporary tablespace and local profile assignments.
*   **🔑 Role-Based Access**: Automatically grants necessary system privileges (`CREATE SESSION`, `RESOURCE`, etc.) during setup.
*   **📏 Resource Limits**: Configures tablespace quotas to prevent single-user storage exhaustion.
*   **📜 Audit Trail**: Logs all user management operations to a dedicated log file (`playbook_users.log`).

---

## 🚀 Usage

```bash
# Provision a new application user
ansible-playbook playbooks/manage_users.yml -i inv_key.yml -l crlnxd2201
```

---

## 📋 Provisioning Settings

| Variable | Description | Default |
| :--- | :--- | :--- |
| `oracle_user_name` | DB Username to create | `APP_USER` |
| `oracle_user_pass` | Secure password for the account | `AppPass123` |
| `default_ts` | Default tablespace for data | `APP_DATA` |
| `quota_mb` | Storage limit on default tablespace | `100M` |

---

## ⚖️ Verification Steps

1.  **Identity Check**: Queries `dba_users` to verify account status and tablespace assignments.
2.  **Privilege Check**: Validates system privileges in `dba_sys_privs`.
3.  **Connection Test**: Attempts a sample login to ensure the password and session permissions are active.

---

## 👨‍💻 Author
**DBA Automation Team**  
*Enterprise Database Engineering*
