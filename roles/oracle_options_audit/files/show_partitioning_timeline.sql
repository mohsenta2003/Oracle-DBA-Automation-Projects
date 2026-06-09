-- ============================================================================
-- Show Partitioning COMPLETE TIMELINE - All Historical Evidence Across All Runs
-- Run as DBAORALIC_SCH on d1hub (repository database)
-- This shows WHAT objects had Partitioning configured, WHEN (across all collection runs)
-- ============================================================================
SET LINESIZE 250
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================================
PROMPT Part 1: Partitioning HISTORICAL FOOTPRINT (When Feature Was Used)
PROMPT ============================================================================
COLUMN hostname FORMAT A20
COLUMN sid FORMAT A10
COLUMN feature_name FORMAT A50
COLUMN first_usage FORMAT A20
COLUMN last_usage FORMAT A20
COLUMN detected FORMAT 999999
COLUMN currently FORMAT A10
COLUMN evidence_rows FORMAT 99999
COLUMN status FORMAT A35

SELECT 
    f.hostname,
    f.sid,
    f.feature_name,
    TO_CHAR(f.first_usage_date, 'YYYY-MM-DD HH24:MI') AS first_usage,
    TO_CHAR(f.last_usage_date, 'YYYY-MM-DD HH24:MI') AS last_usage,
    f.detected_usages AS detected,
    f.currently_used AS currently,
    COUNT(p.detail_id) AS evidence_rows,
    CASE 
        WHEN COUNT(p.detail_id) > 0 THEN 'ACTIVE - Has Evidence'
        WHEN f.currently_used = 'TRUE' THEN 'HISTORICAL - Used Recently'
        WHEN f.detected_usages > 0 THEN 'HISTORICAL - Used in Past'
        ELSE 'Not Used'
    END AS status
FROM ORACLE_OPT_FEATURES f
LEFT JOIN ORACLE_OPT_D_PART p 
    ON f.hostname = p.hostname 
    AND f.sid = p.sid
    AND f.run_id = p.run_id
WHERE f.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(f.feature_name) LIKE '%PARTITION%'
  AND (f.detected_usages > 0 OR f.currently_used = 'TRUE')
GROUP BY f.hostname, f.sid, f.feature_name, 
         f.first_usage_date, f.last_usage_date,
         f.detected_usages, f.currently_used
ORDER BY f.hostname, f.sid, f.feature_name;

PROMPT
PROMPT ============================================================================
PROMPT Part 2A: CURRENT Partitioned Objects (Most Recent Run)
PROMPT ============================================================================
COLUMN owner FORMAT A20
COLUMN table_name FORMAT A30
COLUMN partition_count FORMAT 999,999
COLUMN partitioning_type FORMAT A20
COLUMN size_gb FORMAT 999,999.99

SELECT 
    p.hostname,
    p.sid,
    p.owner,
    p.table_name,
    p.partition_count,
    p.partitioning_type,
    p.size_gb
FROM ORACLE_OPT_D_PART p
WHERE p.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
ORDER BY p.hostname, p.sid, p.size_gb DESC NULLS LAST, p.owner, p.table_name;

PROMPT
PROMPT ============================================================================
PROMPT Part 2B: HISTORICAL Partitioning Evidence Timeline (All Runs)
PROMPT ============================================================================
PROMPT Shows WHAT objects had Partitioning WHEN (complete audit trail)
PROMPT ============================================================================
COLUMN run_date FORMAT A19
COLUMN days_ago FORMAT 999,999

SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_timestamp) AS days_ago,
    p.hostname,
    p.sid,
    p.owner,
    p.table_name,
    p.partition_count,
    p.partitioning_type,
    p.size_gb
FROM ORACLE_OPT_D_PART p
JOIN ORACLE_OPT_RUNS r ON p.run_id = r.run_id
ORDER BY r.run_timestamp DESC, p.hostname, p.sid, p.size_gb DESC NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT Part 2C: Object Appearance History Summary
PROMPT ============================================================================
COLUMN first_seen FORMAT A19
COLUMN last_seen FORMAT A19
COLUMN times_seen FORMAT 99,999
COLUMN days_since FORMAT 999,999
COLUMN avg_partitions FORMAT 999,999

SELECT 
    p.hostname,
    p.sid,
    p.owner,
    p.table_name,
    TO_CHAR(MIN(r.run_timestamp), 'YYYY-MM-DD HH24:MI') AS first_seen,
    TO_CHAR(MAX(r.run_timestamp), 'YYYY-MM-DD HH24:MI') AS last_seen,
    COUNT(DISTINCT p.run_id) AS times_seen,
    ROUND(SYSDATE - MAX(r.run_timestamp)) AS days_since,
    ROUND(AVG(p.partition_count)) AS avg_partitions,
    MAX(p.size_gb) AS max_size_gb
FROM ORACLE_OPT_D_PART p
JOIN ORACLE_OPT_RUNS r ON p.run_id = r.run_id
GROUP BY p.hostname, p.sid, p.owner, p.table_name
ORDER BY MAX(r.run_timestamp) DESC, p.hostname, p.sid, MAX(p.size_gb) DESC NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT Part 3: Summary by Run
PROMPT ============================================================================
COLUMN object_count FORMAT 999,999
COLUMN total_partitions FORMAT 9,999,999
COLUMN total_size_gb FORMAT 9,999,999.99

SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_timestamp) AS days_ago,
    p.hostname,
    p.sid,
    COUNT(*) AS object_count,
    SUM(p.partition_count) AS total_partitions,
    SUM(p.size_gb) AS total_size_gb
FROM ORACLE_OPT_D_PART p
JOIN ORACLE_OPT_RUNS r ON p.run_id = r.run_id
GROUP BY r.run_timestamp, p.hostname, p.sid
ORDER BY r.run_timestamp DESC, p.hostname, p.sid;

PROMPT
PROMPT ============================================================================
PROMPT KEY INTERPRETATION:
PROMPT ============================================================================
PROMPT - FIRST_SEEN:  First collection run where object appeared as partitioned
PROMPT - LAST_SEEN:   Last collection run where object appeared as partitioned
PROMPT - TIMES_SEEN:  Number of runs where object was present
PROMPT - DAYS_SINCE:  Days since object was last seen as partitioned
PROMPT
PROMPT If object disappeared (LAST_SEEN old) = dropped or de-partitioned
PROMPT If TIMES_SEEN = 1 = possibly test/temporary usage
PROMPT This provides complete audit trail of partitioning usage!
PROMPT ============================================================================
