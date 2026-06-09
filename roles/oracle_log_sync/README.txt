ORACLE LOG SYNC ROLE FOR AIX
============================

This Ansible role automates the synchronization of Oracle logs (Alert, Audit, and Listener logs) from AIX servers to a centralized location (usually an NFS share). It is designed for robust operation in enterprise environments with strict security controls and limited user access.

FEATURES
--------
- Auto-Discovery: Automatically detects Oracle users, active database instances, and listeners.
- Robust Log Discovery:
    - Uses v$diag_info and v$parameter for primary discovery.
    - Native Fallback: Automatically scans for alert and trace directories if SQL queries fail or paths are non-standard.
    - Listener Logic: Robustly handles listener paths by ignoring case-sensitivity issues on AIX.
- ELK Stack Optimization:
    - Trace Exclusion: Excludes bulky .trc and .trm files by default.
    - Focus: Syncs only high-value logs (alert_*.log, *.xml, *.aud).
- Reporting System:
    - Summary Report: Generates a clear summary of all transferred files.
    - Detailed History: Appends every run to a persistent _history.log file for each host.
    - Per-Instance Reports: Creates individual history logs for each instance with full file paths.
- Limited Access Support:
    - Fully compatible with remote_user: oracle (no root required).
    - Uses user-writable paths (default: /tmp/oracle_log_sync/) for scripts and logs.
- Instance Filtering: Allows excluding specific instances (e.g., +ASM, -MGMTDB) via configuration.
- Continuous Sync: Generates recommended crontab entries for scheduling on your control node (manual setup).
- Post-Run Summary: Always displays a quick sync summary showing files synced per instance/listener.

REQUIREMENTS
------------
- AIX Operating System.
- rsync must be installed on the target AIX servers.
- Oracle environment must be active (at least one instance/listener running for discovery).

ROLE VARIABLES
--------------
Variable              | Default                       | Description
--------------------- | ----------------------------- | -----------------------------------------------------
nfs_log_path          | /local/utils/AIX_ORA_LOGS     | Root destination path for logs.
sync_mode             | initial                       | "initial" (full) or "incremental" (uses --update).
setup_cron            | false                         | If true, deploys sync script and displays crontab config.
cron_interval         | 15                            | Cron interval in minutes.
log_retention_days    | 30                            | Number of days to keep logs on the destination.
compress_logs         | true                          | Whether to compress logs older than 1 day.
sync_alert_logs       | true                          | Sync database alert and trace logs.
sync_listener_logs    | true                          | Sync listener logs.
sync_audit_logs       | true                          | Sync database audit logs.
job_type              | full                          | full, sync_only, or report_only.
skip_instances        | ["-MGMTDB", "+ASM"]           | List of SID patterns to skip during auto-detection.
oracle_script_path    | /tmp/oracle_log_sync          | Writable path for scripts/logs on the remote host.
local_report_dir      | ../reports                    | Directory on control node to save reports.

USAGE EXAMPLES
--------------

1. Initial Full Sync (Interactive)
   ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_prod -k -e "nfs_log_path=/nfs/storage/logs"

2. Sync Only (Fast, No Reports)
   ansible-playbook playbooks/sync_oracle_logs.yml -l dcunx218,dcunx219 -e "job_type=sync_only"

3. Generate Crontab Config (Manual Setup)
   This deploys the sync script and DISPLAYS recommended crontab entries.
   It does NOT modify any crontab automatically.
   ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_prod -k -e "setup_cron=true cron_interval=15"
   
   The output shows three scheduling options:
   - Option A: Sync only (fast, every N minutes)
   - Option B: Full run with reports (hourly)
   - Option C: Combined (sync frequently + report hourly)
   
   Copy the desired line and add it to your control node's crontab: crontab -e

4. Exclude Multiple ASM Instances
   ansible-playbook playbooks/sync_oracle_logs.yml -e '{"skip_instances": ["+ASM1", "+ASM2", "-MGMTDB"]}'

5. Force Resync (Reload from Scratch)
   To re-transfer all files regardless of timestamps:
   ansible-playbook playbooks/sync_oracle_logs.yml -e "force_resync=true"

6. Specific Testing Example (dcunx218 & dcunx219)
   ansible-playbook playbooks/sync_oracle_logs.yml -i tests/test_inventory.ini -k -e "force_resync=true"

7. Skip Audit Logs (Selective Sync)
   ansible-playbook playbooks/sync_oracle_logs.yml -e "sync_audit_logs=false"

UI MODERNIZATION
----------------

1. Dashboard 2.0 (Modern UI)
   The HTML dashboard (reports/<DATE>/log_sync_jobs/index.html) features:
   - KPI Cards: Instant view of Total Hosts, Active Status, and critical alerts.
   - Status Pills: Color-coded badges for Lag (Green/Yellow/Red).
   - Glassmorphism Design: Modern, clean aesthetics with hover effects.
   - Real-time Monitoring: Shows latest status per host (dedup multiple daily runs).

2. Job Detail Views
   Each instance/listener has a detailed report showing:
   - NFS Log Age: The "True Lag" (how old the backup is on the NFS share).
   - Sync Verification: Side-by-side Source (AIX) vs Destination (NFS) comparison.
   - Visual Alerts: Indicators for high lag, large files, or excessive audit counts.

AGILE OPERATION MODES
---------------------
Mode          | Description                                    | Use Case
------------- | ---------------------------------------------- | -----------------------------------------
full          | Syncs all logs AND generates HTML reports.     | Daily/Hourly runs. (Default)
sync_only     | Syncs logs ONLY. Skips report generation.      | High-frequency cron (every 15 mins).
report_only   | Generates reports from existing NFS data.      | Ad-hoc dashboard updates.

SELECTIVE SYNC CONTROL
----------------------
Enable/disable specific log types (Default: true):
- sync_alert_logs
- sync_audit_logs
- sync_listener_logs

STATE MANAGEMENT (LIFECYCLE)
-----------------------------
- sync_state.json: Tracks "Base Time" (creation) and "Last Sync Time" per instance/listener.
- sync_history.log: Append-only audit trail of every file transferred.

POST-RUN SUMMARY
-----------------
After every run (including sync_only), the playbook displays a quick summary:

    ================================================================
    SYNC SUMMARY: dcunx218
    Time: 2026-02-17T14:47:00Z
    Mode: sync_only | Sync Mode: initial
    ================================================================
    INSTANCES (2):
      d1cms: 3 alert, 12 audit files synced
      d1prd: 1 alert, 5 audit files synced

    LISTENERS (1):
      LSNR_D1CMS: 2 files synced

    DESTINATION: /local/utils/AIX_ORA_LOGS/dcunx218/
    ================================================================

SCHEDULING (CONTROL NODE CRONTAB)
---------------------------------
The playbook does NOT auto-configure crontab on any machine.
Run with -e "setup_cron=true" to see recommended crontab entries.
Add them manually to your control node's crontab (crontab -e).

Example crontab entries:

  # Option A: Sync every 15 minutes (fast, no reports)
  */15 * * * * cd /path/to/project && ansible-playbook playbooks/sync_oracle_logs.yml -e "job_type=sync_only" -l dcunx218,dcunx219

  # Option B: Full run with reports (hourly)
  0 * * * * cd /path/to/project && ansible-playbook playbooks/sync_oracle_logs.yml -e "job_type=full" -l dcunx218,dcunx219

  # Option C: Combined (sync often + report hourly)
  */15 * * * * cd /path/to/project && ansible-playbook playbooks/sync_oracle_logs.yml -e "job_type=sync_only" -l dcunx218,dcunx219
  0 * * * *   cd /path/to/project && ansible-playbook playbooks/sync_oracle_logs.yml -e "job_type=report_only" -l dcunx218,dcunx219

REPORTING & STATUS
------------------
1. Summary Report: reports/<TIMESTAMP>/<HOSTNAME>/log_sync_summary.txt
2. Host History: reports/data/<HOSTNAME>_history.log
3. Instance History: reports/data/<SID>_history.log (full file paths)

PROFESSIONAL ENHANCEMENTS
-------------------------
1. HTML Status Dashboard: reports/<DATE>/log_sync_jobs/index.html
2. Consolidated Summary: Daily_Execution_Summary.txt
3. Advanced Reporting & Metrics: Interactive Dashboard with Search/Sort.
4. Log Maintenance Playbook: playbooks/maintain_logs.yml

RUNNING WITH LIMITED ACCESS (AD USERS)
--------------------------------------
- No Root Required: Scripts and logs use user-writable paths (/tmp/oracle_log_sync/).
- User-Level Cron: Schedule on the control node crontab (not the target).
- Nesting: Logs organized by hostname for safe multi-server aggregation.
