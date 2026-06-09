-- Schema Validation Script for d1hub Repository
SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK ON
COLUMN table_name FORMAT A30
COLUMN object_type FORMAT A20
COLUMN privilege FORMAT A30

PROMPT ============================================================
PROMPT Repository Connection Check
PROMPT ============================================================
SELECT 'Connected as: ' || user || ' to database: ' || 
       sys_context('USERENV','DB_NAME') AS connection_info
FROM dual;

PROMPT
PROMPT ============================================================
PROMPT Tables in DBAORALIC_SCH Schema
PROMPT ============================================================
SELECT table_name, num_rows, last_analyzed
FROM user_tables
WHERE table_name LIKE 'ORACLE_OPT%'
ORDER BY table_name;

PROMPT
PROMPT ============================================================
PROMPT All Objects in Schema (Summary)
PROMPT ============================================================
SELECT object_type, COUNT(*) AS object_count
FROM user_objects
GROUP BY object_type
ORDER BY object_type;

PROMPT
PROMPT ============================================================
PROMPT System Privileges for DBAORALIC_SCH
PROMPT ============================================================
SELECT privilege 
FROM user_sys_privs 
ORDER BY privilege;

PROMPT
PROMPT ============================================================
PROMPT Current Row Counts in ORACLE_OPT_* Tables
PROMPT ============================================================
SELECT 'ORACLE_OPT_RUNS' AS table_name, COUNT(*) AS row_count 
FROM ORACLE_OPT_RUNS
UNION ALL
SELECT 'ORACLE_OPT_INSTANCES', COUNT(*) FROM ORACLE_OPT_INSTANCES
UNION ALL
SELECT 'ORACLE_OPT_VOPTION', COUNT(*) FROM ORACLE_OPT_VOPTION
UNION ALL
SELECT 'ORACLE_OPT_FEATURES', COUNT(*) FROM ORACLE_OPT_FEATURES
UNION ALL
SELECT 'ORACLE_OPT_D_PART', COUNT(*) FROM ORACLE_OPT_D_PART
UNION ALL
SELECT 'ORACLE_OPT_D_COMPRESS', COUNT(*) FROM ORACLE_OPT_D_COMPRESS
UNION ALL
SELECT 'ORACLE_OPT_D_SECURITY', COUNT(*) FROM ORACLE_OPT_D_SECURITY
UNION ALL
SELECT 'ORACLE_OPT_D_INMEM', COUNT(*) FROM ORACLE_OPT_D_INMEM
UNION ALL
SELECT 'ORACLE_OPT_D_PDB', COUNT(*) FROM ORACLE_OPT_D_PDB
UNION ALL
SELECT 'ORACLE_OPT_D_ADG', COUNT(*) FROM ORACLE_OPT_D_ADG
UNION ALL
SELECT 'ORACLE_OPT_D_RAC', COUNT(*) FROM ORACLE_OPT_D_RAC
ORDER BY table_name;

PROMPT
PROMPT ============================================================
PROMPT Table Structure Verification
PROMPT ============================================================
SELECT 'Total ORACLE_OPT tables: ' || COUNT(*) AS status
FROM user_tables
WHERE table_name LIKE 'ORACLE_OPT%';

PROMPT
PROMPT === Checking for Required Columns ===
SELECT 'IS_EE_EXTRA column exists in ORACLE_OPT_VOPTION: ' ||
       CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END AS status
FROM user_tab_columns
WHERE table_name = 'ORACLE_OPT_VOPTION'
  AND column_name = 'IS_EE_EXTRA';

SELECT 'IS_INUSE column exists in ORACLE_OPT_VOPTION: ' ||
       CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END AS status
FROM user_tab_columns
WHERE table_name = 'ORACLE_OPT_VOPTION'
  AND column_name = 'IS_INUSE';

PROMPT
PROMPT ============================================================
PROMPT Schema Validation Summary
PROMPT ============================================================
SELECT 
  CASE 
    WHEN (SELECT COUNT(*) FROM user_tables WHERE table_name LIKE 'ORACLE_OPT%') = 11
    THEN '✓ All 11 tables exist'
    ELSE '✗ Missing tables - expected 11, found ' || 
         TO_CHAR((SELECT COUNT(*) FROM user_tables WHERE table_name LIKE 'ORACLE_OPT%'))
  END AS validation_status
FROM dual;

EXIT;
