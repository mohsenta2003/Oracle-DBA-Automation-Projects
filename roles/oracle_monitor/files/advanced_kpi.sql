-- =============================================================================
-- Name: advanced_kpi.sql
-- Goal: Capture advanced Performance, APP DBA, and SYSDBA KPIs with Recommendations
-- =============================================================================
SET TERMOUT OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGESIZE 0
SET LINESIZE 500
SET TRIMSPOOL ON
SET VERIFY OFF

-- 1. TOP 10 WAIT EVENTS (by time waited)
PROMPT [TOP_WAITS_START]
SELECT 'Event: ' || event || ' | Time: ' || time_waited || 's'
FROM (SELECT event, ROUND(time_waited/100,2) as time_waited 
      FROM v$system_event 
      WHERE wait_class != 'Idle' 
      ORDER BY time_waited DESC)
WHERE rownum <= 10;
PROMPT [TOP_WAITS_END]

-- 2. TOP 10 HIGH LOAD SQL
PROMPT [TOP_SQL_START]
SELECT 'SQL_ID: ' || sql_id || ' | CPU: ' || ROUND(cpu_time/1000000,2) || 's | Gets: ' || buffer_gets
FROM (SELECT sql_id, cpu_time, buffer_gets 
      FROM v$sqlarea 
      ORDER BY cpu_time DESC)
WHERE rownum <= 10;
PROMPT [TOP_SQL_END]

-- 3. INVALID OBJECTS (APP DBA)
PROMPT [INVALID_OBJECTS_START]
SELECT owner || '.' || object_name || ' (' || object_type || ')'
FROM dba_objects 
WHERE status = 'INVALID' 
AND owner NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'OUTLN', 'MDSYS', 'ORDSYS')
AND rownum <= 20;
PROMPT [INVALID_OBJECTS_END]

-- 4. STALE STATISTICS (APP DBA) - Top 10 candidates
PROMPT [STALE_STATS_START]
SELECT 'Table: ' || owner || '.' || table_name || ' | Advisor: EXEC DBMS_STATS.GATHER_TABLE_STATS(''' || owner || ''',''' || table_name || ''');'
FROM dba_tab_statistics 
WHERE stale_stats = 'YES' 
AND owner NOT IN ('SYS', 'SYSTEM', 'DBSNMP')
AND rownum <= 10;
PROMPT [STALE_STATS_END]

-- 5. MISSING FOREIGN KEY INDEXES (APP DBA & Stability)
PROMPT [MISSING_FK_INDEX_START]
SELECT 'FK: ' || owner || '.' || constraint_name || ' (Table: ' || table_name || ') | Advisor: CREATE INDEX ' || owner || '.IDX_' || table_name || '_FK ON ' || owner || '.' || table_name || '(' || column_name || ') TABLESPACE USERS PARALLEL 4;'
FROM (
  SELECT a.owner, a.table_name, a.constraint_name, a.column_name
  FROM dba_cons_columns a
  JOIN dba_constraints c ON a.constraint_name = c.constraint_name AND a.owner = c.owner
  WHERE c.constraint_type = 'R'
  AND NOT EXISTS (
    SELECT 1 FROM dba_ind_columns i 
    WHERE i.table_owner = a.owner 
    AND i.table_name = a.table_name 
    AND i.column_name = a.column_name
    AND i.column_position = 1
  )
) WHERE rownum <= 10;
PROMPT [MISSING_FK_INDEX_END]

-- 6. RESOURCE ADVICE (Shaping/Consolidation)
PROMPT [RESOURCE_ADVICE_START]
SELECT 'Target: SGA | Suggestion: Increase to ' || sga_size || 'M | Est. DB Time Save: ' || ROUND((1-estd_db_time_factor)*100,1) || '%'
FROM v$sga_target_advice 
WHERE estd_db_time_factor < 0.9 -- Only suggest if > 10% gain
AND rownum = 1
UNION ALL
SELECT 'Target: PGA | Suggestion: Increase to ' || pga_target_for_estimate/1024/1024 || 'M | Est. Overalloc: ' || estd_overalloc_count
FROM v$pga_target_advice 
WHERE estd_overalloc_count > 0
AND rownum = 1;
PROMPT [RESOURCE_ADVICE_END]

-- 7. HOT IO SEGMENTS (Performance)
PROMPT [HOT_IO_START]
SELECT 'Segment: ' || owner || '.' || object_name || ' (' || object_type || ') | IO Ops: ' || (physical_reads + physical_writes)
FROM (SELECT owner, object_name, object_type, (logical_reads + physical_reads + physical_writes) as total_io, physical_reads, physical_writes
      FROM v$segment_statistics 
      WHERE owner NOT IN ('SYS', 'SYSTEM')
      ORDER BY (logical_reads + physical_reads + physical_writes) DESC)
WHERE rownum <= 5;
PROMPT [HOT_IO_END]

-- 8. BACKUP HISTORY (RMAN)
PROMPT [BACKUP_HISTORY_START]
SELECT 'Type: ' || nvl(input_type,'N/A') || ' | Status: ' || nvl(status,'N/A') || ' | Start: ' || TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI') || ' | End: ' || TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI')
FROM (SELECT input_type, status, start_time, end_time 
      FROM v$rman_backup_job_details 
      WHERE input_type IN ('DB FULL', 'DB INCR')
      ORDER BY start_time DESC)
WHERE rownum <= 5;
SELECT 'No backup records found via RMAN' FROM dual WHERE NOT EXISTS (SELECT 1 FROM v$rman_backup_job_details WHERE input_type IN ('DB FULL', 'DB INCR'));
PROMPT [BACKUP_HISTORY_END]

-- 9. PATCH HISTORY (Registry)
PROMPT [PATCH_HISTORY_START]
SELECT 'Action: ' || nvl(action,'N/A') || ' | Version: ' || nvl(version,'N/A') || ' | Date: ' || TO_CHAR(action_time, 'YYYY-MM-DD HH24:MI')
FROM (SELECT action, version, action_time 
      FROM dba_registry_history 
      ORDER BY action_time DESC)
WHERE rownum <= 5;
SELECT 'No patch history found in dba_registry_history' FROM dual WHERE NOT EXISTS (SELECT 1 FROM dba_registry_history);
PROMPT [PATCH_HISTORY_END]

-- 10. ACTIVE WAIT HISTORY (Last 24 Hours)
PROMPT [WAIT_HISTORY_START]
SELECT 'Wait Class: ' || wait_class || ' | Percent: ' || ROUND(cnt/total*100,1) || '%'
FROM (
  SELECT wait_class, count(*) as cnt, sum(count(*)) over () as total
  FROM v$active_session_history
  WHERE sample_time > sysdate - 1
  AND wait_class IS NOT NULL
  GROUP BY wait_class
  ORDER BY cnt DESC
) WHERE rownum <= 5;
PROMPT [WAIT_HISTORY_END]

-- 11. PERFORMANCE RATIOS (Efficiency)
PROMPT [PERF_RATIOS_START]
SELECT 'Metric: Buffer Cache Hit Ratio | Value: ' || ROUND((1-(phy.value / (cur.value + con.value)))*100,2) || '%'
FROM v$sysstat phy, v$sysstat cur, v$sysstat con
WHERE phy.name = 'physical reads' AND cur.name = 'db block gets' AND con.name = 'consistent gets'
UNION ALL
SELECT 'Metric: Library Cache Hit Ratio | Value: ' || ROUND(SUM(pins-reloads)/SUM(pins)*100,2) || '%'
FROM v$librarycache;
PROMPT [PERF_RATIOS_END]

-- 12. REDO LOG HEALTH (Log Switches last 24h)
PROMPT [REDO_LOG_START]
SELECT 'Metric: Log Switches (24h) | Value: ' || count(*)
FROM v$log_history 
WHERE first_time > sysdate - 1;
SELECT 'Metric: Redo Allocation Retries | Value: ' || value 
FROM v$sysstat WHERE name = 'redo buffer allocation retries';
PROMPT [REDO_LOG_END]

-- 13. STABILITY RISK: SEQUENCE EXHAUSTION (>85% used)
PROMPT [SEQ_RISK_START]
SELECT 'Sequence: ' || sequence_owner || '.' || sequence_name || ' | Used: ' || ROUND((last_number/max_value)*100,2) || '%'
FROM dba_sequences 
WHERE max_value > 0 
AND (last_number/max_value) > 0.85
AND sequence_owner NOT IN ('SYS', 'SYSTEM');
PROMPT [SEQ_RISK_END]

-- 14. SESSION AUDIT (Load Profile)
PROMPT [SESSION_AUDIT_START]
SELECT 'Status: ' || status || ' (' || type || ') | Count: ' || count(*)
FROM v$session 
GROUP BY status, type;
PROMPT [SESSION_AUDIT_END]

-- 15. SECURITY AUDIT (Privileged Access)
PROMPT [SECURITY_AUDIT_START]
SELECT 'Grantee: PUBLIC | Privilege: ' || privilege || ' | Admin: ' || admin_option
FROM dba_sys_privs 
WHERE grantee = 'PUBLIC' 
AND privilege IN ('DBA', 'ANY PRIVILEGE', 'UNLIMITED TABLESPACE')
AND rownum <= 10;
PROMPT [SECURITY_AUDIT_END]

-- 16. RESOURCE LIMITS (Capacity)
PROMPT [RESOURCE_LIMITS_START]
SELECT 'Resource: ' || resource_name || ' | Current: ' || current_utilization || ' | Max: ' || limit_value || ' | Pct: ' || ROUND(current_utilization/limit_value*100,2) || '%'
FROM v$resource_limit 
WHERE resource_name IN ('processes', 'sessions', 'enqueue_locks', 'enqueue_resources')
AND limit_value > 0;
PROMPT [RESOURCE_LIMITS_END]

-- 17. RECOVERY HEALTH (FRA Usage)
PROMPT [FRA_HEALTH_START]
SELECT 'Name: ' || name || ' | Pct Used: ' || space_used/space_limit*100 || '% | Space: ' || ROUND(space_limit/1024/1024/1024,2) || 'GB'
FROM v$recovery_file_dest;
PROMPT [FRA_HEALTH_END]

-- 18. SHARED POOL DIAGNOSTICS (ORAchk)
PROMPT [SHARED_POOL_START]
SELECT 'Metric: Library Cache Reloads | Value: ' || SUM(reloads) FROM v$librarycache;
SELECT 'Metric: Dictionary Cache Hit Ratio | Value: ' || ROUND(SUM(gets-getmisses)/SUM(gets)*100,2) || '%' FROM v$rowcache;
PROMPT [SHARED_POOL_END]

-- 19. CONTENTION DIAGNOSTICS (Latch/Mutex)
PROMPT [CONTENTION_START]
SELECT 'Latch: ' || name || ' | Sleeps: ' || sleeps || ' | Gets: ' || gets
FROM (SELECT n.name, sleeps, gets FROM v$latch l, v$latchname n WHERE l.latch# = n.latch# ORDER BY sleeps DESC)
WHERE rownum <= 5;
PROMPT [CONTENTION_END]

-- 21. TABLE STATISTICS (Gather Dates)
PROMPT [STATS_GATHER_START]
SELECT 'Table: ' || owner || '.' || table_name || ' | Last Analyzed: ' || TO_CHAR(last_analyzed, 'YYYY-MM-DD')
FROM (SELECT owner, table_name, last_analyzed FROM dba_tab_statistics 
      WHERE owner NOT IN ('SYS','SYSTEM') ORDER BY last_analyzed ASC NULLS FIRST)
WHERE rownum <= 10;
PROMPT [STATS_GATHER_END]

-- 22. INDEX HEALTH (Rebuild Candidates)
PROMPT [INDEX_REBUILD_START]
SELECT 'Index: ' || owner || '.' || index_name || ' (Table: ' || table_name || ') | Factor: ' || clustering_factor || ' | Blocks: ' || blevel
FROM (SELECT owner, index_name, table_name, clustering_factor, blevel 
      FROM dba_indexes 
      WHERE owner NOT IN ('SYS','SYSTEM') 
      AND blevel >= 3
      ORDER BY blevel DESC)
WHERE rownum <= 10;
PROMPT [INDEX_REBUILD_END]

-- 23. SORT SEGMENTS (Usage)
PROMPT [SORT_SEGMENTS_START]
SELECT 'TS: ' || tablespace_name || ' | Used: ' || ROUND(used_blocks*8192/1024/1024,2) || 'MB | Max: ' || ROUND(total_blocks*8192/1024/1024,2) || 'MB'
FROM v$sort_segment;
PROMPT [SORT_SEGMENTS_END]

-- 24. DATABASE EXTRA INFO
PROMPT [DB_EXTRA_START]
SELECT 'Startup Time: ' || TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') FROM v$instance;
SELECT 'Archivelog Mode: ' || log_mode FROM v$database;
SELECT 'DB ID: ' || dbid || ' | Created: ' || TO_CHAR(created, 'YYYY-MM-DD') FROM v$database;
SELECT 'Global Stats Gather: ' || TO_CHAR(MAX(start_time), 'YYYY-MM-DD') FROM dba_optstat_operations WHERE operation = 'gather_database_stats';
PROMPT [DB_EXTRA_END]

EXIT;
