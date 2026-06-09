# Oracle Options Audit — Architecture & Data Flow

## 📊 How The Playbook Works (Updated May 2026)

### Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 1: SCAN (Parallel across all hosts)                      │
├─────────────────────────────────────────────────────────────────┤
│ • Detect Oracle processes on each host                         │
│ • Parse /etc/oratab for ORACLE_HOME mapping                    │
│ • Connect to each SID and collect:                             │
│   - v$option (license flags)                                    │
│   - dba_feature_usage_statistics                               │
│   - AUTO-DETECTION: Automatically triggers evidence collection │
│     when CURRENTLY_USED='TRUE' OR DETECTED_USAGES > 0          │
│   - Partitioning objects (auto-detected or explicit)           │
│   - Compression objects (auto-detected or explicit)            │
│   - Security/TDE objects (auto-detected or explicit)           │
│   - In-Memory objects (auto-detected or explicit)              │
│ • Store ALL results in memory (hostvars)                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 2: INSERT (After all scanning complete)                  │
├─────────────────────────────────────────────────────────────────┤
│ STEP 1: Test repository connection                             │
│         ✓ Validates credentials & network connectivity         │
│         ✗ FAILS playbook if repo unreachable                   │
│                                                                 │
│ STEP 2: INSERT run header → ORACLE_OPT_RUNS                    │
│         Creates NEW RUN_ID for this execution                   │
│         Returns RUN_ID (e.g., 42)                               │
│                                                                 │
│ STEP 3: Generate SQL script files                              │
│         Per-host files:                                         │
│         • oracle_audit_<RUN_ID>_<hostname>.sql                  │
│         • oracle_audit_detail_<RUN_ID>_<hostname>.sql           │
│         Location: logs/oracle_options_audit/<date>/             │
│                                                                 │
│ STEP 4: Execute SQL scripts via sqlplus                        │
│         All data inserted with SAME RUN_ID                      │
│         OLD DATA IS NEVER DELETED (historical timeline!)        │
│         ✓ Error detection: ORA-, SP2- errors fail playbook     │
│         ✓ Verification: SELECT COUNT(*) after insert           │
│         ✗ FAILS if expected rows != actual rows                │
│                                                                 │
│ STEP 5: Display summary                                        │
│         • Total hosts, instances, run label                     │
│         • RUN_ID, data location, evidence counts               │
│         • Auto-detection status per feature                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 3: REPORTING                                              │
├─────────────────────────────────────────────────────────────────┤
│ Option A: Current State Report (report_audit_run.yml)          │
│          • Queries LATEST run_id only                           │
│          • Shows what's enabled/in-use NOW                      │
│          • Generates HTML report + email                        │
│                                                                 │
│ Option B: Historical Timeline Report (report_timeline.yml NEW) │
│          • Queries ALL run_ids                                  │
│          • Shows what changed WHEN                              │
│          • Tracks feature adoption/removal over time            │
│          • Generates HTML + text reports                        │
│          • Provides complete audit trail                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Why Batch Processing?

### Current Design (Batch at END)

**Advantages:**
- ✅ **Transaction safety** — all data from one run is committed together
- ✅ **Audit trail** — SQL files preserved for compliance/debugging
- ✅ **Performance** — single connection per host, bulk INSERT
- ✅ **Rollback capability** — can review/edit SQL files before re-running
- ✅ **Network efficiency** — fewer DB connections, less overhead

**Disadvantages:**
- ⚠️ **Delayed feedback** — must scan ALL hosts before seeing insert status
- ⚠️ **Memory usage** — all results held in Ansible hostvars until end
- ⚠️ **All-or-nothing** — if one host fails to scan, no data is inserted

### Alternative Design (Real-time INSERT per host)

**If you wanted to insert data as each host is scanned:**

**Advantages:**
- ✅ Immediate feedback per host
- ✅ Lower memory footprint
- ✅ Partial success possible (some hosts succeed even if others fail)

**Disadvantages:**
- ❌ Inconsistent RUN_ID snapshots
- ❌ More DB connections (load on repository)
- ❌ Complex transaction management
- ❌ No audit trail (SQL executed inline, not saved)

**Recommendation:** **Keep current batch design** for enterprise auditing requirements.

---

## � AUTO-DETECTION FEATURE (New - May 2026)

### How It Works

**Problem:** Features may show usage statistics but have zero evidence rows if collection flags are disabled.

**Solution:** Automatic evidence collection when feature usage is detected.

### Auto-Detection Logic

```yaml
# For each licensed feature, check if it's in use:
- name: Auto-detect Partitioning usage
  set_fact:
    _cur_partitioning_in_use: >-
      {{
        _inst_features.stdout_lines
        | select('search', 'Partitioning')
        | select('search', 'currently_used.*TRUE|detected_usages.*[1-9]')
        | list | length > 0
      }}

# Collection happens if EITHER:
when: >-
  ((collect_partitioning | default(true) | bool) or      ← User flag
   (_cur_partitioning_in_use | default(false) | bool))   ← Auto-detected
```

### What Gets Auto-Detected

| Feature | Auto-Detection Criteria |
|---------|------------------------|
| **Partitioning** | Feature name contains 'Partitioning' AND (CURRENTLY_USED='TRUE' OR DETECTED_USAGES > 0) |
| **Compression** | Feature name contains 'Compression' or 'HCC' AND (CURRENTLY_USED='TRUE' OR DETECTED_USAGES > 0) |
| **Security/TDE** | Feature name contains 'Encryption', 'TDE', 'Advanced Security', or 'Transparent Data Encryption' AND (CURRENTLY_USED='TRUE' OR DETECTED_USAGES > 0) |
| **In-Memory** | Feature name contains 'In-Memory' AND (CURRENTLY_USED='TRUE' OR DETECTED_USAGES > 0) |

### Benefits

- ✅ **No missing evidence** — Automatically collects when feature is used
- ✅ **Explicit override** — User can still set collect_*=false to skip
- ✅ **Debug visibility** — Shows auto-detection status in output
- ✅ **Consistent behavior** — Same logic for all licensed features

### Debug Output Example

```
TASK [oracle_options_audit : Debug - Show evidence summary for aahd]
ok: [crlnxm145] => {
    "msg": [
        "=== EVIDENCE COLLECTION SUMMARY ===",
        "Partitioning rows: 264 [IN USE]",
        "Compression rows:  0",
        "Security rows:     0",
        "In-Memory rows:    0 [IN USE]",
        "",
        "Auto-detection: Part=True Comp=False Sec=False IM=True",
        "IM Auto-collected: False (no objects found despite usage stats)",
        "",
        "Interpretation:",
        "  • Part/IM show 'IN USE' = feature usage detected in stats",
        "  • 0 evidence rows + IN USE = feature enabled but no current objects",
        "  • This is VALID: Feature used historically, now disabled/removed"
    ]
}
```

---

## 📅 HISTORICAL TIMELINE PRESERVATION (New - May 2026)

### Data Preservation Strategy

**Key Principle:** OLD DATA IS NEVER DELETED

### How Timeline Works

```
Each playbook run:
┌────────────────────────────────────────────────┐
│ 1. Creates NEW RUN_ID (e.g., 42)              │
│ 2. Inserts complete snapshot with that RUN_ID │
│ 3. Previous runs (41, 40, 39...) stay intact  │
└────────────────────────────────────────────────┘

Repository Timeline:
┌─────────┬────────────┬─────────┬──────────────────┐
│ RUN_ID  │ RUN_DATE   │ HOST    │ INMEM_OBJECTS    │
├─────────┼────────────┼─────────┼──────────────────┤
│ 42      │ 2026-05-12 │crlnxm145│ 0                │ ← Today
│ 41      │ 2026-05-11 │crlnxm145│ 0                │
│ 40      │ 2026-05-10 │crlnxm145│ 0                │
│ 39      │ 2026-04-25 │crlnxm145│ 3 (SALES, ORDERS)│
│ 38      │ 2026-04-24 │crlnxm145│ 3                │
│ ...     │ ...        │...      │ ...              │
└─────────┴────────────┴─────────┴──────────────────┘

Analysis: In-Memory was used until run 39 (2026-04-25),
          then removed. Now has 0 objects but historical
          proof exists in repository.
```

### Timeline Queries

**Current State (report_audit_run.yml):**
```sql
-- Shows LATEST run only
SELECT * FROM ORACLE_OPT_D_INMEM
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS);
```

**Historical Timeline (report_timeline.yml - NEW):**
```sql
-- Shows ALL runs with timeline analysis
SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD') AS run_date,
    im.hostname, im.sid, im.owner, im.table_name,
    im.inmemory, im.priority, im.compression
FROM ORACLE_OPT_D_INMEM im
JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
ORDER BY r.run_timestamp DESC;

-- Object appearance history
SELECT 
    im.hostname, im.sid, im.owner, im.table_name,
    TO_CHAR(MIN(r.run_timestamp), 'YYYY-MM-DD') AS first_seen,
    TO_CHAR(MAX(r.run_timestamp), 'YYYY-MM-DD') AS last_seen,
    COUNT(DISTINCT im.run_id) AS times_seen,
    ROUND(SYSDATE - MAX(r.run_timestamp)) AS days_since
FROM ORACLE_OPT_D_INMEM im
JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
GROUP BY im.hostname, im.sid, im.owner, im.table_name
ORDER BY MAX(r.run_timestamp) DESC;
```

### Use Cases

| Scenario | Solution |
|----------|----------|
| **License auditor says:** "You used In-Memory in March" | Show dba_feature_usage_statistics with FIRST_USAGE_DATE and timeline query showing objects present in March runs |
| **Need to prove:** When feature was added/removed | Timeline query shows first_seen/last_seen dates for each object |
| **Track configuration changes:** Partition counts growing | Compare partition_count across run_ids for same table |
| **Distinguish test vs production:** | Check times_seen: 1-2 runs = test, 20+ runs = production |

### Files

| File | Purpose |
|------|---------|
| `show_all_options_timeline.sql` | Comprehensive timeline across all features |
| `show_inmemory_timeline.sql` | In-Memory specific timeline |
| `show_partitioning_timeline.sql` | Partitioning timeline |
| `show_compression_timeline.sql` | Compression timeline |
| `show_security_timeline.sql` | Security/TDE timeline |

### Playbook

```bash
# Generate timeline reports
ansible-playbook playbooks/report_timeline.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub option=all"

# Output: HTML + text reports in reports/timeline/
```

---

## �📁 SQL Script Files

### Files Created

| File Pattern | Contents | When Created |
|--------------|----------|--------------|
| `oracle_audit_<RUN_ID>_<hostname>.sql` | Instance metadata, v$option, feature usage | Every run |
| `oracle_audit_detail_<RUN_ID>_<hostname>.sql` | Partitioning, compression, TDE, In-Memory objects | If collect_* flags enabled |

### Location

```
logs/oracle_options_audit/<YYYY-MM-DD>/
├── oracle_audit_22_crlnxp1015.sql
├── oracle_audit_22_crlnxp1088.sql
├── oracle_audit_detail_22_crlnxp1015.sql
├── oracle_audit_detail_22_crlnxp1088.sql
└── audit_summary_run22_2026-05-11.txt
```

### Lifecycle

**Files are NOT automatically deleted.**

**Why kept:**
- Audit trail for compliance (who ran what, when)
- Debugging failed inserts
- Re-running specific hosts without re-scanning
- Historical evidence of data collected

**Cleanup:**

```bash
# Delete logs older than 90 days
find logs/oracle_options_audit/ -type f -mtime +90 -delete

# Archive old runs
tar -czf logs_archive_$(date +%Y%m).tar.gz logs/oracle_options_audit/2026-*
rm -rf logs/oracle_options_audit/2026-01-* logs/oracle_options_audit/2026-02-*
```

**Add to cron:**

```bash
# /etc/cron.weekly/cleanup_oracle_audit_logs
#!/bin/bash
find /path/to/logs/oracle_options_audit/ -type f -mtime +90 -delete
```

---

## 🔍 How To Detect Connection Problems

### 1. Repository Connection Test (NEW)

At the start of the playbook, **before any scanning**, the repo connection is tested:

```yaml
TASK [oracle_options_audit : Test repository database connection]
ok: [localhost]

TASK [oracle_options_audit : Display repository connection status]
ok: [localhost] => {
    "msg": "✓ Repository connection SUCCESSFUL: DBAORALIC_SCH@d1hub"
}
```

**If connection fails:**

```
fatal: [localhost]: FAILED! => {
    "msg": "REPO_CONNECTION_OK not in stdout",
    "stdout": "ORA-12154: TNS:could not resolve the connect identifier specified"
}
```

**Playbook STOPS immediately** — no scanning happens if repo is unreachable.

---

### 2. Insert Error Detection (NEW)

After SQL scripts execute, errors are detected:

```yaml
TASK [oracle_options_audit : Execute SQL insert file for crlnxp1015]
fatal: [localhost] => {
    "msg": "ORA-00001: unique constraint violated"
}
```

**Triggers failure if:**
- Exit code != 0
- `ORA-` errors in stdout/stderr
- `SP2-` errors (SQL*Plus errors)

---

### 3. Row Count Verification (NEW)

After inserts, the playbook **verifies data arrived**:

```yaml
TASK [oracle_options_audit : Verify data inserted successfully]
ok: [localhost]

TASK [oracle_options_audit : Display insert verification]
ok: [localhost] => {
    "msg": "✓ DATA INSERT VERIFIED: 47 instances inserted into DBAORALIC_SCH.ORACLE_OPT_INSTANCES (RUN_ID=22)"
}
```

**If no data inserted:**

```yaml
TASK [oracle_options_audit : Fail if no data was inserted]
fatal: [localhost] => {
    "msg": "✗ CRITICAL ERROR: No data was inserted into repository!\n
            Expected 47 instances but found 0 in database.\n
            Check SQL files in: logs/oracle_options_audit/2026-05-11/oracle_audit_22_*.sql\n
            Check repo connection: DBAORALIC_SCH@d1hub"
}
```

**Playbook FAILS** — alerts you immediately that no data was saved.

---

## 🛠️ Troubleshooting Failed Inserts

### Symptom: Playbook says "success" but no data in repository

**Possible causes:**

1. **Wrong TNS alias or connection string**

   ```bash
   # Test manually from Ansible controller:
   sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub
   ```

2. **Network firewall blocking port 1535**

   ```bash
   telnet crlnxd1046 1535
   tnsping d1hub
   ```

3. **Schema permissions missing**

   ```sql
   -- Check as DBA:
   SELECT privilege FROM dba_sys_privs WHERE grantee = 'DBAORALIC_SCH';
   SELECT table_name FROM all_tables WHERE owner = 'DBAORALIC_SCH' AND table_name LIKE 'ORACLE_OPT%';
   ```

4. **Tables not created**

   ```bash
   # Run setup first:
   ansible-playbook playbooks/_setup_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"
   ```

---

### Symptom: Playbook fails with "ORA-12154"

**Cause:** TNS alias not found or connection string malformed.

**Fix:**

```bash
# Option 1: Use TNS alias (recommended)
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "repo_tns_alias=d1hub"

# Option 2: Override connection string
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "repo_host=crlnxd1046 repo_port=1535 repo_sid=d1hub"
```

**Verify tnsnames.ora on Ansible controller:**

```bash
cat $ORACLE_HOME/network/admin/tnsnames.ora | grep -A5 d1hub
```

---

### Symptom: SQL script file shows errors

**Check the generated SQL file:**

```bash
cd logs/oracle_options_audit/2026-05-11/
cat oracle_audit_22_crlnxp1015.sql

# Look for:
# - CONNECT line (credentials visible)
# - INSERT statements
# - COMMIT at end
```

**Re-run SQL file manually:**

```bash
sqlplus /nolog @logs/oracle_options_audit/2026-05-11/oracle_audit_22_crlnxp1015.sql
```

**Common errors:**

- **ORA-00001**: Duplicate key (run already inserted — ignore or truncate)
- **ORA-00904**: Column not found (run `_setup_audit_tables.yml` to add missing columns)
- **ORA-00942**: Table doesn't exist (run `_setup_audit_tables.yml` first)
- **ORA-01017**: Invalid credentials (check `repo_password`)

---

## ✅ Monitoring Successful Runs

### Query the repository to verify data arrived

```sql
-- Latest run summary
SELECT run_id, run_date, run_label, total_hosts, total_instances
FROM DBAORALIC_SCH.ORACLE_OPT_RUNS
ORDER BY run_date DESC
FETCH FIRST 5 ROWS ONLY;

-- Instances from latest run
SELECT hostname, sid, db_name, oracle_version, region
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
ORDER BY hostname, sid;

-- Count options collected in latest run
SELECT COUNT(*)
FROM DBAORALIC_SCH.ORACLE_OPT_VOPTION
WHERE run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS);

-- Verify expected number of instances
SELECT r.total_instances AS expected,
       (SELECT COUNT(*) FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i WHERE i.run_id = r.run_id) AS actual
FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
WHERE r.run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS);
```

---

## 🔄 Re-Running Failed Hosts

### If a host failed during scanning but repo connection is OK

**Scan single host and append to existing run:**

```bash
# Get the RUN_ID from last run
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<< "SELECT MAX(run_id) FROM ORACLE_OPT_RUNS;"

# Re-run failed host (creates new RUN_ID)
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1088 \
  -e "run_label=Retry-crlnxp1088"
```

**Or manually edit and re-run SQL file:**

```bash
# Edit oracle_audit_22_crlnxp1088.sql to fix data
vi logs/oracle_options_audit/2026-05-11/oracle_audit_22_crlnxp1088.sql

# Re-execute
sqlplus /nolog @logs/oracle_options_audit/2026-05-11/oracle_audit_22_crlnxp1088.sql
```

---

## 📈 Performance Considerations

### Current Performance

| Estate Size | Scan Time | Insert Time | Total |
|-------------|-----------|-------------|-------|
| 10 hosts, 20 instances | ~5 min | ~30 sec | ~6 min |
| 50 hosts, 150 instances | ~15 min | ~2 min | ~17 min |
| 200 hosts, 600 instances | ~45 min | ~5 min | ~50 min |

### Bottlenecks

1. **Scanning** (95% of time)
   - Parallel execution across hosts (Ansible forks=5)
   - Detail queries on large DBs (partitioning, compression)

2. **Inserting** (5% of time)
   - Single DB connection per script file
   - Network latency (controller → repository)

### Optimization

**Faster scanning:**

```bash
# Increase parallel forks
export ANSIBLE_FORKS=10
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml

# Skip detail evidence queries
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "collect_partitioning=false collect_compression=false"
```

**Faster inserting:**
- Use TNS alias (avoids DESCRIPTION syntax parsing)
- Ensure repository on fast network (1 Gbps+)
- Use SQL*Net compression (`SQLNET.COMPRESSION=on` in sqlnet.ora)

---

## 🔐 Security Best Practices

### Credential Management

**Current:**
- Passwords in `defaults/main.yml` (plaintext)

**Recommended:**
- Ansible Vault for sensitive variables
- Separate `vars/vault.yml` with encrypted credentials

```bash
# Encrypt passwords
ansible-vault create roles/oracle_options_audit/vars/vault.yml

# Add to playbook:
vars_files:
  - roles/oracle_options_audit/vars/vault.yml

# Run with vault password:
ansible-playbook playbooks/collect_oracle_options.yml \
  --ask-vault-pass \
  -i ansibleInventory/inv_key.yml
```

### SQL File Cleanup

**SQL files contain plaintext passwords!**

```bash
# Secure log directory
chmod 700 logs/oracle_options_audit/
chown svcorap:dba logs/oracle_options_audit/

# Auto-delete after 30 days
find logs/oracle_options_audit/ -type f -name "*.sql" -mtime +30 -delete
```

---

## 📚 Related Documentation

- **[RUNBOOK.md](RUNBOOK.md)** — Operational procedures, SOPs, troubleshooting
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** — One-page command cheat sheet
- **[README.md](README.md)** — Technical reference, variables, queries

---

**Last Updated:** 2026-05-11  
**Maintained by:** DBA Team (Mohsen Taheri)
