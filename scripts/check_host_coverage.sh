#!/bin/bash
##############################################################################
# Script: check_host_coverage.sh
# Purpose: Generate host coverage report from Oracle audit repository
# Usage: ./check_host_coverage.sh [days_threshold]
# Example: ./check_host_coverage.sh 7  (show hosts not audited in last 7 days)
##############################################################################

REPO_USER="DBAORALIC_SCH"
REPO_PASS="PP1_mQo84M8G"
REPO_TNS="d1hub"

# Days threshold (default: 7)
DAYS_THRESHOLD=${1:-7}

echo "=============================================="
echo "HOST COVERAGE AUDIT REPORT"
echo "Threshold: Hosts not audited in last $DAYS_THRESHOLD days"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="
echo ""

sqlplus -s ${REPO_USER}/${REPO_PASS}@${REPO_TNS} <<EOF
SET LINESIZE 200 PAGESIZE 1000
SET FEEDBACK OFF
COL hostname FORMAT A25
COL os_type FORMAT A15
COL region FORMAT A10
COL last_audit FORMAT A11
COL days_ago FORMAT 999
COL instances FORMAT 999
COL run_id FORMAT 999999
COL run_label FORMAT A35
COL status FORMAT A15

PROMPT ============================================
PROMPT HOSTS NOT AUDITED RECENTLY (>${DAYS_THRESHOLD} days)
PROMPT ============================================

SELECT 
  i.hostname,
  i.os_type,
  NVL(i.region, 'N/A') AS region,
  TO_CHAR(MAX(r.run_date), 'YYYY-MM-DD') AS last_audit,
  TRUNC(SYSDATE - MAX(r.run_date)) AS days_ago,
  COUNT(DISTINCT i.sid) AS instances,
  MAX(r.run_id) AS run_id,
  SUBSTR(MAX(r.run_label), 1, 35) AS run_label,
  CASE 
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) <= 1 THEN '✓ Current'
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) <= 7 THEN '✓ Recent'
    WHEN TRUNC(SYSDATE - MAX(r.run_date)) <= 30 THEN '⚠ Aging'
    ELSE '✗ STALE'
  END AS status
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
WHERE r.run_id = (
  SELECT MAX(r2.run_id)
  FROM ORACLE_OPT_RUNS r2
  JOIN ORACLE_OPT_INSTANCES i2 ON i2.run_id = r2.run_id
  WHERE i2.hostname = i.hostname
)
GROUP BY i.hostname, i.os_type, i.region
HAVING TRUNC(SYSDATE - MAX(r.run_date)) > ${DAYS_THRESHOLD}
ORDER BY TRUNC(SYSDATE - MAX(r.run_date)) DESC, i.hostname;

PROMPT 
PROMPT ============================================
PROMPT PLATFORM COVERAGE SUMMARY
PROMPT ============================================

SELECT 
  NVL(i.os_type, 'Unknown') AS platform,
  COUNT(DISTINCT i.hostname) AS total_hosts,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) <= 1 THEN 1 ELSE 0 END) AS current_24h,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) BETWEEN 2 AND 7 THEN 1 ELSE 0 END) AS within_7d,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) BETWEEN 8 AND 30 THEN 1 ELSE 0 END) AS aging_30d,
  SUM(CASE WHEN TRUNC(SYSDATE - r.run_date) > 30 THEN 1 ELSE 0 END) AS stale_30plus
FROM ORACLE_OPT_INSTANCES i
JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
WHERE r.run_id = (
  SELECT MAX(r2.run_id)
  FROM ORACLE_OPT_RUNS r2
  JOIN ORACLE_OPT_INSTANCES i2 ON i2.run_id = r2.run_id
  WHERE i2.hostname = i.hostname
)
GROUP BY i.os_type
ORDER BY i.os_type;

PROMPT 
PROMPT ============================================
PROMPT RECENT AUDIT ACTIVITY (Last 7 days)
PROMPT ============================================

SELECT 
  r.run_id,
  TO_CHAR(r.run_date, 'YYYY-MM-DD HH24:MI') AS run_date,
  SUBSTR(r.run_label, 1, 40) AS run_label,
  COUNT(DISTINCT i.hostname) AS hosts,
  COUNT(DISTINCT i.inst_id) AS instances,
  LISTAGG(DISTINCT SUBSTR(i.os_type, 1, 10), ', ') WITHIN GROUP (ORDER BY i.os_type) AS platforms
FROM ORACLE_OPT_RUNS r
JOIN ORACLE_OPT_INSTANCES i ON i.run_id = r.run_id
WHERE r.run_date >= SYSDATE - 7
GROUP BY r.run_id, r.run_date, r.run_label
ORDER BY r.run_date DESC;

PROMPT 
PROMPT ============================================
PROMPT ACTION ITEMS
PROMPT ============================================
SELECT 
  'Missing/Stale Hosts (>30d)' AS action,
  TO_CHAR(COUNT(*)) AS count
FROM (
  SELECT i.hostname
  FROM ORACLE_OPT_INSTANCES i
  JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
  WHERE r.run_id = (
    SELECT MAX(r2.run_id)
    FROM ORACLE_OPT_RUNS r2
    JOIN ORACLE_OPT_INSTANCES i2 ON i2.run_id = r2.run_id
    WHERE i2.hostname = i.hostname
  )
  GROUP BY i.hostname
  HAVING TRUNC(SYSDATE - MAX(r.run_date)) > 30
)
UNION ALL
SELECT 
  'Aging Hosts (8-30d)' AS action,
  TO_CHAR(COUNT(*)) AS count
FROM (
  SELECT i.hostname
  FROM ORACLE_OPT_INSTANCES i
  JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
  WHERE r.run_id = (
    SELECT MAX(r2.run_id)
    FROM ORACLE_OPT_RUNS r2
    JOIN ORACLE_OPT_INSTANCES i2 ON i2.run_id = r2.run_id
    WHERE i2.hostname = i.hostname
  )
  GROUP BY i.hostname
  HAVING TRUNC(SYSDATE - MAX(r.run_date)) BETWEEN 8 AND 30
)
UNION ALL
SELECT 
  'Current Hosts (<7d)' AS action,
  TO_CHAR(COUNT(*)) AS count
FROM (
  SELECT i.hostname
  FROM ORACLE_OPT_INSTANCES i
  JOIN ORACLE_OPT_RUNS r ON r.run_id = i.run_id
  WHERE r.run_id = (
    SELECT MAX(r2.run_id)
    FROM ORACLE_OPT_RUNS r2
    JOIN ORACLE_OPT_INSTANCES i2 ON i2.run_id = r2.run_id
    WHERE i2.hostname = i.hostname
  )
  GROUP BY i.hostname
  HAVING TRUNC(SYSDATE - MAX(r.run_date)) <= 7
);

PROMPT 
PROMPT Legend: ✓ = Current/OK, ⚠ = Review Needed, ✗ = Action Required
EOF

echo ""
echo "=============================================="
echo "Report complete. Review hosts marked with ✗ or ⚠"
echo "=============================================="
