-- ============================================================================
-- Java Footprint Audit -- Direct Repository Checks
-- ============================================================================
-- Run against US repo:  sqlplus mtaheri/<pwd>@dbai    @scripts/java_repo_checks.sql
-- Run against EU repo:  sqlplus mtaheri/<pwd>@DBAINFO @scripts/java_repo_checks.sql
--
-- All queries use latest-scan-per-host view (V_JAVA_INSTALLS_CLASSIFIED).
-- ============================================================================

SET PAGESIZE 200 LINESIZE 240 FEEDBACK ON VERIFY OFF
SET COLSEP ' | '
COLUMN HOSTNAME             FORMAT A28
COLUMN JAVA_TYPE            FORMAT A14
COLUMN JAVA_VERSION         FORMAT A16
COLUMN TARGET_JAVA_VERSION  FORMAT A16
COLUMN TARGET_STATUS        FORMAT A14
COLUMN RISK_TIER            FORMAT A8
COLUMN INSTALL_CONTEXT      FORMAT A16
COLUMN RESPONSIBLE_TEAM     FORMAT A20
COLUMN ACTION_METHOD        FORMAT A50
COLUMN JAVA_BIN_PATH        FORMAT A80
COLUMN OS_TYPE              FORMAT A20
COLUMN OS_VERSION           FORMAT A20
COLUMN CNT                  FORMAT 999999
COLUMN HOSTS                FORMAT 9999

-- ============================================================================
-- 1. OVERALL SUMMARY — installs + hosts by team and risk
-- ============================================================================
PROMPT
PROMPT === [1] Overall summary by team and risk tier ===

SELECT RESPONSIBLE_TEAM,
       RISK_TIER,
       COUNT(*)                    AS INSTALLS,
       COUNT(DISTINCT HOSTNAME)    AS HOSTS
FROM   V_JAVA_INSTALLS_CLASSIFIED
GROUP  BY RESPONSIBLE_TEAM, RISK_TIER
ORDER  BY RESPONSIBLE_TEAM,
          CASE RISK_TIER WHEN 'RED' THEN 1 WHEN 'YELLOW' THEN 2
                         WHEN 'GREEN' THEN 3 WHEN 'INFO' THEN 4 ELSE 5 END;

-- ============================================================================
-- 2. UNCLASSIFIED CHECK — must always be 0
-- ============================================================================
PROMPT
PROMPT === [2] Unclassified installs (must be 0) ===

SELECT HOSTNAME, INSTALL_CONTEXT, JAVA_VERSION, JAVA_BIN_PATH
FROM   V_JAVA_INSTALLS_CLASSIFIED
WHERE  RESPONSIBLE_TEAM = 'UNASSIGNED'
   OR  RISK_TIER = 'UNCLASSIFIED'
ORDER  BY HOSTNAME;

-- ============================================================================
-- 3. RED installs — highest priority, no patch path
-- ============================================================================
PROMPT
PROMPT === [3] RED installs (EOL / no patch path) ===

SELECT HOSTNAME, OS_TYPE, OS_VERSION,
       JAVA_TYPE, JAVA_VERSION, INSTALL_CONTEXT,
       RESPONSIBLE_TEAM, ACTION_METHOD, JAVA_BIN_PATH
FROM   V_JAVA_INSTALLS_CLASSIFIED
WHERE  RISK_TIER = 'RED'
ORDER  BY HOSTNAME, JAVA_BIN_PATH;

-- ============================================================================
-- 4. DBA PATCH TEAM summary by work queue
-- ============================================================================
PROMPT
PROMPT === [4] DBA work queues ===

SELECT
  CASE
    WHEN JAVA_BIN_PATH LIKE '%/OPatch/%'    THEN 'OPatch queue'
    WHEN TARGET_STATUS = 'BELOW_TARGET'     THEN 'Patch-cycle queue'
    WHEN JAVA_VERSION  LIKE '1.5.%'
      OR JAVA_VERSION  LIKE '1.6.%'         THEN 'Legacy queue (1.5/1.6)'
    WHEN JAVA_BIN_PATH LIKE '%/product/%'   THEN 'Oracle-home queue'
    ELSE 'Review queue'
  END                             AS WORK_QUEUE,
  RISK_TIER,
  COUNT(*)                        AS INSTALLS,
  COUNT(DISTINCT HOSTNAME)        AS HOSTS
FROM   V_JAVA_INSTALLS_CLASSIFIED
WHERE  RESPONSIBLE_TEAM = 'DBA PATCH TEAM'
GROUP  BY
  CASE
    WHEN JAVA_BIN_PATH LIKE '%/OPatch/%'    THEN 'OPatch queue'
    WHEN TARGET_STATUS = 'BELOW_TARGET'     THEN 'Patch-cycle queue'
    WHEN JAVA_VERSION  LIKE '1.5.%'
      OR JAVA_VERSION  LIKE '1.6.%'         THEN 'Legacy queue (1.5/1.6)'
    WHEN JAVA_BIN_PATH LIKE '%/product/%'   THEN 'Oracle-home queue'
    ELSE 'Review queue'
  END, RISK_TIER
ORDER  BY 1, 2;

-- ============================================================================
-- 5. OS TEAM summary — remove candidates + patch queue
-- ============================================================================
PROMPT
PROMPT === [5] OS team work queues ===

SELECT
  CASE
    WHEN ACTION_METHOD LIKE 'dnf remove%'
      OR ACTION_METHOD LIKE 'rpm -e%'   THEN 'Remove queue'
    WHEN TARGET_STATUS = 'BELOW_TARGET' THEN 'Patch queue'
    WHEN TARGET_STATUS = 'NO_TARGET'    THEN 'Legacy / no target'
    WHEN TARGET_STATUS = 'AT_TARGET'    THEN 'At target (clean)'
    ELSE 'Review'
  END                             AS WORK_QUEUE,
  COUNT(*)                        AS INSTALLS,
  COUNT(DISTINCT HOSTNAME)        AS HOSTS
FROM   V_JAVA_INSTALLS_CLASSIFIED
WHERE  RESPONSIBLE_TEAM = 'OS TEAM'
GROUP  BY
  CASE
    WHEN ACTION_METHOD LIKE 'dnf remove%'
      OR ACTION_METHOD LIKE 'rpm -e%'   THEN 'Remove queue'
    WHEN TARGET_STATUS = 'BELOW_TARGET' THEN 'Patch queue'
    WHEN TARGET_STATUS = 'NO_TARGET'    THEN 'Legacy / no target'
    WHEN TARGET_STATUS = 'AT_TARGET'    THEN 'At target (clean)'
    ELSE 'Review'
  END
ORDER  BY 1;

-- ============================================================================
-- 6. OEM / OMS / AGENT team rows
-- ============================================================================
PROMPT
PROMPT === [6] OEM team installs ===

SELECT HOSTNAME, JAVA_TYPE, JAVA_VERSION, TARGET_JAVA_VERSION,
       TARGET_STATUS, RISK_TIER, INSTALL_CONTEXT, JAVA_BIN_PATH
FROM   V_JAVA_INSTALLS_CLASSIFIED
WHERE  RESPONSIBLE_TEAM = 'OEM/OMS/AGENT TEAM'
ORDER  BY HOSTNAME, JAVA_BIN_PATH;

-- ============================================================================
-- 7. BELOW_TARGET detail — all teams
-- ============================================================================
PROMPT
PROMPT === [7] All BELOW_TARGET installs ===

SELECT HOSTNAME, RESPONSIBLE_TEAM, JAVA_TYPE,
       JAVA_VERSION, TARGET_JAVA_VERSION, INSTALL_CONTEXT, JAVA_BIN_PATH
FROM   V_JAVA_INSTALLS_CLASSIFIED
WHERE  TARGET_STATUS = 'BELOW_TARGET'
ORDER  BY RESPONSIBLE_TEAM, HOSTNAME, JAVA_BIN_PATH;

-- ============================================================================
-- 8. NO_TARGET gaps — installs with no reference version (review needed)
-- ============================================================================
PROMPT
PROMPT === [8] NO_TARGET gaps (no reference version exists) ===

SELECT HOSTNAME, RESPONSIBLE_TEAM, JAVA_TYPE,
       JAVA_VERSION, INSTALL_CONTEXT, ACTION_METHOD, JAVA_BIN_PATH
FROM   V_JAVA_INSTALLS_CLASSIFIED
WHERE  TARGET_STATUS = 'NO_TARGET'
ORDER  BY RESPONSIBLE_TEAM, HOSTNAME;

-- ============================================================================
-- 9. JAVA_ACTION_RULES — current rule set
-- ============================================================================
PROMPT
PROMPT === [9] Active classification rules ===

SELECT RULE_ID, PATH_PATTERN, PRIORITY, RISK_TIER,
       SUBSTR(ACTION_METHOD,1,60) AS ACTION_METHOD,
       OWNER
FROM   JAVA_ACTION_RULES
ORDER  BY PRIORITY;

-- ============================================================================
-- 10. JAVA_VERSION_REFERENCE — current target versions
-- ============================================================================
PROMPT
PROMPT === [10] Java version reference (target versions) ===

SELECT TRACK_KEY, VENDOR, MAJOR,
       LATEST_VERSION, EOL_DATE, UPDATED_AT
FROM   JAVA_VERSION_REFERENCE
ORDER  BY VENDOR, MAJOR DESC;

-- ============================================================================
-- 11. SCAN RUN HISTORY — last 10 runs
-- ============================================================================
PROMPT
PROMPT === [11] Last 10 scan runs ===

SELECT RUN_ID,
       SUBSTR(RUN_LABEL,1,40)                          AS RUN_LABEL,
       TO_CHAR(RUN_DATE,'YYYY-MM-DD HH24:MI:SS')       AS RUN_DATE,
       NVL(TOTAL_HOSTS,0)                              AS HOSTS,
       NVL(TOTAL_INSTALLS,0)                           AS INSTALLS
FROM   JAVA_SCAN_RUNS
ORDER  BY RUN_ID DESC
FETCH  FIRST 10 ROWS ONLY;

-- ============================================================================
-- 12. PER-HOST latest status — one row per host
-- ============================================================================
PROMPT
PROMPT === [12] Per-host worst risk tier (latest scan) ===

SELECT HOSTNAME,
       MAX(CASE RISK_TIER WHEN 'RED'    THEN 4
                          WHEN 'YELLOW' THEN 3
                          WHEN 'GREEN'  THEN 2
                          WHEN 'INFO'   THEN 1 ELSE 0 END) AS WORST_SCORE,
       MAX(CASE RISK_TIER WHEN 'RED'    THEN 'RED'
                          WHEN 'YELLOW' THEN 'YELLOW'
                          WHEN 'GREEN'  THEN 'GREEN'
                          WHEN 'INFO'   THEN 'INFO'
                          ELSE 'UNCLASSIFIED' END)          AS WORST_TIER,
       COUNT(*)                                             AS TOTAL_INSTALLS,
       SUM(CASE WHEN RISK_TIER='RED'    THEN 1 ELSE 0 END) AS RED_CNT,
       SUM(CASE WHEN RISK_TIER='YELLOW' THEN 1 ELSE 0 END) AS YELLOW_CNT,
       SUM(CASE WHEN RISK_TIER='GREEN'  THEN 1 ELSE 0 END) AS GREEN_CNT
FROM   V_JAVA_INSTALLS_CLASSIFIED
GROUP  BY HOSTNAME
ORDER  BY WORST_SCORE DESC, HOSTNAME;

-- ============================================================================
-- 13. DUPLICATE PATH CHECK — same host + base path scanned twice
-- ============================================================================
PROMPT
PROMPT === [13] Potential duplicate installs (same host + base path) ===

SELECT HOSTNAME,
       REGEXP_REPLACE(JAVA_BIN_PATH,'(/jre)?/bin/java$','') AS BASE_PATH,
       COUNT(*) AS CNT
FROM   V_JAVA_INSTALLS_CLASSIFIED
GROUP  BY HOSTNAME,
          REGEXP_REPLACE(JAVA_BIN_PATH,'(/jre)?/bin/java$','')
HAVING COUNT(*) > 1
ORDER  BY HOSTNAME, BASE_PATH;

-- ============================================================================
-- 14. QUICK HEALTH CHECK — counts only (for a fast sanity check)
-- ============================================================================
PROMPT
PROMPT === [14] Quick health check ===

SELECT 'Total installs'           AS METRIC, COUNT(*)                              AS VALUE FROM V_JAVA_INSTALLS_CLASSIFIED
UNION ALL
SELECT 'Total hosts',                         COUNT(DISTINCT HOSTNAME)              FROM V_JAVA_INSTALLS_CLASSIFIED
UNION ALL
SELECT 'RED',                                 COUNT(*) FROM V_JAVA_INSTALLS_CLASSIFIED WHERE RISK_TIER='RED'
UNION ALL
SELECT 'YELLOW',                              COUNT(*) FROM V_JAVA_INSTALLS_CLASSIFIED WHERE RISK_TIER='YELLOW'
UNION ALL
SELECT 'GREEN',                               COUNT(*) FROM V_JAVA_INSTALLS_CLASSIFIED WHERE RISK_TIER='GREEN'
UNION ALL
SELECT 'INFO',                                COUNT(*) FROM V_JAVA_INSTALLS_CLASSIFIED WHERE RISK_TIER='INFO'
UNION ALL
SELECT 'UNCLASSIFIED',                        COUNT(*) FROM V_JAVA_INSTALLS_CLASSIFIED WHERE RISK_TIER='UNCLASSIFIED'
UNION ALL
SELECT 'NO_TARGET gaps',                      COUNT(*) FROM V_JAVA_INSTALLS_CLASSIFIED WHERE TARGET_STATUS='NO_TARGET'
UNION ALL
SELECT 'AT_TARGET (clean)',                   COUNT(*) FROM V_JAVA_INSTALLS_CLASSIFIED WHERE TARGET_STATUS='AT_TARGET'
UNION ALL
SELECT 'Action rules loaded',                 COUNT(*) FROM JAVA_ACTION_RULES
UNION ALL
SELECT 'Reference versions loaded',           COUNT(*) FROM JAVA_VERSION_REFERENCE;

EXIT;
