-- ============================================================================
-- Complete In-Memory Information - Usage History + Object Evidence
-- Run as DBAORALIC_SCH on d1hub (repository database)
-- Shows both WHEN features were used AND WHICH objects have In-Memory enabled
-- ============================================================================
SET LINESIZE 250
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================
PROMPT Part 1: In-Memory HISTORICAL FOOTPRINT (When Feature Was Used)
PROMPT ============================================================
PROMPT This shows the complete history of In-Memory usage, even if disabled now
PROMPT ============================================================
COLUMN hostname FORMAT A20
COLUMN sid FORMAT A10
COLUMN feature_name FORMAT A50
COLUMN first_usage FORMAT A20
COLUMN last_usage FORMAT A20
COLUMN last_sample FORMAT A20
COLUMN detected FORMAT 999999
COLUMN currently FORMAT A10
COLUMN evidence_rows FORMAT 99999
COLUMN status FORMAT A35

-- Show In-Memory feature usage statistics with evidence counts
SELECT 
    f.hostname,
    f.sid,
    f.feature_name,
    TO_CHAR(f.first_usage_date, 'YYYY-MM-DD HH24:MI') AS first_usage,
    TO_CHAR(f.last_usage_date, 'YYYY-MM-DD HH24:MI') AS last_usage,
    TO_CHAR(f.last_sample_date, 'YYYY-MM-DD HH24:MI') AS last_sample,
    f.detected_usages AS detected,
    f.currently_used AS currently,
    COUNT(im.detail_id) AS evidence_rows,
    CASE 
        WHEN COUNT(im.detail_id) > 0 THEN 'ACTIVE - Has Evidence'
        WHEN f.currently_used = 'TRUE' THEN 'HISTORICAL - Used Recently'
        WHEN f.detected_usages > 0 THEN 'HISTORICAL - Used in Past'
        ELSE 'Not Used'
    END AS status
FROM ORACLE_OPT_FEATURES f
LEFT JOIN ORACLE_OPT_D_INMEM im 
    ON f.hostname = im.hostname 
    AND f.sid = im.sid
    AND f.run_id = im.run_id
WHERE f.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(f.feature_name) LIKE '%IN-MEMORY%'
  AND (f.detected_usages > 0 OR f.currently_used = 'TRUE')
GROUP BY f.hostname, f.sid, f.feature_name, 
         f.first_usage_date, f.last_usage_date, f.last_sample_date,
         f.detected_usages, f.currently_used
ORDER BY f.hostname, f.sid, f.feature_name;

PROMPT
PROMPT ============================================================
PROMPT KEY INTERPRETATION - HISTORICAL FOOTPRINT:
PROMPT ============================================================
PROMPT - FIRST_USAGE: When In-Memory was FIRST detected (proof of initial use)
PROMPT - LAST_USAGE:  When In-Memory was LAST detected (proof of final use)
PROMPT - DETECTED:    Number of times Oracle detected usage (cumulative)
PROMPT - CURRENTLY:   TRUE if actively used now, FALSE if historical only
PROMPT - EVIDENCE:    Current objects with In-Memory (0 = all removed/disabled)
PROMPT
PROMPT THIS DATA IS THE FOOTPRINT! Oracle preserves this even after disabling.
PROMPT Even with 0 evidence rows, you have PROOF of when it was used!
PROMPT ============================================================

PROMPT
PROMPT ============================================================
PROMPT Part 2A: CURRENT In-Memory Object Evidence (Most Recent Run)
PROMPT ============================================================
COLUMN owner FORMAT A30
COLUMN table_name FORMAT A35
COLUMN inmemory FORMAT A10
COLUMN priority FORMAT A12
COLUMN compression FORMAT A20
COLUMN size_gb FORMAT 999.99

SELECT 
    im.hostname,
    im.sid,
    im.owner,
    im.table_name,
    im.inmemory,
    im.priority,
    im.compression,
    im.size_gb
FROM ORACLE_OPT_D_INMEM im
WHERE im.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
ORDER BY im.hostname, im.sid, im.owner, im.table_name;

PROMPT
PROMPT ============================================================
PROMPT Part 2B: HISTORICAL In-Memory Evidence Timeline (All Runs)
PROMPT ============================================================
PROMPT Shows WHAT objects had In-Memory WHEN (complete audit trail)
PROMPT ============================================================
COLUMN run_date FORMAT A19
COLUMN days_ago FORMAT 999,999
COLUMN owner FORMAT A20
COLUMN table_name FORMAT A30

SELECT 
    TO_CHAR(r.run_timestamp, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_timestamp) AS days_ago,
    im.hostname,
    im.sid,
    im.owner,
    im.table_name,
    im.inmemory,
    im.priority,
    im.compression,
    im.size_gb
FROM ORACLE_OPT_D_INMEM im
JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
ORDER BY r.run_timestamp DESC, im.hostname, im.sid, im.owner, im.table_name;

PROMPT
PROMPT ============================================================
PROMPT Part 2C: Object Appearance History Summary
PROMPT ============================================================
COLUMN first_seen FORMAT A19
COLUMN last_seen FORMAT A19
COLUMN times_seen FORMAT 99,999
COLUMN days_since FORMAT 999,999

SELECT 
    im.hostname,
    im.sid,
    im.owner,
    im.table_name,
    TO_CHAR(MIN(r.run_timestamp), 'YYYY-MM-DD HH24:MI') AS first_seen,
    TO_CHAR(MAX(r.run_timestamp), 'YYYY-MM-DD HH24:MI') AS last_seen,
    COUNT(DISTINCT im.run_id) AS times_seen,
    ROUND(SYSDATE - MAX(r.run_timestamp)) AS days_since
FROM ORACLE_OPT_D_INMEM im
JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
GROUP BY im.hostname, im.sid, im.owner, im.table_name
ORDER BY MAX(r.run_timestamp) DESC, im.hostname, im.sid, im.owner, im.table_name;

PROMPT
PROMPT KEY INTERPRETATION - EVIDENCE TIMELINE:
PROMPT - FIRST_SEEN:  First collection run where object appeared with In-Memory
PROMPT - LAST_SEEN:   Last collection run where object appeared with In-Memory
PROMPT - TIMES_SEEN:  Number of runs where object was present
PROMPT - DAYS_SINCE:  Days since object was last seen with In-Memory
PROMPT
PROMPT If LAST_SEEN is recent and TIMES_SEEN is high = actively used
PROMPT If LAST_SEEN is old (90+ days) = object was disabled/removed
PROMPT If TIMES_SEEN = 1 = possibly test/temporary usage
PROMPT ============================================================

PROMPT
PROMPT ============================================================
PROMPT Part 3: Problem Detection - Usage WITHOUT Evidence
PROMPT ============================================================
PROMPT Instances showing In-Memory usage but ZERO evidence rows:

SELECT 
    f.hostname,
    f.sid,
    f.feature_name,
    f.detected_usages,
    f.currently_used,
    TO_CHAR(f.first_usage_date, 'YYYY-MM-DD') AS first_used,
    TO_CHAR(f.last_usage_date, 'YYYY-MM-DD') AS last_used,
    COUNT(im.detail_id) AS evidence_count,
    CASE 
        WHEN COUNT(im.detail_id) = 0 THEN '❌ MISSING EVIDENCE'
        ELSE '✓ OK'
    END AS status
FROM ORACLE_OPT_FEATURES f
LEFT JOIN ORACLE_OPT_D_INMEM im 
    ON f.hostname = im.hostname 
    AND f.sid = im.sid
    AND f.run_id = im.run_id
WHERE f.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(f.feature_name) LIKE '%IN-MEMORY%'
  AND (f.detected_usages > 0 OR f.currently_used = 'TRUE')
GROUP BY f.hostname, f.sid, f.feature_name, f.detected_usages, 
         f.currently_used, f.first_usage_date, f.last_usage_date
HAVING COUNT(im.detail_id) = 0
ORDER BY f.hostname, f.sid;

PROMPT
PROMPT ============================================================
PROMPT Part 4: Summary Statistics
PROMPT ============================================================

SELECT 
    'Total Instances with In-Memory Features Used' AS metric,
    COUNT(DISTINCT f.hostname || '|' || f.sid) AS count_value
FROM ORACLE_OPT_FEATURES f
WHERE f.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(f.feature_name) LIKE '%IN-MEMORY%'
  AND (f.detected_usages > 0 OR f.currently_used = 'TRUE')
UNION ALL
SELECT 
    'Total In-Memory Evidence Rows Collected' AS metric,
    COUNT(*) AS count_value
FROM ORACLE_OPT_D_INMEM
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
UNION ALL
SELECT 
    'Instances with Evidence Missing (❌ Problem)' AS metric,
    COUNT(DISTINCT f.hostname || '|' || f.sid) AS count_value
FROM ORACLE_OPT_FEATURES f
LEFT JOIN ORACLE_OPT_D_INMEM im 
    ON f.hostname = im.hostname 
    AND f.sid = im.sid
    AND f.run_id = im.run_id
WHERE f.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
  AND UPPER(f.feature_name) LIKE '%IN-MEMORY%'
  AND (f.detected_usages > 0 OR f.currently_used = 'TRUE')
GROUP BY f.hostname, f.sid
HAVING COUNT(im.detail_id) = 0;

PROMPT
PROMPT ============================================================================
PROMPT INTERPRETATION:
PROMPT ============================================================================
PROMPT - Part 1: Shows WHEN In-Memory was used (usage dates and counts)
PROMPT - Part 2: Shows WHICH tables/objects have In-Memory enabled (evidence)
PROMPT - Part 3: Identifies instances with usage stats but NO evidence (problem)
PROMPT - Part 4: Summary counts
PROMPT
PROMPT If Part 3 shows any rows, those instances need re-collection with the fix!
PROMPT ============================================================================
