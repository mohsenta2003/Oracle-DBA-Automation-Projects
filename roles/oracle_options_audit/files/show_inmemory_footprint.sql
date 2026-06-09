-- ============================================================================
-- Show In-Memory Historical Footprint - PROOF of Past Usage
-- Run as DBAORALIC_SCH on d1hub (repository database)
-- This shows the "footprint" of In-Memory usage even if disabled now
-- ============================================================================
SET LINESIZE 200
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================================
PROMPT HISTORICAL FOOTPRINT: In-Memory Usage Over Time
PROMPT ============================================================================
PROMPT This data PROVES when In-Memory was used, even if later disabled!
PROMPT ============================================================================

COLUMN hostname FORMAT A20
COLUMN sid FORMAT A10
COLUMN feature_name FORMAT A45
COLUMN first_used FORMAT A19
COLUMN last_used FORMAT A19
COLUMN days_ago FORMAT 999999
COLUMN detected FORMAT 999999
COLUMN currently FORMAT A10
COLUMN current_objects FORMAT 999999
COLUMN status FORMAT A30

SELECT 
    f.hostname,
    f.sid,
    f.feature_name,
    TO_CHAR(f.first_usage_date, 'YYYY-MM-DD HH24:MI') AS first_used,
    TO_CHAR(f.last_usage_date, 'YYYY-MM-DD HH24:MI') AS last_used,
    ROUND(SYSDATE - f.last_usage_date) AS days_ago,
    f.detected_usages AS detected,
    f.currently_used AS currently,
    COUNT(im.detail_id) AS current_objects,
    CASE 
        WHEN COUNT(im.detail_id) > 0 THEN '✓ ACTIVE (has objects)'
        WHEN f.currently_used = 'TRUE' THEN '⚠ ENABLED (no objects)'
        WHEN SYSDATE - f.last_usage_date < 90 THEN '○ RECENT (< 90 days)'
        ELSE '○ HISTORICAL (> 90 days)'
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
         f.first_usage_date, f.last_usage_date,
         f.detected_usages, f.currently_used
ORDER BY f.hostname, f.sid;

PROMPT
PROMPT ============================================================================
PROMPT KEY FIELDS:
PROMPT ============================================================================
PROMPT - FIRST_USED:      Timestamp when In-Memory was FIRST detected
PROMPT - LAST_USED:       Timestamp when In-Memory was LAST detected  
PROMPT - DAYS_AGO:        Days since last detection
PROMPT - DETECTED:        Total number of times usage was detected
PROMPT - CURRENTLY:       TRUE if actively monitored, FALSE if historical
PROMPT - CURRENT_OBJECTS: Count of tables/segments with In-Memory NOW
PROMPT - STATUS:          Current state interpretation
PROMPT
PROMPT ============================================================================
PROMPT INTERPRETATION:
PROMPT ============================================================================
PROMPT
PROMPT ✓ ACTIVE (has objects)   = In-Memory is configured and objects exist
PROMPT ⚠ ENABLED (no objects)   = Feature enabled but no objects using it
PROMPT ○ RECENT (< 90 days)     = Used recently, now disabled/removed
PROMPT ○ HISTORICAL (> 90 days) = Used in the past, now disabled/removed
PROMPT
PROMPT Even with 0 current_objects, you have PROOF of usage via dates!
PROMPT Oracle preserves this historical data - it is NOT cleared when disabled.
PROMPT ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT For License Auditing:
PROMPT ============================================================================
PROMPT
PROMPT This footprint data can be used to demonstrate:
PROMPT   1. When the feature was first used (contract compliance date)
PROMPT   2. Duration of usage (first_used to last_used)
PROMPT   3. Frequency of usage (detected count)
PROMPT   4. Whether usage was temporary (test) or production
PROMPT
PROMPT Even if current_objects = 0, the dates prove historical usage occurred.
PROMPT ============================================================================
