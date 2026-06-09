-- ============================================================================
-- Show Security/TDE COMPLETE TIMELINE - All Historical Evidence Across All Runs
-- Run as DBAORALIC_SCH on d1hub (repository database)
-- This shows WHAT objects had Encryption configured, WHEN (across all collection runs)
-- ============================================================================
SET LINESIZE 250
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================================
PROMPT Part 1: Security/TDE HISTORICAL FOOTPRINT (When Feature Was Used)
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
    COUNT(s.detail_id) AS evidence_rows,
    CASE 
        WHEN COUNT(s.detail_id) > 0 THEN 'ACTIVE - Has Evidence'
        WHEN f.currently_used = 'TRUE' THEN 'HISTORICAL - Used Recently'
        WHEN f.detected_usages > 0 THEN 'HISTORICAL - Used in Past'
        ELSE 'Not Used'
    END AS status
FROM ORACLE_OPT_FEATURES f
LEFT JOIN ORACLE_OPT_D_SECURITY s 
    ON f.hostname = s.hostname 
    AND f.sid = s.sid
    AND f.run_id = s.run_id
WHERE f.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND (UPPER(f.feature_name) LIKE '%ENCRYPTION%' 
       OR UPPER(f.feature_name) LIKE '%ADVANCED SECURITY%'
       OR UPPER(f.feature_name) LIKE '%TDE%'
       OR UPPER(f.feature_name) LIKE '%TRANSPARENT DATA ENCRYPTION%')
  AND (f.detected_usages > 0 OR f.currently_used = 'TRUE')
GROUP BY f.hostname, f.sid, f.feature_name, 
         f.first_usage_date, f.last_usage_date,
         f.detected_usages, f.currently_used
ORDER BY f.hostname, f.sid, f.feature_name;

PROMPT
PROMPT ============================================================================
PROMPT Part 2A: CURRENT Encrypted Objects (Most Recent Run)
PROMPT ============================================================================
COLUMN object_type FORMAT A15
COLUMN owner_or_ts FORMAT A25
COLUMN object_name FORMAT A30
COLUMN encrypted FORMAT A10
COLUMN algorithm FORMAT A20
COLUMN size_gb FORMAT 999,999.99

SELECT 
    s.hostname,
    s.sid,
    s.object_type,
    s.owner_or_ts,
    s.object_name,
    s.encrypted,
    s.algorithm,
    s.size_gb
FROM ORACLE_OPT_D_SECURITY s
WHERE s.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
ORDER BY s.hostname, s.sid, s.object_type, s.size_gb DESC NULLS LAST, s.owner_or_ts, s.object_name;

PROMPT
PROMPT ============================================================================
PROMPT Part 2B: HISTORICAL Security/TDE Evidence Timeline (All Runs)
PROMPT ============================================================================
PROMPT Shows WHAT objects had Encryption WHEN (complete audit trail)
PROMPT ============================================================================
COLUMN run_date FORMAT A19
COLUMN days_ago FORMAT 999,999

SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_timestamp) AS days_ago,
    s.hostname,
    s.sid,
    s.object_type,
    s.owner_or_ts,
    s.object_name,
    s.encrypted,
    s.algorithm,
    s.size_gb
FROM ORACLE_OPT_D_SECURITY s
JOIN ORACLE_OPT_RUNS r ON s.run_id = r.run_id
ORDER BY r.run_timestamp DESC, s.hostname, s.sid, s.object_type, s.size_gb DESC NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT Part 2C: Object Appearance History Summary
PROMPT ============================================================================
COLUMN first_seen FORMAT A19
COLUMN last_seen FORMAT A19
COLUMN times_seen FORMAT 99,999
COLUMN days_since FORMAT 999,999

SELECT 
    s.hostname,
    s.sid,
    s.object_type,
    s.owner_or_ts,
    s.object_name,
    TO_CHAR(MIN(r.run_timestamp), 'YYYY-MM-DD HH24:MI') AS first_seen,
    TO_CHAR(MAX(r.run_timestamp), 'YYYY-MM-DD HH24:MI') AS last_seen,
    COUNT(DISTINCT s.run_id) AS times_seen,
    ROUND(SYSDATE - MAX(r.run_timestamp)) AS days_since,
    MAX(s.algorithm) AS last_algorithm,
    MAX(s.size_gb) AS max_size_gb
FROM ORACLE_OPT_D_SECURITY s
JOIN ORACLE_OPT_RUNS r ON s.run_id = r.run_id
GROUP BY s.hostname, s.sid, s.object_type, s.owner_or_ts, s.object_name
ORDER BY MAX(r.run_timestamp) DESC, s.hostname, s.sid, s.object_type, MAX(s.size_gb) DESC NULLS LAST;

PROMPT
PROMPT ============================================================================
PROMPT Part 3: Summary by Run and Object Type
PROMPT ============================================================================
COLUMN object_count FORMAT 999,999
COLUMN total_size_gb FORMAT 9,999,999.99

SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_timestamp) AS days_ago,
    s.hostname,
    s.sid,
    s.object_type,
    COUNT(*) AS object_count,
    COUNT(DISTINCT s.algorithm) AS algorithm_count,
    SUM(s.size_gb) AS total_size_gb
FROM ORACLE_OPT_D_SECURITY s
JOIN ORACLE_OPT_RUNS r ON s.run_id = r.run_id
GROUP BY r.run_timestamp, s.hostname, s.sid, s.object_type
ORDER BY r.run_timestamp DESC, s.hostname, s.sid, COUNT(*) DESC;

PROMPT
PROMPT ============================================================================
PROMPT KEY INTERPRETATION:
PROMPT ============================================================================
PROMPT - FIRST_SEEN:  First collection run where object appeared encrypted
PROMPT - LAST_SEEN:   Last collection run where object appeared encrypted
PROMPT - TIMES_SEEN:  Number of runs where object was present
PROMPT - DAYS_SINCE:  Days since object was last seen encrypted
PROMPT
PROMPT If object disappeared (LAST_SEEN old) = dropped or decrypted
PROMPT Track algorithm changes (AES128 to AES256, etc.)
PROMPT This provides complete audit trail of encryption usage!
PROMPT ============================================================================
