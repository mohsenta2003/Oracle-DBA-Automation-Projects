-- ============================================================================
-- In-Memory Evidence Investigation Script
-- Run as DBAORALIC_SCH on d1hub
-- ============================================================================
SET LINESIZE 250
SET PAGESIZE 1000
SET FEEDBACK ON
SET VERIFY OFF

PROMPT ============================================================
PROMPT 1. Latest Run Information
PROMPT ============================================================
COLUMN run_id FORMAT 999999
COLUMN run_label FORMAT A40
COLUMN run_date FORMAT A20
COLUMN host_count FORMAT 999999

SELECT run_id, run_label, 
       TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI:SS') AS run_date,
       total_hosts AS host_count
FROM ORACLE_OPT_RUNS
ORDER BY run_id DESC
FETCH FIRST 5 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT 2. In-Memory Option Status from v$option (Latest Run)
PROMPT ============================================================
COLUMN hostname FORMAT A20
COLUMN sid FORMAT A15
COLUMN option_name FORMAT A40
COLUMN option_enabled FORMAT A10
COLUMN is_ee_extra FORMAT A8
COLUMN is_inuse FORMAT A8

SELECT v.hostname, v.sid, v.option_name, v.option_enabled, v.is_ee_extra, v.is_inuse
FROM ORACLE_OPT_VOPTION v
WHERE v.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(v.option_name) LIKE '%MEMORY%'
ORDER BY v.hostname, v.sid;

PROMPT
PROMPT ============================================================
PROMPT 3. In-Memory Objects Count per Host (ORACLE_OPT_D_INMEM)
PROMPT ============================================================
COLUMN inmem_count FORMAT 999999

SELECT i.hostname, i.sid, i.db_role, 
       i.oracle_version,
       COUNT(m.detail_id) AS inmem_count
FROM ORACLE_OPT_INSTANCES i
LEFT JOIN ORACLE_OPT_D_INMEM m ON i.inst_id = m.inst_id
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY i.hostname, i.sid, i.db_role, i.oracle_version
HAVING COUNT(m.detail_id) > 0 OR 
       EXISTS (SELECT 1 FROM ORACLE_OPT_VOPTION v 
               WHERE v.inst_id = i.inst_id 
               AND UPPER(v.option_name) LIKE '%IN-MEMORY%' 
               AND v.option_enabled = 'TRUE')
ORDER BY inmem_count DESC, i.hostname;

PROMPT
PROMPT ============================================================
PROMPT 4. Detailed In-Memory Evidence (Latest Run)
PROMPT ============================================================
COLUMN owner FORMAT A25
COLUMN table_name FORMAT A35
COLUMN inmemory FORMAT A10
COLUMN priority FORMAT A15
COLUMN compression FORMAT A20
COLUMN size_gb FORMAT 999999.99

SELECT i.hostname, i.sid, 
       m.owner, m.table_name, 
       m.inmemory, m.priority, m.compression,
       m.size_gb
FROM ORACLE_OPT_D_INMEM m
JOIN ORACLE_OPT_INSTANCES i ON m.inst_id = i.inst_id
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
ORDER BY i.hostname, i.sid, m.owner, m.table_name;

PROMPT
PROMPT ============================================================
PROMPT 5. Hosts with In-Memory Option TRUE but NO Evidence
PROMPT ============================================================
SELECT DISTINCT i.hostname, i.sid, i.db_role, i.oracle_version,
       v.option_name, v.option_enabled
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_VOPTION v ON i.inst_id = v.inst_id
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(v.option_name) LIKE '%IN-MEMORY%'
  AND v.option_enabled = 'TRUE'
  AND NOT EXISTS (
    SELECT 1 FROM ORACLE_OPT_D_INMEM m
    WHERE m.inst_id = i.inst_id
  )
ORDER BY i.hostname, i.sid;

PROMPT
PROMPT ============================================================
PROMPT 6. All Instances from Latest Run (12c+ only)
PROMPT ============================================================
COLUMN oracle_version FORMAT A15
COLUMN db_role FORMAT A18
COLUMN is_standby FORMAT A4

SELECT i.hostname, i.sid, i.oracle_version, i.db_role, i.is_standby,
       (SELECT COUNT(*) FROM ORACLE_OPT_D_INMEM m WHERE m.inst_id = i.inst_id) AS inmem_rows
FROM ORACLE_OPT_INSTANCES i
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND TO_NUMBER(REGEXP_SUBSTR(i.oracle_version, '^[0-9]+')) >= 12
ORDER BY i.hostname, i.sid;

PROMPT
PROMPT ============================================================
PROMPT 7. Check if collect_inmemory Was Enabled (Indirect Check)
PROMPT ============================================================
PROMPT Note: If ORACLE_OPT_D_INMEM has NO rows at all, collection may be disabled
PROMPT

SELECT CASE 
         WHEN evidence_count > 0 THEN '✓ In-Memory collection WAS run (found ' || evidence_count || ' evidence rows)'
         ELSE '✗ No In-Memory evidence found - may indicate collect_inmemory=false'
       END AS collection_status
FROM (
  SELECT COUNT(*) AS evidence_count
  FROM ORACLE_OPT_D_INMEM
  WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
);

PROMPT
PROMPT ============================================================
PROMPT 8. Table Row Count Summary (Latest Run)
PROMPT ============================================================
COLUMN table_name FORMAT A30
COLUMN row_count FORMAT 999999
COLUMN distinct_instances FORMAT 999999

SELECT 'ORACLE_OPT_D_INMEM' AS table_name, 
       COUNT(*) AS row_count,
       COUNT(DISTINCT inst_id) AS distinct_instances
FROM ORACLE_OPT_D_INMEM
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
UNION ALL
SELECT 'ORACLE_OPT_INSTANCES', COUNT(*), COUNT(DISTINCT inst_id)
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
UNION ALL
SELECT 'ORACLE_OPT_VOPTION', COUNT(*), COUNT(DISTINCT inst_id)
FROM ORACLE_OPT_VOPTION
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS);

EXIT;
