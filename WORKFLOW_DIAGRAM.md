# Oracle Options Audit - Workflow Diagram

## 📊 High-Level Architecture (Updated May 2026)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ANSIBLE CONTROLLER                               │
│                         (crlnxp1086)                                    │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  Step 1: ansible-playbook collect_oracle_options.yml          │  │
│  │          -i inv_key.yml -l "server_list"                       │  │
│  │          • Collects current state from ALL hosts               │  │
│  │          • Auto-detects feature usage                          │  │
│  │          • Creates NEW snapshot with unique RUN_ID             │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                               │                                         │
│                               ▼                                         │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  Step 2: ansible-playbook report_audit_run.yml                │  │
│  │          -i "localhost," -c local                              │  │
│  │          • Queries LATEST run (current state)                  │  │
│  │          • Generates HTML report with license risks            │  │
│  │          • Emails report to stakeholders                       │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                               │                                         │
│                               ▼                                         │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  Step 3 (NEW): ansible-playbook report_timeline.yml           │  │
│  │               -i "localhost," -c local -e "option=all"         │  │
│  │          • Queries ALL runs (historical timeline)              │  │
│  │          • Shows what changed when                             │  │
│  │          • Generates HTML/text timeline reports                │  │
│  └────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
           │                                              │
           │ SSH to targets                               │ Query repo
           ▼                                              ▼
┌──────────────────────┐                    ┌─────────────────────────┐
│   TARGET SERVERS     │                    │  CENTRAL REPOSITORY     │
│  (100+ servers)      │◄───────────────────│  crlnxd1046:1535/d1hub │
│                      │  Store results     │  DBAORALIC_SCH schema   │
│  • crlnxp316         │  with RUN_ID       │                         │
│  • crlnxm1014        │                    │  ┌───────────────────┐  │
│  • uklnxt222         │                    │  │ RUN 42: 2026-05-12│  │
│  • crlnxm145         │                    │  │ RUN 41: 2026-05-11│  │
│  • uklnxpnl1042      │                    │  │ RUN 40: 2026-05-10│  │
│  • dcup60 (AIX)      │                    │  │ RUN 39: 2026-04-15│  │
│  • ...               │                    │  │ ...               │  │
└──────────────────────┘                    │  └───────────────────┘  │
                                            │  All historical data!   │
                                            └─────────────────────────┘
                                                       │
                                                       │ Generate reports
                                                       ▼
                                            ┌─────────────────────────┐
                                            │    EMAIL REPORTS        │
                                            │  mail1.us.aegon.com     │
                                            │                         │
                                            │  1. Current state (HTML)│
                                            │  2. Timeline (HTML+TXT) │
                                            └─────────────────────────┘
```

---

## 🔄 Detailed Workflow: Step-by-Step

### **PHASE 1: COLLECTION** (Per Server)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ FOR EACH SERVER IN INVENTORY (e.g., crlnxp316)                         │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. DISCOVER ORACLE                                                      │
│    • SSH to server as svcorap/oracle                                    │
│    • Run: ps -ef | grep pmon                                            │
│    • Extract SID list: [mrxhistp, invdev, etc.]                         │
│    • Parse /etc/oratab for ORACLE_HOME                                  │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. FOR EACH ORACLE INSTANCE (e.g., mrxhistp)                           │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2a. GATHER BASIC INFO                                                   │
│     • Connect: sqlplus / as sysdba                                      │
│     • Query: v$instance, v$database                                     │
│     • Collect:                                                          │
│       - Instance name: mrxhistp                                         │
│       - Version: 19.0.0.0.0                                             │
│       - DB role: PRIMARY / PHYSICAL STANDBY                             │
│       - Database size: 1876 GB                                          │
│       - Patch level: 19.21.0.0.0                                        │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2b. COLLECT v$option (ALL OPTIONS)                                     │
│     • Query: SELECT parameter, value FROM v$option                      │
│     • Results: 88 rows                                                  │
│       - Partitioning: TRUE                                              │
│       - Advanced Compression: TRUE                                      │
│       - Real Application Clusters: FALSE                                │
│       - In-Memory Column Store: TRUE                                    │
│       - Active Data Guard: TRUE                                         │
│       - ...                                                             │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2c. COLLECT dba_feature_usage_statistics (USAGE EVIDENCE)              │
│     • Query: SELECT name, version, detected_usages, currently_used,    │
│              first_usage_date, last_usage_date, aux_count              │
│              FROM dba_feature_usage_statistics                          │
│     • Results: 65 rows                                                  │
│       - Partitioning (system usage): 14 usages, CURRENTLY_USED=TRUE    │
│       - ADDM: 3 usages, aux_count=2                                     │
│       - Automatic Workload Repository: 1867 usages                      │
│       - ...                                                             │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2d. COLLECT EVIDENCE TABLES (WITH AUTO-DETECTION - May 2026 Fix)       │
│     ┌───────────────────────────────────────────────────────────────┐ │
│     │ IF Partitioning Auto-Detected OR Explicitly Enabled:         │ │
│     │  • Auto-detect: CURRENTLY_USED='TRUE' OR DETECTED_USAGES > 0 │ │
│     │  • Query: dba_tab_partitions, dba_part_tables                │ │
│     │  • Find: Tables/indexes using partitioning                   │ │
│     │  • Store: Table name, partition count, type, size            │ │
│     │  • Debug: Shows auto-detection status and row counts         │ │
│     └───────────────────────────────────────────────────────────────┘ │
│     ┌───────────────────────────────────────────────────────────────┐ │
│     │ IF Compression Auto-Detected OR Explicitly Enabled:          │ │
│     │  • Auto-detect: Feature name contains 'Compression' or 'HCC' │ │
│     │  • Query: dba_tables WHERE compression='ENABLED'             │ │
│     │  • Find: Compressed tables/indexes                           │ │
│     │  • Store: Table name, compression type, compress_for, size   │ │
│     └───────────────────────────────────────────────────────────────┘ │
│     ┌───────────────────────────────────────────────────────────────┐ │
│     │ IF Security/TDE Auto-Detected OR Explicitly Enabled:         │ │
│     │  • Auto-detect: Feature name contains 'Encryption', 'TDE',   │ │
│     │                 'Advanced Security', 'Transparent Data...'   │ │
│     │  • Query: v$encrypted_tablespaces, dba_encrypted_columns     │ │
│     │  • Find: Encrypted tablespaces/columns                       │ │
│     │  • Store: Object name, encryption algorithm, key info        │ │
│     └───────────────────────────────────────────────────────────────┘ │
│     ┌───────────────────────────────────────────────────────────────┐ │
│     │ IF In-Memory Auto-Detected OR Explicitly Enabled:            │ │
│     │  • Auto-detect: Feature name contains 'In-Memory' AND        │ │
│     │                 (CURRENTLY_USED='TRUE' OR DETECTED_USAGES>0) │ │
│     │  • Query: dba_tables WHERE inmemory='ENABLED'                │ │
│     │          UNION v$im_segments (actually populated)            │ │
│     │  • Find: In-Memory enabled AND populated objects             │ │
│     │  • Store: Object name, priority, compression, size           │ │
│     └───────────────────────────────────────────────────────────────┘ │
│     ┌───────────────────────────────────────────────────────────────┐ │
│     │ IF RAC Detected:                                             │ │
│     │  • Query: gv$instance                                        │ │
│     │  • Find: All RAC nodes                                       │ │
│     │  • Store: Node number, instance name, host                   │ │
│     └───────────────────────────────────────────────────────────────┘ │
│     ┌───────────────────────────────────────────────────────────────┐ │
│     │ IF Standby Database Detected:                                │ │
│     │  • Query: v$archive_dest_status, v$dataguard_stats           │ │
│     │  • Detect: Active Data Guard (read-only queries on standby)  │ │
│     │  • Store: Standby type, sync status, apply lag               │ │
│     └───────────────────────────────────────────────────────────────┘ │
│                                                                       │
│     ★ KEY FEATURE (May 2026): AUTO-DETECTION                         │
│       Even if collect_* flags are FALSE, system automatically        │
│       collects evidence when feature usage is detected!              │
│       This prevents "missing evidence" issues.                       │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. GENERATE LOCAL SQL FILES                                            │
│    • Location: /home/svcorap/mohsen/ansible/logs/oracle_options_audit/ │
│                2026-05-11/                                              │
│    • Files created:                                                     │
│      - oracle_audit_3_crlnxp316.sql (INSERT statements)                │
│      - oracle_audit_3_crlnxp316_summary.txt (text summary)             │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. INSERT INTO CENTRAL REPOSITORY (With Unique RUN_ID)                 │
│    • Connect: sqlplus DBAORALIC_SCH/***@crlnxd1046:1535/d1hub          │
│    • Create NEW RUN_ID (e.g., 42) for this collection                  │
│    • Execute SQL file with all INSERTs:                                │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ INSERT INTO ORACLE_OPT_RUNS (RUN_ID=42, RUN_DATE=SYSDATE)   │ │
│      │ INSERT INTO ORACLE_OPT_INSTANCES (instance metadata)         │ │
│      │ INSERT INTO ORACLE_OPT_VOPTION (88 v$option rows)            │ │
│      │ INSERT INTO ORACLE_OPT_FEATURES (65 feature rows)            │ │
│      │ INSERT INTO ORACLE_OPT_D_PART (partitioning evidence)        │ │
│      │ INSERT INTO ORACLE_OPT_D_COMPRESS (compression evidence)     │ │
│      │ INSERT INTO ORACLE_OPT_D_SECURITY (TDE evidence)             │ │
│      │ INSERT INTO ORACLE_OPT_D_INMEM (In-Memory evidence)          │ │
│      │ ...                                                          │ │
│      │ COMMIT;                                                      │ │
│      └──────────────────────────────────────────────────────────────┘ │
│    ★ OLD DATA IS NEVER DELETED!                                        │
│      Previous runs (41, 40, 39...) remain in repository                │
│      Each RUN_ID is a complete snapshot for timeline analysis          │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 5. REPEAT FOR ALL SERVERS                                              │
│    • Process crlnxm1014, crlnxt222, crlnxm145, uklnxpnl1042, etc.      │
│    • All data stored with same RUN_ID=42                               │
│    • Repository now contains COMPLETE snapshot for this collection     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### **PHASE 2: CURRENT STATE REPORTING** (report_audit_run.yml)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. QUERY LATEST RUN FROM REPOSITORY                                    │
│    • Connect: sqlplus DBAORALIC_SCH/***@crlnxd1046:1535/d1hub          │
│    • Query: SELECT MAX(run_id) FROM ORACLE_OPT_RUNS                    │
│    • Get RUN_ID=42 (just completed)                                    │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. AGGREGATE DATA FOR LATEST RUN (RUN_ID=42)                           │
│    • Total servers processed: 45                                        │
│    • Total Oracle instances: 78                                         │
│    • Instances with Partitioning ENABLED: 12                            │
│    • Instances with Partitioning IN-USE: 8  ⚠️ LICENSE RISK            │
│    • Instances with Compression ENABLED: 15                             │
│    • Instances with Compression IN-USE: 10  ⚠️ LICENSE RISK            │
│    • Instances with Advanced Security ENABLED: 5                        │
│    • Instances with In-Memory IN-USE: 2  ⚠️ LICENSE RISK               │
│    • Active Data Guard detected: 3  ⚠️ LICENSE RISK                     │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. GENERATE HTML REPORT (CURRENT STATE)                                │
│    • Template: Jinja2 HTML template                                    │
│    • Sections:                                                          │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ ✅ Executive Summary                                         │ │
│      │    - Total instances scanned (RUN_ID=42)                     │ │
│      │    - Licensing risks identified                              │ │
│      │    - Recommendations                                         │ │
│      └──────────────────────────────────────────────────────────────┘ │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ ⚠️  HIGH-RISK OPTIONS (Enabled + In-Use NOW)                │ │
│      │    - Partitioning: 8 instances ⚠️                           │ │
│      │      • crlnxp316/mrxhistp (1876 GB, 45 partitioned tables)   │ │
│      │      • crlnxm1014/invdev (890 GB, 23 partitioned tables)     │ │
│      │    - Advanced Compression: 10 instances ⚠️                   │ │
│      │    - Active Data Guard: 3 standbys ⚠️                        │ │
│      └──────────────────────────────────────────────────────────────┘ │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ ℹ️  OPTIONS ENABLED BUT NOT USED                            │ │
│      │    - Real Application Clusters: 0 instances                  │ │
│      │    - In-Memory: Feature used historically but no objects now │ │
│      └──────────────────────────────────────────────────────────────┘ │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ 📊 ALL OPTIONS BY INSTANCE (Detailed Matrix)                │ │
│      │    [Table showing all 78 instances x all options]            │ │
│      └──────────────────────────────────────────────────────────────┘ │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ 📋 EVIDENCE DETAILS (Drill-down - Current State)            │ │
│      │    - Partitioned tables by instance (now)                    │ │
│      │    - Compressed objects by instance (now)                    │ │
│      │    - Encrypted tablespaces by instance (now)                 │ │
│      │    - In-Memory objects by instance (now)                     │ │
│      └──────────────────────────────────────────────────────────────┘ │
│    • File: /tmp/oracle_options_audit_RUN42_2026-05-12.html            │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. SEND EMAIL (Current State Report)                                   │
│    • SMTP: mail1.us.aegon.com:25                                       │
│    • From: crlnxp1086@transamerica.com                                 │
│    • To: Mohsen.Taheri@transamerica.com                                │
│    • Subject: Oracle Options Audit - RUN42 - 2026-05-12                │
│    • Body: Plain text summary + HTML attachment                        │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ Oracle Options Audit Summary                                 │ │
│      │ ================================                             │ │
│      │ Run ID: 42                                                   │ │
│      │ Run Date: 2026-05-12                                         │ │
│      │ Total Instances: 78                                          │ │
│      │                                                              │ │
│      │ ⚠️  HIGH-RISK LICENSE FINDINGS:                             │ │
│      │ • Partitioning in-use: 8 instances                           │ │
│      │ • Advanced Compression in-use: 10 instances                  │ │
│      │ • Active Data Guard: 3 standbys                              │ │
│      │                                                              │ │
│      │ See attached HTML report for details.                        │ │
│      └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### **PHASE 3: HISTORICAL TIMELINE REPORTING** (NEW - May 2026)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. QUERY ALL HISTORICAL RUNS FROM REPOSITORY                           │
│    • Connect: sqlplus DBAORALIC_SCH/***@crlnxd1046:1535/d1hub          │
│    • Query: SELECT * FROM ORACLE_OPT_RUNS ORDER BY run_id              │
│    • Find: 42 collection runs spanning 180 days                        │
│      - RUN_ID 42: 2026-05-12 (today)                                   │
│      - RUN_ID 41: 2026-05-11                                           │
│      - RUN_ID 40: 2026-05-10                                           │
│      - ...                                                             │
│      - RUN_ID 1:  2025-11-15 (first collection)                        │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. BUILD TIMELINE FOR SELECTED OPTION (e.g., In-Memory)                │
│    • Query evidence across ALL run_ids:                                │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ SELECT run_timestamp, hostname, sid, owner, table_name      │ │
│      │ FROM ORACLE_OPT_D_INMEM im                                   │ │
│      │ JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id              │ │
│      │ ORDER BY run_timestamp DESC                                  │ │
│      └──────────────────────────────────────────────────────────────┘ │
│    • Timeline reconstruction:                                           │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ RUN 42 (2026-05-12): crlnxm145/aahd - 0 objects             │ │
│      │ RUN 41 (2026-05-11): crlnxm145/aahd - 0 objects             │ │
│      │ RUN 40 (2026-05-10): crlnxm145/aahd - 0 objects             │ │
│      │ RUN 35 (2026-04-25): crlnxm145/aahd - 3 objects             │ │
│      │   • SALES_DATA, ORDERS_HISTORY, CUSTOMER_INFO               │ │
│      │ RUN 20 (2026-02-15): crlnxm145/aahd - 3 objects             │ │
│      │ RUN 10 (2025-12-20): crlnxm145/aahd - 5 objects             │ │
│      │   • Added INVENTORY, PRODUCTS                                │ │
│      └──────────────────────────────────────────────────────────────┘ │
│    • Analysis:                                                          │
│      - Feature FIRST seen: 2025-12-20 (5 objects)                      │
│      - Feature LAST seen: 2026-04-25 (3 objects)                       │
│      - Days since last use: 17 days                                    │
│      - Objects removed: INVENTORY, PRODUCTS (between run 35-36)        │
│      - All objects removed: After run 35 (2026-04-25)                  │
│      - Current status: HISTORICAL (used before, disabled now)          │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. GENERATE TIMELINE REPORTS (HTML + TEXT)                             │
│    • HTML Report with charts and tables:                               │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ 📊 Oracle In-Memory Historical Timeline                     │ │
│      │                                                              │ │
│      │ Timeline: 2025-11-15 to 2026-05-12 (42 collection runs)     │ │
│      │                                                              │ │
│      │ Part 1: Feature Usage Dates (From Oracle's Tracking)        │ │
│      │ ┌──────────┬────────┬────────────┬────────────┬─────────┐  │ │
│      │ │ Hostname │ SID    │ First Used │ Last Used  │ Status  │  │ │
│      │ ├──────────┼────────┼────────────┼────────────┼─────────┤  │ │
│      │ │crlnxm145 │ aahd   │ 2024-03-15 │ 2024-08-22 │ HIST    │  │ │
│      │ │crlnxt222 │ aahsb  │ 2024-05-10 │ 2024-09-15 │ HIST    │  │ │
│      │ └──────────┴────────┴────────────┴────────────┴─────────┘  │ │
│      │                                                              │ │
│      │ Part 2: Object Evidence Timeline (What Objects WHEN)        │ │
│      │ ┌──────────┬────────┬──────────┬────────────┬────────────┐ │ │
│      │ │ Run Date │ Host   │ Table    │ First Seen │ Last Seen  │ │ │
│      │ ├──────────┼────────┼──────────┼────────────┼────────────┤ │ │
│      │ │2026-04-25│crlnxm..│SALES_DATA│ 2025-12-20 │ 2026-04-25 │ │ │
│      │ │2025-12-20│crlnxm..│INVENTORY │ 2025-12-20 │ 2026-02-15 │ │ │
│      │ └──────────┴────────┴──────────┴────────────┴────────────┘ │ │
│      │                                                              │ │
│      │ Interpretation:                                              │ │
│      │ • In-Memory was actively used from Dec 2025 to Apr 2026     │ │
│      │ • All objects removed after 2026-04-25                      │ │
│      │ • Currently: 0 objects (feature disabled/unused)            │ │
│      │ • Audit trail: Complete history preserved for compliance    │ │
│      └──────────────────────────────────────────────────────────────┘ │
│    • Files generated:                                                   │
│      - reports/timeline/timeline_inmemory_20260512_143022.html         │
│      - reports/timeline/timeline_inmemory_20260512_143022.txt          │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. AVAILABLE TIMELINE OPTIONS                                           │
│    • option=all         - All licensed features comprehensive timeline  │
│    • option=inmemory    - In-Memory Column Store timeline               │
│    • option=partitioning- Partitioning timeline                         │
│    • option=compression - Advanced Compression timeline                 │
│    • option=security    - Security/TDE timeline                         │
│                                                                         │
│    Usage:                                                               │
│    ansible-playbook playbooks/report_timeline.yml \                    │
│      -i "localhost," -c local \                                         │
│      -e "repo_tns_alias=d1hub option=all"                              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### **KEY INSIGHTS: Historical Timeline Feature** (NEW)
│      │    - Compressed objects by instance                          │ │
│      │    - Encrypted tablespaces by instance                       │ │
│      └──────────────────────────────────────────────────────────────┘ │
│    • File: /tmp/oracle_options_audit_RUN3_2026-05-11.html             │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. SEND EMAIL                                                           │
│    • SMTP: mail1.us.aegon.com:25                                       │
│    • From: crlnxp1086@transamerica.com                                 │
│    • To: Mohsen.Taheri@transamerica.com                                │
│    • Subject: Oracle Options Audit - RUN3 - 2026-05-11                 │
│    • Body: Plain text summary + HTML attachment                        │
│      ┌──────────────────────────────────────────────────────────────┐ │
│      │ Oracle Options Audit Summary                                 │ │
│      │ ================================                             │ │
│      │ Run ID: 3                                                    │ │
│      │ Run Date: 2026-05-11                                         │ │
│      │ Total Instances: 78                                          │ │
│      │                                                              │ │
│      │ ⚠️  HIGH-RISK LICENSE FINDINGS:                             │ │
│      │ • Partitioning in-use: 8 instances                           │ │
│      │ • Advanced Compression in-use: 10 instances                  │ │
│      │ • Active Data Guard: 3 standbys                              │ │
│      │                                                              │ │
│      │ See attached HTML report for details.                        │ │
│      └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Data Storage Structure

```
CENTRAL REPOSITORY: crlnxd1046:1535/d1hub - DBAORALIC_SCH schema

┌─────────────────────────────────────────────────────────────────────────┐
│ ORACLE_OPT_RUNS (Master run header)                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ RUN_ID │ RUN_DATE   │ RUN_LABEL        │ TOTAL_HOSTS │ TOTAL_INSTANCES│
│ ────────────────────────────────────────────────────────────────────── │
│ 1      │ 2026-05-08 │ Test-Run         │ 1           │ 1              │
│ 2      │ 2026-05-10 │ US-Prod-Only     │ 15          │ 28             │
│ 3      │ 2026-05-11 │ Full-Estate      │ 45          │ 78             │ ◄─ Latest
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ├──────────────────────────────────────┐
                               ▼                                      ▼
┌─────────────────────────────────────────┐  ┌──────────────────────────────────────┐
│ ORACLE_OPT_INSTANCES                    │  │ ORACLE_OPT_VOPTION                   │
│ (Instance metadata)                     │  │ (v$option results)                   │
├─────────────────────────────────────────┤  ├──────────────────────────────────────┤
│ RUN_ID=3, HOSTNAME, SID, VERSION,       │  │ RUN_ID=3, HOSTNAME, SID,             │
│ DB_ROLE, SIZE_GB, PATCH_LEVEL           │  │ OPTION_NAME, OPTION_ENABLED,         │
│                                         │  │ IS_INUSE, IS_EE_EXTRA                │
│ • crlnxp316/mrxhistp (19c, 1876 GB)     │  │                                      │
│ • crlnxm1014/invdev (19c, 890 GB)       │  │ • Partitioning: TRUE, INUSE=Y, EE+=Y │
│ • uklnxpnl1042/infoprod (12c, 450 GB)   │  │ • Compression: TRUE, INUSE=Y, EE+=Y  │
│ • dcup60/finprod (11g, 2100 GB)         │  │ • RAC: FALSE, INUSE=N, EE+=Y         │
│ ... (78 rows total)                     │  │ ... (88 rows × 78 instances)         │
└─────────────────────────────────────────┘  └──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ ORACLE_OPT_FEATURES                                                     │
│ (dba_feature_usage_statistics results)                                 │
├─────────────────────────────────────────────────────────────────────────┤
│ RUN_ID=3, HOSTNAME, SID, FEATURE_NAME, DETECTED_USAGES, CURRENTLY_USED,│
│ FIRST_USAGE_DATE, LAST_USAGE_DATE, AUX_COUNT                           │
│                                                                         │
│ • crlnxp316/mrxhistp/Partitioning: 14 usages, TRUE, 2023-01-15         │
│ • crlnxp316/mrxhistp/ADDM: 3 usages, FALSE, 2024-03-20                 │
│ ... (65 rows × 78 instances)                                            │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ├──────────────┬──────────────┬───────────────┐
                               ▼              ▼              ▼               ▼
┌──────────────────────┐  ┌───────────────┐  ┌──────────────┐  ┌──────────────────┐
│ ORACLE_OPT_D_PART    │  │ ORACLE_OPT_   │  │ ORACLE_OPT_  │  │ ORACLE_OPT_D_IM  │
│ (Partitioning tables)│  │ D_COMP        │  │ D_SEC        │  │ (In-Memory objs) │
├──────────────────────┤  │ (Compressed)  │  │ (TDE/encryp) │  ├──────────────────┤
│ RUN_ID=3             │  ├───────────────┤  ├──────────────┤  │ RUN_ID=3         │
│ TABLE_NAME,          │  │ RUN_ID=3      │  │ RUN_ID=3     │  │ OBJECT_NAME,     │
│ PARTITION_COUNT,     │  │ TABLE_NAME,   │  │ TABLESPACE,  │  │ IM_SIZE_MB       │
│ SIZE_GB              │  │ COMPRESS_FOR  │  │ ENCR_ALG     │  │                  │
│                      │  │               │  │              │  │ ... (0 rows)     │
│ • TRANSACTIONS: 24   │  │ • AUDIT_LOG:  │  │ • USERS_TBS: │  └──────────────────┘
│   partitions, 450 GB │  │   OLTP, 89 GB │  │   AES256     │
│ • ORDERS: 12 parts,  │  │ • ARCHIVE:    │  │ • SECURE_TBS:│
│   125 GB             │  │   ARCHIVE, 2TB│  │   AES128     │
└──────────────────────┘  └───────────────┘  └──────────────┘
```

---

## 🔍 Example: Single Server Processing Timeline

```
Time: 00:00 - Start collection on crlnxp316
Time: 00:01 - SSH connected, discover Oracle user: svcorap
Time: 00:02 - Found 1 instance: mrxhistp
Time: 00:03 - Connect to mrxhistp as sysdba
Time: 00:04 - Query v$instance, v$database (basic info collected)
Time: 00:05 - Query v$option (88 rows retrieved)
Time: 00:06 - Query dba_feature_usage_statistics (65 rows retrieved)
Time: 00:07 - Partitioning enabled → Query dba_tab_partitions (45 tables found)
Time: 00:08 - Compression enabled → Query dba_tables (23 compressed objects)
Time: 00:09 - TDE enabled → Query v$encrypted_tablespaces (2 encrypted TS)
Time: 00:10 - Generate SQL file: oracle_audit_3_crlnxp316.sql (2145 lines)
Time: 00:11 - Connect to repository: crlnxd1046:1535/d1hub
Time: 00:12 - Execute INSERT statements (1 run + 1 instance + 88 options + 65 features + 45 partition + 23 compression + 2 TDE = 225 INSERTs)
Time: 00:13 - COMMIT successful, RUN_ID=3 stored
Time: 00:14 - Server crlnxp316 complete ✓

Total time per server: ~2-5 minutes (depending on database size and evidence queries)
Total time for 45 servers (parallel execution with forks=10): ~30-45 minutes
```

---

## 📧 Email Report Format

```
From: crlnxp1086@transamerica.com
To: Mohsen.Taheri@transamerica.com
Subject: Oracle Options Audit - RUN3 - 2026-05-11 - 78 Instances

Body:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ORACLE OPTIONS & FEATURES AUDIT SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Run ID:          3
Run Label:       Full-Estate-May2026
Run Date:        2026-05-11 14:23:45
Total Hosts:     45
Total Instances: 78 (62 PRIMARY, 16 STANDBY)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  HIGH-RISK LICENSE FINDINGS (ENABLED + IN-USE)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 Partitioning (8 instances)
   • crlnxp316/mrxhistp (19c, 1876 GB) - 45 partitioned tables
   • crlnxm1014/invdev (19c, 890 GB) - 23 partitioned tables
   • uklnxpnl1042/infoprod (12c, 450 GB) - 12 partitioned tables
   ... (5 more)

🔴 Advanced Compression (10 instances)
   • dcup60/finprod (11g, 2100 GB) - 89 compressed tables
   • crlnxm145/archprod (12c, 3400 GB) - 156 compressed tables
   ... (8 more)

🔴 Active Data Guard (3 standby databases)
   • uklnxtuk0203/hrprod_standby (read-only queries detected)
   • crlnxp1088/finprod_standby (real-time query enabled)
   ... (1 more)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ️  OPTIONS ENABLED BUT NOT CURRENTLY USED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Real Application Clusters: 0 instances
✓ In-Memory Column Store: 2 instances (enabled but no data populated)
✓ Label Security: 0 instances

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📎 Attachment: oracle_options_audit_RUN3_2026-05-11.html
   (Complete report with all instances, all options, and drill-down evidence)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🎯 Key Benefits

1. **Automated Discovery** - No manual SID list needed
2. **Evidence-Based** - Collects proof of usage (partitioned tables, compressed objects, etc.)
3. **Centralized Storage** - All runs stored historically in repository
4. **Standby-Aware** - Detects standbys and Active Data Guard usage
5. **Actionable Reports** - Clear risk identification with drill-down details
6. **Reusable** - Can regenerate reports from old runs without re-collecting

---

## 📚 See Also

- [RUNBOOK.md](roles/oracle_options_audit/RUNBOOK.md) - Full operational procedures
- [QUICK_REFERENCE.md](roles/oracle_options_audit/QUICK_REFERENCE.md) - Quick commands
- [README.md](roles/oracle_options_audit/README.md) - Technical reference
