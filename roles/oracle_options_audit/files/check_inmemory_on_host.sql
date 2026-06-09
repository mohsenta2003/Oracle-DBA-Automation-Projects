-- ============================================================================
-- Check In-Memory Objects Directly on Host
-- Run this on crlnxm145 (aahd) and crlnxt222 (aahsb)
-- ============================================================================
SET LINESIZE 200
SET PAGESIZE 1000
SET FEEDBACK ON

PROMPT ============================================================
PROMPT Current Database and Instance Info
PROMPT ============================================================
SELECT instance_name, host_name, version, database_role, open_mode
FROM v$instance i, v$database d;

PROMPT
PROMPT ============================================================
PROMPT In-Memory Parameters
PROMPT ============================================================
COLUMN name FORMAT A40
COLUMN value FORMAT A30

SELECT name, value, isdefault
FROM v$parameter
WHERE UPPER(name) LIKE '%INMEMORY%'
ORDER BY name;

PROMPT
PROMPT ============================================================
PROMPT In-Memory Feature Usage Statistics (WHY IS_INUSE=Y)
PROMPT ============================================================
COLUMN name FORMAT A50
COLUMN detected_usages FORMAT 999999999
COLUMN currently_used FORMAT A15
COLUMN first_usage_date FORMAT A20
COLUMN last_usage_date FORMAT A20

SELECT name, 
       detected_usages, 
       currently_used,
       TO_CHAR(first_usage_date, 'YYYY-MM-DD HH24:MI:SS') AS first_usage_date,
       TO_CHAR(last_usage_date, 'YYYY-MM-DD HH24:MI:SS') AS last_usage_date,
       TO_CHAR(last_sample_date, 'YYYY-MM-DD HH24:MI:SS') AS last_sample_date,
       aux_count
FROM dba_feature_usage_statistics
WHERE UPPER(name) LIKE '%MEMORY%'
  AND (detected_usages > 0 OR currently_used = 'TRUE')
ORDER BY name;

PROMPT
PROMPT ============================================================
PROMPT Tables with INMEMORY=ENABLED (Evidence Source #1)
PROMPT ============================================================
COLUMN owner FORMAT A30
COLUMN table_name FORMAT A35
COLUMN inmemory FORMAT A10
COLUMN inmemory_priority FORMAT A15
COLUMN inmemory_compression FORMAT A20
COLUMN inmemory_distribute FORMAT A20

SELECT COUNT(*) AS table_count FROM dba_tables WHERE inmemory = 'ENABLED';

SELECT owner, table_name, 
       inmemory, 
       inmemory_priority,
       inmemory_compression,
       inmemory_distribute,
       inmemory_duplicate
FROM dba_tables
WHERE inmemory = 'ENABLED'
  AND owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN','APEX_PUBLIC_USER',
                    'OUTLN','XDB','ORDDATA','CTXSYS','MDSYS','WMSYS',
                    'EXFSYS','DVSYS','LBACSYS','OLAPSYS','ORDSYS')
ORDER BY owner, table_name;

PROMPT
PROMPT ============================================================
PROMPT In-Memory Segments Actually Populated (Evidence Source #2)
PROMPT ============================================================
COLUMN segment_name FORMAT A35
COLUMN bytes_not_populated FORMAT 999,999,999,999

SELECT COUNT(*) AS populated_segment_count FROM v$im_segments;

SELECT owner, segment_name, 
       ROUND(populate_status,2) AS populate_pct,
       ROUND(bytes/1024/1024/1024, 2) AS size_gb,
       ROUND(inmemory_size/1024/1024/1024, 2) AS inmem_size_gb,
       bytes_not_populated
FROM v$im_segments
WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN','APEX_PUBLIC_USER',
                    'OUTLN','XDB','ORDDATA','CTXSYS','MDSYS','WMSYS',
                    'EXFSYS','DVSYS','LBACSYS','OLAPSYS','ORDSYS')
ORDER BY owner, segment_name;

PROMPT
PROMPT ============================================================
PROMPT Total In-Memory Usage
PROMPT ============================================================
SELECT 
  ROUND(SUM(bytes)/1024/1024/1024, 2) AS total_segment_size_gb,
  ROUND(SUM(inmemory_size)/1024/1024/1024, 2) AS total_inmemory_size_gb,
  COUNT(*) AS segment_count
FROM v$im_segments;

PROMPT
PROMPT ============================================================
PROMPT DIAGNOSIS
PROMPT ============================================================
PROMPT If feature usage shows DETECTED_USAGES > 0 or CURRENTLY_USED=TRUE
PROMPT BUT both Evidence Source #1 and #2 show 0 rows, then:
PROMPT 
PROMPT   => In-Memory was USED IN THE PAST but is not currently active
PROMPT   => Tables/segments were configured then removed/dropped
PROMPT   => Feature was tested temporarily  
PROMPT   => This is EXPECTED BEHAVIOR - evidence table will be empty
PROMPT 
PROMPT The feature usage statistics track HISTORICAL usage, not just current.
PROMPT They are NOT cleared even after all In-Memory objects are removed.
PROMPT 
PROMPT For license auditing:
PROMPT   - IS_INUSE=Y with 0 evidence = historical usage only
PROMPT   - IS_INUSE=Y with >0 evidence = active usage with proof
PROMPT

COLUMN last_ddl_time FORMAT A20

SELECT owner, table_name, 
       TO_CHAR(created, 'YYYY-MM-DD HH24:MI:SS') AS created,
       TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') AS last_ddl_time,
       inmemory
FROM dba_tables
WHERE inmemory = 'ENABLED'
  AND owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')
ORDER BY last_ddl_time DESC;

EXIT;
