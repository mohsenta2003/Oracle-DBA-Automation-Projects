-- ============================================================================
-- Show ALL Oracle Options COMPLETE TIMELINE - Comprehensive Audit Trail
-- Run as DBAORALIC_SCH on d1hub (repository database)
-- This provides a unified view of ALL licensed features across ALL collection runs
-- ============================================================================
SET LINESIZE 250
SET PAGESIZE 5000
SET FEEDBACK ON

PROMPT ============================================================================
PROMPT COMPREHENSIVE TIMELINE: All Oracle Licensed Options
PROMPT ============================================================================
PROMPT This report shows complete audit trail for ALL licensed features
PROMPT ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT Part 1: Feature Usage Summary Across All Runs
PROMPT ============================================================================
COLUMN run_date FORMAT A19
COLUMN hostname FORMAT A20
COLUMN sid FORMAT A10
COLUMN option_name FORMAT A30
COLUMN evidence_count FORMAT 999,999
COLUMN status FORMAT A25

-- Summary of all features by run
SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_timestamp) AS days_ago,
    f.hostname,
    f.sid,
    CASE 
        WHEN UPPER(f.feature_name) LIKE '%PARTITION%' THEN 'Partitioning'
        WHEN UPPER(f.feature_name) LIKE '%COMPRESSION%' OR UPPER(f.feature_name) LIKE '%HCC%' THEN 'Compression'
        WHEN UPPER(f.feature_name) LIKE '%IN-MEMORY%' THEN 'In-Memory'
        WHEN UPPER(f.feature_name) LIKE '%ENCRYPTION%' OR UPPER(f.feature_name) LIKE '%TDE%' OR UPPER(f.feature_name) LIKE '%ADVANCED SECURITY%' THEN 'Security/TDE'
        WHEN UPPER(f.feature_name) LIKE '%RAC%' OR UPPER(f.feature_name) LIKE '%REAL APPLICATION CLUSTER%' THEN 'RAC'
        WHEN UPPER(f.feature_name) LIKE '%DATA GUARD%' OR UPPER(f.feature_name) LIKE '%ACTIVE DATA GUARD%' THEN 'Active Data Guard'
        WHEN UPPER(f.feature_name) LIKE '%MULTITENANT%' OR UPPER(f.feature_name) LIKE '%PDB%' THEN 'Multitenant'
        ELSE 'Other'
    END AS option_name,
    f.detected_usages,
    f.currently_used,
    CASE 
        WHEN f.detected_usages > 0 AND f.currently_used = 'TRUE' THEN 'ACTIVE'
        WHEN f.detected_usages > 0 THEN 'HISTORICAL'
        ELSE 'UNUSED'
    END AS status
FROM ORACLE_OPT_FEATURES f
JOIN ORACLE_OPT_RUNS r ON f.run_id = r.run_id
WHERE (f.detected_usages > 0 OR f.currently_used = 'TRUE')
ORDER BY r.run_timestamp DESC, f.hostname, f.sid, option_name;

PROMPT
PROMPT ============================================================================
PROMPT Part 2: Evidence Object Counts Per Run (All Options)
PROMPT ============================================================================
COLUMN partitioning FORMAT 999,999
COLUMN compression FORMAT 999,999
COLUMN inmemory FORMAT 999,999
COLUMN security FORMAT 999,999
COLUMN rac_nodes FORMAT 999,999
COLUMN pdbs FORMAT 999,999

-- Count evidence objects per run for each option
SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_timestamp) AS days_ago,
    COALESCE(counts.hostname, 'ALL') AS hostname,
    COALESCE(counts.sid, 'ALL') AS sid,
    SUM(counts.part_count) AS partitioning,
    SUM(counts.comp_count) AS compression,
    SUM(counts.inmem_count) AS inmemory,
    SUM(counts.sec_count) AS security,
    SUM(counts.rac_count) AS rac_nodes,
    SUM(counts.pdb_count) AS pdbs
FROM ORACLE_OPT_RUNS r
LEFT JOIN (
    SELECT run_id, hostname, sid,
           COUNT(*) AS part_count, 0 AS comp_count, 0 AS inmem_count, 
           0 AS sec_count, 0 AS rac_count, 0 AS pdb_count
    FROM ORACLE_OPT_D_PART
    GROUP BY run_id, hostname, sid
    UNION ALL
    SELECT run_id, hostname, sid,
           0, COUNT(*), 0, 0, 0, 0
    FROM ORACLE_OPT_D_COMPRESS
    GROUP BY run_id, hostname, sid
    UNION ALL
    SELECT run_id, hostname, sid,
           0, 0, COUNT(*), 0, 0, 0
    FROM ORACLE_OPT_D_INMEM
    GROUP BY run_id, hostname, sid
    UNION ALL
    SELECT run_id, hostname, sid,
           0, 0, 0, COUNT(*), 0, 0
    FROM ORACLE_OPT_D_SECURITY
    GROUP BY run_id, hostname, sid
    UNION ALL
    SELECT run_id, hostname, sid,
           0, 0, 0, 0, COUNT(*), 0
    FROM ORACLE_OPT_D_RAC
    GROUP BY run_id, hostname, sid
    UNION ALL
    SELECT run_id, hostname, sid,
           0, 0, 0, 0, 0, COUNT(*)
    FROM ORACLE_OPT_D_PDB
    GROUP BY run_id, hostname, sid
) counts ON r.run_id = counts.run_id
GROUP BY r.run_timestamp, GROUPING SETS ((counts.hostname, counts.sid), ())
ORDER BY r.run_timestamp DESC, hostname NULLS LAST, sid NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT Part 3: Feature Activity Summary (First/Last Seen)
PROMPT ============================================================================
COLUMN option_name FORMAT A30
COLUMN hostname FORMAT A20
COLUMN sid FORMAT A10
COLUMN first_evidence FORMAT A19
COLUMN last_evidence FORMAT A19
COLUMN runs_with_evidence FORMAT 999,999
COLUMN days_since_last FORMAT 999,999
COLUMN current_status FORMAT A25

SELECT 
    option_name,
    hostname,
    sid,
    TO_CHAR(first_evidence, 'YYYY-MM-DD HH24:MI') AS first_evidence,
    TO_CHAR(last_evidence, 'YYYY-MM-DD HH24:MI') AS last_evidence,
    runs_with_evidence,
    ROUND(SYSDATE - last_evidence) AS days_since_last,
    CASE 
        WHEN ROUND(SYSDATE - last_evidence) <= 7 THEN 'ACTIVE (< 7 days)'
        WHEN ROUND(SYSDATE - last_evidence) <= 30 THEN 'RECENT (< 30 days)'
        WHEN ROUND(SYSDATE - last_evidence) <= 90 THEN 'OLDER (< 90 days)'
        ELSE 'HISTORICAL (> 90 days)'
    END AS current_status
FROM (
    SELECT 'Partitioning' AS option_name, hostname, sid,
           MIN(r.run_timestamp) AS first_evidence,
           MAX(r.run_timestamp) AS last_evidence,
           COUNT(DISTINCT p.run_id) AS runs_with_evidence
    FROM ORACLE_OPT_D_PART p
    JOIN ORACLE_OPT_RUNS r ON p.run_id = r.run_id
    GROUP BY hostname, sid
    UNION ALL
    SELECT 'Compression', hostname, sid,
           MIN(r.run_timestamp), MAX(r.run_timestamp), COUNT(DISTINCT c.run_id)
    FROM ORACLE_OPT_D_COMPRESS c
    JOIN ORACLE_OPT_RUNS r ON c.run_id = r.run_id
    GROUP BY hostname, sid
    UNION ALL
    SELECT 'In-Memory', hostname, sid,
           MIN(r.run_timestamp), MAX(r.run_timestamp), COUNT(DISTINCT im.run_id)
    FROM ORACLE_OPT_D_INMEM im
    JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
    GROUP BY hostname, sid
    UNION ALL
    SELECT 'Security/TDE', hostname, sid,
           MIN(r.run_timestamp), MAX(r.run_timestamp), COUNT(DISTINCT s.run_id)
    FROM ORACLE_OPT_D_SECURITY s
    JOIN ORACLE_OPT_RUNS r ON s.run_id = r.run_id
    GROUP BY hostname, sid
    UNION ALL
    SELECT 'RAC', hostname, sid,
           MIN(r.run_timestamp), MAX(r.run_timestamp), COUNT(DISTINCT rac.run_id)
    FROM ORACLE_OPT_D_RAC rac
    JOIN ORACLE_OPT_RUNS r ON rac.run_id = r.run_id
    GROUP BY hostname, sid
    UNION ALL
    SELECT 'Multitenant', hostname, sid,
           MIN(r.run_timestamp), MAX(r.run_timestamp), COUNT(DISTINCT pdb.run_id)
    FROM ORACLE_OPT_D_PDB pdb
    JOIN ORACLE_OPT_RUNS r ON pdb.run_id = r.run_id
    GROUP BY hostname, sid
)
ORDER BY hostname, sid, option_name;

PROMPT
PROMPT ============================================================================
PROMPT SUMMARY INTERPRETATION:
PROMPT ============================================================================
PROMPT
PROMPT This report provides THREE types of historical footprints:
PROMPT
PROMPT 1. FEATURE USAGE DATES (from dba_feature_usage_statistics)
PROMPT    - FIRST_USAGE_DATE, LAST_USAGE_DATE, DETECTED_USAGES
PROMPT    - Preserved even if feature is disabled
PROMPT
PROMPT 2. EVIDENCE OBJECTS TIMELINE (from detail tables)
PROMPT    - WHAT specific objects had feature configured
PROMPT    - WHEN they appeared/disappeared
PROMPT    - Complete audit trail across all collection runs
PROMPT
PROMPT 3. ACTIVITY SUMMARY
PROMPT    - Overall feature usage patterns
PROMPT    - Current vs historical status
PROMPT    - Compliance and licensing audit trail
PROMPT
PROMPT For detailed object-level timelines, use the specific option reports:
PROMPT   - show_partitioning_timeline.sql
PROMPT   - show_compression_timeline.sql
PROMPT   - show_inmemory_timeline.sql
PROMPT   - show_security_timeline.sql
PROMPT ============================================================================
