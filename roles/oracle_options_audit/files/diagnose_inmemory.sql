-- ============================================================================
-- SIMPLE In-Memory Diagnostic
-- Run as DBAORALIC_SCH on d1hub
-- ============================================================================
SET LINESIZE 200
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================
PROMPT 1. Check ORACLE_OPT_D_INMEM Table Structure
PROMPT ============================================================
COLUMN column_name FORMAT A30
COLUMN data_type FORMAT A20

SELECT column_name, data_type, nullable
FROM user_tab_columns
WHERE table_name = 'ORACLE_OPT_D_INMEM'
ORDER BY column_id;

PROMPT
PROMPT ============================================================
PROMPT 2. Check ORACLE_OPT_VOPTION Table Structure
PROMPT ============================================================
SELECT column_name, data_type, nullable
FROM user_tab_columns
WHERE table_name = 'ORACLE_OPT_VOPTION'
ORDER BY column_id;

PROMPT
PROMPT ============================================================
PROMPT 3. Any In-Memory Related Options in v$option?
PROMPT ============================================================
COLUMN hostname FORMAT A20
COLUMN sid FORMAT A15
COLUMN option_name FORMAT A40
COLUMN option_enabled FORMAT A10

SELECT DISTINCT v.option_name, v.option_enabled, COUNT(*) AS instance_count
FROM ORACLE_OPT_VOPTION v
WHERE v.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(v.option_name) LIKE '%MEMORY%'
GROUP BY v.option_name, v.option_enabled
ORDER BY v.option_name;

PROMPT
PROMPT ============================================================
PROMPT 4. Sample Hosts with In-Memory Option
PROMPT ============================================================
SELECT i.hostname, i.sid, i.oracle_version, v.option_name, v.option_enabled
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_VOPTION v ON i.inst_id = v.inst_id
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(v.option_name) LIKE '%IN-MEMORY%'
  AND v.option_enabled = 'TRUE'
ORDER BY i.hostname, i.sid
FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT 5. Total Count: Instances with In-Memory Option TRUE
PROMPT ============================================================
SELECT COUNT(DISTINCT i.inst_id) AS instances_with_inmemory_option
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_VOPTION v ON i.inst_id = v.inst_id
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(v.option_name) LIKE '%IN-MEMORY%'
  AND v.option_enabled = 'TRUE';

PROMPT
PROMPT ============================================================
PROMPT 6. In-Memory Evidence Table Status
PROMPT ============================================================
SELECT 
  CASE 
    WHEN evidence_count = 0 THEN 
      '✗ ZERO rows in ORACLE_OPT_D_INMEM for run ' || TO_CHAR(run_id)
    ELSE 
      '✓ Found ' || evidence_count || ' In-Memory evidence rows'
  END AS status
FROM (
  SELECT (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS) AS run_id,
         COUNT(*) AS evidence_count
  FROM ORACLE_OPT_D_INMEM
  WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
);

PROMPT
PROMPT ============================================================
PROMPT DIAGNOSIS
PROMPT ============================================================
PROMPT If section 5 shows > 0 instances with In-Memory option TRUE
PROMPT BUT section 6 shows ZERO evidence rows, then:
PROMPT 
PROMPT   => collect_inmemory=false was used during playbook run
PROMPT   OR => Collection SQL failed on those hosts (check Ansible logs)
PROMPT 
PROMPT If section 5 shows 0 instances, then:
PROMPT   => No instances have In-Memory option enabled (normal)
PROMPT

EXIT;
