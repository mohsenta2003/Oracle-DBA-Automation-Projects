-- ============================================================================
-- Audit Completion Verification Script
-- Run as DBAORALIC_SCH on d1hub
-- ============================================================================
SET LINESIZE 200
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================
PROMPT 1. Latest 5 Audit Runs
PROMPT ============================================================
COLUMN run_id FORMAT 999999
COLUMN run_label FORMAT A45
COLUMN run_date FORMAT A20
COLUMN total_hosts FORMAT 999999
COLUMN total_instances FORMAT 999999

SELECT run_id, run_label, 
       TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI:SS') AS run_date,
       total_hosts, total_instances
FROM ORACLE_OPT_RUNS
ORDER BY run_id DESC
FETCH FIRST 5 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT 2. Latest Run - Data Completeness Check
PROMPT ============================================================
COLUMN metric FORMAT A35
COLUMN count_value FORMAT 999999999

WITH latest AS (
  SELECT MAX(run_id) AS run_id FROM ORACLE_OPT_RUNS
)
SELECT 'Run ID' AS metric, TO_CHAR(run_id) AS count_value 
FROM latest
UNION ALL
SELECT 'Total Instances', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'v$option Rows', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_VOPTION
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'Feature Usage Rows', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_FEATURES
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'Partitioning Evidence', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_D_PART
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'Compression Evidence', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_D_COMPRESS
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'Security/TDE Evidence', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_D_SECURITY
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'In-Memory Evidence', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_D_INMEM
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'PDB Evidence', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_D_PDB
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'ADG Evidence', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_D_ADG
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'RAC Evidence', TO_CHAR(COUNT(*))
FROM ORACLE_OPT_D_RAC
WHERE run_id = (SELECT run_id FROM latest);

PROMPT
PROMPT ============================================================
PROMPT 3. Instance Distribution (Latest Run)
PROMPT ============================================================
COLUMN db_role FORMAT A20
COLUMN instance_count FORMAT 999999

SELECT db_role, COUNT(*) AS instance_count
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY db_role
ORDER BY instance_count DESC;

PROMPT
PROMPT ============================================================
PROMPT 4. Version Distribution (Latest Run)
PROMPT ============================================================
COLUMN oracle_version FORMAT A15

SELECT oracle_version, COUNT(*) AS instance_count
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY oracle_version
ORDER BY oracle_version DESC;

PROMPT
PROMPT ============================================================
PROMPT 5. Expected vs Actual Rows per Instance (Sample Check)
PROMPT ============================================================
COLUMN hostname FORMAT A20
COLUMN sid FORMAT A12
COLUMN voption_rows FORMAT 999999
COLUMN expected FORMAT A20

SELECT i.hostname, i.sid, i.oracle_version,
       COUNT(v.voption_id) AS voption_rows
FROM ORACLE_OPT_INSTANCES i
LEFT JOIN ORACLE_OPT_VOPTION v ON i.inst_id = v.inst_id
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY i.hostname, i.sid, i.oracle_version
ORDER BY voption_rows ASC, i.hostname
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT 6. Any Missing Data? (Instances without v$option rows)
PROMPT ============================================================
SELECT i.hostname, i.sid, i.db_role, i.oracle_version
FROM ORACLE_OPT_INSTANCES i
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND NOT EXISTS (
    SELECT 1 FROM ORACLE_OPT_VOPTION v WHERE v.inst_id = i.inst_id
  )
ORDER BY i.hostname;

PROMPT
PROMPT ============================================================
PROMPT SUMMARY
PROMPT ============================================================
PROMPT If section 6 shows any rows, those instances have MISSING data.
PROMPT If section 2 shows 0 for In-Memory Evidence, check if:
PROMPT   - collect_inmemory was set to false, OR
PROMPT   - No instances actually have INMEMORY='ENABLED' tables
PROMPT

EXIT;
