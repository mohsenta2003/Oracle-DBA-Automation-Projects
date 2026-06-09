# Oracle Options & Features Audit - Operational Runbook

**Last Updated:** May 11, 2026  
**Owner:** DBA Team  
**Central Repository:** d1hub on crlnxd1046:1535 (DBAORALIC_SCH schema)  
**Legacy Repository:** dbai on crlnxp1086:1535 (MTAHERI schema)  
**📋 Quick commands:** See [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Prerequisites](#prerequisites)
3. [Initial Setup (One-Time)](#initial-setup-one-time)
4. [Repository Build & Management](#repository-build--management)
   - [Task 1: Test Repository Connection](#task-1-test-repository-connection)
   - [Task 2: Build Repository](#task-2-build-repository-create-all-objects)
   - [Task 3: Verify Repository Structure](#task-3-verify-repository-structure)
   - [Task 4: Create/Update Reporting Views](#task-4-createupdate-reporting-views)
   - [Task 5: Fix Missing Components](#task-5-fix-missing-components)
   - [Task 6: Complete Verification Checklist](#task-6-complete-verification-checklist)
5. [Playbook Reference](#playbook-reference)
   - [_validate_repo.yml](#_validate_repoyml)
   - [_setup_audit_tables.yml](#_setup_audit_tablesyml)
   - [_clean_repo_data.yml](#_clean_repo_datayml)
   - [_check_audit_tables.yml](#_check_audit_tablesyml)
   - [collect_oracle_options.yml](#collect_oracle_optionsyml)
   - [report_audit_run.yml](#report_audit_runyml)
6. [Standard Operating Procedures](#standard-operating-procedures)
7. [Common Scenarios](#common-scenarios)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance Tasks](#maintenance-tasks)
10. [Query Examples](#query-examples)

---

## Quick Reference

### Most Common Commands

```bash
# Weekly full audit + email
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml -e "run_label=Weekly-$(date +%Y-%m-%d)"
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local

# Test single host
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml -l crlnxp1015 -e "run_label=Test-Run"
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local -e "send_summary_email=false"

# Production only
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml -l "us_lnx_prod,eu_nl_lnx_prod,eu_uk_lnx_prod" -e "run_label=Prod-$(date +%Y-%m-%d)"
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local

# US TLP AIX servers - Background execution with nohup (14 servers, ~30 min runtime)
nohup ansible-playbook playbooks/collect_oracle_options.yml \
  -i inv_var.yml \
  -l "tlp_aix_prod,tlp_aix_prod2,tlp_aix_nonprod,tlp_aix_nonprod2" \
  -e "tlporacle_ssh_pass='<aix-group1-password>'" \
  -e "tlp2oracle_ssh_pass='<aix-group2-password>'" \
  -e "run_label=US-TLP-AIX-Full-$(date +%Y-%m-%d)" \
  > logs/aix_audit_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# Monitor AIX audit progress (filtered view)
tail -f logs/aix_audit_*.log | grep -E "TASK|PLAY|ok=|changed=|failed="

# Monitor full log output
tail -f logs/aix_audit_*.log

# Check host coverage (identify missing/stale servers)
./scripts/check_host_coverage.sh 7    # Show hosts not audited in last 7 days
./scripts/check_host_coverage.sh 30   # Show hosts missing for 30+ days

# Verify host counts after audit run (check if all expected hosts captured)
./scripts/quick_host_check.sh         # Quick summary: Latest vs All-Time counts
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub @scripts/quick_check.sql  # Simple SQL check
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub @scripts/verify_host_coverage.sql  # Full 12-section report
```

### Repository Management Commands

```bash
# Validate repository (before any operation)
ansible-playbook playbooks/_validate_repo.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# Build complete schema (first-time setup or rebuild)
ansible-playbook playbooks/_setup_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# Clean all data (start fresh, keep schema)
ansible-playbook playbooks/_clean_repo_data.yml -i "localhost," -c local -e "repo_tns_alias=d1hub confirm_clean=yes"

# Check table structure
ansible-playbook playbooks/_check_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"
```

---

## Prerequisites

### System Requirements

- **Ansible Controller:** crlnxp1086 (or designated control node)
- **Ansible Version:** 2.9+
- **Python:** 3.x
- **Collections:** `community.general`
- **Database Access:** sqlplus installed and configured

### Access Requirements

- SSH key access to all target Linux hosts
- AIX/TLP hosts: Password authentication configured in inventory
- Central DB: MTAHERI user credentials (stored in role defaults)
- Email: Access to SMTP relay (mail1.us.aegon.com:25)

### Installation Check

```bash
# Verify Ansible
ansible --version

# Verify collection
ansible-galaxy collection list | grep community.general

# Install if missing
ansible-galaxy collection install community.general

# Test inventory access
ansible all -i ansibleInventory/inv_key.yml -m ping --limit "crlnxp1015"

# Test NEW repository connection (d1hub)
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub

# Validate repository schema
ansible-playbook playbooks/_validate_repo.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"
```

---

## Initial Setup (One-Time)

### Step 1: Create Central Repository Tables

**When:** First time setup or after schema changes

```bash
# Create all tables and views
ansible-playbook playbooks/_setup_audit_tables.yml -i "localhost," -c local

# Verify table creation
ansible-playbook playbooks/_check_audit_tables.yml -i "localhost," -c local
```

**Expected Output:**
```
ORACLE_OPT_RUNS: 0 rows
ORACLE_OPT_INSTANCES: 0 rows
ORACLE_OPT_VOPTION: 0 rows
ORACLE_OPT_FEATURES: 0 rows
... (all tables created)
```

### Step 2: Test Single Host

**Purpose:** Validate playbook before full run

```bash
# Pick a known working host (e.g., crlnxp1015)
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "run_label=Initial-Test-$(date +%Y-%m-%d)" \
  -vv

# Check data inserted
sqlplus mtaheri/PASSWORD@crlnxp1086:1535/dbai << EOF
SELECT COUNT(*) FROM MTAHERI.ORACLE_OPT_INSTANCES;
SELECT COUNT(*) FROM MTAHERI.ORACLE_OPT_VOPTION;
EXIT;
EOF
```

### Step 3: Generate Test Report

```bash
# Generate report without sending email
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "send_summary_email=false report_output_dir=/tmp"

# Check HTML file
ls -lh /tmp/oracle_options_audit_*.html
```

---

## Repository Build & Management

### Overview

The central repository stores all audit data in **d1hub** (DBAORALIC_SCH schema). This section covers:
- ✅ Testing repository connectivity
- 🔨 Building/rebuilding the repository  
- 🔍 Validating schema structure
- 📊 Creating reporting views
- 🛠️ Fixing missing components
- ✓ Verification procedures

---

### Task 1: Test Repository Connection

**When:** Before any repository operations, troubleshooting connection issues

#### Using Validation Playbook (Recommended)

```bash
# Test connection + validate schema
ansible-playbook playbooks/_validate_repo.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"
```

**Expected Output:**
```
TASK [Test repository database connection]
ok: [localhost]

TASK [Display connection status]
ok: [localhost] => {
    "msg": "✓ Repository connection SUCCESSFUL: DBAORALIC_SCH@d1hub"
}

TASK [Validation successful]
ok: [localhost] => {
    "msg": "✓✓✓ REPOSITORY VALIDATION PASSED ✓✓✓"
}
```

#### Manual Connection Test

```bash
# Test TNS alias
tnsping d1hub

# Test SQL*Plus connection
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<EOF
SELECT 'Connected to: ' || sys_context('USERENV','DB_NAME') AS status FROM dual;
EXIT;
EOF
```

#### Using Custom Credentials (Different Repository)

**To set up repository on ANY database**, pass custom credentials:

```bash
# Test connection with custom credentials via TNS alias
ansible-playbook playbooks/_validate_repo.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=MYDB repo_user=AUDITUSER repo_password='MyP@ss123' repo_schema=AUDITUSER"

# Test connection with connection string (host:port:sid)
ansible-playbook playbooks/_validate_repo.yml \
  -i "localhost," -c local \
  -e "repo_host=dbserver.company.com repo_port=1521 repo_sid=ORCL repo_user=AUDITUSER repo_password='MyP@ss123' repo_schema=AUDITUSER"

# Manual SQL*Plus test with custom TNS
sqlplus AUDITUSER/MyP@ss123@MYDB <<EOF
SELECT sys_context('USERENV','CURRENT_SCHEMA') AS schema_name FROM dual;
EXIT;
EOF
```

**Complete Example: Build Repository on Custom Database**

```bash
# 1. Validate connection
ansible-playbook playbooks/_validate_repo.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=prodaudit repo_user=LICENSE_AUDIT repo_password='SecureP@ss' repo_schema=LICENSE_AUDIT"

# 2. Build all objects (if validation shows missing tables)
ansible-playbook playbooks/_setup_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=prodaudit repo_user=LICENSE_AUDIT repo_password='SecureP@ss' repo_schema=LICENSE_AUDIT"

# 3. Collect data to custom repository
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "repo_tns_alias=prodaudit repo_user=LICENSE_AUDIT repo_password='SecureP@ss' repo_schema=LICENSE_AUDIT run_label=CustomDB-Test"

# 4. Generate report from custom repository
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=prodaudit repo_user=LICENSE_AUDIT repo_password='SecureP@ss' repo_schema=LICENSE_AUDIT send_summary_email=false"
```

#### Troubleshooting Connection Failures

**Error: ORA-12154 (TNS:could not resolve)**

```bash
# Check tnsnames.ora on Ansible controller
echo $ORACLE_HOME
cat $ORACLE_HOME/network/admin/tnsnames.ora | grep -A5 d1hub

# If missing, add TNS entry:
cat >> $ORACLE_HOME/network/admin/tnsnames.ora << 'EOF'
d1hub =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = crlnxd1046)(PORT = 1535))
    (CONNECT_DATA =
      (SID = d1hub)
    )
  )
EOF

# Test again
tnsping d1hub
```

**Error: ORA-01017 (Invalid username/password)**

```bash
# Verify credentials in defaults file
cat roles/oracle_options_audit/defaults/main.yml | grep -A5 repo_

# Test with correct password
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub
```

**Error: ORA-12170 (Connect timeout) or ORA-12541 (No listener)**

```bash
# Check network connectivity
ping crlnxd1046
telnet crlnxd1046 1535

# Check listener status on target server (as oracle user on crlnxd1046)
lsnrctl status
```

---

### Task 2: Build Repository (Create All Objects)

**When:** First-time setup, new repository, or complete rebuild

**Options:**
- **Full Build** — Creates all tables, indexes, sequences, views (use for new repo or schema rebuild)
- **Clean Data Only** — Truncates all data but keeps schema structure (use to start fresh)

#### Automated Build (Recommended)

```bash
# Create all tables, indexes, sequences, views (default d1hub repository)
ansible-playbook playbooks/_setup_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"

# Create on CUSTOM database with different credentials
ansible-playbook playbooks/_setup_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=MYDB repo_user=MYSCHEMA repo_password='MyP@ss' repo_schema=MYSCHEMA"
```

**What This Creates:**

| Object Type | Count | Description |
|-------------|-------|-------------|
| **Tables** | 11 | ORACLE_OPT_RUNS, INSTANCES, VOPTION, FEATURES, D_PART, D_COMPRESS, D_SECURITY, D_INMEM, D_PDB, D_ADG, D_RAC |
| **Indexes** | 23 | 11 PRIMARY KEY (auto-created) + 12 performance indexes |
| **Sequences** | 11 | Auto-increment for primary keys (auto-created by IDENTITY columns) |
| **Views** | 5 | LATEST_VW, ENABLED_VW, INUSE_VW, TREND_VW, HISTORY_VW |

**Performance Indexes Created:**
- RUNS: RUN_DATE, RUN_LABEL
- INSTANCES: RUN_ID+HOSTNAME, HOSTNAME+SID, DB_ROLE+IS_STANDBY
- VOPTION: RUN_ID+IS_INUSE, OPTION_NAME+IS_EE_EXTRA, HOSTNAME+SID
- FEATURES: RUN_ID+DETECTED_USAGES, FEATURE_NAME
- Detail tables: RUN_ID indexes on D_PART, D_COMPRESS, D_SECURITY

**Expected Output:**
```
TASK [Create all ORACLE_OPT_* tables (idempotent)]
ok: [localhost]

TASK [Create performance indexes]
ok: [localhost]

TASK [Create reporting views]
ok: [localhost]

TASK [Repository build complete]
ok: [localhost] => {
    "msg": "✓✓✓ REPOSITORY BUILD COMPLETE ✓✓✓
            
            Objects created:
            TABLES:11
            INDEXES:23
            SEQUENCES:11
            VIEWS:5"
}
```

#### Clean Data Only (Recommended for Fresh Start)

**Use when:** You want to remove all collected data but keep the schema structure intact.

```bash
# Clean all data from d1hub repository (with confirmation prompt)
ansible-playbook playbooks/_clean_repo_data.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"

# Clean without confirmation prompt
ansible-playbook playbooks/_clean_repo_data.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub confirm_clean=yes"

# Clean custom repository
ansible-playbook playbooks/_clean_repo_data.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=MYDB repo_user=AUDITUSER repo_password='MyPass' repo_schema=AUDITUSER confirm_clean=yes"
```

**What This Does:**
- ✓ Truncates all 11 tables (removes all data)
- ✓ Resets all sequences to 1
- ✓ Preserves schema structure (tables, indexes, views remain)
- ✗ Does NOT drop or recreate any objects

**Expected Output:**
```
📊 Current row counts BEFORE clean:
RUNS:15
INSTANCES:450
VOPTION:18000
...

✓ All tables truncated successfully
✓ All sequences reset to 1

📊 Row counts AFTER clean (all should be 0):
RUNS:0
INSTANCES:0
VOPTION:0
...

✓✓✓ REPOSITORY DATA CLEAN COMPLETED ✓✓✓
```

---

### Task 3: Verify Repository Structure

**When:** After building repository, after schema changes, troubleshooting

#### Automated Verification

```bash
# Check all objects exist
ansible-playbook playbooks/_check_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"
```

**Expected Output:**
```
Table Structure Verification:
  ORACLE_OPT_RUNS: EXISTS (0 rows)
  ORACLE_OPT_INSTANCES: EXISTS (0 rows)
  ORACLE_OPT_VOPTION: EXISTS (0 rows)
  ... 8 more tables ...

✓ All 11 tables verified
✓ All required columns present
✓ Repository ready for data collection
```

#### Manual Verification (SQL)

```bash
# Use the validation script
cd c:\temp\project\ansible\Oracle-DBA-Automation-Projects-main
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub @check_repo_schema.sql
```

**Or query directly:**

```sql
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 200 PAGESIZE 100

-- Count objects by type
SELECT object_type, COUNT(*) AS cnt
FROM user_objects
WHERE object_name LIKE 'ORACLE_OPT%'
GROUP BY object_type
ORDER BY object_type;

-- Expected output:
-- INDEX        23
-- SEQUENCE     11
-- TABLE        11
-- VIEW          5

-- List all tables
SELECT table_name FROM user_tables 
WHERE table_name LIKE 'ORACLE_OPT%' 
ORDER BY table_name;

-- Check required columns
SELECT column_name 
FROM user_tab_columns 
WHERE table_name = 'ORACLE_OPT_VOPTION'
  AND column_name IN ('IS_EE_EXTRA', 'IS_INUSE');

-- Expected: IS_EE_EXTRA, IS_INUSE

EXIT;
EOF
```

---

### Task 4: Create/Update Reporting Views

**When:** Initial setup, adding new reporting requirements

Views provide easy access to commonly queried data without complex JOINs.

#### Standard Reporting Views (Auto-created by _setup_audit_tables.yml)

**1. ORACLE_OPT_LATEST_VW** — Most recent run snapshot

```sql
-- Quick license risk overview
SELECT option_name, COUNT(DISTINCT hostname) AS hosts_at_risk
FROM DBAORALIC_SCH.ORACLE_OPT_LATEST_VW
WHERE is_inuse = 'Y' AND is_ee_extra = 'Y'
GROUP BY option_name
ORDER BY hosts_at_risk DESC;
```

**2. ORACLE_OPT_INUSE_VW** — Only options with detected usage (license exposure)

```sql
-- License risk by region
SELECT region, option_name, COUNT(*) AS instance_count
FROM DBAORALIC_SCH.ORACLE_OPT_INUSE_VW
GROUP BY region, option_name
ORDER BY region, option_name;
```

**3. ORACLE_OPT_TREND_VW** — Usage over time

```sql
-- Partitioning usage trend (last 90 days)
SELECT run_date, in_use_count
FROM DBAORALIC_SCH.ORACLE_OPT_TREND_VW
WHERE option_name = 'Partitioning'
  AND run_date >= SYSDATE - 90
ORDER BY run_date;
```

**4. ORACLE_OPT_ENABLED_VW** — All enabled options (v$option=TRUE)

```sql
-- Count enabled vs in-use
SELECT 
  is_ee_extra,
  COUNT(*) AS enabled_count,
  SUM(CASE WHEN is_inuse='Y' THEN 1 ELSE 0 END) AS inuse_count
FROM DBAORALIC_SCH.ORACLE_OPT_ENABLED_VW
GROUP BY is_ee_extra;
```

**5. ORACLE_OPT_HISTORY_VW** — Full point-in-time history (all runs)

```sql
-- Compare two specific runs
SELECT run_label, hostname, option_name, is_inuse
FROM DBAORALIC_SCH.ORACLE_OPT_HISTORY_VW
WHERE run_id IN (22, 25)  -- Replace with your RUN_IDs
  AND option_name = 'Partitioning'
ORDER BY hostname, run_id;
```

#### Manually Create Views (If Needed)

```bash
# If views are missing, recreate them
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
-- Create LATEST view
CREATE OR REPLACE VIEW ORACLE_OPT_LATEST_VW AS
SELECT 
  r.run_id, r.run_date, r.run_label,
  i.hostname, i.sid, i.db_name, i.oracle_version, i.region,
  v.option_name, v.option_enabled, v.is_ee_extra, v.is_inuse
FROM ORACLE_OPT_RUNS r
JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
LEFT JOIN ORACLE_OPT_VOPTION v ON v.inst_id = i.inst_id
WHERE r.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS);

-- Verify
SELECT view_name FROM user_views WHERE view_name LIKE 'ORACLE_OPT%';
EXIT;
EOF
```

---

### Task 5: Fix Missing Components

**When:** Validation shows missing objects, after failed setup, upgrading schema

#### Identify Missing Components

```bash
# Run validation to see what's missing
ansible-playbook playbooks/_validate_repo.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"
```

**Common Issues & Fixes:**

| Issue | Symptom | Fix Command |
|-------|---------|-------------|
| **Missing Tables** | "Expected 11, found X" | `ansible-playbook playbooks/_setup_audit_tables.yml` |
| **Missing Columns** | "IS_EE_EXTRA: NO" | See ALTER TABLE statements below |
| **Missing Indexes** | Slow queries | See recreate indexes below |
| **Missing Views** | "ORA-00942: view does not exist" | Re-run `_setup_audit_tables.yml` |
| **Missing Sequences** | "ORA-02289: sequence does not exist" | See recreate sequences below |

#### Fix Missing Columns

```bash
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
-- Add IS_EE_EXTRA column if missing
BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE ORACLE_OPT_VOPTION ADD (IS_EE_EXTRA VARCHAR2(1) DEFAULT ''N'' NOT NULL)';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -1430 THEN NULL;  -- Column already exists
    ELSE RAISE;
    END IF;
END;
/

-- Add IS_INUSE column if missing
BEGIN
  EXECUTE IMMEDIATE 'ALTER TABLE ORACLE_OPT_VOPTION ADD (IS_INUSE VARCHAR2(1) DEFAULT ''N'' NOT NULL)';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -1430 THEN NULL;
    ELSE RAISE;
    END IF;
END;
/

-- Verify
SELECT column_name, data_type 
FROM user_tab_columns
WHERE table_name = 'ORACLE_OPT_VOPTION'
  AND column_name IN ('IS_EE_EXTRA', 'IS_INUSE');

EXIT;
EOF
```

#### Recreate Missing Indexes

```bash
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
-- Performance indexes on ORACLE_OPT_VOPTION
CREATE INDEX ORACLE_OPT_VOPTION_IDX1 ON ORACLE_OPT_VOPTION(RUN_ID, IS_INUSE);
CREATE INDEX ORACLE_OPT_VOPTION_IDX2 ON ORACLE_OPT_VOPTION(OPTION_NAME, IS_EE_EXTRA);

-- Indexes on ORACLE_OPT_INSTANCES
CREATE INDEX ORACLE_OPT_INSTANCES_IDX1 ON ORACLE_OPT_INSTANCES(RUN_ID, HOSTNAME);
CREATE INDEX ORACLE_OPT_INSTANCES_IDX2 ON ORACLE_OPT_INSTANCES(HOSTNAME, SID);

-- Verify
SELECT index_name, table_name 
FROM user_indexes
WHERE table_name LIKE 'ORACLE_OPT%'
ORDER BY table_name;

EXIT;
EOF
```

#### Recreate Missing Sequences

```bash
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
-- Check current max values first
SELECT MAX(run_id) AS max_run_id FROM ORACLE_OPT_RUNS;
SELECT MAX(inst_id) AS max_inst_id FROM ORACLE_OPT_INSTANCES;

-- Recreate sequences (adjust START WITH based on MAX values + buffer)
CREATE SEQUENCE ORACLE_OPT_RUNS_SEQ START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE ORACLE_OPT_INSTANCES_SEQ START WITH 1000 INCREMENT BY 1;

-- Verify
SELECT sequence_name, last_number 
FROM user_sequences 
WHERE sequence_name LIKE 'ORACLE_OPT%';

EXIT;
EOF
```

#### Full Repository Rebuild (Last Resort)

```bash
# ⚠️ WARNING: This DROPS all data!

# Drop all objects
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
BEGIN
  FOR t IN (SELECT table_name FROM user_tables WHERE table_name LIKE 'ORACLE_OPT%') LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
  
  FOR v IN (SELECT view_name FROM user_views WHERE view_name LIKE 'ORACLE_OPT%') LOOP
    EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
  END LOOP;
  
  FOR s IN (SELECT sequence_name FROM user_sequences WHERE sequence_name LIKE 'ORACLE_OPT%') LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/
EXIT;
EOF

# Rebuild from scratch
ansible-playbook playbooks/_setup_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"
```

---

### Task 6: Complete Verification Checklist

**Run this after any repository build/fix operations:**

#### Automated Full Verification

```bash
# Single command for complete validation
ansible-playbook playbooks/_validate_repo.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"
```

**Expected Result:** `✓✓✓ REPOSITORY VALIDATION PASSED ✓✓✓`

#### Manual Step-by-Step Verification

```bash
# ✅ Step 1: Connection test
echo "Testing connection..."
tnsping d1hub && echo "✓ TNS resolves" || echo "✗ TNS failed"

sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<< "SELECT 'CONNECTED' FROM DUAL;" | grep -q CONNECTED && echo "✓ SQL*Plus works" || echo "✗ Connection failed"

# ✅ Step 2: Object counts
echo "Checking object counts..."
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT 'TABLES:' || COUNT(*) FROM user_tables WHERE table_name LIKE 'ORACLE_OPT%';
SELECT 'INDEXES:' || COUNT(*) FROM user_indexes WHERE table_name LIKE 'ORACLE_OPT%';
SELECT 'SEQUENCES:' || COUNT(*) FROM user_sequences WHERE sequence_name LIKE 'ORACLE_OPT%';
SELECT 'VIEWS:' || COUNT(*) FROM user_views WHERE view_name LIKE 'ORACLE_OPT%';
EOF

# Expected: TABLES:11, INDEXES:23, SEQUENCES:11, VIEWS:5

# ✅ Step 3: Required columns
echo "Checking required columns..."
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SELECT COUNT(*) FROM user_tab_columns 
WHERE table_name = 'ORACLE_OPT_VOPTION' 
  AND column_name IN ('IS_EE_EXTRA', 'IS_INUSE');
EOF

# Expected: 2

# ✅ Step 4: View query test
echo "Testing views..."
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SELECT COUNT(*) FROM ORACLE_OPT_LATEST_VW;
EXIT;
EOF

# Expected: 0 (if no data) or actual row count
```

#### Verification Checklist Table

| Check | Expected | Command | Status |
|-------|----------|---------|--------|
| TNS Ping | Success | `tnsping d1hub` | ⬜ |
| SQL*Plus Connect | Success | `sqlplus DBAORALIC_SCH/***@d1hub` | ⬜ |
| Tables | 11 | Query user_tables | ⬜ |
| Indexes | 23 | Query user_indexes | ⬜ |
| Sequences | 11 | Query user_sequences | ⬜ |
| Views | 5 | Query user_views | ⬜ |
| IS_EE_EXTRA Column | Exists | Query user_tab_columns | ⬜ |
| IS_INUSE Column | Exists | Query user_tab_columns | ⬜ |
| Validation Playbook | PASSED | `_validate_repo.yml` | ⬜ |

---

### Quick Command Reference

```bash
# 1️⃣ Test Connection
ansible-playbook playbooks/_validate_repo.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# 2️⃣ Build Repository
ansible-playbook playbooks/_setup_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# 3️⃣ Check Structure
ansible-playbook playbooks/_check_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# 4️⃣ Manual Validation
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub @check_repo_schema.sql

# 5️⃣ Quick Status Check
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<< "SELECT COUNT(*) AS runs FROM ORACLE_OPT_RUNS; SELECT COUNT(*) AS instances FROM ORACLE_OPT_INSTANCES;"
```

---

## Playbook Reference

### Overview of All Playbooks

| Playbook | Type | Purpose | When to Use |
|----------|------|---------|-------------|
| **`_validate_repo.yml`** | Repository | Test connection + validate schema structure | Before any repo operation, troubleshooting |
| **`_setup_audit_tables.yml`** | Repository | Create complete schema (11 tables, 23 indexes, 11 sequences, 5 views) | First-time setup, schema rebuild |
| **`_clean_repo_data.yml`** | Repository | Truncate all data, reset sequences (preserve schema) | Start fresh, remove old data |
| **`_check_audit_tables.yml`** | Repository | Verify table structure + show row counts | Schema verification, debugging |
| **`collect_oracle_options.yml`** | Data Collection | Scan hosts + insert to repository | Weekly audits, ad-hoc scans |
| **`report_audit_run.yml`** | Reporting | Query DB + generate HTML + email | Generate reports after collection |

### _validate_repo.yml

**Purpose:** Pre-flight validation - test connection and verify repository schema is ready

**Usage:**
```bash
# Default (d1hub)
ansible-playbook playbooks/_validate_repo.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# Custom repository
ansible-playbook playbooks/_validate_repo.yml -i "localhost," -c local \
  -e "repo_tns_alias=MYDB repo_user=AUDITUSER repo_password='MyPass' repo_schema=AUDITUSER"
```

**What It Checks:**
- ✓ Repository database connection
- ✓ All 11 tables exist
- ✓ Required columns (IS_EE_EXTRA, IS_INUSE)
- ✓ Indexes (23 expected)
- ✓ Sequences (11 expected)
- ✓ Views (5 expected)

**Output:** `✓✓✓ REPOSITORY VALIDATION PASSED ✓✓✓` or detailed error messages

---

### _setup_audit_tables.yml

**Purpose:** Full schema build - create all repository objects from scratch

**Usage:**
```bash
# Default (d1hub)
ansible-playbook playbooks/_setup_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# Custom repository
ansible-playbook playbooks/_setup_audit_tables.yml -i "localhost," -c local \
  -e "repo_tns_alias=MYDB repo_user=AUDITUSER repo_password='MyPass' repo_schema=AUDITUSER"
```

**What It Creates:**
- 11 tables (all ORACLE_OPT_*)
- 23 indexes (11 PRIMARY KEY + 12 performance)
- 11 sequences (auto-created by IDENTITY columns)
- 5 reporting views (LATEST_VW, ENABLED_VW, INUSE_VW, TREND_VW, HISTORY_VW)
- Truncates all tables (starts clean)

**When to Use:**
- First-time repository setup
- Complete schema rebuild after corruption
- Migrating to new database

**⚠️ Warning:** Truncates all existing data after creating schema

---

### _clean_repo_data.yml

**Purpose:** Clean all data without dropping schema - start fresh while preserving structure

**Usage:**
```bash
# With confirmation prompt
ansible-playbook playbooks/_clean_repo_data.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# Skip confirmation
ansible-playbook playbooks/_clean_repo_data.yml -i "localhost," -c local -e "repo_tns_alias=d1hub confirm_clean=yes"

# Custom repository
ansible-playbook playbooks/_clean_repo_data.yml -i "localhost," -c local \
  -e "repo_tns_alias=MYDB repo_user=AUDITUSER repo_password='MyPass' repo_schema=AUDITUSER confirm_clean=yes"
```

**What It Does:**
- ✓ Shows current row counts BEFORE clean
- ✓ Truncates all 11 tables
- ✓ Resets all 11 sequences to 1
- ✓ Preserves schema structure (tables, indexes, views remain)
- ✗ Does NOT drop or recreate any objects

**When to Use:**
- Remove test/dev data before production run
- Clear old data to start fresh collection cycle
- Fix data corruption issues without schema rebuild

**⚠️ Warning:** All data will be permanently deleted (tables, sequences reset)

---

### _check_audit_tables.yml

**Purpose:** Verify table structure and show current row counts

**Usage:**
```bash
ansible-playbook playbooks/_check_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"
```

**What It Shows:**
- Table existence (11 tables)
- Current row counts per table
- Last data collection date

**When to Use:**
- Quick health check
- Verify data was inserted
- Debugging data collection issues

---

### collect_oracle_options.yml

**Purpose:** Main data collection - scan target hosts and insert to repository

**Usage:**
```bash
# Full estate
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml \
  -e "repo_tns_alias=d1hub run_label=Weekly-$(date +%Y-%m-%d)"

# Single host
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 -e "repo_tns_alias=d1hub run_label=Test"

# Host group
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml \
  -l us_lnx_prod -e "repo_tns_alias=d1hub run_label=US-Prod"
```

**What It Collects:**
- v$option flags (all instances including standbys)
- dba_feature_usage_statistics
- Partitioned objects
- Compression evidence
- TDE encryption
- In-Memory objects
- PDB list (12c+)
- Active Data Guard status
- RAC topology

**When to Use:**
- Weekly full estate audits
- Ad-hoc license risk assessments
- Post-upgrade validation

---

### report_audit_run.yml

**Purpose:** Generate HTML report from repository data + send via email

**Usage:**
```bash
# Latest run with email
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# Latest run without email
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local \
  -e "repo_tns_alias=d1hub send_summary_email=false"

# Specific run ID
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local \
  -e "repo_tns_alias=d1hub report_run_id=25"

# List all available runs
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local \
  -e "repo_tns_alias=d1hub list_runs_only=true"
```

**What It Generates:**
- Colour-coded HTML report
- License risk summary (!! RISK, ~~ CHK, --)
- Evidence tables per option
- Instance inventory
- Historical trend charts

**When to Use:**
- After every data collection
- Generate historical reports from past runs
- Share with management/auditors

---

## Standard Operating Procedures

### SOP 1: Weekly Full Estate Audit

**Frequency:** Every Monday 8:00 AM  
**Duration:** 2-4 hours (depending on estate size)  
**Notification:** Email sent to Mohsen.Taheri@transamerica.com

#### Steps:

1. **Start Collection (Monday 8:00 AM)**

```bash
cd /path/to/ansible/Oracle-DBA-Automation-Projects-main

# Run full collection
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "run_label=Weekly-$(date +%Y-W%W)" \
  > logs/weekly_collection_$(date +%Y%m%d).log 2>&1 &

# Monitor progress
tail -f logs/weekly_collection_$(date +%Y%m%d).log
```

2. **Verify Completion**

```bash
# Check run completed
sqlplus -s mtaheri/PASSWORD@crlnxp1086:1535/dbai << EOF
SELECT run_id, run_date, run_label, total_hosts, total_instances
FROM MTAHERI.ORACLE_OPT_RUNS
ORDER BY run_date DESC
FETCH FIRST 1 ROW ONLY;
EXIT;
EOF
```

3. **Generate and Email Report**

```bash
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "email_skip_empty_sections=true"
```

4. **Verify Email Sent**

- Check inbox: Mohsen.Taheri@transamerica.com
- HTML report should show latest run statistics
- Review any "!! RISK" flagged options

5. **Archive Logs**

```bash
# Move logs to archive
mkdir -p logs/archive/$(date +%Y-%m)
mv logs/weekly_collection_*.log logs/archive/$(date +%Y-%m)/
```

---

### SOP 2: Monthly Production-Only Audit

**Frequency:** First business day of each month  
**Purpose:** Compliance reporting for production environments

```bash
# Collect production only
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l "us_lnx_prod,eu_nl_lnx_prod,eu_uk_lnx_prod" \
  -e "run_label=Production-Monthly-$(date +%Y-%m)"

# Generate report with specific run ID
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "email_skip_empty_sections=true"

# Save HTML to compliance archive
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "send_summary_email=false report_output_dir=/compliance/oracle_licensing/$(date +%Y-%m)"
```

---

### SOP 3: Ad-Hoc Host Group Audit

**When:** New servers added, targeted investigation, troubleshooting

```bash
# US Linux only
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l all_us_linux \
  -e "run_label=US-AdHoc-$(date +%Y-%m-%d)"

# EU Linux only
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l all_eu_linux \
  -e "run_label=EU-AdHoc-$(date +%Y-%m-%d)"

# US TLP AIX servers (14 servers with inline passwords)
ansible-playbook playbooks/collect_oracle_options.yml \
  -i inv_var.yml \
  -l "tlp_aix_prod,tlp_aix_prod2,tlp_aix_nonprod,tlp_aix_nonprod2" \
  -e "tlporacle_ssh_pass='<aix-group1-password>'" \
  -e "tlp2oracle_ssh_pass='<aix-group2-password>'" \
  -e "run_label=US-TLP-AIX-Full-$(date +%Y-%m-%d)"

# US TLP AIX servers - Background execution with nohup (recommended for long runs)
nohup ansible-playbook playbooks/collect_oracle_options.yml \
  -i inv_var.yml \
  -l "tlp_aix_prod,tlp_aix_prod2,tlp_aix_nonprod,tlp_aix_nonprod2" \
  -e "tlporacle_ssh_pass='<aix-group1-password>'" \
  -e "tlp2oracle_ssh_pass='<aix-group2-password>'" \
  -e "run_label=US-TLP-AIX-Full-$(date +%Y-%m-%d)" \
  > logs/aix_audit_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# Monitor progress (filtered view showing tasks and summary)
tail -f logs/aix_audit_*.log | grep -E "TASK|PLAY|ok=|changed=|failed="

# Check full log output
tail -f logs/aix_audit_*.log

# Check if job is still running
jobs -l
ps -ef | grep ansible-playbook

# Generate report after completion
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local
```

---

### SOP 4: Single Instance Investigation

**When:** License question for specific database

```bash
# Collect from single host
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "run_label=Investigation-crlnxp1015-$(date +%Y-%m-%d)"

# Specific SID on multi-instance host
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxm2139 \
  -e "db_sid=invdev run_label=Investigation-invdev"

# Generate report
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "send_summary_email=false report_output_dir=/tmp"
```

---

## Common Scenarios

### Scenario 1: Fast Audit (v$option Only, No Detail Queries)

**Use Case:** Quick check, no need for evidence tables

```bash
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "run_label=Quick-Check-$(date +%Y-%m-%d) \
      collect_partitioning=false \
      collect_compression=false \
      collect_security=false \
      collect_inmemory=false \
      collect_pdbs=false \
      collect_adg=false \
      collect_rac=false"

ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local
```

---

### Scenario 2: Partitioning Evidence Only

**Use Case:** Known partitioning servers, deep dive

```bash
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l "crlnxp1015,crlnxp1088,crlnxm145,crlnxm157,crlnxm2139" \
  -e "run_label=Partitioning-Evidence-$(date +%Y-%m-%d) \
      collect_compression=false \
      collect_security=false \
      collect_inmemory=false \
      collect_pdbs=false \
      collect_adg=false \
      collect_rac=false"

ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local
```

---

### Scenario 3: TDE/Security Evidence Only

**Use Case:** Security audit, encryption review

```bash
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "run_label=Security-Audit-$(date +%Y-%m-%d) \
      collect_partitioning=false \
      collect_compression=false \
      collect_inmemory=false \
      collect_pdbs=false \
      collect_adg=false \
      collect_rac=false"

ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local
```

---

### Scenario 4: Re-Report from Previous Run

**Use Case:** Generate report for historical data

```bash
# List all available runs with platform coverage
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "list_runs_only=true"

# Alternative: SQL query to see platform breakdown per run
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SELECT 
  r.run_id,
  r.run_label,
  TO_CHAR(r.run_date, 'YYYY-MM-DD') AS run_date,
  LISTAGG(DISTINCT i.os_type, ', ') WITHIN GROUP (ORDER BY i.os_type) AS platforms,
  COUNT(DISTINCT i.hostname) AS hosts
FROM ORACLE_OPT_RUNS r
JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
WHERE r.run_date >= SYSDATE - 30
GROUP BY r.run_id, r.run_label, r.run_date
ORDER BY r.run_date DESC;
EXIT;
EOF

# Generate report for specific run ID
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "report_run_id=22 send_summary_email=false report_output_dir=/tmp"
```

---

### Scenario 5: Custom Email Recipients

```bash
# Collect data
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "run_label=Custom-$(date +%Y-%m-%d)"

# Send to multiple recipients
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "email_to=person1@transamerica.com,person2@transamerica.com,person3@transamerica.com"
```

---

### Scenario 6: Override Repository Credentials

**Use Case:** Testing with different repo or after password change

```bash
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "run_label=Test-NewRepo \
      repo_host=newhost \
      repo_port=1521 \
      repo_sid=newdb \
      repo_user=newuser \
      repo_password=newpass"
```

---

### Scenario 5: Cross-Platform Comprehensive Report (AIX + Linux US + EU)

**Use Case:** Generate a single comprehensive report covering all platforms and regions

**Problem:** When you run separate collections (AIX, US Linux, EU Linux), they create different RUN_IDs. The report tool only shows the latest single RUN_ID, not a combined view.

**Solution Options:**

#### Option 1: Collect All Platforms in One Run (Recommended)

```bash
# Single collection covering AIX, US Linux, and EU Linux
ansible-playbook playbooks/collect_oracle_options.yml \
  -i inv_var.yml \
  -l "tlp_aix_prod,tlp_aix_prod2,tlp_aix_nonprod,tlp_aix_nonprod2,us_lnx_prod,us_lnx_nonprod,eu_nl_lnx_prod,eu_uk_lnx_prod" \
  -e "tlporacle_ssh_pass='<aix-group1-password>'" \
  -e "tlp2oracle_ssh_pass='<aix-group2-password>'" \
  -e "run_label=Global-Full-Estate-$(date +%Y-%m-%d)"

# Single report for all platforms
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local
```

#### Option 2: Find and Report from Multiple RUN_IDs

**Step 1: Identify latest RUN_ID for each platform**

```bash
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 200 PAGESIZE 50
COL run_label FORMAT A40
COL platform FORMAT A15

-- Find latest run for each platform type
WITH latest_runs AS (
  SELECT 
    r.run_id,
    r.run_date,
    r.run_label,
    CASE 
      WHEN r.run_label LIKE '%AIX%' THEN 'AIX'
      WHEN r.run_label LIKE '%US%' OR r.run_label LIKE '%us%' THEN 'US-Linux'
      WHEN r.run_label LIKE '%EU%' OR r.run_label LIKE '%eu%' THEN 'EU-Linux'
      ELSE 'Other'
    END AS platform,
    ROW_NUMBER() OVER (
      PARTITION BY CASE 
        WHEN r.run_label LIKE '%AIX%' THEN 'AIX'
        WHEN r.run_label LIKE '%US%' THEN 'US-Linux'
        WHEN r.run_label LIKE '%EU%' THEN 'EU-Linux'
        ELSE 'Other'
      END 
      ORDER BY r.run_date DESC
    ) AS rn
  FROM ORACLE_OPT_RUNS r
  WHERE r.run_date >= SYSDATE - 30  -- Last 30 days
)
SELECT run_id, TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI') AS run_date, 
       run_label, platform
FROM latest_runs
WHERE rn = 1
ORDER BY platform;

EXIT;
EOF
```

**Step 2: Verify platform coverage by RUN_ID**

```bash
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 200
COL run_label FORMAT A30
COL os_type FORMAT A10

-- Check what each recent run contains
SELECT 
  r.run_id,
  r.run_label,
  i.os_type,
  COUNT(DISTINCT i.hostname) AS hosts,
  COUNT(DISTINCT i.inst_id) AS instances
FROM ORACLE_OPT_RUNS r
JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
WHERE r.run_date >= SYSDATE - 7  -- Last 7 days
GROUP BY r.run_id, r.run_label, i.os_type
ORDER BY r.run_id DESC, i.os_type;

EXIT;
EOF
```

#### Option 3: Create Combined View Query

**Query all platforms from their respective latest runs:**

```sql
-- Combined view: Latest data from AIX, US Linux, and EU Linux runs
WITH platform_runs AS (
  -- Get latest AIX run
  SELECT MAX(r.run_id) AS run_id, 'AIX' AS platform
  FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
  JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
  WHERE UPPER(i.os_type) = 'AIX'
    AND r.run_date >= SYSDATE - 30
  
  UNION ALL
  
  -- Get latest US Linux run
  SELECT MAX(r.run_id) AS run_id, 'US-Linux' AS platform
  FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
  JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
  WHERE UPPER(i.region) LIKE '%US%'
    AND UPPER(i.os_type) LIKE '%LINUX%'
    AND r.run_date >= SYSDATE - 30
  
  UNION ALL
  
  -- Get latest EU Linux run
  SELECT MAX(r.run_id) AS run_id, 'EU-Linux' AS platform
  FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
  JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
  WHERE UPPER(i.region) LIKE '%EU%'
    AND UPPER(i.os_type) LIKE '%LINUX%'
    AND r.run_date >= SYSDATE - 30
)
SELECT 
  pr.platform,
  pr.run_id,
  r.run_label,
  r.run_date,
  COUNT(DISTINCT i.hostname) AS hosts,
  COUNT(DISTINCT i.inst_id) AS instances
FROM platform_runs pr
JOIN DBAORALIC_SCH.ORACLE_OPT_RUNS r ON r.run_id = pr.run_id
JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
GROUP BY pr.platform, pr.run_id, r.run_label, r.run_date
ORDER BY pr.platform;
```

**Unified license risk across all platforms:**

```sql
-- License risk summary across latest AIX, US Linux, and EU Linux runs
WITH latest_platform_data AS (
  SELECT i.*, v.option_name, v.is_ee_extra, v.is_inuse, v.option_enabled
  FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
  JOIN DBAORALIC_SCH.ORACLE_OPT_VOPTION v ON v.inst_id = i.inst_id
  WHERE i.run_id IN (
    -- Latest AIX run
    SELECT MAX(r.run_id)
    FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
    JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i2 ON i2.run_id = r.run_id
    WHERE UPPER(i2.os_type) = 'AIX'
      AND r.run_date >= SYSDATE - 30
    
    UNION
    
    -- Latest US Linux run
    SELECT MAX(r.run_id)
    FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
    JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i2 ON i2.run_id = r.run_id
    WHERE UPPER(i2.region) LIKE '%US%'
      AND UPPER(i2.os_type) LIKE '%LINUX%'
      AND r.run_date >= SYSDATE - 30
    
    UNION
    
    -- Latest EU Linux run
    SELECT MAX(r.run_id)
    FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
    JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i2 ON i2.run_id = r.run_id
    WHERE UPPER(i2.region) LIKE '%EU%'
      AND UPPER(i2.os_type) LIKE '%LINUX%'
      AND r.run_date >= SYSDATE - 30
  )
)
SELECT 
  option_name,
  os_type,
  region,
  COUNT(DISTINCT hostname) AS affected_hosts,
  COUNT(DISTINCT inst_id) AS affected_instances,
  SUM(CASE WHEN is_inuse = 'Y' THEN 1 ELSE 0 END) AS in_use_count
FROM latest_platform_data
WHERE is_ee_extra = 'Y'
  AND option_enabled = 'TRUE'
GROUP BY option_name, os_type, region
HAVING SUM(CASE WHEN is_inuse = 'Y' THEN 1 ELSE 0 END) > 0
ORDER BY option_name, os_type, region;
```

#### Option 4: Export Combined CSV Report

```bash
# Export comprehensive estate report to CSV
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET COLSEP ','
SET PAGESIZE 0
SET TRIMSPOOL ON
SET HEADSEP OFF
SET LINESIZE 300
SET FEEDBACK OFF

SPOOL /tmp/oracle_estate_combined_report.csv

-- Header
SELECT 'Platform,OS_Type,Region,Hostname,SID,DB_Name,Oracle_Version,DB_Role,Option_Name,Is_EE_Extra,Enabled,In_Use'
FROM DUAL;

-- Data from latest runs per platform
SELECT 
  CASE 
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.region) LIKE '%US%' THEN 'US-Linux'
    WHEN UPPER(i.region) LIKE '%EU%' THEN 'EU-Linux'
    ELSE 'Other'
  END AS platform,
  i.os_type,
  i.region,
  i.hostname,
  i.sid,
  i.db_name,
  i.oracle_version,
  i.db_role,
  v.option_name,
  v.is_ee_extra,
  v.option_enabled,
  v.is_inuse
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_VOPTION v ON v.inst_id = i.inst_id
WHERE i.run_id IN (
  SELECT MAX(run_id) FROM ORACLE_OPT_RUNS WHERE run_date >= SYSDATE - 30
)
  AND v.is_ee_extra = 'Y'
ORDER BY platform, i.hostname, i.sid, v.option_name;

SPOOL OFF
EXIT;
EOF

echo "Report saved to: /tmp/oracle_estate_combined_report.csv"
```

---

### Scenario 6: Scheduled Weekly Combined Collection

**Use Case:** Automate weekly collection across all platforms in one job (when maintenance windows align)

```bash
# Create weekly collection script
cat > ~/weekly_oracle_audit.sh << 'SCRIPT'
#!/bin/bash
# Weekly Oracle License Audit - All Platforms
# Schedule: Every Monday 6:00 AM

TIMESTAMP=$(date +%Y-%m-%d)
LOG_DIR="/home/oracle/logs/weekly_audit"
mkdir -p ${LOG_DIR}

echo "========================================" | tee -a ${LOG_DIR}/audit_${TIMESTAMP}.log
echo "Starting Weekly Oracle Audit - ${TIMESTAMP}" | tee -a ${LOG_DIR}/audit_${TIMESTAMP}.log
echo "========================================" | tee -a ${LOG_DIR}/audit_${TIMESTAMP}.log

# Collect from all platforms
nohup ansible-playbook playbooks/collect_oracle_options.yml \
  -i inv_var.yml \
  -l "tlp_aix_prod,tlp_aix_prod2,tlp_aix_nonprod,tlp_aix_nonprod2,us_lnx_prod,us_lnx_nonprod,eu_nl_lnx_prod,eu_uk_lnx_prod" \
  -e "tlporacle_ssh_pass='<aix-group1-password>'" \
  -e "tlp2oracle_ssh_pass='<aix-group2-password>'" \
  -e "run_label=Weekly-Global-${TIMESTAMP}" \
  >> ${LOG_DIR}/audit_${TIMESTAMP}.log 2>&1

# Generate and email report
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "send_summary_email=true" \
  >> ${LOG_DIR}/audit_${TIMESTAMP}.log 2>&1

echo "Audit completed: $(date)" | tee -a ${LOG_DIR}/audit_${TIMESTAMP}.log
SCRIPT

chmod +x ~/weekly_oracle_audit.sh

# Add to crontab (every Monday at 6 AM)
(crontab -l 2>/dev/null; echo "0 6 * * 1 /home/oracle/weekly_oracle_audit.sh") | crontab -
```

---

### Scenario 7: Unified Reporting from Separate Platform Collections

**Use Case:** AIX, US Linux, and EU Linux collected on different schedules - generate one unified report

**Prerequisites:** Create the `ORACLE_OPT_UNIFIED_LATEST_VW` view (see Issue 6 Resolution Option 3)

**Daily Unified Report Script:**

```bash
# Create automated unified report script
cat > ~/generate_unified_report.sh << 'SCRIPT'
#!/bin/bash
# Generate unified platform report
# Combines latest AIX, US Linux, and EU Linux runs

REPORT_DATE=$(date +%Y%m%d)
REPORT_DIR="/reports/oracle_licensing"
mkdir -p ${REPORT_DIR}

echo "Generating unified Oracle license audit report..."

# Generate comprehensive CSV report
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF' > ${REPORT_DIR}/unified_${REPORT_DATE}.csv
SET COLSEP ','
SET PAGESIZE 0
SET TRIMSPOOL ON
SET LINESIZE 400
SET FEEDBACK OFF
SET HEADING ON

SELECT 
  platform_type AS "Platform",
  run_id AS "Run_ID",
  TO_CHAR(run_date, 'YYYY-MM-DD') AS "Run_Date",
  hostname AS "Hostname",
  sid AS "SID",
  db_name AS "DB_Name",
  oracle_version AS "Version",
  option_name AS "Option",
  option_enabled AS "Enabled",
  is_inuse AS "In_Use"
FROM ORACLE_OPT_UNIFIED_LATEST_VW
WHERE is_ee_extra = 'Y'
  AND option_enabled = 'TRUE'
ORDER BY platform_type, hostname, option_name;
EXIT;
EOF

# Generate summary report
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF' > ${REPORT_DIR}/summary_${REPORT_DATE}.txt
SET LINESIZE 150 PAGESIZE 100
COL platform_type FORMAT A12
COL option_name FORMAT A35

PROMPT ========================================
PROMPT Oracle License Audit - Unified Summary
PROMPT Generated: $(date +"%Y-%m-%d %H:%M")
PROMPT ========================================
PROMPT

PROMPT Platform Coverage:
SELECT 
  platform_type,
  run_id,
  TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
  COUNT(DISTINCT hostname) AS hosts,
  COUNT(DISTINCT sid) AS instances
FROM ORACLE_OPT_UNIFIED_LATEST_VW
GROUP BY platform_type, run_id, run_date
ORDER BY platform_type;

PROMPT
PROMPT High-Risk Options (In Use):
SELECT 
  option_name,
  COUNT(DISTINCT platform_type) AS platforms,
  COUNT(DISTINCT hostname) AS hosts,
  SUM(CASE WHEN is_inuse = 'Y' THEN 1 ELSE 0 END) AS in_use_instances
FROM ORACLE_OPT_UNIFIED_LATEST_VW
WHERE is_ee_extra = 'Y'
  AND option_enabled = 'TRUE'
GROUP BY option_name
HAVING SUM(CASE WHEN is_inuse = 'Y' THEN 1 ELSE 0 END) > 0
ORDER BY in_use_instances DESC;

EXIT;
EOF

# Email report
echo "Oracle License Audit - Unified Report for $(date +%Y-%m-%d)" | \
  mail -s "Oracle License Audit - Unified Platform Report" \
       -a ${REPORT_DIR}/unified_${REPORT_DATE}.csv \
       -a ${REPORT_DIR}/summary_${REPORT_DATE}.txt \
       mohsen.taheri@transamerica.com

echo "Report generation complete. Files:"
ls -lh ${REPORT_DIR}/*${REPORT_DATE}*
SCRIPT

chmod +x ~/generate_unified_report.sh

# Schedule it
(crontab -l 2>/dev/null; echo "0 9 * * * /home/oracle/generate_unified_report.sh") | crontab -
```

---

## Troubleshooting

### Issue 1: Host Not Responding

**Symptom:** "Host unreachable" or "Connection refused"

**Resolution:**
```bash
# Test connectivity
ansible crlnxp1015 -i ansibleInventory/inv_key.yml -m ping

# Test SSH manually
ssh svcorap@crlnxp1015

# Check inventory file
grep crlnxp1015 ansibleInventory/inv_key.yml
```

---

### Issue 2: Oracle User Not Detected

**Symptom:** "No Oracle ora_pmon processes found"

**Resolution:**
```bash
# Check manually
ssh svcorap@crlnxp1015 "ps -eo user,args | grep pmon"

# Override oracle_user
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "oracle_user=oracle run_label=Test"
```

---

### Issue 3: Database Connection Fails

**Symptom:** "ORA-12514" or "ORA-01017"

**Resolution:**
```bash
# Test manually
sqlplus / as sysdba

# Check ORACLE_HOME
cat /etc/oratab

# Check listener
lsnrctl status

# Run with verbose logging
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "run_label=Debug" \
  -vvv
```

---

### Issue 4: Central Repository Insert Fails

**Symptom:** "Unable to connect to repository" or "ORA-00942: table or view does not exist"

**Resolution:**
```bash
# Test repo connection
sqlplus mtaheri/PASSWORD@crlnxp1086:1535/dbai

# Verify tables exist
SELECT table_name FROM user_tables WHERE table_name LIKE 'ORACLE_OPT%';

# Re-create tables if needed
ansible-playbook playbooks/_setup_audit_tables.yml -i "localhost," -c local
```

---

### Issue 5: Email Not Received

**Symptom:** Report generated but no email

**Resolution:**
```bash
# Check SMTP connectivity
telnet mail1.us.aegon.com 25

# Test with verbose
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -vvv

# Check email settings
grep -A5 "smtp" roles/oracle_options_audit/defaults/main.yml

# Override email settings
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "smtp_host=mail1.us.aegon.com smtp_port=25"
```

---

### Issue 6: Report Only Shows One Platform (Missing AIX or Linux Data)

**Symptom:** You ran separate collections for AIX, US Linux, and EU Linux, but the report only shows data from one platform (usually the most recent collection).

**Root Cause:** The report playbook uses `SELECT MAX(RUN_ID)` to find the latest run. When you run separate collections, each creates a different RUN_ID:
- AIX audit → RUN_ID 64
- US Linux audit → RUN_ID 65  
- EU Linux audit → RUN_ID 66

The report only uses RUN_ID 66 (the maximum), which contains only EU Linux data. AIX and US Linux data from earlier RUN_IDs are ignored.

**Resolution Option 1: Collect All Platforms in One Run (Recommended)**

```bash
# Single collection covering ALL platforms - creates one RUN_ID with complete data
nohup ansible-playbook playbooks/collect_oracle_options.yml \
  -i inv_var.yml \
  -l "tlp_aix_prod,tlp_aix_prod2,tlp_aix_nonprod,tlp_aix_nonprod2,us_lnx_prod,us_lnx_nonprod,eu_nl_lnx_prod,eu_uk_lnx_prod" \
  -e "tlporacle_ssh_pass='<aix-group1-password>'" \
  -e "tlp2oracle_ssh_pass='<aix-group2-password>'" \
  -e "run_label=Global-Full-Estate-$(date +%Y-%m-%d)" \
  > logs/global_audit_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# Monitor progress
tail -f logs/global_audit_*.log | grep -E "TASK|PLAY|ok=|changed=|failed="

# Now the report will include ALL platforms
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local
```

**Resolution Option 2: Generate Separate Reports for Each Platform**

If you already ran separate collections, generate individual reports by specifying the RUN_ID:

```bash
# Step 1: Find the RUN_IDs for each platform
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 150
COL run_label FORMAT A35

SELECT r.run_id, r.run_label, 
       TO_CHAR(r.run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
       LISTAGG(DISTINCT 
         CASE 
           WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
           WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN i.region || '-Linux'
           ELSE i.os_type
         END, ', '
       ) WITHIN GROUP (ORDER BY i.os_type) AS platforms
FROM ORACLE_OPT_RUNS r
JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
WHERE r.run_date >= SYSDATE - 7
GROUP BY r.run_id, r.run_label, r.run_date
ORDER BY r.run_date DESC;
EXIT;
EOF

# Step 2: Generate report for AIX (example RUN_ID=64)
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "report_run_id=64 send_summary_email=false report_output_dir=/tmp"

# Step 3: Generate report for US Linux (example RUN_ID=65)
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "report_run_id=65 send_summary_email=false report_output_dir=/tmp"

# Step 4: Generate report for EU Linux (example RUN_ID=66)
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "report_run_id=66 send_summary_email=false report_output_dir=/tmp"
```

**Resolution Option 3: Create Unified Multi-Platform View (Recommended for Separate Schedules)**

When AIX, US Linux, and EU Linux are collected on different schedules, create a database view that automatically picks the latest RUN_ID for each platform:

```bash
# Step 1: Create the unified view in repository
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
-- Drop existing view if present
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW ORACLE_OPT_UNIFIED_LATEST_VW';
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
/

-- Create unified view combining latest run per platform
CREATE OR REPLACE VIEW ORACLE_OPT_UNIFIED_LATEST_VW AS
WITH latest_runs_by_platform AS (
  -- Get latest AIX run
  SELECT 'AIX' AS platform_type, MAX(r.run_id) AS run_id
  FROM ORACLE_OPT_RUNS r
  JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
  WHERE UPPER(i.os_type) = 'AIX'
    AND r.run_date >= SYSDATE - 30  -- Last 30 days
  
  UNION ALL
  
  -- Get latest US Linux run
  SELECT 'US-Linux' AS platform_type, MAX(r.run_id) AS run_id
  FROM ORACLE_OPT_RUNS r
  JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
  WHERE UPPER(i.os_type) LIKE '%LINUX%'
    AND UPPER(i.region) LIKE '%US%'
    AND r.run_date >= SYSDATE - 30
  
  UNION ALL
  
  -- Get latest EU Linux run
  SELECT 'EU-Linux' AS platform_type, MAX(r.run_id) AS run_id
  FROM ORACLE_OPT_RUNS r
  JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
  WHERE UPPER(i.os_type) LIKE '%LINUX%'
    AND UPPER(i.region) LIKE '%EU%'
    AND r.run_date >= SYSDATE - 30
)
SELECT 
  lr.platform_type,
  r.run_id,
  r.run_label,
  r.run_date,
  i.hostname,
  i.sid,
  i.db_name,
  i.oracle_version,
  i.db_role,
  i.region,
  i.os_type,
  v.option_name,
  v.option_enabled,
  v.is_ee_extra,
  v.is_inuse
FROM latest_runs_by_platform lr
JOIN ORACLE_OPT_RUNS r ON r.run_id = lr.run_id
JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
LEFT JOIN ORACLE_OPT_VOPTION v ON v.inst_id = i.inst_id;

-- Verify view creation
SELECT view_name FROM user_views WHERE view_name = 'ORACLE_OPT_UNIFIED_LATEST_VW';

EXIT;
EOF
```

**Step 2: Query the unified view for comprehensive reporting:**

```bash
# Generate unified report from all platforms
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 200 PAGESIZE 100
COL platform_type FORMAT A12
COL run_label FORMAT A30
COL option_name FORMAT A35

PROMPT ========================================
PROMPT Unified Platform Report - Latest Runs
PROMPT ========================================

-- Summary by platform
SELECT 
  platform_type,
  run_id,
  TO_CHAR(MAX(run_date), 'YYYY-MM-DD HH24:MI') AS run_date,
  MAX(run_label) AS run_label,
  COUNT(DISTINCT hostname) AS hosts,
  COUNT(DISTINCT sid) AS instances
FROM ORACLE_OPT_UNIFIED_LATEST_VW
GROUP BY platform_type, run_id
ORDER BY platform_type;

PROMPT
PROMPT ========================================
PROMPT License Risk - High-Value Options
PROMPT ========================================

-- Options in use across all platforms
SELECT 
  option_name,
  COUNT(DISTINCT platform_type) AS platforms,
  COUNT(DISTINCT hostname) AS affected_hosts,
  SUM(CASE WHEN is_inuse = 'Y' THEN 1 ELSE 0 END) AS in_use_count
FROM ORACLE_OPT_UNIFIED_LATEST_VW
WHERE is_ee_extra = 'Y'
  AND option_enabled = 'TRUE'
GROUP BY option_name
HAVING SUM(CASE WHEN is_inuse = 'Y' THEN 1 ELSE 0 END) > 0
ORDER BY in_use_count DESC, option_name;

PROMPT
PROMPT ========================================
PROMPT Platform Breakdown by Option
PROMPT ========================================

SELECT 
  platform_type,
  option_name,
  COUNT(DISTINCT hostname) AS hosts,
  SUM(CASE WHEN is_inuse = 'Y' THEN 1 ELSE 0 END) AS in_use
FROM ORACLE_OPT_UNIFIED_LATEST_VW
WHERE is_ee_extra = 'Y'
  AND option_enabled = 'TRUE'
GROUP BY platform_type, option_name
HAVING SUM(CASE WHEN is_inuse = 'Y' THEN 1 ELSE 0 END) > 0
ORDER BY platform_type, option_name;

EXIT;
EOF
```

**Step 3: Export unified CSV report:**

```bash
# Export comprehensive unified report to CSV
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET COLSEP ','
SET PAGESIZE 0
SET TRIMSPOOL ON
SET LINESIZE 400
SET FEEDBACK OFF
SET HEADING OFF

SPOOL /tmp/oracle_unified_platform_report_$(date +%Y%m%d).csv

-- Header
SELECT 'Platform,RUN_ID,Run_Label,Run_Date,Hostname,SID,DB_Name,Oracle_Version,DB_Role,Region,OS_Type,Option_Name,Enabled,EE_Extra,In_Use'
FROM DUAL;

-- Data from all platforms (latest run per platform)
SELECT 
  platform_type || ',' ||
  run_id || ',' ||
  '"' || run_label || '",' ||
  TO_CHAR(run_date, 'YYYY-MM-DD') || ',' ||
  hostname || ',' ||
  sid || ',' ||
  db_name || ',' ||
  oracle_version || ',' ||
  db_role || ',' ||
  region || ',' ||
  os_type || ',' ||
  '"' || option_name || '",' ||
  option_enabled || ',' ||
  is_ee_extra || ',' ||
  is_inuse
FROM ORACLE_OPT_UNIFIED_LATEST_VW
WHERE is_ee_extra = 'Y'
ORDER BY platform_type, hostname, sid, option_name;

SPOOL OFF
EXIT;
EOF

echo "Unified report saved to: /tmp/oracle_unified_platform_report_$(date +%Y%m%d).csv"
```

**Best Practice - Separate Scheduled Collections with Unified Reporting:**

When each platform has different maintenance windows, schedule them separately but generate unified reports:

```bash
# Step 1: Create separate collection scripts

# AIX Collection - Every Saturday 2 AM
cat > ~/aix_audit.sh << 'SCRIPT'
#!/bin/bash
nohup ansible-playbook /path/to/playbooks/collect_oracle_options.yml \
  -i /path/to/inv_var.yml \
  -l "tlp_aix_prod,tlp_aix_prod2,tlp_aix_nonprod,tlp_aix_nonprod2" \
  -e "tlporacle_ssh_pass='<aix-group1-password>'" \
  -e "tlp2oracle_ssh_pass='<aix-group2-password>'" \
  -e "run_label=AIX-Weekly-$(date +%Y-W%W)" \
  >> /logs/aix_audit_$(date +%Y%m%d).log 2>&1 &
SCRIPT

# US Linux Collection - Every Monday 6 AM
cat > ~/us_linux_audit.sh << 'SCRIPT'
#!/bin/bash
ansible-playbook /path/to/playbooks/collect_oracle_options.yml \
  -i /path/to/inv_var.yml \
  -l "us_lnx_prod,us_lnx_nonprod" \
  -e "run_label=US-Linux-Weekly-$(date +%Y-W%W)" \
  >> /logs/us_linux_audit_$(date +%Y%m%d).log 2>&1
SCRIPT

# EU Linux Collection - Every Tuesday 6 AM
cat > ~/eu_linux_audit.sh << 'SCRIPT'
#!/bin/bash
ansible-playbook /path/to/playbooks/collect_oracle_options.yml \
  -i /path/to/inv_var.yml \
  -l "eu_nl_lnx_prod,eu_uk_lnx_prod" \
  -e "run_label=EU-Linux-Weekly-$(date +%Y-W%W)" \
  >> /logs/eu_linux_audit_$(date +%Y%m%d).log 2>&1
SCRIPT

# Unified Report Generation - Every Wednesday 8 AM (after all collections)
cat > ~/unified_audit_report.sh << 'SCRIPT'
#!/bin/bash
# Generate unified report from latest run per platform
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET COLSEP ','
SET PAGESIZE 0
SET TRIMSPOOL ON
SET LINESIZE 400
SET FEEDBACK OFF
SET HEADING OFF

SPOOL /reports/oracle_unified_$(date +%Y%m%d).csv

SELECT 'Platform,RUN_ID,Run_Date,Hostname,SID,Option_Name,Enabled,In_Use' FROM DUAL;

SELECT 
  platform_type || ',' ||
  run_id || ',' ||
  TO_CHAR(run_date, 'YYYY-MM-DD') || ',' ||
  hostname || ',' ||
  sid || ',' ||
  '"' || option_name || '",' ||
  option_enabled || ',' ||
  is_inuse
FROM ORACLE_OPT_UNIFIED_LATEST_VW
WHERE is_ee_extra = 'Y'
  AND option_enabled = 'TRUE'
ORDER BY platform_type, hostname, option_name;

SPOOL OFF
EXIT;
EOF

# Email the unified report
echo "Unified Oracle License Audit Report - Week $(date +%Y-W%W)" | \
  mail -s "Oracle License Audit - Unified Report" \
       -a /reports/oracle_unified_$(date +%Y%m%d).csv \
       mohsen.taheri@transamerica.com
SCRIPT

chmod +x ~/*.sh

# Step 2: Add to crontab
(crontab -l 2>/dev/null; cat <<CRON
# AIX audit - Every Saturday 2:00 AM
0 2 * * 6 /home/oracle/aix_audit.sh

# US Linux audit - Every Monday 6:00 AM
0 6 * * 1 /home/oracle/us_linux_audit.sh

# EU Linux audit - Every Tuesday 6:00 AM
0 6 * * 2 /home/oracle/eu_linux_audit.sh

# Unified report - Every Wednesday 8:00 AM
0 8 * * 3 /home/oracle/unified_audit_report.sh
CRON
) | crontab -

echo "Scheduled jobs installed:"
crontab -l | grep audit
```

**Verify unified view is working:**

```bash
# Quick test - see which RUN_IDs are being used
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 150
COL run_label FORMAT A30

SELECT 
  platform_type,
  run_id,
  TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
  run_label,
  COUNT(DISTINCT hostname) AS hosts
FROM ORACLE_OPT_UNIFIED_LATEST_VW
GROUP BY platform_type, run_id, run_date, run_label
ORDER BY platform_type;

-- Should show 3 rows: AIX (RUN_ID 64), US-Linux (RUN_ID 65), EU-Linux (RUN_ID 66)
EXIT;
EOF
```

---

### Scenario 8: Multi-Platform Report Generation (Enhanced)

**Use Case:** Generate comprehensive reports automatically combining latest AIX, US Linux, and EU Linux collections

**New Features (Enhanced Report Module):**
- ✅ **Automatic Platform Detection**: Smart RUN_ID selection per platform
- 📊 **Platform Breakdown**: Separate collection dates and instance counts per platform
- 🎨 **Color-Coded Badges**: Visual platform indicators (AIX=Blue, US=Green, EU=Red)
- 📧 **Dual Attachments**: Both HTML (interactive) and text files attached to every email

**Generate Multi-Platform Report:**

```bash
# NEW: Auto-detect and combine latest run from each platform
ansible-playbook playbooks/report_audit_run.yml \
  -i inv_var.yml \
  -e "multi_platform_report=true"

# Output:
# - Platform breakdown table showing:
#   [AIX      ] RUN_ID=64 | 2026-05-10 02:30 | Hosts: 14  | Instances: 47
#   [US-Linux ] RUN_ID=65 | 2026-05-11 06:15 | Hosts: 38  | Instances: 142
#   [EU-Linux ] RUN_ID=66 | 2026-05-12 07:45 | Hosts: 22  | Instances: 68
#
# - Both files generated:
#   oracle_audit_run64,65,66_2026-05-12.html (interactive, collapsible)
#   oracle_audit_run64,65,66_2026-05-12.txt (plain text)
#
# - Email sent with both files attached
```

**Report Features:**

| Feature | Description | Benefit |
|---------|-------------|---------|
| **Platform Breakdown** | Shows each platform's RUN_ID, collection date, hosts, instances | Clear visibility into when each region was last audited |
| **Platform Badges** | Color-coded tags (AIX/US-Linux/EU-Linux) on every instance | Instant platform identification in option details |
| **Dual Format** | HTML (interactive) + Text (plain) | HTML for deep analysis, text for quick review |
| **Smart Email** | Both files automatically attached | No manual file distribution needed |

**Sample Report Output:**

```text
PLATFORM BREAKDOWN
----------------------------------------------------------------------
[AIX       ] RUN_ID=64    | 2026-05-10 02:30     | Hosts: 14  | Instances: 47
[US-Linux  ] RUN_ID=65    | 2026-05-11 06:15     | Hosts: 38  | Instances: 142
[EU-Linux  ] RUN_ID=66    | 2026-05-12 07:45     | Hosts: 22  | Instances: 68
----------------------------------------------------------------------

EE EXTRA-COST OPTIONS -- LICENSE RISK SUMMARY
+------------------------------------------+----------+----------+---------+
| OPTION NAME                              | ENABLED  | IN-USE   | RISK    |
+------------------------------------------+----------+----------+---------+
| Real Application Clusters                | 12/257   | 12/257   | !! RISK |
    [AIX       ] dcup60                     hzarcmo      enabled=TRUE     inuse=Y
    [AIX       ] dcup61                     m1prod       enabled=TRUE     inuse=Y
    [US-Linux  ] crlnxp1015                 prod01       enabled=TRUE     inuse=Y
    [EU-Linux  ] nllnxp2030                 euprod       enabled=TRUE     inuse=Y
| Partitioning                             | 45/257   | 45/257   | !! RISK |
    [AIX       ] dcup60                     hzmo         enabled=TRUE     inuse=Y
    [US-Linux  ] crlnxp1086                 lic01        enabled=TRUE     inuse=Y
...
```

**Standard Report (Single RUN_ID):**

```bash
# Generate report for latest single run (original behavior)
ansible-playbook playbooks/report_audit_run.yml \
  -i inv_var.yml

# Generate report for specific RUN_ID
ansible-playbook playbooks/report_audit_run.yml \
  -i inv_var.yml \
  -e "report_run_id=64"

# List available runs
ansible-playbook playbooks/report_audit_run.yml \
  -i inv_var.yml \
  -e "list_runs_only=true"
```

**Automated Weekly Multi-Platform Report:**

```bash
# Schedule weekly unified report generation
cat > ~/weekly_unified_report.sh << 'SCRIPT'
#!/bin/bash
ansible-playbook playbooks/report_audit_run.yml \
  -i inv_var.yml \
  -e "multi_platform_report=true" \
  -e "send_summary_email=true"
SCRIPT

chmod +x ~/weekly_unified_report.sh

# Add to crontab - Every Friday 9 AM
(crontab -l 2>/dev/null; echo "0 9 * * 5 /home/oracle/weekly_unified_report.sh") | crontab -
```

---

### Issue 7: Playbook Hangs or Slow

**Symptom:** Collection takes unusually long

**Resolution:**
```bash
# Check for detail queries flag
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "collect_partitioning=false collect_compression=false collect_security=false \
      collect_inmemory=false collect_pdbs=false collect_adg=false collect_rac=false"

# Run with fewer hosts in parallel (reduce forks)
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  --forks 5

# Check for large databases
ssh oracle@host "sqlplus / as sysdba << EOF
SELECT SUM(bytes)/1024/1024/1024 size_gb FROM dba_data_files;
EXIT;
EOF"
```

---

## Maintenance Tasks

### Task 1: Archive Old Runs

**Frequency:** Quarterly  
**Retention:** Keep 12 months of data

```sql
-- Connect to central DB
sqlplus mtaheri/PASSWORD@crlnxp1086:1535/dbai

-- Check run history
SELECT run_id, run_date, run_label, total_instances
FROM MTAHERI.ORACLE_OPT_RUNS
ORDER BY run_date DESC;

-- Archive runs older than 12 months (optional - create archive tables first)
-- DELETE FROM MTAHERI.ORACLE_OPT_FEATURES WHERE run_id IN (SELECT run_id FROM MTAHERI.ORACLE_OPT_RUNS WHERE run_date < ADD_MONTHS(SYSDATE, -12));
-- DELETE FROM MTAHERI.ORACLE_OPT_VOPTION WHERE run_id IN (SELECT run_id FROM MTAHERI.ORACLE_OPT_RUNS WHERE run_date < ADD_MONTHS(SYSDATE, -12));
-- DELETE FROM MTAHERI.ORACLE_OPT_INSTANCES WHERE run_id IN (SELECT run_id FROM MTAHERI.ORACLE_OPT_RUNS WHERE run_date < ADD_MONTHS(SYSDATE, -12));
-- DELETE FROM MTAHERI.ORACLE_OPT_RUNS WHERE run_date < ADD_MONTHS(SYSDATE, -12);
-- COMMIT;
```

---

### Task 2: Update Inventory

**When:** New hosts added or decommissioned

```bash
# Edit inventory
vi ansibleInventory/inv_key.yml

# Test new host
ansible new_host -i ansibleInventory/inv_key.yml -m ping

# Run test collection
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l new_host \
  -e "run_label=New-Host-Test"
```

---

### Task 3: Update Repository Password

**When:** Password rotation

```bash
# Edit role defaults
vi roles/oracle_options_audit/defaults/main.yml

# Find and update
repo_password: "NEW_PASSWORD_HERE"

# Test connection
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "run_label=Password-Test"
```

---

### Task 4: Clean Up Log Files

**Frequency:** Monthly

```bash
# Archive old logs
cd logs/oracle_options_audit
mkdir -p archive/$(date +%Y-%m)
find . -maxdepth 1 -type f -mtime +30 -name "*.sql" -exec mv {} archive/$(date +%Y-%m)/ \;
find . -maxdepth 1 -type f -mtime +30 -name "*.log" -exec mv {} archive/$(date +%Y-%m)/ \;

# Compress archives older than 3 months
find archive/ -type f -mtime +90 -name "*.sql" -exec gzip {} \;
find archive/ -type f -mtime +90 -name "*.log" -exec gzip {} \;
```

---

### Scenario 9: Check Host Coverage & Identify Missing Servers

**Use Case:** Audit completeness - identify hosts not collected recently

**Method 1: Quick Script (Recommended)**

```bash
# Run the coverage check script (shows hosts not audited in last 7 days)
cd /home/svcorap/mohsen/ansible
chmod +x scripts/check_host_coverage.sh
./scripts/check_host_coverage.sh 7

# Or check hosts missing for 30+ days
./scripts/check_host_coverage.sh 30
```

**Method 2: Direct SQL Query**

```bash
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 180 PAGESIZE 100
COL hostname FORMAT A25
COL os_type FORMAT A15
COL last_audit FORMAT A11
COL days_ago FORMAT 999
COL status FORMAT A15

SELECT 
  i.hostname,
  i.os_type,
  TO_CHAR(MAX(r.run_date), 'YYYY-MM-DD') AS last_audit,
  TRUNC(SYSDATE - MAX(r.run_date)) AS days_ago,
  CASE 
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) <= 7 THEN '✓ Current'
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) <= 30 THEN '⚠ Aging'
    ELSE '✗ STALE'
  END AS status
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
WHERE r.run_id = (
  SELECT MAX(r2.run_id)
  FROM ORACLE_OPT_RUNS r2
  JOIN ORACLE_OPT_INSTANCES i2 ON i2.run_id = r2.run_id
  WHERE i2.hostname = i.hostname
)
GROUP BY i.hostname, i.os_type
HAVING TRUNC(SYSDATE - MAX(r.run_date)) > 7
ORDER BY TRUNC(SYSDATE - MAX(r.run_date)) DESC;
EOF
```

**Action Items from Coverage Report:**

1. **✗ STALE hosts (>30 days):** 
   - Verify host is still active (not decommissioned)
   - Check SSH connectivity: `ansible -i inv_var.yml -m ping <hostname>`
   - Check credentials: Review inventory password groups
   - Check if host excluded from collection

2. **⚠ Aging hosts (7-30 days):**
   - Review collection schedule for that platform
   - Check for recent collection failures in logs
   - Consider running targeted collection

3. **Missing entire platforms:**
   - Cross-reference with inventory groups
   - Ensure multi-platform reporting includes all regions
   - Check if scheduled collections are running

**Expected Coverage:**
- **AIX TLP:** 14 servers (collected weekly)
- **Linux US:** ~61 servers (collected weekly)
- **Linux EU:** ~45 servers (collected bi-weekly)

**Fix: Re-collect Missing Hosts**

```bash
# Option 1: Re-run full platform collection
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l "tlp_aix_prod,tlp_aix_prod2" \
  -e "run_label=AIX-Recovery-$(date +%Y-%m-%d)"

# Option 2: Target specific missing hosts
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l "dcup60,dcup61,cranxp016" \
  -e "run_label=Missing-Hosts-$(date +%Y-%m-%d)"
```

---

### Scenario 10: Verify Host Counts After Audit Run

**Use Case:** Confirm all expected hosts were captured in the audit run

**Method 1: Quick Terminal Check (Fastest)**

```bash
cd /home/svcorap/mohsen/ansible
chmod +x scripts/quick_host_check.sh
./scripts/quick_host_check.sh
```

**Method 2: Simple SQL Check**

```bash
# Quick one-liner to see host counts
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub @scripts/quick_check.sql
```

**Method 3: Comprehensive Verification (Detailed)**

```bash
# Full 12-section verification report
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub @scripts/verify_host_coverage.sql
```

**Method 4: Manual SQL (Copy/Paste)**

```sql
-- Connect to repository
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub

-- Check latest run summary
SELECT 
  run_id,
  TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
  run_label,
  total_hosts,
  total_instances
FROM ORACLE_OPT_RUNS
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS);

-- Compare platform counts: Latest Run vs All Time
SELECT 
  'Latest Run' AS scope,
  CASE
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' AND UPPER(i.region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END AS platform,
  COUNT(DISTINCT i.hostname) AS hosts,
  COUNT(DISTINCT i.sid) AS instances
FROM ORACLE_OPT_INSTANCES i
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY
  CASE
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' AND UPPER(i.region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END
UNION ALL
SELECT 
  'All Time' AS scope,
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' AND UPPER(region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END AS platform,
  COUNT(DISTINCT hostname) AS hosts,
  0 AS instances
FROM ORACLE_OPT_INSTANCES
GROUP BY
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' AND UPPER(region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END
ORDER BY platform, scope DESC;

-- Check Linux region values (diagnose NULL regions)
SELECT 
  NVL(region, 'NULL/EMPTY') AS region,
  COUNT(DISTINCT hostname) AS host_count,
  COUNT(DISTINCT sid) AS instance_count
FROM ORACLE_OPT_INSTANCES
WHERE UPPER(os_type) LIKE '%LINUX%'
  AND run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY region
ORDER BY host_count DESC;

-- List all hosts in latest run with details
SELECT 
  hostname,
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'Linux'
    ELSE os_type
  END AS platform,
  NVL(region, 'NULL') AS region,
  COUNT(DISTINCT sid) AS instances
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY hostname, os_type, region
ORDER BY platform, hostname;
```

**Expected Counts:**
- **AIX TLP:** 14 servers
- **US Linux:** ~61 servers  
- **EU Linux:** ~45 servers
- **Total:** ~120 servers

**Common Issues:**

1. **Host count lower than expected:**
   - Check Ansible execution log for failed hosts: `grep -i "failed\|unreachable" logs/*.log`
   - Verify SSH connectivity: `ansible -i inv_var.yml -m ping all`
   - Check for skipped hosts in the run

2. **NULL/Empty region values:**
   - Linux servers without region will be classified as "US-Linux" by default
   - Check: `SELECT hostname, region FROM ORACLE_OPT_INSTANCES WHERE region IS NULL`
   - To fix: Update inventory to set `region` variable for hosts

3. **Hosts showing in "Other" category:**
   - Check `os_type` value: `SELECT DISTINCT os_type FROM ORACLE_OPT_INSTANCES`
   - Verify `os_type` matches expected values (AIX, Linux, etc.)

**Remediation:**

```bash
# If hosts are missing, check which inventory groups were used
ansible-playbook playbooks/collect_oracle_options.yml \
  -i inv_var.yml \
  --list-hosts \
  -l "us_lnx_prod,us_lnx_nonprod,tlp_aix_prod,tlp_aix_prod2"

# Re-run for specific missing hosts
ansible-playbook playbooks/collect_oracle_options.yml \
  -i inv_var.yml \
  -l "missing_host1,missing_host2,missing_host3" \
  -e "run_label=Recovery-$(date +%Y-%m-%d)"
```

---

## Query Examples

### Query 1: All High-Risk Options (Enabled + In-Use)

```sql
SELECT hostname, sid, option_name, is_inuse
FROM DBAORALIC_SCH.ORACLE_OPT_VOPTION v
JOIN DBAORALIC_SCH.ORACLE_OPT_RUNS r ON r.run_id = v.run_id
WHERE r.run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
  AND v.is_ee_extra = 'Y'
  AND v.option_enabled = 'TRUE'
  AND v.is_inuse = 'Y'
ORDER BY option_name, hostname;
```

---

### Query 2: Partitioning Usage by Host

```sql
SELECT hostname, sid, COUNT(*) AS part_table_count, 
       SUM(size_gb) AS total_size_gb
FROM DBAORALIC_SCH.ORACLE_OPT_D_PART
WHERE run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
GROUP BY hostname, sid
ORDER BY total_size_gb DESC;
```

---

### Query 3: All Standby Databases

```sql
SELECT hostname, sid, db_role, open_mode, is_standby
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
  AND is_standby = 'Y'
ORDER BY hostname;
```

---

### Query 4: License Usage Trend Over Time

```sql
SELECT r.run_date, 
       COUNT(DISTINCT v.hostname || v.sid) AS instance_count
FROM DBAORALIC_SCH.ORACLE_OPT_VOPTION v
JOIN DBAORALIC_SCH.ORACLE_OPT_RUNS r ON r.run_id = v.run_id
WHERE v.option_name = 'Partitioning'
  AND v.is_inuse = 'Y'
GROUP BY r.run_date
ORDER BY r.run_date;
```

---

### Query 5: Latest Run Summary

```sql
SELECT run_id, run_date, run_label, 
       total_hosts, total_instances
FROM MTAHERI.ORACLE_OPT_RUNS
ORDER BY run_date DESC
FETCH FIRST 10 ROWS ONLY;
```

---

### Query 6: Verify AIX Server Data Collection

**Check if specific AIX servers have reported data:**

```sql
-- Quick check - AIX servers in latest run (by OS type)
SELECT hostname, os_type, COUNT(DISTINCT sid) AS instance_count
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
  AND UPPER(os_type) = 'AIX'
GROUP BY hostname, os_type
ORDER BY hostname;

-- Expected: Should return rows for all 14 TLP AIX servers

-- Alternative: Filter by specific hostname list
SELECT hostname, os_type, COUNT(DISTINCT sid) AS instance_count
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
  AND UPPER(hostname) IN ('DCUP60', 'DCUP61', 'DCUNX216', 'DCUNX217', 
                          'CRANXP016', 'CRANXP014', 'CRANXP012',
                          'CRANXM006', 'DCUNX218', 'DCUNX219', 
                          'CRANXM008', 'CRANXM010', 'CRANXP018', 'CRANXP020')
GROUP BY hostname, os_type
ORDER BY hostname;
```

**Detailed AIX instance inventory:**

```sql
-- All instances on AIX servers with version info (by OS type)
SELECT i.hostname, i.sid, i.db_name, i.oracle_version, 
       i.db_role, i.is_standby, i.region, i.os_type
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
WHERE i.run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
  AND UPPER(i.os_type) = 'AIX'
ORDER BY i.hostname, i.sid;

-- Expected: Should show 17 instances on dcup60, etc.
```

**AIX data collection summary by host:**

```sql
-- Count data collected per AIX server
SELECT 
  i.hostname,
  COUNT(DISTINCT i.sid) AS instances, (by OS type)
SELECT 
  i.hostname,
  i.os_type,
  COUNT(DISTINCT i.sid) AS instances,
  COUNT(v.voption_id) AS voption_rows,
  COUNT(f.feature_id) AS feature_rows
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
LEFT JOIN DBAORALIC_SCH.ORACLE_OPT_VOPTION v ON v.inst_id = i.inst_id
LEFT JOIN DBAORALIC_SCH.ORACLE_OPT_FEATURES f ON f.inst_id = i.inst_id
WHERE i.run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
  AND UPPER(i.os_type) = 'AIX'
GROUP BY i.hostname, i.os_typon_rows should be ~40-60 per instance, features ~300-500 per instance
```

**Check for missing AIX servers:**

```sql
-- List which AIX servers are missing from latest run
SELECT server_name, expected_instances
FROM (
  SELECT 'dcup60' AS server_name, 17 AS expected_instances FROM DUAL UNION ALL
  SELECT 'dcup61', 5 FROM DUAL UNION ALL
  SELECT 'dcunx216', 3 FROM DUAL UNION ALL
  SELECT 'dcunx217', 2 FROM DUAL UNION ALL
  SELECT 'cranxp016', 4 FROM DUAL UNION ALL
  SELECT 'cranxp014', 3 FROM DUAL UNION ALL
  SELECT 'cranxp012', 2 FROM DUAL UNION ALL
  SELECT 'cranxm006', 1 FROM DUAL UNION ALL
  SELECT 'dcunx218', 2 FROM DUAL UNION ALL
  SELECT 'dcunx219', 2 FROM DUAL UNION ALL
  SELECT 'cranxm008', 1 FROM DUAL UNION ALL
  SELECT 'cranxm010', 1 FROM DUAL UNION ALL
  SELECT 'cranxp018', 1 FROM DUAL UNION ALL
  SELECT 'cranxp020', 1 FROM DUAL
) expected
WHERE NOT EXISTS (
  SELECT 1 
  FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
  WHERE i.run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
    AND UPPER(i.hostname) = UPPER(expected.server_name)
)
ORDER BY server_name;

-- Expected: Empty result set (all servers collected)
```

**Verify specific AIX run by label:**

```sql
-- Check TLP AIX run data (by OS type)
SELECT 
  r.run_id, 
  r.run_date, 
  r.run_label,
  COUNT(DISTINCT i.hostname) AS aix_hosts,
  COUNT(DISTINCT i.inst_id) AS total_instances
FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
WHERE r.run_label LIKE '%TLP%AIX%'
  AND UPPER(i.os_type) = 'AIX'
GROUP BY r.run_id, r.run_date, r.run_label
ORDER BY r.run_date DESC;

-- Expected: Should show runs with label 'US-TLP-AIX-Full-YYYY-MM-DD'

-- Compare AIX vs Linux data in latest run
SELECT 
  i.os_type,
  COUNT(DISTINCT i.hostname) AS hosts,
  COUNT(DISTINCT i.inst_id) AS instances
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
WHERE i.run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
GROUP BY i.os_type
ORDER BY i.os_type;
```

**AIX license risk summary:**

```sql
-- High-risk options on AIX servers
SELECT 
  i.hostname, (by OS type)
SELECT 
  i.hostname,
  v.option_name,
  COUNT(DISTINCT i.sid) AS affected_instances,
  SUM(CASE WHEN v.is_inuse = 'Y' THEN 1 ELSE 0 END) AS in_use_count
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
JOIN DBAORALIC_SCH.ORACLE_OPT_VOPTION v ON v.inst_id = i.inst_id
WHERE i.run_id = (SELECT MAX(run_id) FROM DBAORALIC_SCH.ORACLE_OPT_RUNS)
  AND UPPER(i.os_type) = 'AIX'
GROUP BY i.hostname, v.option_name
HAVING SUM(CASE WHEN v.is_inuse = 'Y' THEN 1 ELSE 0 END) > 0
ORDER BY i.hostname, v.option_name;
```

**Quick verification script (run after AIX collection):**

```bash
# Complete AIX audit verification
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 200 PAGESIZE 100
COL hostname FORMAT A15 (using OS type filter)
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 200 PAGESIZE 100
COL hostname FORMAT A15
COL os_type FORMAT A10
COL run_label FORMAT A30
COL run_date FORMAT A20

PROMPT ========================================
PROMPT Latest AIX Run Summary
PROMPT ========================================
SELECT r.run_id, 
       TO_CHAR(r.run_date, 'YYYY-MM-DD HH24:MI:SS') AS run_date,
       r.run_label,
       COUNT(DISTINCT i.hostname) AS aix_hosts,
       COUNT(DISTINCT i.inst_id) AS total_instances
FROM ORACLE_OPT_RUNS r
JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
WHERE r.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(i.os_type) = 'AIX'
GROUP BY r.run_id, r.run_date, r.run_label;

PROMPT 
PROMPT ========================================
PROMPT AIX Hosts - Instance Count
PROMPT ========================================
SELECT hostname, os_type, COUNT(*) AS instances
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(os_type) = 'AIX'
GROUP BY hostname, os_type
ORDER BY hostname;

PROMPT 
PROMPT ========================================
PROMPT Data Completeness Check
PROMPT ========================================
SELECT 
  'Expected TLP AIX Servers' AS metric,
  '14' AS expected_value,
  TO_CHAR(COUNT(DISTINCT hostname)) AS actual_value,
  CASE WHEN COUNT(DISTINCT hostname) >= 14 THEN '✓ PASS' ELSE '✗ FAIL' END AS status
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(os_type) = 'AIX';

PROMPT 
PROMPT ========================================
PROMPT AIX OS Distribution
PROMPT ========================================
SELECT os_type, COUNT(DISTINCT hostname) AS hosts, COUNT(*) AS instances
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(os_type) LIKE '%AIX%'
GROUP BY os_type
EOF
```

---

### Query 7: Host Coverage & Audit History Report

**Purpose:** Identify ALL hosts in the repository and their audit status to detect missing or stale servers.

**Complete Host Inventory with Last Audit:**

```sql
-- All unique hosts with their last audit date and instance count
SELECT 
  i.hostname,
  i.os_type,
  i.region,
  MAX(r.run_date) AS last_audit_date,
  TRUNC(SYSDATE - MAX(r.run_date)) AS days_since_audit,
  COUNT(DISTINCT i.sid) AS instance_count,
  MAX(r.run_id) AS last_run_id,
  MAX(r.run_label) AS last_run_label,
  CASE 
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) = 0 THEN '✓ Today'
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) <= 7 THEN '✓ Recent'
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) <= 30 THEN '⚠ Aging'
    ELSE '✗ STALE'
  END AS audit_status
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
JOIN DBAORALIC_SCH.ORACLE_OPT_RUNS r ON r.run_id = i.run_id
GROUP BY i.hostname, i.os_type, i.region
ORDER BY MAX(r.run_date) DESC, i.hostname;
```

**Host Coverage by Platform:**

```sql
-- Summary: How many hosts audited by platform and recency
SELECT 
  i.os_type,
  COUNT(DISTINCT i.hostname) AS total_hosts,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) = 0 THEN 1 ELSE 0 END) AS audited_today,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) BETWEEN 1 AND 7 THEN 1 ELSE 0 END) AS audited_this_week,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) > 30 THEN 1 ELSE 0 END) AS stale_30plus_days
FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
JOIN DBAORALIC_SCH.ORACLE_OPT_RUNS r ON r.run_id = i.run_id
WHERE r.run_id = (
  SELECT MAX(r2.run_id)
  FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r2
  JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i2 ON i2.run_id = r2.run_id
  WHERE i2.hostname = i.hostname
)
GROUP BY i.os_type
ORDER BY i.os_type;
```

**Latest Run Coverage Comparison:**

```sql
-- Compare different RUN_IDs to see platform coverage
SELECT 
  r.run_id,
  TO_CHAR(r.run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
  r.run_label,
  COUNT(DISTINCT i.hostname) AS hosts,
  COUNT(DISTINCT i.inst_id) AS instances,
  LISTAGG(DISTINCT i.os_type, ', ') WITHIN GROUP (ORDER BY i.os_type) AS platforms
FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
WHERE r.run_date >= SYSDATE - 7
GROUP BY r.run_id, r.run_date, r.run_label
ORDER BY r.run_date DESC;
```

**Missing Linux Servers (Expected vs Actual):**

```sql
-- Find Linux servers that haven't reported in latest runs
WITH latest_linux_hosts AS (
  SELECT DISTINCT i.hostname
  FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
  JOIN DBAORALIC_SCH.ORACLE_OPT_RUNS r ON r.run_id = i.run_id
  WHERE UPPER(i.os_type) LIKE '%LINUX%'
    AND r.run_date >= SYSDATE - 30
),
historical_linux_hosts AS (
  SELECT DISTINCT i.hostname
  FROM DBAORALIC_SCH.ORACLE_OPT_INSTANCES i
  WHERE UPPER(i.os_type) LIKE '%LINUX%'
)
SELECT 
  h.hostname AS missing_linux_host,
  MAX(r.run_date) AS last_seen_date,
  TRUNC(SYSDATE - MAX(r.run_date)) AS days_missing
FROM historical_linux_hosts h
LEFT JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i ON i.hostname = h.hostname
LEFT JOIN DBAORALIC_SCH.ORACLE_OPT_RUNS r ON r.run_id = i.run_id
WHERE h.hostname NOT IN (SELECT hostname FROM latest_linux_hosts)
GROUP BY h.hostname
ORDER BY MAX(r.run_date) DESC;
```

**Quick Coverage Check Script:**

```bash
# Generate host coverage report
sqlplus -s DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<'EOF'
SET LINESIZE 180 PAGESIZE 100
COL hostname FORMAT A20
COL os_type FORMAT A12
COL region FORMAT A8
COL last_audit_date FORMAT A11
COL days_ago FORMAT 999
COL instances FORMAT 999
COL run_label FORMAT A30
COL status FORMAT A12

PROMPT ========================================
PROMPT HOST COVERAGE REPORT
PROMPT ========================================
PROMPT 

SELECT 
  i.hostname,
  i.os_type,
  NVL(i.region, 'N/A') AS region,
  TO_CHAR(MAX(r.run_date), 'YYYY-MM-DD') AS last_audit_date,
  TRUNC(SYSDATE - MAX(r.run_date)) AS days_ago,
  COUNT(DISTINCT i.sid) AS instances,
  SUBSTR(MAX(r.run_label), 1, 30) AS run_label,
  CASE 
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) = 0 THEN '✓ Today'
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) <= 7 THEN '✓ Recent'
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) <= 30 THEN '⚠ Aging'
    ELSE '✗ STALE'
  END AS status
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
GROUP BY i.hostname, i.os_type, i.region
HAVING TRUNC(SYSDATE - MAX(r.run_date)) > 7  -- Show only aging/stale hosts
ORDER BY TRUNC(SYSDATE - MAX(r.run_date)) DESC, i.hostname;

PROMPT 
PROMPT ========================================
PROMPT PLATFORM SUMMARY
PROMPT ========================================

SELECT 
  NVL(i.os_type, 'Unknown') AS platform,
  COUNT(DISTINCT i.hostname) AS total_hosts,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) <= 1 THEN 1 ELSE 0 END) AS current,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) BETWEEN 2 AND 7 THEN 1 ELSE 0 END) AS recent,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) > 7 THEN 1 ELSE 0 END) AS stale
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
WHERE r.run_id = (
  SELECT MAX(r2.run_id)
  FROM ORACLE_OPT_RUNS r2
  JOIN ORACLE_OPT_INSTANCES i2 ON i2.run_id = r2.run_id
  WHERE i2.hostname = i.hostname
)
GROUP BY i.os_type
ORDER BY i.os_type;

PROMPT 
PROMPT Legend: ✓ = Current, ⚠ = Review, ✗ = Action Required
EOF
```

**Action Items from Coverage Report:**

1. **Stale hosts (>30 days):** Investigate why not collecting - connectivity, credentials, decommissioned?
2. **Missing hosts:** Cross-reference with infrastructure inventory to identify gaps
3. **Platform imbalances:** Ensure all platforms collected on appropriate schedules
4. **Run failures:** Check logs for hosts that attempted but failed collection

---

## Escalation Contacts

| Issue Type | Contact | Email |
|------------|---------|-------|
| Playbook Errors | DBA Automation Team | dba-automation@transamerica.com |
| Licensing Questions | Oracle LMS Team | licensing@transamerica.com |
| Access Issues | Infrastructure Team | infra-support@transamerica.com |
| Email/SMTP Issues | Messaging Team | messaging@transamerica.com |

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-05-11 | 1.0 | Initial runbook creation | DBA Team |

---

**For 1-page cheat sheet, see [QUICK_REFERENCE.md](QUICK_REFERENCE.md)**

