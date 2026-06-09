-- ============================================================================
-- Show Compression COMPLETE TIMELINE - All Historical Evidence Across All Runs
-- Run as DBAORALIC_SCH on d1hub (repository database)
-- This shows WHAT objects had Compression configured, WHEN (across all collection runs)
-- ============================================================================
SET LINESIZE 250
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================================
PROMPT Part 1: Compression HISTORICAL FOOTPRINT (When Feature Was Used)
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
    COUNT(c.detail_id) AS evidence_rows,
    CASE 
        WHEN COUNT(c.detail_id) > 0 THEN 'ACTIVE - Has Evidence'
        WHEN f.currently_used = 'TRUE' THEN 'HISTORICAL - Used Recently'
        WHEN f.detected_usages > 0 THEN 'HISTORICAL - Used in Past'
        ELSE 'Not Used'
    END AS status
FROM ORACLE_OPT_FEATURES f
LEFT JOIN ORACLE_OPT_D_COMPRESS c 
    ON f.hostname = c.hostname 
    AND f.sid = c.sid
    AND f.run_id = c.run_id
WHERE f.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND (UPPER(f.feature_name) LIKE '%COMPRESSION%' OR UPPER(f.feature_name) LIKE '%HCC%')
  AND (f.detected_usages > 0 OR f.currently_used = 'TRUE')
GROUP BY f.hostname, f.sid, f.feature_name, 
         f.first_usage_date, f.last_usage_date,
         f.detected_usages, f.currently_used
ORDER BY f.hostname, f.sid, f.feature_name;

PROMPT
PROMPT ============================================================================
PROMPT Part 2A: CURRENT Compressed Objects (Most Recent Run)
PROMPT ============================================================================
COLUMN owner FORMAT A20
COLUMN object_name FORMAT A30
COLUMN object_type FORMAT A15
COLUMN compression_type FORMAT A25
COLUMN size_gb FORMAT 999,999.99

SELECT 
    c.hostname,
    c.sid,
    c.owner,
    c.object_name,
    c.object_type,
    c.compression,
    c.compress_for,
    c.size_gb
FROM ORACLE_OPT_D_COMPRESS c
WHERE c.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
ORDER BY c.hostname, c.sid, c.size_gb DESC NULLS LAST, c.owner, c.object_name;

PROMPT
PROMPT ============================================================================
PROMPT Part 2B: HISTORICAL Compression Evidence Timeline (All Runs)
PROMPT ============================================================================
PROMPT Shows WHAT objects had Compression WHEN (complete audit trail)
PROMPT ============================================================================
COLUMN run_date FORMAT A19
COLUMN days_ago FORMAT 999,999
COLUMN compression FORMAT A15
COLUMN compress_for FORMAT A20

SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_timestamp) AS days_ago,
    c.hostname,
    c.sid,
    c.owner,
    c.object_name,
    c.object_type,
    c.compression,
    c.compress_for,
    c.size_gb
FROM ORACLE_OPT_D_COMPRESS c
JOIN ORACLE_OPT_RUNS r ON c.run_id = r.run_id
ORDER BY r.run_timestamp DESC, c.hostname, c.sid, c.size_gb DESC NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT Part 2C: Object Appearance History Summary
PROMPT ============================================================================
COLUMN first_seen FORMAT A19
COLUMN last_seen FORMAT A19
COLUMN times_seen FORMAT 99,999
COLUMN days_since FORMAT 999,999

SELECT 
    c.hostname,
    c.sid,
    c.owner,
    c.object_name,
    c.object_type,
    TO_CHAR(MIN(r.run_timestamp), 'YYYY-MM-DD HH24:MI') AS first_seen,
    TO_CHAR(MAX(r.run_timestamp), 'YYYY-MM-DD HH24:MI') AS last_seen,
    COUNT(DISTINCT c.run_id) AS times_seen,
    ROUND(SYSDATE - MAX(r.run_timestamp)) AS days_since,
    MAX(c.compression) AS last_compression_type,
    MAX(c.size_gb) AS max_size_gb
FROM ORACLE_OPT_D_COMPRESS c
JOIN ORACLE_OPT_RUNS r ON c.run_id = r.run_id
GROUP BY c.hostname, c.sid, c.owner, c.object_name, c.object_type
ORDER BY MAX(r.run_timestamp) DESC, c.hostname, c.sid, MAX(c.size_gb) DESC NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT Part 3: Summary by Run and Compression Type
PROMPT ============================================================================
COLUMN object_count FORMAT 999,999
COLUMN total_size_gb FORMAT 9,999,999.99

SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_timestamp) AS days_ago,
    c.hostname,
    c.sid,
    c.compression,
    c.compress_for,
    COUNT(*) AS object_count,
    SUM(c.size_gb) AS total_size_gb
FROM ORACLE_OPT_D_COMPRESS c
JOIN ORACLE_OPT_RUNS r ON c.run_id = r.run_id
GROUP BY r.run_timestamp, c.hostname, c.sid, c.compression, c.compress_for
ORDER BY r.run_timestamp DESC, c.hostname, c.sid, COUNT(*) DESC;

PROMPT
PROMPT ============================================================================
PROMPT KEY INTERPRETATION:
PROMPT ============================================================================
PROMPT - FIRST_SEEN:  First collection run where object appeared with compression
PROMPT - LAST_SEEN:   Last collection run where object appeared with compression
PROMPT - TIMES_SEEN:  Number of runs where object was present
PROMPT - DAYS_SINCE:  Days since object was last seen with compression
PROMPT
PROMPT If object disappeared (LAST_SEEN old) = dropped or decompressed
PROMPT Track compression type changes over time (OLTP to HCC, etc.)
PROMPT This provides complete audit trail of compression usage!
PROMPT ============================================================================
