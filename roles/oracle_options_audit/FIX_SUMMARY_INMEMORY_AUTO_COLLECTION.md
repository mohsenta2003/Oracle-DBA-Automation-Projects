# In-Memory Auto-Collection Fix - Summary

**Date:** May 12, 2026  
**Issue:** In-Memory evidence missing despite IS_INUSE=Y flag in audit results  
**Status:** ✅ **RESOLVED**

---

## 🎯 What Was Fixed

The `oracle_options_audit` role has been enhanced to **automatically detect and collect In-Memory evidence** when Oracle Database In-Memory features are actively being used, even if the user sets `collect_inmemory=false`.

### Why This Matters

**License Compliance:** Oracle licenses In-Memory Column Store separately. If the audit shows `IS_INUSE=Y` but has no supporting evidence (which tables/segments are using In-Memory), the audit is incomplete and may not hold up in a license review.

---

## 🔍 Root Cause

Oracle Database feature tracking happens in **two separate places**:

1. **`DBA_FEATURE_USAGE_STATISTICS`** - Tracks high-level feature usage (CURRENTLY_USED = TRUE/FALSE)
   - ✅ This is **ALWAYS collected** by the role for all features
   - Sets the `IS_INUSE` flag in `ORACLE_OPT_FEATURES` table

2. **Object-level evidence queries** - Finds actual objects using the feature
   - ❌ This was **ONLY collected** if `collect_inmemory=true`
   - Populates `ORACLE_OPT_D_INMEM` with specific table/segment details

**The Problem:** When `collect_inmemory=false`, the role would:
- ✅ Show In-Memory as "ENABLED" and "IN USE" in the features table
- ❌ But have **ZERO rows** in the evidence table

This created a data integrity gap where we knew In-Memory was being used but had no proof.

---

## ✅ Solution Implemented

### Files Modified

| File | Changes |
|------|---------|
| `roles/oracle_options_audit/tasks/check_instance.yml` | Added auto-detection logic (lines 435-470), tracking facts (lines 615-630), summary reporting |
| `roles/oracle_options_audit/tasks/main.yml` | Added auto-collection counter and warning display in summary report |

### Key Logic Changes

#### 1. **Auto-Detection** (check_instance.yml:435)

After collecting feature usage stats, the role now checks:

```yaml
- name: "{{ current_sid }} - Check if In-Memory is in use"
  ansible.builtin.set_fact:
    _cur_inmemory_in_use: >-
      {{
        _inst_features.stdout | default('') | 
        regex_search('In-Memory.*\\|.*\\|.*\\|TRUE', ignorecase=True) is not none
      }}
```

This parses the feature usage output looking for any In-Memory feature with `CURRENTLY_USED=TRUE`.

#### 2. **Warning Display** (check_instance.yml:447)

If usage is detected but `collect_inmemory=false`:

```
⚠️  WARNING: In-Memory feature shows CURRENTLY_USED=TRUE but collect_inmemory=false
Host: crlnxm145 | SID: aahd
Evidence will be collected AUTOMATICALLY to ensure license audit compliance.
```

#### 3. **Modified Collection Logic** (check_instance.yml:460)

Old condition:
```yaml
when: collect_inmemory | default(true) | bool
```

New condition:
```yaml
when: >-
  not (_cur_is_standby | bool) and (_cur_is_12c_plus | bool) and
  ((collect_inmemory | default(true) | bool) or (_cur_inmemory_in_use | default(false) | bool))
```

**Translation:** Collect In-Memory evidence if:
- Instance is 12c+ and not a standby, **AND**
- (`collect_inmemory=true` **OR** In-Memory is actively being used)

#### 4. **Tracking** (check_instance.yml:617-630)

The role now tracks which instances had evidence auto-collected:

```yaml
_cur_inmem_autocollected: >-
  {{
    (_cur_inmemory_in_use | default(false) | bool) and
    not (collect_inmemory | default(true) | bool) and
    (_cur_inmem_rows | default([]) | length > 0)
  }}
```

#### 5. **Summary Report** (main.yml:777-793)

At the end of the audit run, if any instances had auto-collection triggered:

```
==================================================================================
⚠️  IN-MEMORY AUTO-COLLECTION TRIGGERED
==================================================================================
2 instance(s) had In-Memory feature IS_INUSE=Y
Evidence was AUTO-COLLECTED even though collect_inmemory=false
This ensures license audit compliance when In-Memory is actively being used.
==================================================================================
```

---

## 📊 Testing & Validation

### Affected Instances (From Run ID 6)

| Host | SID | Status |
|------|-----|--------|
| crlnxm145 | aahd | In-Memory CURRENTLY_USED=TRUE |
| crlnxt222 | aahsb | In-Memory CURRENTLY_USED=TRUE |

### Validation Steps

1. ✅ **Code Review:** Auto-detection logic added to `check_instance.yml`
2. ✅ **Tracking:** Instance results now include `inmem_autocollected` flag
3. ✅ **Reporting:** Summary displays auto-collection count
4. ⏳ **Real-World Test:** Needs to be run with `collect_inmemory=false` to verify auto-collection

### Recommended Test Command

```bash
# Test on the two affected hosts
ansible-playbook playbooks/collect_oracle_options.yml \
  -i ansibleInventory/inv_key.yml \
  -l "crlnxm145,crlnxt222" \
  -e "run_label=Test-AutoCollection" \
  -e "collect_inmemory=false" \
  -e "repo_tns_alias=d1hub"
```

**Expected Outcome:**
- ⚠️ Warning message during collection for aahd and aahsb
- ✅ In-Memory evidence still collected for both instances
- 📊 Summary shows "2 instance(s) had In-Memory feature IS_INUSE=Y"

### Validation Query

After the test run, verify evidence was collected:

```sql
-- Check latest run for the test hosts
SELECT r.run_label,
       i.hostname || ':' || i.port || ':' || i.sid AS instance_name,
       v.option_name,
       v.is_inuse,
       (SELECT COUNT(*) 
        FROM DBAORALIC_SCH.ORACLE_OPT_D_INMEM d 
        WHERE d.inst_id = i.inst_id) AS evidence_rows
FROM DBAORALIC_SCH.ORACLE_OPT_RUNS r
JOIN DBAORALIC_SCH.ORACLE_OPT_INSTANCES i ON r.run_id = i.run_id
JOIN DBAORALIC_SCH.ORACLE_OPT_VOPTION v ON i.inst_id = v.inst_id
WHERE r.run_label = 'Test-AutoCollection'
  AND v.option_name = 'In-Memory Column Store'
ORDER BY i.hostname, i.sid;
```

**Expected Result:**
| run_label | instance_name | option_name | is_inuse | evidence_rows |
|-----------|---------------|-------------|----------|---------------|
| Test-AutoCollection | crlnxm145:1535:aahd | In-Memory Column Store | Y | > 0 |
| Test-AutoCollection | crlnxt222:1535:aahsb | In-Memory Column Store | Y | > 0 |

---

## 📁 Files Organized

All diagnostic and documentation files have been moved to the role directory:

```
roles/oracle_options_audit/
├── INMEMORY_EVIDENCE_ISSUE.md              # Root cause analysis
├── FIX_SUMMARY_INMEMORY_AUTO_COLLECTION.md # This file
├── files/
│   ├── check_audit_completion.sql          # Overall audit verification
│   ├── check_inmemory_evidence.sql         # In-Memory specific checks
│   ├── diagnose_inmemory.sql               # Quick diagnostic
│   ├── check_what_was_collected.sql        # Evidence type verification
│   └── check_inmemory_on_host.sql          # Run directly on Oracle hosts
└── tasks/
    ├── main.yml                             # ✅ MODIFIED
    └── check_instance.yml                   # ✅ MODIFIED
```

---

## 🚀 Next Steps

1. **Test the Fix:**
   ```bash
   ansible-playbook playbooks/collect_oracle_options.yml \
     -i ansibleInventory/inv_key.yml \
     -l "crlnxm145,crlnxt222" \
     -e "run_label=Test-AutoCollection" \
     -e "collect_inmemory=false" \
     -e "repo_tns_alias=d1hub"
   ```

2. **Verify Evidence:**
   - Check warning messages in playbook output
   - Query `ORACLE_OPT_D_INMEM` for new run
   - Confirm auto-collection summary appears

3. **Full Re-Collection (Optional):**
   If you want to backfill Run ID 6 evidence:
   ```bash
   ansible-playbook playbooks/collect_oracle_options.yml \
     -i ansibleInventory/inv_key.yml \
     -l "us_lnx_prod,us_lnx_nonprod" \
     -e "run_label=US-Linux-May2026-COMPLETE" \
     -e "repo_tns_alias=d1hub"
   ```

---

## 📚 Documentation Updated

- ✅ `INMEMORY_EVIDENCE_ISSUE.md` - Added "ISSUE RESOLVED" header and fix details
- ✅ Code comments in `check_instance.yml` - Explain auto-detection logic
- ✅ Console output - `[AUTO-COLLECTED]` tag in per-instance summary
- ✅ Summary report - Shows count of auto-collected instances

---

## 🎓 Lessons Learned

1. **Feature Usage ≠ Evidence:** Oracle tracks usage separately from actual object details
2. **Trust But Verify:** IS_INUSE=Y should ALWAYS have supporting evidence
3. **User Flags as Hints:** Collection flags should be guidance, not hard rules when compliance is at stake
4. **Transparent Automation:** Auto-collection is fine if clearly reported to users

---

## 🔗 Related Files

- [INMEMORY_EVIDENCE_ISSUE.md](INMEMORY_EVIDENCE_ISSUE.md) - Full root cause analysis
- [check_instance.yml](tasks/check_instance.yml) - Implementation details
- [main.yml](tasks/main.yml) - Summary reporting logic
- [files/check_inmemory_evidence.sql](files/check_inmemory_evidence.sql) - Diagnostic queries

---

**End of Summary**
