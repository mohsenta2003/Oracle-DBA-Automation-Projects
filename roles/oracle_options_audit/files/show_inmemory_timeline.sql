-- ============================================================================
-- Show In-Memory COMPLETE TIMELINE - All Historical Evidence Across All Runs
-- Run as DBAORALIC_SCH on d1hub (repository database)
-- This shows WHAT objects had In-Memory configured, WHEN (across all collection runs)
-- ============================================================================
SET LINESIZE 250
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================================
PROMPT COMPLETE TIMELINE: Objects with In-Memory Configuration (All Runs)
PROMPT ============================================================================
PROMPT This shows the audit trail of what objects had In-Memory enabled over time
PROMPT ============================================================================

COLUMN run_date FORMAT A19
COLUMN hostname FORMAT A20
COLUMN sid FORMAT A10
COLUMN owner FORMAT A20
COLUMN table_name FORMAT A30
COLUMN inmemory FORMAT A10
COLUMN priority FORMAT A12
COLUMN compression FORMAT A20
COLUMN size_gb FORMAT 999,999.99
COLUMN days_ago FORMAT 999,999

-- Show all In-Memory evidence across all runs (complete historical timeline)
SELECT 
    TO_CHAR(r.run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_date) AS days_ago,
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
WHERE im.hostname IN ('crlnxm145', 'crlnxt222')  -- Focus on problem hosts
ORDER BY r.run_date DESC, im.hostname, im.sid, im.owner, im.table_name;

PROMPT
PROMPT ============================================================================
PROMPT Summary: Objects Seen Per Run
PROMPT ============================================================================

COLUMN run_date FORMAT A19
COLUMN hostname FORMAT A20
COLUMN sid FORMAT A10
COLUMN object_count FORMAT 999,999
COLUMN tables_list FORMAT A80

SELECT 
    TO_CHAR(r.run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
    ROUND(SYSDATE - r.run_date) AS days_ago,
    im.hostname,
    im.sid,
    COUNT(*) AS object_count,
    LISTAGG(im.owner || '.' || im.table_name, ', ') 
        WITHIN GROUP (ORDER BY im.owner, im.table_name) AS tables_list
FROM ORACLE_OPT_D_INMEM im
JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
WHERE im.hostname IN ('crlnxm145', 'crlnxt222')
GROUP BY r.run_date, im.hostname, im.sid
ORDER BY r.run_date DESC, im.hostname, im.sid;

PROMPT
PROMPT ============================================================================
PROMPT First and Last Appearance of Each Object
PROMPT ============================================================================

COLUMN hostname FORMAT A20
COLUMN sid FORMAT A10
COLUMN owner FORMAT A20
COLUMN table_name FORMAT A30
COLUMN first_seen FORMAT A19
COLUMN last_seen FORMAT A19
COLUMN times_seen FORMAT 99,999
COLUMN days_since FORMAT 999,999

SELECT 
    im.hostname,
    im.sid,
    im.owner,
    im.table_name,
    TO_CHAR(MIN(r.run_date), 'YYYY-MM-DD HH24:MI') AS first_seen,
    TO_CHAR(MAX(r.run_date), 'YYYY-MM-DD HH24:MI') AS last_seen,
    COUNT(DISTINCT im.run_id) AS times_seen,
    ROUND(SYSDATE - MAX(r.run_date)) AS days_since
FROM ORACLE_OPT_D_INMEM im
JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
WHERE im.hostname IN ('crlnxm145', 'crlnxt222')
GROUP BY im.hostname, im.sid, im.owner, im.table_name
ORDER BY MAX(r.run_date) DESC, im.hostname, im.sid, im.owner, im.table_name;

PROMPT
PROMPT ============================================================================
PROMPT INTERPRETATION:
PROMPT ============================================================================
PROMPT
PROMPT - RUN_DATE:     When the collection was performed
PROMPT - DAYS_AGO:     Days since that collection run
PROMPT - FIRST_SEEN:   First time this object appeared with In-Memory
PROMPT - LAST_SEEN:    Last time this object appeared with In-Memory  
PROMPT - TIMES_SEEN:   Number of collection runs where object was present
PROMPT - DAYS_SINCE:   Days since object was last seen with In-Memory
PROMPT
PROMPT If LAST_SEEN is old (e.g., 90+ days ago), object was disabled/removed.
PROMPT If TIMES_SEEN = 1, object may have been used for testing only.
PROMPT If TIMES_SEEN is high, object was in consistent use.
PROMPT
PROMPT This data provides complete audit trail of what was configured and when!
PROMPT ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT Check If Any Historical Evidence Exists
PROMPT ============================================================================

SELECT 
    hostname,
    sid,
    COUNT(DISTINCT run_id) AS total_runs_with_evidence,
    COUNT(*) AS total_objects_ever_seen,
    COUNT(DISTINCT owner || '.' || table_name) AS unique_objects,
    TO_CHAR(MIN(r.run_date), 'YYYY-MM-DD') AS earliest_evidence,
    TO_CHAR(MAX(r.run_date), 'YYYY-MM-DD') AS latest_evidence
FROM ORACLE_OPT_D_INMEM im
JOIN ORACLE_OPT_RUNS r ON im.run_id = r.run_id
WHERE hostname IN ('crlnxm145', 'crlnxt222')
GROUP BY hostname, sid
ORDER BY hostname, sid;

PROMPT
PROMPT ============================================================================
PROMPT If above query returns 0 rows for a host, it means:
PROMPT - No objects have EVER had In-Memory configuration in this audit system
PROMPT - In-Memory was enabled but no tables/segments were configured to use it
PROMPT - Feature was tracked in ORACLE_OPT_FEATURES (dates), but no objects used it
PROMPT
PROMPT This is VALID - you can enable In-Memory without actually configuring objects!
PROMPT ============================================================================
