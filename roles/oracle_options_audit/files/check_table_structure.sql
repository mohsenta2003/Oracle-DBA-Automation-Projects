-- ============================================================================
-- Check Actual Table Structure
-- Run as DBAORALIC_SCH on d1hub to verify column names
-- ============================================================================
SET LINESIZE 250
SET PAGESIZE 1000

PROMPT ============================================================
PROMPT ORACLE_OPT_VOPTION Table Columns
PROMPT ============================================================
COLUMN column_name FORMAT A30
COLUMN data_type FORMAT A20
COLUMN nullable FORMAT A8

SELECT column_id, column_name, data_type, nullable
FROM user_tab_columns
WHERE table_name = 'ORACLE_OPT_VOPTION'
ORDER BY column_id;

PROMPT
PROMPT ============================================================
PROMPT ORACLE_OPT_INSTANCES Table Columns
PROMPT ============================================================
SELECT column_id, column_name, data_type, nullable
FROM user_tab_columns
WHERE table_name = 'ORACLE_OPT_INSTANCES'
ORDER BY column_id;

PROMPT
PROMPT ============================================================
PROMPT ORACLE_OPT_D_INMEM Table Columns
PROMPT ============================================================
SELECT column_id, column_name, data_type, nullable
FROM user_tab_columns
WHERE table_name = 'ORACLE_OPT_D_INMEM'
ORDER BY column_id;

PROMPT
PROMPT ============================================================
PROMPT ORACLE_OPT_FEATURES Table Columns
PROMPT ============================================================
SELECT column_id, column_name, data_type, nullable
FROM user_tab_columns
WHERE table_name = 'ORACLE_OPT_FEATURES'
ORDER BY column_id;

PROMPT
PROMPT ============================================================
PROMPT Test Query - Check if INST_ID exists in ORACLE_OPT_VOPTION
PROMPT ============================================================
SELECT COUNT(*) AS voption_rows, 
       COUNT(DISTINCT inst_id) AS distinct_inst_ids
FROM ORACLE_OPT_VOPTION
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS);

PROMPT
PROMPT ============================================================
PROMPT Test Query - Join INSTANCES and VOPTION
PROMPT ============================================================
SELECT i.hostname, i.sid, COUNT(v.voption_id) AS voption_count
FROM ORACLE_OPT_INSTANCES i
LEFT JOIN ORACLE_OPT_VOPTION v ON i.inst_id = v.inst_id
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY i.hostname, i.sid
ORDER BY i.hostname
FETCH FIRST 10 ROWS ONLY;

EXIT;
