# Oracle Options Audit - Quick Reference Card

---

## 🚀 MOST COMMON COMMANDS

### Full Audit + Email
```bash
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml -e "run_label=Full-$(date +%Y-%m-%d)"
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local
```

### Historical Timeline Report (NEW)
```bash
# All options timeline (comprehensive)
ansible-playbook playbooks/report_timeline.yml -i "localhost," -c local -e "option=all"

# Specific option timeline
ansible-playbook playbooks/report_timeline.yml -i "localhost," -c local -e "option=inmemory"
ansible-playbook playbooks/report_timeline.yml -i "localhost," -c local -e "option=partitioning"
ansible-playbook playbooks/report_timeline.yml -i "localhost," -c local -e "option=compression"
ansible-playbook playbooks/report_timeline.yml -i "localhost," -c local -e "option=security"
```

### Production Only
```bash
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml -l "us_lnx_prod,eu_nl_lnx_prod,eu_uk_lnx_prod" -e "run_label=Prod-$(date +%Y-%m-%d)"
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local
```

### Single Host Test
```bash
ansible-playbook playbooks/collect_oracle_options.yml -i ansibleInventory/inv_key.yml -l crlnxp1015 -e "run_label=Test"
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local -e "send_summary_email=false"
```

---

## 📊 HOST GROUPS

| Group | Command |
|-------|---------|
| **All US Linux** | `-l all_us_linux` |
| **All EU Linux** | `-l all_eu_linux` |
| **US Production** | `-l us_lnx_prod` |
| **EU NL Production** | `-l eu_nl_lnx_prod` |
| **EU UK Production** | `-l eu_uk_lnx_prod` |
| **AIX/TLP Prod** | `-l "tlp_aix_prod,tlp_aix_prod2"` |
| **AIX/TLP Non-Prod** | `-l "tlp_aix_nonprod,tlp_aix_nonprod2"` |

---

## ⚡ SPEED OPTIONS (Skip Detail Queries)

### Fast (v$option Only)
```bash
-e "collect_partitioning=false collect_compression=false collect_security=false collect_inmemory=false collect_pdbs=false collect_adg=false collect_rac=false"
```

### Partitioning Only
```bash
-e "collect_compression=false collect_security=false collect_inmemory=false collect_pdbs=false collect_adg=false collect_rac=false"
```

### Security Only
```bash
-e "collect_partitioning=false collect_compression=false collect_inmemory=false collect_pdbs=false collect_adg=false collect_rac=false"
```

---

## �️ REPOSITORY MANAGEMENT

```bash
# Validate repository schema
ansible-playbook playbooks/_validate_repo.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# Build complete schema (11 tables, 23 indexes, 11 sequences, 5 views)
ansible-playbook playbooks/_setup_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"

# Clean all data (truncate tables, keep schema structure)
ansible-playbook playbooks/_clean_repo_data.yml -i "localhost," -c local -e "repo_tns_alias=d1hub confirm_clean=yes"

# Check table structure
ansible-playbook playbooks/_check_audit_tables.yml -i "localhost," -c local -e "repo_tns_alias=d1hub"
```

---

## �📧 EMAIL OPTIONS

| Task | Command |
|------|---------|
| **Send email (default)** | *(no extra flags)* |
| **Skip email** | `-e "send_summary_email=false"` |
| **Different recipient** | `-e "email_to=your.email@transamerica.com"` |
| **Multiple recipients** | `-e "email_to=p1@ta.com,p2@ta.com,p3@ta.com"` |
| **Skip empty sections** | `-e "email_skip_empty_sections=true"` |
| **Custom output dir** | `-e "report_output_dir=/path/to/dir"` |

---

## 🔍 REPORT OPTIONS

```bash
# List all runs
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local -e "list_runs_only=true"

# Report from specific run ID
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local -e "report_run_id=22"

# Latest run without email
ansible-playbook playbooks/report_audit_run.yml -i "localhost," -c local -e "send_summary_email=false"
```

---

## 🛠️ OVERRIDE OPTIONS

### Oracle User
```bash
-e "oracle_user=oracle"
```

### Single SID
```bash
-e "db_sid=MYSID"
```

### Repository Connection
```bash
-e "repo_host=newhost repo_port=1521 repo_sid=newdb repo_user=user repo_password=pass"
```

---

## 🚨 QUICK TROUBLESHOOTING

| Issue | Check |
|-------|-------|
| **Host not found** | `ansible HOSTNAME -i ansibleInventory/inv_key.yml -m ping` |
| **No Oracle detected** | `ssh user@host "ps aux \| grep pmon"` |
| **DB connection fails** | `ssh oracle@host "sqlplus / as sysdba"` |
| **Repo connection fails** | `sqlplus mtaheri/PASS@crlnxp1086:1535/dbai` |
| **Email not sent** | `telnet mail1.us.aegon.com 25` |

---

## 📁 KEY FILES

| File | Purpose |
|------|---------|
| `RUNBOOK.md` | Full operational procedures (this directory) |
| `QUICK_REFERENCE.md` | This file - 1-page cheat sheet |
| `README.md` | Technical reference (this directory) |
| `../../playbooks/collect_oracle_options.yml` | Data collection playbook |
| `../../playbooks/report_audit_run.yml` | Report generation playbook |
| `../../ansibleInventory/inv_key.yml` | Host inventory |

---

## 🗄️ CENTRAL DATABASE

**Host:** crlnxp1086  
**Port:** 1535  
**SID:** dbai  
**Schema:** MTAHERI  

### Quick Queries
```sql
-- Latest run info
SELECT * FROM MTAHERI.ORACLE_OPT_RUNS ORDER BY run_date DESC FETCH FIRST 5 ROWS ONLY;

-- High-risk options
SELECT hostname, sid, option_name FROM MTAHERI.ORACLE_OPT_VOPTION v
JOIN MTAHERI.ORACLE_OPT_RUNS r ON r.run_id = v.run_id
WHERE r.run_id = (SELECT MAX(run_id) FROM MTAHERI.ORACLE_OPT_RUNS)
AND v.is_ee_extra = 'Y' AND v.option_enabled = 'TRUE' AND v.is_inuse = 'Y';

-- Instance count
SELECT COUNT(*) FROM MTAHERI.ORACLE_OPT_INSTANCES 
WHERE run_id = (SELECT MAX(run_id) FROM MTAHERI.ORACLE_OPT_RUNS);
```

---

## 📞 CONTACTS

| Issue | Contact |
|-------|---------|
| Playbook Errors | dba-automation@transamerica.com |
| Licensing Questions | licensing@transamerica.com |
| Access Issues | infra-support@transamerica.com |

---

**For detailed procedures, see [RUNBOOK.md](RUNBOOK.md)**
