-- ========================================
-- HOST COVERAGE VERIFICATION SCRIPT
-- Purpose: Verify all hosts are being captured in audit runs
-- Usage: sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub @verify_host_coverage.sql
-- ========================================

SET LINESIZE 200 PAGESIZE 1000
SET FEEDBACK ON
COL hostname FORMAT A25
COL os_type FORMAT A15
COL region FORMAT A10
COL run_id FORMAT 999999
COL run_label FORMAT A35
COL run_date FORMAT A20
COL instance_count FORMAT 999
COL status FORMAT A10

PROMPT ========================================
PROMPT 1. LATEST RUN SUMMARY
PROMPT ========================================
SELECT 
  run_id,
  TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI:SS') AS run_date,
  SUBSTR(run_label, 1, 35) AS run_label,
  total_hosts,
  total_instances
FROM ORACLE_OPT_RUNS
ORDER BY run_id DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT 
PROMPT ========================================
PROMPT 2. ALL UNIQUE HOSTS IN REPOSITORY (EVER)
PROMPT ========================================
SELECT 
  COUNT(DISTINCT hostname) AS total_unique_hosts
FROM ORACLE_OPT_INSTANCES;

PROMPT 
PROMPT ========================================
PROMPT 3. HOST COUNT BY PLATFORM (ALL TIME)
PROMPT ========================================
SELECT 
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' AND UPPER(region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END AS platform,
  COUNT(DISTINCT hostname) AS unique_hosts,
  COUNT(*) AS total_instance_records
FROM ORACLE_OPT_INSTANCES
GROUP BY
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' AND UPPER(region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END
ORDER BY 1;

PROMPT 
PROMPT ========================================
PROMPT 4. LATEST RUN BREAKDOWN
PROMPT ========================================
SELECT 
  r.run_id,
  TO_CHAR(r.run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
  SUBSTR(r.run_label, 1, 30) AS run_label,
  CASE
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' AND UPPER(i.region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END AS platform,
  COUNT(DISTINCT i.hostname) AS hosts,
  COUNT(DISTINCT i.sid) AS instances
FROM ORACLE_OPT_RUNS r
JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
WHERE r.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY 
  r.run_id,
  r.run_date,
  r.run_label,
  CASE
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' AND UPPER(i.region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END
ORDER BY platform;

PROMPT 
PROMPT ========================================
PROMPT 5. ALL LINUX HOSTS (GROUPED BY REGION)
PROMPT ========================================
SELECT 
  NVL(region, 'NULL/EMPTY') AS region,
  COUNT(DISTINCT hostname) AS host_count,
  LISTAGG(DISTINCT hostname, ', ') WITHIN GROUP (ORDER BY hostname) AS hostnames
FROM ORACLE_OPT_INSTANCES
WHERE UPPER(os_type) LIKE '%LINUX%'
GROUP BY region
ORDER BY region;

PROMPT 
PROMPT ========================================
PROMPT 6. AIX HOSTS - LATEST DATA
PROMPT ========================================
SELECT 
  i.hostname,
  i.os_type,
  COUNT(DISTINCT i.sid) AS instance_count,
  MAX(i.run_id) AS latest_run,
  TO_CHAR(MAX(r.run_date), 'YYYY-MM-DD HH24:MI') AS latest_audit
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
WHERE UPPER(i.os_type) = 'AIX'
GROUP BY i.hostname, i.os_type
ORDER BY i.hostname;

PROMPT 
PROMPT ========================================
PROMPT 7. US LINUX HOSTS - LATEST DATA
PROMPT ========================================
SELECT 
  i.hostname,
  NVL(i.region, 'NULL') AS region,
  COUNT(DISTINCT i.sid) AS instance_count,
  MAX(i.run_id) AS latest_run,
  TO_CHAR(MAX(r.run_date), 'YYYY-MM-DD HH24:MI') AS latest_audit
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
WHERE UPPER(i.os_type) LIKE '%LINUX%'
  AND (UPPER(NVL(i.region,'US')) LIKE '%US%' OR i.region IS NULL)
  AND UPPER(NVL(i.region,'')) NOT LIKE '%EU%'
GROUP BY i.hostname, i.region
ORDER BY i.hostname;

PROMPT 
PROMPT ========================================
PROMPT 8. RECENT RUNS WITH HOST COUNTS (Last 7 days)
PROMPT ========================================
SELECT 
  r.run_id,
  TO_CHAR(r.run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
  SUBSTR(r.run_label, 1, 35) AS run_label,
  COUNT(DISTINCT i.hostname) AS actual_hosts,
  r.total_hosts AS recorded_hosts,
  COUNT(DISTINCT i.inst_id) AS instances
FROM ORACLE_OPT_RUNS r
LEFT JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
WHERE r.run_date >= SYSDATE - 7
GROUP BY r.run_id, r.run_date, r.run_label, r.total_hosts
ORDER BY r.run_date DESC;

PROMPT 
PROMPT ========================================
PROMPT 9. HOSTS WITH MULTIPLE RUN_IDs (Latest 3)
PROMPT ========================================
SELECT 
  hostname,
  COUNT(DISTINCT run_id) AS run_count,
  LISTAGG(DISTINCT run_id, ',') WITHIN GROUP (ORDER BY run_id DESC) AS run_ids,
  TO_CHAR(MAX(r.run_date), 'YYYY-MM-DD') AS latest_audit
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
GROUP BY hostname
HAVING COUNT(DISTINCT run_id) > 1
ORDER BY MAX(r.run_date) DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT 
PROMPT ========================================
PROMPT 10. EXPECTED vs ACTUAL HOST COUNT
PROMPT ========================================
WITH expected_counts AS (
  SELECT 'AIX TLP' AS group_name, 14 AS expected_count FROM DUAL
  UNION ALL
  SELECT 'US Linux', 61 FROM DUAL
  UNION ALL
  SELECT 'EU Linux', 45 FROM DUAL
),
actual_counts AS (
  SELECT 
    CASE
      WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX TLP'
      WHEN UPPER(i.os_type) LIKE '%LINUX%' AND UPPER(i.region) LIKE '%EU%' THEN 'EU Linux'
      WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'US Linux'
      ELSE 'Other'
    END AS group_name,
    COUNT(DISTINCT i.hostname) AS actual_count
  FROM ORACLE_OPT_INSTANCES i
  GROUP BY
    CASE
      WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX TLP'
      WHEN UPPER(i.os_type) LIKE '%LINUX%' AND UPPER(i.region) LIKE '%EU%' THEN 'EU Linux'
      WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'US Linux'
      ELSE 'Other'
    END
)
SELECT 
  e.group_name,
  e.expected_count AS expected,
  NVL(a.actual_count, 0) AS actual,
  NVL(a.actual_count, 0) - e.expected_count AS difference,
  CASE 
    WHEN NVL(a.actual_count, 0) >= e.expected_count THEN '✓ OK'
    ELSE '✗ MISSING'
  END AS status
FROM expected_counts e
LEFT JOIN actual_counts a ON a.group_name = e.group_name
ORDER BY e.group_name;

PROMPT 
PROMPT ========================================
PROMPT 11. INSTANCES PER HOST (Latest Run)
PROMPT ========================================
SELECT 
  i.hostname,
  CASE
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'Linux'
    ELSE i.os_type
  END AS platform,
  COUNT(*) AS instance_count,
  LISTAGG(i.sid, ', ') WITHIN GROUP (ORDER BY i.sid) AS sids
FROM ORACLE_OPT_INSTANCES i
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY i.hostname, 
  CASE
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'Linux'
    ELSE i.os_type
  END
ORDER BY instance_count DESC, i.hostname;

PROMPT 
PROMPT ========================================
PROMPT 12. CHECK FOR DUPLICATE INSTANCES (Same host/sid, different runs)
PROMPT ========================================
SELECT 
  hostname,
  sid,
  COUNT(DISTINCT run_id) AS run_count,
  LISTAGG(run_id, ',') WITHIN GROUP (ORDER BY run_id) AS run_ids
FROM ORACLE_OPT_INSTANCES
GROUP BY hostname, sid
HAVING COUNT(DISTINCT run_id) > 3
ORDER BY COUNT(DISTINCT run_id) DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT 
PROMPT ========================================
PROMPT VERIFICATION COMPLETE
PROMPT ========================================
PROMPT Review sections 10 (Expected vs Actual) and 4 (Latest Run Breakdown)
PROMPT to identify any missing hosts.
