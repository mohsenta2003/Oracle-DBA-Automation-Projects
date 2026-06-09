# 📊 Oracle Database Monitoring

[![Ansible](https://img.shields.io/badge/Ansible-2.9+-ee0000.svg?style=flat-square&logo=ansible)](https://www.ansible.com/)
[![Oracle](https://img.shields.io/badge/Oracle-12c--19c-F80000.svg?style=flat-square&logo=oracle)](https://www.oracle.com/database/)

A robust, **read-only** monitoring playbook that provides real-time health checks for all Oracle instances on a host. It captures database status, tablespace utilization, recent alert log errors, and performance bottlenecks like blocking sessions.

---

## 🌟 Key Features

*   **🕵️ Auto-Discovery**: Automatically identifies all running SIDs, Oracle Home, and the Oracle OS owner.
*   **📈 Capacity Insights**: Real-time tablespace usage report with GB/TB scaling and utilization percentages.
*   **🚨 Alert Intelligence**: Scans the last 24 hours of the alert log for critical `ORA-` errors.
*   **⚡ Performance Audit**: Detects active wait events and blocking sessions to identify performance hotspots.
*   **🔗 Listener Health**: Verifies the status of all running TNS Listeners.

---

## 🚀 Usage

Execute the monitoring check across your inventory:
```bash
# Monitor all production instances
ansible-playbook playbooks/monitor_oracle.yml -i inv_key.yml -l all_prod_linux

# Monitor a specific host
ansible-playbook playbooks/monitor_oracle.yml -i inv_key.yml -l crlnxd2201
```

---

## 📋 Metrics Captured

| Category | Details | Status Indicators |
| :--- | :--- | :--- |
| **Instance** | Version, Status, Startup Time, Hostname | OPEN, MOUNTED, STARTED |
| **Storage** | Tablespace Name, Used/Max Size, Pct Used | Warning > 85% |
| **Logs** | Recent ORA- Errors (Tail 50) | ✅ Clear or ⚠️ Error List |
| **Concurrency**| Blocking SIDs, Blocked Users, Events | ✅ No Blocking or ⚠️ Blocking Alert |
| **Wait Events**| Top 20 Non-Idle Active Wait Events | Seconds in Wait |

---

## 📂 Reports & Output

Reports are generated locally on the Ansible controller at `reports/<date>/<hostname>/`.

1.  **DB Instance Reports**: `monitor_<SID>.txt` - Detailed health drill-down per SID.
2.  **Listener Reports**: `listener_status.txt` - Status of all detected listeners on the host.

---

## ⚙️ Configuration

*   **`oracle_user`**: (Optional) Manually specify the Oracle owner if auto-detection fails.
*   **`db_sid`**: (Optional) Specify a single SID to monitor instead of all running instances.

---

## 🛠️ Internal Logic

1.  **Gathering Facts**: Collects timestamp and host-specific data.
2.  **Ownership Mapping**: Uses `ps -eo user,comm` to identify the Oracle owner.
3.  **SID Extraction**: Extracts instance names from PMON process list.
4.  **SQL Execution**: Connects via `sqlplus -s / as sysdba` to run optimized health check queries.
5.  **Report Assembly**: Consolidates results into localized text files for easy sharing.

---

## 👨‍💻 Author
**DBA Automation Team**  
*Enterprise Database Engineering*
