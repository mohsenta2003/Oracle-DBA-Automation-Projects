# Oracle Options & Features Audit

Collects Oracle EE license-relevant data from every running instance in the estate, stores it in a central Oracle repository, and generates a colour-coded HTML report with per-option evidence tables.

---

## Architecture

```
_validate_repo.yml                 <- Pre-flight: verify repository schema is ready
collect_oracle_options.yml         <- Step 1: gather data from all hosts
report_audit_run.yml               <- Step 2: query DB, build + email HTML report
_setup_audit_tables.yml            <- One-off: create/rebuild all schema objects
_clean_repo_data.yml               <- One-off: truncate all data (keep schema structure)
_check_audit_tables.yml            <- One-off: verify tables + row counts
```

---

## What Gets Collected

| # | Data | Source | Standby? |
|---|------|--------|----------|
| 1 | Auto-detect Oracle OS user + all running SIDs | `ps aux` / `ora_pmon_*` | YES |
| 2 | Map each SID to ORACLE_HOME | `/etc/oratab` | YES |
| 3 | DB role, open mode, DB name, DBID | `v$database` | YES |
| 4 | Oracle version, OPatch version, latest PSU/RU | `dba_registry_sqlpatch` (12c+) | YES |
| 5 | Total DB allocated size | `dba_data_files` | YES |
| 6 | **All `v$option` flags** (every licensed option) | `v$option` | YES |
| 7 | **Active Data Guard detection** -- standby open READ ONLY | `v$database` + `v$archive_dest_status` | Standbys only |
| 8 | Refresh + collect feature usage statistics | `dba_feature_usage_statistics` | Primary only |
| 9 | Partitioned objects list (owner, type, key, count, size) | `dba_part_tables` | Primary only |
| 10 | Advanced Compression objects | `dba_tables` | Primary only |
| 11 | TDE encrypted tablespaces + columns | `dba_tablespaces`, `dba_encrypted_columns` | Primary only |
| 12 | In-Memory objects (`INMEMORY=ENABLED`) | `dba_tables` | Primary only |
| 13 | PDB list (CDB instances, 12c+) | `v$pdbs` | Primary only |
| 14 | RAC node list | `gv$instance` | Primary only |

**Standby instances are NOT skipped.** `v$option` is collected on all instances including standbys.
Active Data Guard `IS_INUSE=Y` is flagged automatically when a standby has `DB_ROLE=PHYSICAL STANDBY` AND `OPEN_MODE` contains `READ ONLY`.

---

## Central Repository

**Current:** d1hub on crlnxd1046:1535 (DBAORALIC_SCH schema)  
**Legacy:** dbai on crlnxp1086:1535 (MTAHERI schema)

Use `-e "repo_tns_alias=d1hub"` for all playbook runs to connect to the new repository.

**Schema Structure:** 11 tables, 23 indexes, 11 sequences, 5 views (auto-created by `_setup_audit_tables.yml`)

### Tables

| Table | Contents |
|-------|----------|
| `ORACLE_OPT_RUNS` | One row per playbook execution |
| `ORACLE_OPT_INSTANCES` | One row per SID per run -- version, role, patch, OS, region |
| `ORACLE_OPT_VOPTION` | All `v$option` rows per SID + `IS_INUSE` flag |
| `ORACLE_OPT_FEATURES` | All `dba_feature_usage_statistics` rows per SID |
| `ORACLE_OPT_D_PART` | Partitioned objects evidence |
| `ORACLE_OPT_D_COMPRESS` | Compression evidence |
| `ORACLE_OPT_D_SECURITY` | TDE encrypted objects evidence |
| `ORACLE_OPT_D_INMEM` | In-Memory objects evidence |
| `ORACLE_OPT_D_PDB` | PDB list |
| `ORACLE_OPT_D_ADG` | Active Data Guard evidence (standby databases open READ ONLY) |
| `ORACLE_OPT_D_RAC` | RAC node list |

### Views

| View | Contents |
|------|----------|
| `ORACLE_OPT_LATEST_VW` | Full snapshot from the most recent run |
| `ORACLE_OPT_ENABLED_VW` | Options marked `TRUE` in the latest run |
| `ORACLE_OPT_INUSE_VW` | Features with `DETECTED_USAGES > 0` in the latest run |
| `ORACLE_OPT_TREND_VW` | Usage count over time per feature, per host |
| `ORACLE_OPT_HISTORY_VW` | Full point-in-time history across all runs |

### Indexes & Sequences

| Object Type | Count | Notes |
|-------------|-------|-------|
| **Indexes** | 23 | 11 PRIMARY KEY (auto-created) + 12 performance indexes |
| **Sequences** | 11 | One per table (auto-created by IDENTITY columns) |

**Performance Indexes:**
- `ORACLE_OPT_RUNS_IDX1` (RUN_DATE) — Time-based queries
- `ORACLE_OPT_RUNS_IDX2` (RUN_LABEL) — Label searches
- `ORACLE_OPT_INSTANCES_IDX1` (RUN_ID, HOSTNAME) — Instance lookups
- `ORACLE_OPT_INSTANCES_IDX2` (HOSTNAME, SID) — Host-SID queries
- `ORACLE_OPT_INSTANCES_IDX3` (DB_ROLE, IS_STANDBY) — Standby filtering
- `ORACLE_OPT_VOPTION_IDX1` (RUN_ID, IS_INUSE) — License risk queries
- `ORACLE_OPT_VOPTION_IDX2` (OPTION_NAME, IS_EE_EXTRA) — Option filtering
- `ORACLE_OPT_VOPTION_IDX3` (HOSTNAME, SID) — Host-based option queries
- `ORACLE_OPT_FEATURES_IDX1` (RUN_ID, DETECTED_USAGES) — Usage filtering
- `ORACLE_OPT_FEATURES_IDX2` (FEATURE_NAME) — Feature lookups
- `ORACLE_OPT_D_PART_IDX1` (RUN_ID) — Partitioning evidence by run
- `ORACLE_OPT_D_COMPRESS_IDX1` (RUN_ID) — Compression evidence by run
- `ORACLE_OPT_D_SECURITY_IDX1` (RUN_ID) — Security evidence by run

---

## Quick Start

**📖 Documentation:**
- **[RUNBOOK.md](RUNBOOK.md)** — Operational procedures, SOPs, troubleshooting, maintenance tasks
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** — One-page command cheat sheet for daily use
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Data flow, batch processing, error detection, SQL file management
- **[WORKFLOW_DIAGRAM.md](../../WORKFLOW_DIAGRAM.md)** — Visual step-by-step workflow diagram

```bash
# PRE-FLIGHT: validate repository schema (recommended before first run)
ansible-playbook playbooks/_validate_repo.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# ONE-OFF: create / rebuild all schema objects (only if validation fails or new repo)
ansible-playbook playbooks/_setup_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# CLEAN: truncate all data without dropping schema (start fresh)
ansible-playbook playbooks/_clean_repo_data.yml -i "localhost," -c local -e "repo_tns_alias=d1hub confirm_clean=yes"

# STEP 1: collect data
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "repo_tns_alias=d1hub"

# STEP 2: generate + email current state report
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"

# STEP 3 (NEW): generate historical timeline report
ansible-playbook playbooks/report_timeline.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub option=all"
```

---

## Timeline & Historical Analysis (NEW - May 2026)

**Historical Evidence Tracking:** All evidence tables preserve complete audit trail across ALL collection runs. Each run creates a new snapshot - old data is NEVER deleted.

### Quick SQL Queries

```bash
# Run directly on repository database
sqlplus DBAORALIC_SCH/password@d1hub

# Show all options timeline
@roles/oracle_options_audit/files/show_all_options_timeline.sql

# Show specific option timeline
@roles/oracle_options_audit/files/show_inmemory_timeline.sql
@roles/oracle_options_audit/files/show_partitioning_timeline.sql
@roles/oracle_options_audit/files/show_compression_timeline.sql
@roles/oracle_options_audit/files/show_security_timeline.sql
```

### Generate Timeline Reports (HTML + Text)

```bash
# All options comprehensive timeline
ansible-playbook playbooks/report_timeline.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub option=all"

# Specific option timelines
ansible-playbook playbooks/report_timeline.yml -i "localhost," -c local -e "option=inmemory"
ansible-playbook playbooks/report_timeline.yml -i "localhost," -c local -e "option=partitioning"
ansible-playbook playbooks/report_timeline.yml -i "localhost," -c local -e "option=compression"
ansible-playbook playbooks/report_timeline.yml -i "localhost," -c local -e "option=security"
```

**What Timeline Reports Show:**
- ✅ **WHEN** features were first/last used (from `dba_feature_usage_statistics`)
- ✅ **WHAT** specific objects had features configured (from evidence tables)
- ✅ **HOW LONG** features were active (first/last appearance across runs)
- ✅ **CHANGES OVER TIME** (objects added/removed, configuration changes)

**Use Cases:**
- License auditing: Prove historical usage even if currently disabled
- Change tracking: See when objects were added/removed
- Compliance: Show feature usage timeframes
- Capacity planning: Track growth trends

**Documentation:**
- **[HISTORICAL_EVIDENCE_GUIDE.md](HISTORICAL_EVIDENCE_GUIDE.md)** — Complete guide with use cases, examples, best practices

---

## Custom Repository Setup (Override Credentials)

You can set up the repository on **any Oracle database** by passing custom credentials:

### Using TNS Alias (Recommended)

```bash
# Validate connection first
ansible-playbook playbooks/_validate_repo.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=MYDB repo_user=AUDIT_SCHEMA repo_password='MyP@ssw0rd' repo_schema=AUDIT_SCHEMA"

# Build repository
ansible-playbook playbooks/_setup_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=MYDB repo_user=AUDIT_SCHEMA repo_password='MyP@ssw0rd' repo_schema=AUDIT_SCHEMA"

# Collect data to custom repository
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "repo_tns_alias=MYDB repo_user=AUDIT_SCHEMA repo_password='MyP@ssw0rd' repo_schema=AUDIT_SCHEMA run_label=CustomRepo-Test"
```

### Using Connection String (host:port:sid)

```bash
# Build repository on a different database
ansible-playbook playbooks/_setup_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_host=myserver.company.com repo_port=1521 repo_sid=PRODDB repo_user=AUDITUSER repo_password='SecretPass123' repo_schema=AUDITUSER"

# Collect data
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "repo_host=myserver.company.com repo_port=1521 repo_sid=PRODDB repo_user=AUDITUSER repo_password='SecretPass123' repo_schema=AUDITUSER"
```

**⚠️ Note:** Connection string format (host:port:sid) may not work on older Oracle clients (11g). Use TNS alias when possible.

### Complete Example: New Repository from Scratch

```bash
# Step 1: Test connection
tnsping newrepo
sqlplus MYUSER/MYPASS@newrepo

# Step 2: Validate (will show missing tables)
ansible-playbook playbooks/_validate_repo.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=newrepo repo_user=MYUSER repo_password='MYPASS' repo_schema=MYUSER"

# Step 3: Build all objects
ansible-playbook playbooks/_setup_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=newrepo repo_user=MYUSER repo_password='MYPASS' repo_schema=MYUSER"

# Step 4: Verify
ansible-playbook playbooks/_check_audit_tables.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=newrepo repo_user=MYUSER repo_password='MYPASS' repo_schema=MYUSER"

# Step 5: Test collection on one host
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015 \
  -e "repo_tns_alias=newrepo repo_user=MYUSER repo_password='MYPASS' repo_schema=MYUSER run_label=NewRepo-Test"
```

---

## Collect -- Common Run Samples

### Target by host group

```bash
# All US Linux servers (prod + model/staging + test)
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l all_us_linux \
  -e "run_label=US-Linux-Weekly-2026-W19"

# All EU Linux servers
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l all_eu_linux \
  -e "run_label=EU-Linux-Weekly-2026-W19"

# Production only (US + EU)
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l "us_lnx_prod,eu_nl_lnx_prod,eu_uk_lnx_prod" \
  -e "run_label=Prod-2026-05-08"

# AIX / TLP servers (passwords are in inventory -- no extra flags needed)
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l "tlp_aix_prod,tlp_aix_prod2,tlp_aix_nonprod,tlp_aix_nonprod2" \
  -e "run_label=AIX-TLP-2026-05-08"

# Full estate in one shot
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "run_label=Full-Estate-2026-05-08"
```

### Target specific hosts

```bash
# Named subset -- e.g. known partitioning servers
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l "crlnxp1015,crlnxp1088,crlnxm145,crlnxm157,crlnxm2139,crlnxt1008,crlnxt1015,crlnxt1035,crlnxt1050,crlnxt222,crlnxt234" \
  -e "run_label=Partitioning-Subset-2026-05-08" \
  -v

# Single host
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp1015

# Single SID on a multi-instance host
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxm2139 \
  -e "db_sid=invdev"

# Override Oracle user when auto-detection fails
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l crlnxp316 \
  -e "oracle_user=oracle"
```

---

## Collect -- Option-Based Runs  (skip detail queries for faster runs)

By default **all** detail evidence queries run. Disable individual ones to speed up targeted runs.
`v$option` and `dba_feature_usage_statistics` are **always** collected regardless of these flags.

### Collect v$option + features ONLY (no object-level evidence)

```bash
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "collect_partitioning=false collect_compression=false collect_security=false \
      collect_inmemory=false collect_pdbs=false collect_adg=false collect_rac=false"
```

### Partitioning evidence only

```bash
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "collect_compression=false collect_security=false collect_inmemory=false \
      collect_pdbs=false collect_adg=false collect_rac=false"
```

### TDE / Advanced Security evidence only

```bash
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "collect_partitioning=false collect_compression=false collect_inmemory=false \
      collect_pdbs=false collect_adg=false collect_rac=false"
```

### ADG + RAC topology only

```bash
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "collect_partitioning=false collect_compression=false collect_security=false \
      collect_inmemory=false collect_pdbs=false"
```

### In-Memory only (12c+)

```bash
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -e "collect_partitioning=false collect_compression=false collect_security=false \
      collect_pdbs=false collect_adg=false collect_rac=false"
```

---

## Report -- Common Run Samples

```bash
# Latest run -- generate + email report (default d1hub repository)
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub"

# Latest run from CUSTOM repository
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=MYDB repo_user=MYSCHEMA repo_password='MyP@ss' repo_schema=MYSCHEMA"

# Specific run ID (report from stored data without re-collecting)
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub report_run_id=22"

# List all available run IDs (no email sent)
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub list_runs_only=true"

# Generate report without sending email (save HTML file only)
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub send_summary_email=false"

# Skip sections with zero rows (compact report)
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub email_skip_empty_sections=true"

# Save HTML report to a custom directory
ansible-playbook playbooks/report_audit_run.yml \
  -i "localhost," -c local \
  -e "repo_tns_alias=d1hub report_output_dir=/home/svcorap/reports"
```
  -i "localhost," -c local \
  -e "report_output_dir=/home/svcorap/reports"
```

---

## Variables

All variables have defaults in `roles/oracle_options_audit/defaults/main.yml`.  
**All repository variables can be overridden** via `-e` parameters to connect to any Oracle database.

### Repository connection variables

| Variable | Default | Description |
|----------|---------|-------------|
| `repo_tns_alias` | *(empty)* | **Recommended:** TNS alias (e.g. `d1hub`) — takes precedence over host/port/sid |
| `repo_host` | `crlnxd1046` | Central repo DB hostname (used if `repo_tns_alias` not set) |
| `repo_port` | `1535` | Listener port |
| `repo_sid` | `d1hub` | SID of the central repo |
| `repo_user` | `DBAORALIC_SCH` | DB user for INSERT — **override for custom database** |
| `repo_password` | `PP1_mQo84M8G` | DB password — **override for custom database** |
| `repo_schema` | `DBAORALIC_SCH` | Schema owner (defaults to `repo_user`) |

**Example: Connect to custom repository**
```bash
-e "repo_tns_alias=MYDB repo_user=AUDITUSER repo_password='MyP@ss' repo_schema=AUDITUSER"
```

### Other variables

| Variable | Default | Description |
|----------|---------|-------------|
| `run_label` | `ansible-<timestamp>` | Free-text tag stored in `ORACLE_OPT_RUNS` |
| `oracle_user` | *(auto-detected)* | Override OS user for `become` if auto-detection fails |
| `db_sid` | *(auto-detected)* | Override to audit a single SID only on multi-instance hosts |
| `log_dir` | `logs/oracle_options_audit/<date>` | Local folder on controller for temp SQL files |

### Detail collection flags

| Variable | Default | Table populated | Description |
|----------|---------|-----------------|-------------|
| `collect_partitioning` | `true` | `ORACLE_OPT_D_PART` | Partitioned objects list |
| `collect_compression` | `true` | `ORACLE_OPT_D_COMPRESS` | Advanced Compression objects |
| `collect_security` | `true` | `ORACLE_OPT_D_SECURITY` | TDE encrypted TS + columns |
| `collect_inmemory` | `true` | `ORACLE_OPT_D_INMEM` | In-Memory objects (12c+ only) |
| `collect_pdbs` | `true` | `ORACLE_OPT_D_PDB` | PDB list (12c+ only) |
| `collect_adg` | `true` | `ORACLE_OPT_D_ADG` | ADG primary-side info |
| `collect_rac` | `true` | `ORACLE_OPT_D_RAC` | RAC node list |

### Report variables

| Variable | Default | Description |
|----------|---------|-------------|
| `report_run_id` | *(latest)* | Set to a specific RUN_ID to report on a past run |
| `list_runs_only` | `false` | Print all run IDs and exit without generating a report |
| `send_summary_email` | `true` | Send HTML report by email |
| `email_skip_empty_sections` | `false` | Hide sections with no rows |
| `report_output_dir` | `/tmp` | Directory where the HTML file is saved |
| `email_to` | `Mohsen.Taheri@transamerica.com` | Recipient(s) -- comma-separated |
| `email_from` | `crlnxp1086@transamerica.com` | Sender address |
| `smtp_host` | `mail1.us.aegon.com` | Internal SMTP relay |
| `smtp_port` | `25` | SMTP port |

---

## Risk Classification

| Badge | Meaning | Action |
|-------|---------|--------|
| `!! RISK` | `v$option=TRUE` AND feature usage detected | License exposure -- review immediately |
| `~~ CHK` | Feature usage detected but `v$option=FALSE` | Anomaly -- verify with Oracle LMS |
| `--` | Enabled only, no usage detected | No license concern |

**Enabled-only is NOT a risk.** Oracle EE installs every option as enabled in `v$option` by default.
Only actual feature *usage* (detected via `dba_feature_usage_statistics`) creates license exposure.

### Active Data Guard (standby-side detection)

ADG `IS_INUSE=Y` is set when the standby instance reports:
- `DB_ROLE = PHYSICAL STANDBY`
- `OPEN_MODE` contains `READ ONLY`  (the standby is open for queries = ADG mode)

A standby that is only receiving redo (mount mode, `OPEN_MODE=MOUNTED`) is **not** flagged as ADG in-use.

---

## Oracle Version Compatibility

| Version | v$option | dba_feature_usage_statistics | Patch info | In-Memory / PDB detail |
|---------|----------|------------------------------|------------|------------------------|
| 11g | YES | YES (`LAST_SAMPLE_DATE` only) | No | No |
| 12c / 12.2 | YES | YES | YES | YES |
| 19c | YES | YES | YES | YES |
| 21c | YES | YES | YES | YES |

---

## EE Extra-Cost Options Tracked

| Option | License Group | Evidence Table |
|--------|--------------|----------------|
| Real Application Clusters | HA & Scalability | `ORACLE_OPT_D_RAC` |
| Active Data Guard | HA & Scalability | `ORACLE_OPT_D_ADG` |
| GoldenGate | HA & Scalability | -- |
| Multitenant | Multitenant | `ORACLE_OPT_D_PDB` |
| Partitioning | Partitioning | `ORACLE_OPT_D_PART` |
| Advanced Compression | Compression | `ORACLE_OPT_D_COMPRESS` |
| Advanced Security Option (TDE) | Security | `ORACLE_OPT_D_SECURITY` |
| Label Security | Security | -- |
| Database Vault | Security | -- |
| In-Memory Column Store | In-Memory & Analytics | `ORACLE_OPT_D_INMEM` |
| OLAP | In-Memory & Analytics | -- |
| Oracle Data Mining | In-Memory & Analytics | -- |
| Oracle Advanced Analytics | In-Memory & Analytics | -- |
| Spatial / Spatial and Graph | In-Memory & Analytics | -- |
| Real Application Testing | Testing & Quality | -- |
| Diagnostics Pack | Management Packs (OEM) | -- |
| Tuning Pack | Management Packs (OEM) | -- |
| Database Lifecycle Management Pack | Management Packs (OEM) | -- |
| Data Masking and Subsetting Pack | Management Packs (OEM) | -- |
| Configuration Management Pack | Management Packs (OEM) | -- |
| Change Management Pack | Management Packs (OEM) | -- |
| Provisioning and Patch Automation Pack | Management Packs (OEM) | -- |

---

## Querying Results Directly on dbai

```sql
-- All EE-extra options enabled + in-use in the latest run
SELECT hostname, sid, option_name, option_enabled, is_inuse
FROM   MTAHERI.ORACLE_OPT_VOPTION v
JOIN   MTAHERI.ORACLE_OPT_RUNS r ON r.run_id = v.run_id
WHERE  r.run_id = (SELECT MAX(run_id) FROM MTAHERI.ORACLE_OPT_RUNS)
AND    v.is_ee_extra = 'Y'
AND    v.option_enabled = 'TRUE'
AND    v.is_inuse = 'Y'
ORDER  BY option_name, hostname;

-- Partitioned objects from latest run
SELECT hostname, sid, owner, table_name, part_type, part_count, size_gb
FROM   MTAHERI.ORACLE_OPT_D_PART
WHERE  run_id = (SELECT MAX(run_id) FROM MTAHERI.ORACLE_OPT_RUNS)
ORDER  BY owner, table_name;

-- Standby instances and their ADG status
SELECT hostname, sid, db_role, open_mode, is_standby
FROM   MTAHERI.ORACLE_OPT_INSTANCES
WHERE  run_id = (SELECT MAX(run_id) FROM MTAHERI.ORACLE_OPT_RUNS)
AND    is_standby = 'Y'
ORDER  BY hostname;

-- All runs recorded
SELECT run_id, run_date, run_label, total_hosts, total_instances
FROM   MTAHERI.ORACLE_OPT_RUNS
ORDER  BY run_date DESC;

-- Trend: how many instances use Partitioning over time?
SELECT r.run_date, COUNT(*) AS instance_count
FROM   MTAHERI.ORACLE_OPT_VOPTION v
JOIN   MTAHERI.ORACLE_OPT_RUNS r ON r.run_id = v.run_id
WHERE  v.option_name = 'Partitioning'
AND    v.is_inuse = 'Y'
GROUP  BY r.run_date
ORDER  BY r.run_date;
```

---

## File Structure

```
playbooks/
  collect_oracle_options.yml        <- Entry point: collect data from all hosts
  report_audit_run.yml              <- Entry point: generate + email HTML report
  _validate_repo.yml                <- Pre-flight: validate repository schema structure
  _setup_audit_tables.yml           <- One-off: create complete schema (11 tables, 23 indexes, 11 sequences, 5 views)
  _clean_repo_data.yml              <- One-off: truncate all data, reset sequences (keep schema intact)
  _check_audit_tables.yml           <- One-off: verify table structure + row counts

roles/
  oracle_options_audit/
    defaults/
      main.yml                      <- All variables: repo, email, collection flags, option catalog
    tasks/
      main.yml                      <- Host discovery, oratab parse, region detect, SQL INSERT loop
      check_instance.yml            <- Per-SID: v$option, feature usage, all evidence queries
    README.md                       <- This file (technical reference)
    RUNBOOK.md                      <- Operational runbook: SOPs, troubleshooting, maintenance
    QUICK_REFERENCE.md              <- 1-page cheat sheet for daily use
    ARCHITECTURE.md                 <- Data flow, error detection, SQL file management

Helper scripts (local Windows controller):
  C:\temp\fix_encoding.py           <- Strip invalid UTF-8 bytes before scp
  C:\temp\scan_yaml.ps1             <- Scan all YAML files for non-ASCII bytes
  check_repo_schema.sql             <- Manual SQL script to validate repository
```

---

## Prerequisites

- `community.general` Ansible collection: `ansible-galaxy collection install community.general`
- SSH key access from `crlnxp1086` to all target Linux hosts
- AIX / TLP hosts: `ansible_ssh_pass` is already set per-group in `ansibleInventory/inv_key.yml`
- sqlplus accessible on the Ansible controller for report generation
