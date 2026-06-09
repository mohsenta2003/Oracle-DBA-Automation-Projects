-- Quick One-Line Check: Compare Latest Run vs All Time Host Counts
-- Usage: Copy and paste into SQL*Plus session

-- Quick Summary
SELECT 
  'Latest Run: ' || MAX(run_id) || ' (' || TO_CHAR(MAX(run_date), 'YYYY-MM-DD') || ')' AS info
FROM ORACLE_OPT_RUNS;

-- Latest Run Host Count by Platform
SELECT 
  'Latest Run' AS scope,
  CASE
    WHEN UPPER(i.os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' AND UPPER(i.region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(i.os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
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
    ELSE 'Other'
  END
UNION ALL
SELECT 
  'All Time' AS scope,
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' AND UPPER(region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END AS platform,
  COUNT(DISTINCT hostname) AS hosts,
  0 AS instances
FROM ORACLE_OPT_INSTANCES
GROUP BY
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' AND UPPER(region) LIKE '%EU%' THEN 'EU-Linux'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'US-Linux'
    ELSE 'Other'
  END
ORDER BY platform, scope DESC;

-- List all hosts in latest run
SELECT 
  hostname,
  CASE
    WHEN UPPER(os_type) = 'AIX' THEN 'AIX'
    WHEN UPPER(os_type) LIKE '%LINUX%' THEN 'Linux'
    ELSE os_type
  END AS platform,
  NVL(region, 'NULL') AS region,
  COUNT(*) AS instances
FROM ORACLE_OPT_INSTANCES
WHERE run_id = (SELECT MAX(run_id) FROM ORACLE_OPT_RUNS)
GROUP BY hostname, os_type, region
ORDER BY platform, hostname;
