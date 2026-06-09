# Role: `oracle_partitioning`

[![Ansible Role](https://img.shields.io/badge/Ansible-Role-ee0000.svg?style=flat-square&logo=ansible)](https://www.ansible.com/)
[![Oracle](https://img.shields.io/badge/Oracle-11g%20%7C%2012c%20%7C%2019c-F80000.svg?style=flat-square&logo=oracle)](https://www.oracle.com/database/)

Checks **Oracle Partitioning EE Option** usage across all instances on a host. Produces per-instance TXT and HTML reports plus consolidated cross-host reports for license compliance auditing.

---

## 📁 Role Structure

```
roles/oracle_partitioning/
├── defaults/
│   └── main.yml           # Default variables (oracle_user auto-detected)
└── tasks/
    ├── main.yml            # Entry point: discovery, loop, consolidated reports
    └── check_instance.yml  # Per-instance logic (called per SID)
```

---

## 🔄 Task Flow

### `tasks/main.yml`
| Step | Task | Description |
| :--- | :--- | :--- |
| 1 | Gather facts | Timestamp for report naming |
| 2 | Create report dirs | `reports/YYYY-MM-DD/<hostname>/` on controller |
| 3 | Detect Oracle user | `ps -eo user:32,args` → `ora_pmon_*` (excludes ASM) |
| 4 | Read oratab | Build `_oratab_map` (SID → ORACLE_HOME) |
| 5 | Detect SIDs | Parse PMON list → `_oracle_sids` list |
| 6 | Loop instances | Call `check_instance.yml` for each SID |
| 7 | Consolidated TXT | Cross-host summary report |
| 8 | Consolidated CSV | Machine-readable results |
| 9 | Consolidated HTML | Full estate overview with risk groupings |

### `tasks/check_instance.yml`
| Step | Task | Description |
| :--- | :--- | :--- |
| 1 | DB status check | `v$instance` + `v$database` → role, open mode |
| 1b | Version check | `v$instance.version` → `_db_version_major`, `_is_12c_plus` |
| 2 | Standby skip | Records result + skips all queries if STANDBY/MOUNTED |
| 3 | Feature refresh | `DBMS_FEATURE_USAGE_INTERNAL.exec_db_usage_sampling(SYSDATE)` — runs **before** summary query |
| 4 | Summary query | 9-column pipe-delimited `SELECT FROM DUAL` (version-branched) |
| 5 | Table detail | `dba_part_tables` + `dba_segments` + `dba_part_key_columns` (In-Use only) |
| 6 | Index detail | `dba_part_indexes` + `dba_segments` + `dba_part_key_columns` (In-Use only) |
| 7 | TXT report | Per-instance plain-text report |
| 8 | HTML report | Per-instance HTML dashboard |
| 9 | Append results | Add to `_instance_results` for consolidated reporting |
| 10 | Console summary | Debug output per instance |

---

## 📦 Variables

### Input Variables (set by `main.yml` or via `-e`)

| Variable | Default | Description |
| :--- | :--- | :--- |
| `oracle_user` | Auto-detected | OS user running Oracle processes |
| `db_sid` | *(all)* | Limit to a specific SID |

### Internal Variables (set at runtime, do not override)

| Variable | Source | Description |
| :--- | :--- | :--- |
| `_oracle_user` | PMON detection | Resolved Oracle OS user |
| `_oracle_sids` | PMON detection | List of running SIDs on the host |
| `_oratab_map` | `/etc/oratab` | Dict of SID → ORACLE_HOME |
| `_current_oracle_home` | `_oratab_map` | ORACLE_HOME for current SID |
| `_db_version_full` | `v$instance` | Full version string (e.g. `19.3.0.0.0`) |
| `_db_version_major` | Parsed | Major version integer (e.g. `19`) |
| `_is_12c_plus` | Derived | Boolean — drives schema filter SQL branch |
| `_is_standby` | Derived | Boolean — skips queries if true |
| `_part_installed` | `v$option` | `TRUE` / `FALSE` |
| `_part_inuse` | `dba_part_tables` | `YES` / `NO` |
| `_part_table_count` | `dba_part_tables` | Count of non-system partitioned tables |
| `_part_index_count` | `dba_part_indexes` | Count of non-system partitioned indexes |
| `_part_schema_count` | `dba_part_tables` | Distinct schemas with partitioned tables |
| `_part_first_used` | `dba_feature_usage_statistics` | `MAX(first_usage_date) WHERE detected_usages > 0` |
| `_part_last_used` | `dba_feature_usage_statistics` | `MAX(last_usage_date)` (12c+) or `MAX(last_sample_date)` (11g) |
| `_part_total_size_gb` | `dba_segments` | GB used by partition/subpartition segments |
| `_db_total_size_gb` | `dba_data_files` | Total allocated GB for the database |
| `_instance_results` | Accumulated | List of result dicts — used for consolidated reports |

---

## 🗃️ `_instance_results` Dict Structure

Each entry in `_instance_results` contains:

```yaml
sid:             "MYDB"
db_role:         "PRIMARY"
open_mode:       "READ WRITE"
is_standby:      false
option_enabled:  true
installed:       "TRUE"
inuse:           "YES"
table_count:     "42"
index_count:     "37"
schema_count:    "5"
total_size_gb:   "12.3456"     # partitioned segments only
db_total_size_gb: "480.0000"   # dba_data_files total
first_used:      "2024-01-15"
last_sampled:    "2026-05-07"  # stores _part_last_used value
report_file:     "partitioning_MYDB_20260507_143022.html"
output:          "..."
```

---

## 🔀 Version Compatibility

| Oracle Version | Schema Filter | Usage Date Columns | Notes |
| :--- | :--- | :--- | :--- |
| **19c / 18c / 12c** | `dba_users.oracle_maintained = 'N'` | `first_usage_date`, `last_usage_date` (WHERE `detected_usages > 0`) | Dynamic — always correct |
| **11g** | Static exclusion list (30+ system schemas) | `first_usage_date` (WHERE `detected_usages > 0`), `last_sample_date` | `oracle_maintained` and `last_usage_date` columns do not exist |

Version is detected automatically per instance — no configuration needed.

---

## 🛡️ Error Handling

| Condition | Behaviour |
| :--- | :--- |
| STANDBY / MOUNTED database | Recorded in `_instance_results` with `is_standby: true`, all SQL steps skipped |
| Connection failure / DB down | Debug task shows RC, stdout, stderr; subsequent steps skip gracefully |
| SQL step returns `ORA-` in stderr | Task fails visibly (`failed_when`) — not silently defaulted |
| Oracle 11g target | Automatically uses 11g-safe SQL (no `oracle_maintained` or `last_usage_date` columns) |
| SID not in oratab | Falls back to first available ORACLE_HOME in the map |

---

## 📊 Consolidated HTML Report Groups

The consolidated HTML report orders instances into 5 risk-sorted groups:

| Group | Colour | Condition |
| :--- | :--- | :--- |
| 🔴 IN-USE — LICENSE REQUIRED | Red | `inuse = YES` |
| ✅ ENABLED — NO OBJECTS | Green | `installed = TRUE`, `inuse = NO` |
| ❌ DISABLED | Slate | `installed = FALSE` |
| ⏸ STANDBY / MOUNTED | Gray | `is_standby = true` |
| 🚫 SKIPPED / UNREACHABLE | Light | Hosts that did not respond |

---

## 📁 Report Output Paths

```
reports/
└── YYYY-MM-DD/
    ├── partitioning_report_<timestamp>.html         # Consolidated HTML (all hosts)
    ├── partitioning_consolidated_<timestamp>.txt    # Consolidated TXT (all hosts)
    ├── partitioning_results_<timestamp>.csv         # CSV (all hosts)
    └── <hostname>/
        ├── partitioning_<SID>_<timestamp>.html      # Per-instance HTML
        └── partitioning_<SID>_<timestamp>.txt       # Per-instance TXT
```

---

## 👨‍💻 Author
**DBA Automation Team**  
*Enterprise Database Engineering*
