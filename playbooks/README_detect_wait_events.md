# 🕵️ Oracle Wait Event Detection

[![Ansible](https://img.shields.io/badge/Ansible-2.9+-ee0000.svg?style=flat-square&logo=ansible)](https://www.ansible.com/)
[![Oracle](https://img.shields.io/badge/Oracle-12c--19c-F80000.svg?style=flat-square&logo=oracle)](https://www.oracle.com/database/)

A surgical performance diagnostic tool designed to identify active performance bottlenecks. This playbook queries real-time wait events and identifies sessions currently competing for system resources.

---

## 🌟 Key Features

*   **⏱️ Real-Time Profiling**: Instant visibility into non-idle wait events across active sessions.
*   **🔍 SQL Identification**: Maps waiting sessions directly to their active `SQL_ID` and SQL text.
*   **📊 Performance Classes**: Categorizes waits (I/O, Concurrency, Network) for faster root-cause analysis.
*   **🛰️ Lightweight Execution**: Directly executes against `v$session` and `v$sql` without requiring heavy diagnostic packs.

---

## 🚀 Usage

Execute a diagnostic check against a specific database:
```bash
# Detect waits on the production instance
ansible-playbook playbooks/detect_wait_events.yml -i inv_key.yml -l crlnxp1024
```

---

## 📈 Monitoring Metrics

| Metric | Source | Value |
| :--- | :--- | :--- |
| **SID / Serial** | `v$session` | Session Identification |
| **Event Name** | `v$session` | The specific bottleneck (e.g., 'db file sequential read') |
| **Wait Class** | `v$session` | Type of wait (User I/O, System I/O, etc.) |
| **SQL Text** | `v$sql` | The actual query causing the wait |

---

## 🛠️ Internal Workflow

1.  **Session Audit**: Scans for sessions where `wait_class != 'Idle'` and `state = 'WAITING'`.
2.  **Join Logic**: Links `v$session` with `v$sql` to provide context to the waits.
3.  **Console Delivery**: Formats and displays the results directly in the Ansible output for immediate action.

---

## 👨‍💻 Author
**DBA Automation Team**  
*Enterprise Database Engineering*
