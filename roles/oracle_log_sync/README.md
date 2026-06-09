# Oracle Log Sync Role for AIX

This Ansible role automates the synchronization of Oracle logs (Alert, Audit, and Listener logs) from AIX servers to a centralized location (usually an NFS share). It is designed for robust operation in enterprise environments with strict security controls and limited user access.

## Features

- **Auto-Discovery**: Automatically detects Oracle users, active database instances, and listeners.
- **Robust Log Discovery**: 
    - Uses `v$diag_info` and `v$parameter` for primary discovery.
    - **Native Fallback**: Automatically scans for `alert` and `trace` directories if SQL queries fail or paths are non-standard.
    - **Listener Logic**: Robustly handles listener paths by ignoring case-sensitivity issues on AIX (finding `trace` OR `alert` directories).
- **ELK Stack Optimization**: 
    - **Trace Exclusion**: Excludes bulky `.trc` and `.trm` files by default to save bandwidth and storage.
    - **Focus**: Syncs only high-value logs (`alert_*.log`, `*.xml`, `*.aud`) for efficient ELK ingestion.
- **Reporting System**:
    - **Summary Report**: Generates a clear summary of all transferred files.
    - **Detailed History**: Appends every run to a persistent `_history.log` file for each host.
    - **Per-Instance Reports**: Creates individual history logs for each instance (e.g., `d1cms_history.log`) with full file paths.
- **Limited Access Support**: 
    - Fully compatible with `remote_user: oracle` (no root required).
    - Uses user-writable paths (default: `/tmp/oracle_log_sync/`) for scripts and logs.
- **Instance Filtering**: Allows excluding specific instances (e.g., `+ASM`, `-MGMTDB`) via configuration.
- **Continuous Sync**: Generates recommended crontab entries for scheduling on your **control node** (manual setup).

## Requirements

- **AIX** Operating System.
- **rsync** must be installed on the target AIX servers.
- **Oracle** environment must be active (at least one instance/listener running for discovery).

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nfs_log_path` | `/local/utils/AIX_ORA_LOGS` | Root destination path for logs. |
| `sync_mode` | `initial` | `initial` (full) or `incremental` (uses `--update`). |
| `setup_cron` | `false` | If `true`, deploys sync script to target and displays recommended crontab entries. |
| `cron_interval` | `15` | Cron interval in minutes. |
| `log_retention_days` | `30` | Number of days to keep logs on the destination. |
| `compress_logs` | `true` | Whether to compress logs older than 1 day. |
| `sync_alert_logs` | `true` | Sync database alert and trace logs. |
| `sync_listener_logs` | `true` | Sync listener logs. |
| `sync_audit_logs` | `true` | Sync database audit logs. |
| `skip_instances` | `["-MGMTDB", "+ASM"]` | List of SID patterns to skip during auto-detection. |
| `oracle_script_path` | `/tmp/oracle_log_sync` | Writable path for scripts/logs on the remote host. |
| `local_report_dir` | `../reports` | Directory on control node to save reports. |

## Usage Examples

### Initial Full Sync (Interactive)
```bash
# Run as the oracle user (remote_user is set to oracle by default in the playbook)
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_prod -k -e "nfs_log_path=/nfs/storage/logs"
```

### Generate Crontab Config (Manual Setup)
This deploys the sync script to the target hosts and **displays** recommended crontab entries.
You then copy the output and add it to your **control node's** crontab manually (`crontab -e`).
```bash
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_prod -k -e "setup_cron=true cron_interval=15"
```
The output will show three scheduling options:
- **Option A**: Sync only (fast, every N minutes)
- **Option B**: Full run with reports (hourly)
- **Option C**: Combined (sync frequently + report hourly)

### Exclude Multiple ASM Instances
```bash
ansible-playbook playbooks/sync_oracle_logs.yml -e '{"skip_instances": ["+ASM1", "+ASM2", "-MGMTDB"]}'
```

### Force Resync (Reload from Scratch)
To re-transfer all files regardless of timestamps (useful for corruption or initial re-seed):
```bash
ansible-playbook playbooks/sync_oracle_logs.yml -e "force_resync=true"
```

### Specific Testing Example (dcunx218 & dcunx219)
To run a forced resync test specifically on the target servers `dcunx218` and `dcunx219`:
```bash
# Ensure tests/test_inventory.ini exists with the two hosts
ansible-playbook playbooks/sync_oracle_logs.yml -i tests/test_inventory.ini -k -e "force_resync=true"
```

## UI Modernization & Continuous Sync

### 1. Dashboard 2.0 (Modern UI)
The new HTML dashboard (`reports/<DATE>/log_sync_jobs/index.html`) features:
- **KPI Cards**: Instant view of Total Hosts, Active Status, and critical alerts.
- **Status Pills**: Color-coded badges for Lag:
  - **Synced** (Green): Log updated < 1 min ago.
  - **< 1h** (Green): Log updated within the last hour.
  - **< 24h** (Yellow): Log updated within the last day.
  - **> 24h** (Red): Log is stale.
  - **Missing** (Red): Log file not found on NFS share (was "Never").
- **Glassmorphism Design**: Modern, clean aesthetics with hover effects and smooth transitions.
- **Real-time Monitoring**: The dashboard intelligently filters daily logs to show the **latest status** for each host, even if the sync runs multiple times a day.

### 2. Job Detail Views
Each instance and listener has a dedicated detailed report (linked from the main dashboard) that follows the same modern design language, showing:
- **NFS Log Age**: The "True Lag" - calculating how old the backup file on the NFS share is.
- **Sync Verification**: A side-by-side comparison table of **Source (AIX)** vs **Destination (NFS)** file attributes (Size, Path, Age) to prove the sync succeeded.
- **Visual Alerts**: Immediate visual indicators for high lag, large files, or excessive audit generation.
- **Smart Listener Detection**: Automatically detects the latest listener log file (either `listener.log` or `.xml`) on the NFS share for accurate verification.

### 2. Agile Operation Modes
The playbook now supports flexible operation modes for different use cases:

| Mode | Description | Use Case |
| :--- | :--- | :--- |
| **`full`** (Default) | Syncs all logs AND generates HTML reports. | Daily/Hourly management runs. |
| **`sync_only`** | Syncs logs ONLY. Skips report generation. | High-frequency cron jobs (e.g., every 15 mins). |
| **`report_only`** | Generates reports from existing NFS data. No sync. | Ad-hoc dashboard updates or testing. |

**Usage:**
```bash
ansible-playbook playbooks/sync_oracle_logs.yml -e "job_type=sync_only"
```

### 3. Selective Sync Control
You can enable/disable specific log types using these variables (Default: `true`):
*   `sync_alert_logs`
*   `sync_audit_logs`
*   `sync_listener_logs`

**Example:** Skip audit logs during a run:
```bash
ansible-playbook playbooks/sync_oracle_logs.yml -e "sync_audit_logs=false"
```

### 6. Advanced State Management (Lifecycle)
The system now maintains extensive metadata directly on the NFS share for lifecycle management:
- **`sync_state.json`**: A JSON file tracking the "Base Time" (creation date) and "Last Sync Time" for each instance/listener. useful for automated lifecycle policies.
- **`sync_history.log`**: A continuous, append-only log file listing every single file transferred and its exact sync timestamp.



## Reporting & Status

The role generates comprehensive reports on the **control node** (where Ansible runs):

1.  **Summary Report**: `reports/<TIMESTAMP>/<HOSTNAME>/log_sync_summary.txt`
    - Snapshot of the specific run.
2.  **Host History**: `reports/<HOSTNAME>_history.log`
    - Cumulative log of all runs for the host.
3.  **Instance History**: `reports/<SID>_history.log`
    - **Granular Detail**: Dedicated history file for *each* instance.
    - **Full Paths**: Lists the absolute path of every synced file (e.g., `/u01/.../alert_prod.log`).

## Logical Flow Map

```text
╔═════════════════════════════════════════════════════════════════════════════╗
║                         SYNC_ORACLE_LOGS.YML                                ║
║                         Target: AIX Servers                                 ║
║                                                                             ║
║  PURPOSE: Discover and sync Oracle alert, listener, and audit logs to NFS  ║
║  DEFAULT NFS: /local/utils/AIX_ORA_LOGS                                     ║
╚═════════════════════════════════════════════════════════════════════════════╝
                                    │
                    ┌───────────────┴───────────────┐
                    │  PLAYBOOK ENTRY POINT         │
                    │  ↓                            │
                    │  roles/oracle_log_sync        │
                    └───────────────┬───────────────┘
                                    │
════════════════════════════════════╪═══════════════════════════════════════════
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 1: VALIDATION & ENVIRONMENT CHECK                    [main.yml:1-60]   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────┐  │
│  │ Check nfs_log_path  │───▶│ Gather date_time    │───▶│ Check OS Type   │  │
│  │ (required variable) │    │ (for report stamp)  │    │ (uname -s)      │  │
│  └─────────────────────┘    └─────────────────────┘    └─────────────────┘  │
│            │                                                    │           │
│            ▼                                                    ▼           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Check NFS Disk Space (df -g)                     │   │
│  │                    Verify mount point accessibility                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 2: AUTO-DETECT ORACLE ENVIRONMENT                  [main.yml:81-170]   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 2a. DETECT ORACLE USER FROM PMON PROCESS (AIX)                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                         │                                                   │
│                         ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 2b. DETECT ALL DATABASE INSTANCES (Filter skipped_instances)        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                         │                                                   │
│                         ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 2c. BUILD ORACLE_HOME MAP FROM /etc/oratab                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 3: SYNC INSTANCE LOGS (Loop)           [sync_instance_logs.yml]        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. PRIMARY DISCOVERY: Query v$diag_info via SQL*Plus                       │
│  2. FALLBACK DISCOVERY: `find` command for alert/audit dirs                 │
│  3. ELK OPTIMIZATION: Exclude *.trc, sync only alert_*.log, *.xml, *.aud    │
│  4. EXECUTION: `rsync` with --update to NFS                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 4: SYNC LISTENER LOGS (Loop)           [sync_listener_logs.yml]        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. DISCOVERY: `adrci` or Standard Path Structure                           │
│  2. FALLBACK: `find` for `trace` OR `alert` directories (Case Insensitive)  │
│  3. EXECUTION: `rsync` listener.log and alert.xml                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 5: GENERATE REPORTS (Local)            [generate_report.yml]           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. SUMMARY: Write timestamped run report.                                  │
│  2. HISTORY: Append to `hostname_history.log`.                              │
│  3. PER-INSTANCE: Append detailed file list to `SID_history.log`.           │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Professional Enhancements

### 1. HTML Status Dashboard
The role now generates a visual **Status Dashboard** at `reports/<DATE>/log_sync_jobs/index.html`.
- **Fleet Overview**: Quickly check the status of all servers.
- **Direct Links**: Click on any instance or listener to view its specific log transfer details.
- **Job Logs**: Detailed sync logs (and the dashboard itself) are consolidated in `reports/<DATE>/log_sync_jobs/`.

### 2. Consolidated Summary
A single file `reports/<DATE>/log_sync_jobs/Daily_Execution_Summary.txt` aggregates the status of every host run during the day.

### 4. Advanced Reporting & Metrics
The role now collects and visualizes key health metrics:
- **Interactive Dashboard**: `reports/<DATE>/log_sync_jobs/index.html` features **Search** and **Sort** headers.
- **Metric Alerts**:
    - **Lag**: Time since last write (Red > 24h, Orange > 1h).
    - **Size**: Alert log size (Red > 2GB).
    - **Audit**: Audit file count (Red > 50,000 files).
- **Detailed Job Reports**: Each job links to a specific HTML report with file-level details.

### 5. Log Maintenance Playbook
A dedicated playbook `playbooks/maintain_logs.yml` is provided for manual log cleanup.
```bash
# Delete logs older than 30 days from NFS and local reports
ansible-playbook playbooks/maintain_logs.yml -e "log_retention_days=30"
```

## Running with Limited Access (AD Users)

This role is optimized for environments where the `oracle` user is an AD account with restricted OS privileges:
- **No Root Required**: The continuous sync script and its execution logs are stored in `{{ oracle_script_path }}` (default: `/tmp/oracle_log_sync/`).
- **User-Level Cron**: The automation is scheduled in the `oracle` user's crontab, avoiding the need for `root` or `sudo` for ongoing synchronization.
- **Nesting**: All logs are integrated into the `nfs_log_path` shared path, organized by hostname, allowing multi-server log aggregation without cross-server permission issues.
