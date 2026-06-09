# Oracle Options Historical Evidence - Quick Reference

## 📋 Overview

The oracle_options_audit role preserves **complete historical evidence** for all licensed Oracle features. Each collection run creates a new snapshot with a unique `run_id` - **old data is NEVER deleted**.

This provides a complete audit trail showing:
- **WHEN** features were used (usage dates from dba_feature_usage_statistics)
- **WHAT** specific objects had features configured (evidence tables)
- **HOW LONG** features were active (first/last appearance)
- **CHANGES OVER TIME** (objects added/removed, configuration changes)

---

## 📊 Two Types of Historical Data

### 1. Feature Usage Footprint (ORACLE_OPT_FEATURES)

**What it shows:** When Oracle detected feature usage  
**Data preserved:** FIRST_USAGE_DATE, LAST_USAGE_DATE, DETECTED_USAGES, CURRENTLY_USED  
**Lifespan:** Persists even after feature is disabled

```sql
-- Quick query: When was In-Memory used?
SELECT hostname, sid, feature_name,
       TO_CHAR(first_usage_date, 'YYYY-MM-DD') AS first_used,
       TO_CHAR(last_usage_date, 'YYYY-MM-DD') AS last_used,
       detected_usages
FROM ORACLE_OPT_FEATURES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND feature_name LIKE '%In-Memory%'
  AND detected_usages > 0;
```

### 2. Object Evidence Timeline (ORACLE_OPT_D_* tables)

**What it shows:** Which specific objects had feature configured  
**Data preserved:** Snapshots across all collection runs  
**Lifespan:** Each run_id creates permanent snapshot

```sql
-- Quick query: What objects had In-Memory across all runs?
SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD') AS run_date,
    im.hostname, im.sid, im.owner, im.table_name,
    im.inmemory, im.priority, im.compression
FROM ORACLE_OPT_D_INMEM im
JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
ORDER BY r.run_timestamp DESC;
```

---

## 🔍 Available Timeline Reports

### Comprehensive View (All Features)
```bash
sqlplus DBAORALIC_SCH/password@d1hub @roles/oracle_options_audit/files/show_all_options_timeline.sql
```
Shows unified timeline across Partitioning, Compression, In-Memory, Security/TDE, RAC, Multitenant

### Feature-Specific Views

#### In-Memory
```bash
sqlplus DBAORALIC_SCH/password@d1hub @roles/oracle_options_audit/files/show_inmemory_timeline.sql
```
- Tables/segments with INMEMORY='ENABLED'
- Actually populated segments from v$im_segments
- First/last appearance, compression types

#### Partitioning
```bash
sqlplus DBAORALIC_SCH/password@d1hub @roles/oracle_options_audit/files/show_partitioning_timeline.sql
```
- Partitioned tables across all runs
- Partition count changes over time
- Partitioning type (RANGE, LIST, HASH, etc.)

#### Compression
```bash
sqlplus DBAORALIC_SCH/password@d1hub @roles/oracle_options_audit/files/show_compression_timeline.sql
```
- Compressed objects across all runs
- Compression type changes (BASIC, OLTP, HCC)
- Compression algorithm evolution

#### Security/TDE
```bash
sqlplus DBAORALIC_SCH/password@d1hub @roles/oracle_options_audit/files/show_security_timeline.sql
```
- Encrypted tablespaces and tables
- Encryption algorithm changes
- TDE adoption timeline

---

## 💡 Common Use Cases

### Use Case 1: Prove Historical Usage for Auditing
**Scenario:** "We don't use In-Memory anymore, but Oracle claims we used it 6 months ago"

**Solution:**
```sql
-- Show when In-Memory was actually used and with what objects
SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD') AS collection_date,
    COUNT(*) AS objects_with_inmemory
FROM ORACLE_OPT_D_INMEM im
JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
WHERE im.hostname = 'yourhost'
GROUP BY r.run_timestamp
ORDER BY r.run_timestamp DESC;
```

**Result:** Shows exact dates when objects had In-Memory, proving usage timeframe

---

### Use Case 2: Track Feature Adoption/Removal
**Scenario:** "When did we start using Compression? When did we stop?"

**Solution:** Run show_compression_timeline.sql Part 2C (Object Appearance History Summary)

**Result:** 
- FIRST_SEEN: When Compression first appeared
- LAST_SEEN: When Compression last appeared
- TIMES_SEEN: How consistently it was used
- DAYS_SINCE: How long since last use

---

### Use Case 3: Configuration Change Tracking
**Scenario:** "What changed in our partitioned tables over the last year?"

**Solution:**
```sql
-- Compare partition counts across runs
SELECT 
    p.owner, p.table_name,
    TO_CHAR(MIN(r.run_timestamp), 'YYYY-MM-DD') AS first_seen,
    TO_CHAR(MAX(r.run_timestamp), 'YYYY-MM-DD') AS last_seen,
    MIN(p.partition_count) AS min_partitions,
    MAX(p.partition_count) AS max_partitions,
    MAX(p.partition_count) - MIN(p.partition_count) AS growth
FROM ORACLE_OPT_D_PART p
JOIN ORACLE_OPT_RUNS r ON p.run_id = r.run_id
WHERE p.hostname = 'yourhost'
  AND r.run_timestamp >= SYSDATE - 365
GROUP BY p.owner, p.table_name
HAVING MAX(p.partition_count) != MIN(p.partition_count)
ORDER BY growth DESC;
```

**Result:** Shows which tables grew partitions over time

---

### Use Case 4: Temporary vs Persistent Usage
**Scenario:** "Was In-Memory used for testing or production?"

**Solution:**
```sql
-- Check how many runs each object appeared in
SELECT 
    im.owner, im.table_name,
    COUNT(DISTINCT im.run_id) AS times_seen,
    ROUND((COUNT(DISTINCT im.run_id) * 100.0) / 
          (SELECT COUNT(*) FROM ORACLE_OPT_RUNS)) AS percent_of_runs,
    CASE 
        WHEN COUNT(DISTINCT im.run_id) = 1 THEN 'One-time (test?)'
        WHEN COUNT(DISTINCT im.run_id) < 5 THEN 'Occasional'
        WHEN COUNT(DISTINCT im.run_id) < 20 THEN 'Frequent'
        ELSE 'Consistent (production)'
    END AS usage_pattern
FROM ORACLE_OPT_D_INMEM im
WHERE im.hostname = 'yourhost'
GROUP BY im.owner, im.table_name
ORDER BY times_seen DESC;
```

**Result:** Distinguishes test vs production usage by appearance frequency

---

### Use Case 5: License Compliance Report
**Scenario:** "Show me all licensed features we've used in the last 2 years"

**Solution:** Run show_all_options_timeline.sql Part 3 (Feature Activity Summary)

**Result:** Complete matrix showing:
- Every licensed feature used
- First/last evidence date
- Number of collection runs with evidence
- Current status (ACTIVE vs HISTORICAL)

---

## 🎯 Key Concepts

### Understanding "Zero Evidence" with Usage Dates

**Situation:**
- `ORACLE_OPT_FEATURES.DETECTED_USAGES > 0` (feature was used)
- `ORACLE_OPT_D_INMEM` has 0 rows in latest run (no current objects)

**Meaning:**
- Feature was enabled historically
- No objects currently configured with feature
- This is **VALID and CORRECT**
- Historical footprint still exists in FEATURES table and old run_ids

**Example:**
```
In-Memory Column Store Feature:
- FIRST_USAGE_DATE: 2024-03-15  ← Proof it was used
- LAST_USAGE_DATE: 2024-08-22   ← Proof of last detection
- DETECTED_USAGES: 42           ← Detected 42 times
- Current evidence rows: 0      ← No objects configured now

Conclusion: Used historically (March-August 2024), now disabled
```

---

### Understanding run_id and Snapshots

Each playbook execution creates a new `run_id`:

```
RUN_ID 45 (2026-05-12): Snapshot showing 3 partitioned tables
RUN_ID 44 (2026-05-11): Snapshot showing 3 partitioned tables  
RUN_ID 43 (2026-05-10): Snapshot showing 5 partitioned tables
RUN_ID 42 (2026-05-09): Snapshot showing 5 partitioned tables
```

**Insights:**
- Between run 43 and 42: No change (5 tables both times)
- Between run 44 and 43: 2 tables dropped/de-partitioned
- Run 45 onwards: Stable at 3 tables

This timeline proves what changed and when!

---

## 📁 File Locations

All timeline queries located in:
```
roles/oracle_options_audit/files/
├── show_all_options_timeline.sql      # Comprehensive view
├── show_inmemory_timeline.sql         # In-Memory specific
├── show_partitioning_timeline.sql     # Partitioning specific
├── show_compression_timeline.sql      # Compression specific
├── show_security_timeline.sql         # Security/TDE specific
├── check_inmemory_complete.sql        # In-Memory diagnostic
└── show_inmemory_footprint.sql        # In-Memory historical dates
```

---

## 🚀 Best Practices

1. **Regular Collections:** Run playbook regularly (daily/weekly) to build historical timeline
2. **Preserve Data:** Never manually delete rows from ORACLE_OPT_D_* tables
3. **Query Patterns:** Always join with ORACLE_OPT_RUNS to get timestamps
4. **Audit Reports:** Use timeline queries for license compliance reviews
5. **Change Tracking:** Compare run_id snapshots to detect configuration changes
6. **Documentation:** Export timeline queries before major changes as proof of state

---

## 🔗 Related Documentation

- [INMEMORY_EVIDENCE_ISSUE.md](INMEMORY_EVIDENCE_ISSUE.md) - Original issue resolution
- [check_instance.yml](tasks/check_instance.yml) - Collection logic with auto-detection
- [main.yml](tasks/main.yml) - Repository insertion logic

---

**Last Updated:** May 2026  
**Maintainer:** Oracle DBA Team
