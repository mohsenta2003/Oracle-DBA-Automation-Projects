-- =========================================================================
-- Java Footprint Audit — repo snapshot
-- Run from EU:  sqlplus mtaheri/<pwd>@dbainfo @vars/java_repo_snapshot.sql
-- Run from US:  sqlplus mtaheri/<pwd>@dbai    @vars/java_repo_snapshot.sql
-- Paste output back into chat for analysis.
-- =========================================================================
SET PAGESIZE 200 LINESIZE 220 FEEDBACK OFF VERIFY OFF TRIMSPOOL ON
COLUMN run_id           FORMAT 9999
COLUMN run_label        FORMAT A40
COLUMN run_date         FORMAT A20
COLUMN hostname         FORMAT A28
COLUMN java_version     FORMAT A18
COLUMN java_type        FORMAT A13
COLUMN install_context  FORMAT A24
COLUMN java_bin_path    FORMAT A80
COLUMN ver_status       FORMAT A10

PROMPT ============================================================
PROMPT 1) ALL SCAN RUNS
PROMPT ============================================================
SELECT run_id, run_label, TO_CHAR(run_date,'YYYY-MM-DD HH24:MI') run_date,
       total_hosts, total_installs
FROM   java_scan_runs ORDER BY run_id;

PROMPT ============================================================
PROMPT 2) HOSTS COVERED (latest run per host)
PROMPT ============================================================
SELECT hostname, MAX(run_id) latest_run
FROM   java_scan_servers
GROUP BY hostname ORDER BY hostname;

PROMPT ============================================================
PROMPT 3) VERSION DISTRIBUTION (latest per host)
PROMPT ============================================================
WITH latest AS (
  SELECT hostname, MAX(run_id) rid FROM java_scan_installs GROUP BY hostname
)
SELECT i.java_type, i.java_major, i.java_version,
       COUNT(*) installs, COUNT(DISTINCT i.hostname) hosts
FROM   java_scan_installs i JOIN latest l ON l.hostname=i.hostname AND l.rid=i.run_id
GROUP BY i.java_type, i.java_major, i.java_version
ORDER BY i.java_major DESC, installs DESC;

PROMPT ============================================================
PROMPT 4) GAP ANALYSIS (vs JAVA_VERSION_REFERENCE)
PROMPT ============================================================
WITH latest AS (
  SELECT hostname, MAX(run_id) rid FROM java_scan_installs GROUP BY hostname
)
SELECT i.java_type, i.java_major, i.java_version,
       NVL(r.latest_version,'(no ref)') ref_ver,
       CASE WHEN r.latest_version IS NULL THEN 'UNKNOWN'
            WHEN i.java_version = r.latest_version THEN 'CURRENT'
            ELSE 'OUTDATED' END ver_status,
       COUNT(*) installs, COUNT(DISTINCT i.hostname) hosts
FROM   java_scan_installs i
       JOIN latest l ON l.hostname=i.hostname AND l.rid=i.run_id
       LEFT JOIN java_version_reference r
         ON UPPER(r.vendor)=UPPER(i.java_type) AND r.major=i.java_major
GROUP BY i.java_type, i.java_major, i.java_version, r.latest_version
ORDER BY ver_status, i.java_major DESC, installs DESC;

PROMPT ============================================================
PROMPT 5) CRITICAL — Java < 8 anywhere
PROMPT ============================================================
WITH latest AS (
  SELECT hostname, MAX(run_id) rid FROM java_scan_installs GROUP BY hostname
)
SELECT i.hostname, i.java_version, i.install_context, i.java_bin_path
FROM   java_scan_installs i JOIN latest l ON l.hostname=i.hostname AND l.rid=i.run_id
WHERE  i.java_major < 8
ORDER BY i.hostname;

PROMPT ============================================================
PROMPT 6) Reference table content
PROMPT ============================================================
SELECT track_key, vendor, major, latest_version, notes
FROM   java_version_reference ORDER BY vendor, major;

EXIT
