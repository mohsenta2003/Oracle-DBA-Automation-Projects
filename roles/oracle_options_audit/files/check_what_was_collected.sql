-- ============================================================================
-- Check What Was Actually Collected in Latest Run
-- Run as DBAORALIC_SCH on d1hub
-- ============================================================================
SET LINESIZE 200
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================
PROMPT Latest Run Details
PROMPT ============================================================
COLUMN run_id FORMAT 999999
COLUMN run_label FORMAT A45
COLUMN run_date FORMAT A20
COLUMN total_hosts FORMAT 99999
COLUMN total_instances FORMAT 99999

SELECT run_id, run_label, 
       TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI:SS') AS run_date,
       total_hosts, total_instances,
       ansible_user, ansible_host
FROM ORACLE_OPT_RUNS
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS);

PROMPT
PROMPT ============================================================
PROMPT Evidence Tables - Row Counts for Latest Run
PROMPT ============================================================
WITH latest AS (SELECT MAX(run_id) AS run_id FROM ORACLE_OPT_RUNS)
SELECT 'Partitioning (D_PART)' AS evidence_type,
       COUNT(*) AS row_count,
       COUNT(DISTINCT inst_id) AS instance_count,
       CASE WHEN COUNT(*) > 0 THEN '✓ Collected' ELSE '✗ Not collected' END AS status
FROM ORACLE_OPT_D_PART
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'Compression (D_COMPRESS)',
       COUNT(*), COUNT(DISTINCT inst_id),
       CASE WHEN COUNT(*) > 0 THEN '✓ Collected' ELSE '✗ Not collected' END
FROM ORACLE_OPT_D_COMPRESS
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'Security/TDE (D_SECURITY)',
       COUNT(*), COUNT(DISTINCT inst_id),
       CASE WHEN COUNT(*) > 0 THEN '✓ Collected' ELSE '✗ Not collected' END
FROM ORACLE_OPT_D_SECURITY
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'In-Memory (D_INMEM)',
       COUNT(*), COUNT(DISTINCT inst_id),
       CASE WHEN COUNT(*) > 0 THEN '✓ Collected' ELSE '✗ Not collected' END
FROM ORACLE_OPT_D_INMEM
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'PDbs (D_PDB)',
       COUNT(*), COUNT(DISTINCT inst_id),
       CASE WHEN COUNT(*) > 0 THEN '✓ Collected' ELSE '✗ Not collected' END
FROM ORACLE_OPT_D_PDB
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'Active Data Guard (D_ADG)',
       COUNT(*), COUNT(DISTINCT inst_id),
       CASE WHEN COUNT(*) > 0 THEN '✓ Collected' ELSE '✗ Not collected' END
FROM ORACLE_OPT_D_ADG
WHERE run_id = (SELECT run_id FROM latest)
UNION ALL
SELECT 'RAC Nodes (D_RAC)',
       COUNT(*), COUNT(DISTINCT inst_id),
       CASE WHEN COUNT(*) > 0 THEN '✓ Collected' ELSE '✗ Not collected' END
FROM ORACLE_OPT_D_RAC
WHERE run_id = (SELECT run_id FROM latest);

PROMPT
PROMPT ============================================================
PROMPT Likely Playbook Command Used
PROMPT ============================================================
PROMPT Based on the evidence collected, the playbook was likely run with:
PROMPT

SELECT 
  CASE 
    WHEN (SELECT COUNT(*) FROM ORACLE_OPT_D_PART WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
     AND (SELECT COUNT(*) FROM ORACLE_OPT_D_COMPRESS WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
     AND (SELECT COUNT(*) FROM ORACLE_OPT_D_SECURITY WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
     AND (SELECT COUNT(*) FROM ORACLE_OPT_D_INMEM WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
     AND (SELECT COUNT(*) FROM ORACLE_OPT_D_PDB WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
     AND (SELECT COUNT(*) FROM ORACLE_OPT_D_ADG WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
    THEN '  -e "collect_partitioning=false collect_compression=false collect_security=false collect_inmemory=false collect_pdbs=false collect_adg=false"'
    
    WHEN (SELECT COUNT(*) FROM ORACLE_OPT_D_COMPRESS WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
     AND (SELECT COUNT(*) FROM ORACLE_OPT_D_SECURITY WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
     AND (SELECT COUNT(*) FROM ORACLE_OPT_D_INMEM WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
     AND (SELECT COUNT(*) FROM ORACLE_OPT_D_PDB WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
     AND (SELECT COUNT(*) FROM ORACLE_OPT_D_ADG WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)) = 0
    THEN '  -e "collect_compression=false collect_security=false collect_inmemory=false collect_pdbs=false collect_adg=false"'
    
    ELSE '  (All collection flags appear to be enabled OR some instances had actual evidence)'
  END AS likely_command
FROM dual;

PROMPT
PROMPT ============================================================
PROMPT CONCLUSIONS for In-Memory
PROMPT ============================================================
PROMPT 1. Check: Did you use -e "collect_inmemory=false" in the command?
PROMPT 2. If YES → Re-run with collect_inmemory=true
PROMPT 3. If NO  → None of your instances have tables with INMEMORY='ENABLED'
PROMPT
PROMPT To verify #3, connect to a 12c+ instance and run:
PROMPT   SELECT owner, table_name, inmemory FROM dba_tables WHERE inmemory='ENABLED';
PROMPT

EXIT;
