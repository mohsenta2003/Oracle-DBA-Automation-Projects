#!/bin/bash
##############################################################################
# Script: quick_host_check.sh
# Purpose: Quick verification of hosts in latest audit run
# Usage: ./quick_host_check.sh
##############################################################################

REPO_USER="DBAORALIC_SCH"
REPO_PASS="PP1_mQo84M8G"
REPO_TNS="d1hub"

echo "=============================================="
echo "QUICK HOST COVERAGE CHECK"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="
echo ""

sqlplus -s ${REPO_USER}/${REPO_PASS}@${REPO_TNS} <<'EOF'
SET LINESIZE 180 PAGESIZE 100
COL hostname FORMAT A25
COL os_type FORMAT A15
COL region FORMAT A10
COL platform FORMAT A12

-- Latest Run Info
PROMPT ========================================
PROMPT LATEST RUN
PROMPT ========================================
SELECT 
  run_id,
  TO_CHAR(run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
  SUBSTR(run_label, 1, 40) AS run_label,
  total_hosts,
  total_instances
FROM ORACLE_OPT_RUNS
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS);

-- Platform Summary
PROMPT 
PROMPT ========================================
PROMPT PLATFORM BREAKDOWN (Latest Run)
PROMPT ========================================
SELECT 
  CASE
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' AND UPPER(i.region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other (' || os_type || ')'
  END AS platform,
  COUNT(DISTINCT i.hostname) AS hosts,
  COUNT(DISTINCT i.sid) AS instances
FROM ORACLE_OPT_INSTANCES i
WHERE i.run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY
  CASE
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' AND UPPER(i.region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other (' || os_type || ')'
  END
ORDER BY 1;

-- All Unique Hosts Ever
PROMPT 
PROMPT ========================================
PROMPT ALL UNIQUE HOSTS IN REPOSITORY (EVER)
PROMPT ========================================
SELECT 
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' AND UPPER(region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END AS platform,
  COUNT(DISTINCT hostname) AS total_hosts
FROM ORACLE_OPT_INSTANCES
GROUP BY
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' AND UPPER(region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END
ORDER BY 1;

-- Region Check for Linux
PROMPT 
PROMPT ========================================
PROMPT LINUX HOSTS BY REGION VALUE
PROMPT ========================================
SELECT 
  NVL(region, 'NULL/EMPTY') AS region,
  COUNT(DISTINCT hostname) AS host_count
FROM ORACLE_OPT_INSTANCES
WHERE UPPER(os_type) LIKE '%LINUX%'
GROUP BY region
ORDER BY host_count DESC;

-- Expected vs Actual
PROMPT 
PROMPT ========================================
PROMPT EXPECTED VS ACTUAL
PROMPT ========================================
WITH actual AS (
  SELECT 
    CASE
      WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
      WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'Linux'
      ELSE 'Other'
    END AS platform,
    COUNT(DISTINCT hostname) AS count
  FROM ORACLE_OPT_INSTANCES
  GROUP BY
    CASE
      WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
      WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'Linux'
      ELSE 'Other'
    END
)
SELECT 
  platform,
  count AS actual_hosts,
  CASE 
    WHEN platform = 'AIX' THEN 14
    WHEN platform = 'Linux' THEN 106
    ELSE 0
  END AS expected_hosts,
  count - CASE 
    WHEN platform = 'AIX' THEN 14
    WHEN platform = 'Linux' THEN 106
    ELSE 0
  END AS difference
FROM actual
ORDER BY platform;

PROMPT 
PROMPT ========================================
EOF

echo ""
echo "=============================================="
echo "If actual < expected, run full verification:"
echo "  sqlplus DBAORALIC_SCH/PP1_mQo84M8G@d1hub @scripts/verify_host_coverage.sql"
echo "=============================================="
