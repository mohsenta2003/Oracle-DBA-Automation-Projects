# d1hub Repository Schema Validation Results
**Date:** 2026-05-11  
**Database:** D1HUB on crlnxd1046:1535  
**Schema:** DBAORALIC_SCH

---

## ✅ Connection Test Results

```
✓ Successfully connected to d1hub using TNS alias
✓ User: DBAORALIC_SCH
✓ Database: D1HUB
✓ Connection string: d1hub (TNS alias)
```

---

## ✅ Schema Object Summary

| Object Type | Count | Status |
|-------------|-------|--------|
| **Tables** | 11 | ✓ All required ORACLE_OPT_* tables exist |
| **Indexes** | 23 | ✓ All indexes created |
| **Sequences** | 11 | ✓ All sequences created |
| **Views** | 5 | ✓ All views created |

---

## ✅ Table Inventory

All 11 required tables exist in DBAORALIC_SCH:

1. `ORACLE_OPT_RUNS` — Run metadata (one row per playbook execution)
2. `ORACLE_OPT_INSTANCES` — Instance details (version, role, patch level, region)
3. `ORACLE_OPT_VOPTION` — v$option flags (license options enabled)
4. `ORACLE_OPT_FEATURES` — dba_feature_usage_statistics (actual usage)
5. `ORACLE_OPT_D_PART` — Partitioning evidence (objects, types, sizes)
6. `ORACLE_OPT_D_COMPRESS` — Advanced Compression evidence
7. `ORACLE_OPT_D_SECURITY` — TDE/Advanced Security evidence
8. `ORACLE_OPT_D_INMEM` — In-Memory Column Store evidence
9. `ORACLE_OPT_D_PDB` — PDB list (12c+ multitenant)
10. `ORACLE_OPT_D_ADG` — Active Data Guard evidence
11. `ORACLE_OPT_D_RAC` — RAC node list

---

## ✅ Required Columns Verified

- ✓ `IS_EE_EXTRA` column exists in `ORACLE_OPT_VOPTION`
- ✓ `IS_INUSE` column exists in `ORACLE_OPT_VOPTION`

These columns are used for license risk classification:
- `IS_EE_EXTRA='Y'` — Extra-cost option (Partitioning, Compression, etc.)
- `IS_INUSE='Y'` — Feature usage detected (license exposure risk)

---

## 📊 Current Data Status

```
Row Count: 0 in all tables
Status: Repository is EMPTY (ready for first data collection)
```

**This is expected for a new repository.**

---

## ⚠️ User Privileges

**Finding:** DBAORALIC_SCH has **NO system privileges** granted.

**Impact:**
- ❌ Cannot query `dba_*` views (e.g., `dba_users`, `dba_tables`, `dba_objects`)
- ✅ Can INSERT into own tables (sufficient for data collection)
- ✅ Can query `user_*` views (own schema objects)

**This is acceptable** — the user only needs to insert data into ORACLE_OPT_* tables.  
No DBA privileges required for data collection operations.

---

## 🎯 Next Steps

### 1. Validate Repository Schema (Pre-flight Check)

```bash
ansible-playbook playbooks/_validate_repo.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"
```

**Expected Output:**
```
✓ Repository connection SUCCESSFUL: DBAORALIC_SCH@d1hub
✓ All 11 tables exist
✓ Required columns present
✓✓✓ REPOSITORY VALIDATION PASSED ✓✓✓
```

---

### 2. Collect Data from Target Hosts

```bash
# Test with single host first
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "repo_tns_alias=d1hub run_label=Test-d1hub-Connection"

# Verify data inserted
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub <<EOF
SELECT run_id, run_date, run_label, total_instances
FROM ORACLE_OPT_RUNS
ORDER BY run_date DESC;

SELECT hostname, sid, db_name, oracle_version
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS);
EOF
```

---

### 3. Full Estate Collection

```bash
# All US Linux servers
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l all_us_linux \
  -e "repo_tns_alias=d1hub run_label=US-Linux-Full-$(date +%Y%m%d)"

# All EU Linux servers
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l all_eu_linux \
  -e "repo_tns_alias=d1hub run_label=EU-Linux-Full-$(date +%Y%m%d)"
```

---

### 4. Generate HTML Report

```bash
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"
```

---

## 🔧 Troubleshooting

### If connection fails:

```bash
# Test TNS connectivity from Ansible controller (crlnxp1086)
tnsping d1hub

# Test sqlplus connection
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub

# Verify tnsnames.ora contains d1hub entry
cat $ORACLE_HOME/network/admin/tnsnames.ora | grep -A5 d1hub
```

### If tables don't exist:

```bash
# Create all tables and objects
ansible-playbook playbooks/_setup_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"
```

### Manual validation:

```bash
# Execute the SQL script directly
cd c:\temp\project\ansible\Oracle-DBA-Automation-Projects-main
sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub @check_repo_schema.sql
```

---

## 📋 Comparison: Old vs New Repository

| Attribute | Old (dbai) | New (d1hub) |
|-----------|------------|-------------|
| **Host** | crlnxp1086 | crlnxd1046 |
| **Port** | 1535 | 1535 |
| **SID** | dbai | d1hub |
| **Schema** | MTAHERI | DBAORALIC_SCH |
| **Connection** | Host:Port:SID (fails) | TNS alias (works) |
| **Status** | Legacy | **Current** |

**Key Change:** New controller environment requires TNS alias format instead of EZConnect syntax.

---

## ✅ Validation Summary

- ✅ **Database connectivity:** TNS alias `d1hub` works
- ✅ **Schema exists:** DBAORALIC_SCH created
- ✅ **All tables created:** 11 ORACLE_OPT_* tables
- ✅ **Indexes created:** 23 indexes for performance
- ✅ **Sequences created:** 11 sequences for primary keys
- ✅ **Views created:** 5 views for reporting
- ✅ **Required columns:** IS_EE_EXTRA, IS_INUSE present
- ✅ **Data state:** Empty, ready for first collection
- ✅ **User permissions:** Sufficient for data insertion

**Result:** Repository is fully prepared and ready for production data collection.

---

**Validated by:** GitHub Copilot  
**Validation Method:** Direct sqlplus connection + schema inspection  
**Ansible Playbook:** `_validate_repo.yml` (automated validation)
