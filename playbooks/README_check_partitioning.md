# 🗂️ Oracle Partitioning Option Check

[![Ansible](https://img.shields.io/badge/Ansible-2.9+-ee0000.svg?style=flat-square&logo=ansible)](https://www.ansible.com/)
[![Oracle](https://img.shields.io/badge/Oracle-11g--19c-F80000.svg?style=flat-square&logo=oracle)](https://www.oracle.com/database/)
[![License](https://img.shields.io/badge/License%20Check-EE%20Option-blue.svg?style=flat-square)](https://www.oracle.com/corporate/pricing/technology-price-list-070617.pdf)

This playbook audits **Oracle Partitioning** — an Enterprise Edition option requiring a separate license — across all database instances in your estate. It automatically discovers every running SID, checks whether the option is installed and actively used, and produces per-instance and consolidated cross-host reports for license compliance.

---

## 🌟 Key Features

*   **🔍 Zero-Touch Discovery**: Automatically detects Oracle OS users, `ORACLE_HOME`, and all running SIDs from the PMON process list.
*   **🌍 Global Support**: Handles EU servers with long usernames (`svcorapeu`) and AIX/Linux platform differences. ASM/Grid processes are excluded automatically.
*   **⚙️ Version-Aware Queries**: Detects Oracle version at runtime — uses `oracle_maintained='N'` (12c+) or a static system schema exclusion list (11g) to filter non-system objects.
*   **📊 Partition Detail**: Lists every partitioned table and index with owner, partitioning type, partition key columns, partition count, and size in GB.
*   **🗓️ Accurate Usage Dates**: Refreshes `dba_feature_usage_statistics` before querying so `First Used` / `Last Used` dates reflect the current run.
*   **⚠️ Silent-Error Detection**: All SQL steps fail visibly on `ORA-` errors rather than defaulting to empty data.
*   **📈 Multi-Format Reports**: Per-instance HTML + TXT, plus consolidated cross-host HTML, CSV, and TXT.

---

## 🚀 Usage

### Run Commands

```bash
# Check ALL hosts in the inventory
ansible-playbook playbooks/check_partitioning.yml -i inv_key.yml

# Check all EU Linux production servers
ansible-playbook playbooks/check_partitioning.yml -i inv_key.yml -l all_eu_linux

# Check all AIX servers (EU + TLP)
ansible-playbook playbooks/check_partitioning.yml -i inv_key.yml -l all_aix_prod

# Check a single host
ansible-playbook playbooks/check_partitioning.yml -i inv_key.yml -l crlnxp316

# Check a single instance on a multi-instance host
ansible-playbook playbooks/check_partitioning.yml -i inv_key.yml -l crlnxd2201 -e "db_sid=MYDB"

# Override Oracle user (if auto-detection fails on non-standard installs)
ansible-playbook playbooks/check_partitioning.yml -i inv_key.yml -l ukaixpuk0001 -e "oracle_user=oracle"

# Use password-based auth instead of SSH key
ansible-playbook playbooks/check_partitioning.yml -i inv_pas.yml -l crlnxp316

# Verbose output (shows SQL stdout for debugging)
ansible-playbook playbooks/check_partitioning.yml -i inv_key.yml -l crlnxp316 -v
```

### Inventory Files

| File | Auth Method | When to Use |
| :--- | :--- | :--- |
| `inv_key.yml` | SSH Key | Production / standard environments |
| `inv_pas.yml` | SSH Password | Jump hosts / legacy servers |
| `inv_var.yml` | Variable-based | Custom per-host credentials |

---

## 📋 What is Checked

| Check | Source | Description |
| :--- | :--- | :--- |
| **Installed?** | `v$option` | Whether Partitioning binary is enabled in this Oracle Home |
| **In-Use?** | `dba_part_tables` | Whether any non-system schema has partitioned objects |
| **Table Count** | `dba_part_tables` | Number of partitioned tables in non-system schemas |
| **Index Count** | `dba_part_indexes` | Number of partitioned indexes in non-system schemas |
| **Schema Count** | `dba_part_tables` | Distinct schemas owning partitioned tables |
| **First Used** | `dba_feature_usage_statistics` | Earliest date Partitioning was detected in use (`detected_usages > 0`) |
| **Last Used** | `dba_feature_usage_statistics` | Most recent date: `last_usage_date` (12c+) or `last_sample_date` (11g) |
| **Partitioned Size (GB)** | `dba_segments` | Total allocated size of all partition/subpartition segments |
| **DB Total Size (GB)** | `dba_data_files` | Total allocated size of the entire database |
| **Partition Key** | `dba_part_key_columns` | Column(s) used as the partitioning key |
| **License Required?** | Derived | YES if In-Use, NO otherwise |

---

## 📊 Reports & Output

All reports are saved locally on the Ansible controller under `reports/YYYY-MM-DD/`.

### Per-Instance Reports (under `reports/<date>/<hostname>/`)

| File | Format | Description |
| :--- | :--- | :--- |
| `partitioning_<SID>_<timestamp>.html` | HTML | Full HTML dashboard with status badges, stat cards, and sortable tables |
| `partitioning_<SID>_<timestamp>.txt` | Text | Plain-text report for archiving, emailing, or diff comparison |

### Consolidated Cross-Host Reports (under `reports/<date>/`)

| File | Format | Description |
| :--- | :--- | :--- |
| `partitioning_report_<timestamp>.html` | HTML | Full estate overview — ordered by risk (In-Use → Enabled-No-Obj → Disabled → Standby) with per-instance drill-down links |
| `partitioning_consolidated_<timestamp>.txt` | Text | Cross-host summary with license counts and details |
| `partitioning_results_<timestamp>.csv` | CSV | Raw data for Excel / CMDB integration |

### HTML Report Sections

- **Header Info Grid**: Host, Database, DB Role, Open Mode, Oracle User, DB Total Size, Partitioned Objects Size
- **Status Table**: Installed?, In-Use?, First Used, Last Used, Tables, Indexes, Schemas, Partitioned Size (GB), DB Total Size (GB), License Required?
- **Stat Cards** *(In-Use only)*: Counts at a glance with colour coding (red = licensed usage)
- **Partitioned Tables Detail**: Owner, Table Name, **Partition Key**, Partitioning Type, Subpartitioning, Partitions, Interval, Size (GB) — scrollable, overflow-safe
- **Partitioned Indexes Detail**: Owner, Index Name, **Partition Key**, Table Name, Partitioning Type, Partitions, Size (GB) — scrollable, overflow-safe

---

## ⚙️ Configuration

| Variable | Default | Description |
| :--- | :--- | :--- |
| `oracle_user` | *Auto-detected* | OS user running Oracle (e.g., `oracle`, `svcorap`, `svcorapeu`) |
| `db_sid` | *All instances* | Limit check to a specific SID on a multi-instance host |

---

## 🛠️ How It Works

1. **Fact Gathering**: Collects timestamp for consistent report naming across all hosts.
2. **Oracle Discovery**: Uses `ps -eo user:32,args` to find full Oracle usernames (prevents truncation on EU servers). Extracts all running SIDs from `ora_pmon_*` processes, excluding `asm_pmon_*`.
3. **Environment Mapping**: Looks up each SID's `ORACLE_HOME` from `/etc/oratab`.
4. **DB Status Check**: Queries `v$instance` + `v$database` to determine database role (PRIMARY/STANDBY) and open mode.
5. **Standby Skip**: Physical/Logical Standby databases and MOUNTED instances are recorded but not queried (cannot write or alter stats).
6. **Version Detection**: Reads `v$instance.version` to determine `_db_version_major` and set the correct schema filter (`oracle_maintained='N'` on 12c+, static list on 11g).
7. **Feature Refresh**: Calls `DBMS_FEATURE_USAGE_INTERNAL.exec_db_usage_sampling(SYSDATE)` to force Oracle to record current usage *before* the summary query runs.
8. **Summary Query**: Single `SELECT ... FROM DUAL` retrieving all 9 metrics in one round-trip (installed, in-use, counts, dates, sizes).
9. **Detail Queries** *(In-Use only)*: Separate queries for table detail (cols 0–7: Owner, Table Name, **Partition Key**, Part Type, Subpart, Count, Interval, Size GB) and index detail (cols 0–6: Owner, Index Name, **Partition Key**, Table Name, Part Type, Count, Size GB). Partition key retrieved via `LISTAGG` on `dba_part_key_columns`.
10. **Report Generation**: TXT and HTML per-instance reports are saved to the controller. Results are appended to `_instance_results` for consolidated reporting.
11. **Consolidated Reports**: `main.yml` iterates `_instance_results` to build the cross-host TXT, CSV, and HTML reports with ordered risk groupings.

---

## 🏷️ License Compliance Context

| Scenario | `v$option` | Objects Exist | License Required |
| :--- | :--- | :--- | :--- |
| Partitioning used in production | TRUE | YES | ✅ **YES — EE Option required** |
| Installed but no objects | TRUE | NO | ⚪ No (but verify with Oracle LMS) |
| Not installed | FALSE | NO | ✅ NO |
| Standby (not queried) | N/A | N/A | ⏸ Check Primary |

> **Note**: Oracle Partitioning is an Enterprise Edition option. Even one partitioned object in a non-system schema constitutes usage and requires a license. Oracle LMS audits check `dba_feature_usage_statistics`.

---

## 🔧 Troubleshooting

| Symptom | Likely Cause | Fix |
| :--- | :--- | :--- |
| Task fails with `ORA-01031` | SQLPlus user lacks `SELECT ANY DICTIONARY` | Grant privilege or run as `sysdba` |
| `_is_12c_plus = NO` on a 12c DB | Version query returned empty | Check `db_version_check.stderr` in verbose output |
| All counts show `0` | ORA- error silently returned | Re-run with `-v` to see `part_summary.stderr` |
| `First Used` / `Last Used` = `Never` | No detected usage rows in `dba_feature_usage_statistics` (`detected_usages = 0` for all rows) | Run feature refresh manually: `EXEC DBMS_FEATURE_USAGE_INTERNAL.exec_db_usage_sampling(SYSDATE);` then re-query |
| Standby shows in consolidated report | Expected behaviour | Standbys are recorded as skipped — check the PRIMARY instance |
| Long usernames truncated | `ps` default truncates at 8 chars | Already handled via `ps -eo user:32` |

---

## 👨‍💻 Author
**DBA Automation Team**  
*Enterprise Database Engineering*
