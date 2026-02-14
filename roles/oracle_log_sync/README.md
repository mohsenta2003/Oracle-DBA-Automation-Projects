# Oracle Log Sync Role

Discovers and continuously syncs Oracle alert logs, listener logs, and audit logs to an NFS share for centralized log aggregation. Designed for **AIX servers** but also works on Linux.

## Ansible Modules & Packages Used

### Core Modules (ansible.builtin)

| Module | Purpose | Used In |
|--------|---------|---------|
| `ansible.builtin.setup` | Gather facts (date_time) | main.yml |
| `ansible.builtin.shell` | Run shell commands, SQL queries | All tasks |
| `ansible.builtin.file` | Create directories, set permissions | main.yml, sync tasks |
| `ansible.builtin.copy` | Deploy sync script to target | setup_cron.yml |
| `ansible.builtin.cron` | Manage cron jobs | setup_cron.yml |
| `ansible.builtin.debug` | Display status messages | All tasks |
| `ansible.builtin.fail` | Abort on validation errors | main.yml |
| `ansible.builtin.set_fact` | Store detected values | All tasks |
| `ansible.builtin.include_tasks` | Loop through instances/listeners | main.yml |

### Alternative Modules (Optional Enhancements)

| Module | Package | Purpose | When to Use |
|--------|---------|---------|-------------|
| `ansible.posix.synchronize` | `ansible.posix` | Wrapper for rsync | Cleaner rsync syntax, better idempotency |
| `ansible.posix.mount` | `ansible.posix` | Mount NFS filesystems | Instead of shell mount command |
| `ansible.builtin.find` | built-in | Find files by pattern/age | Replace `find` shell command |
| `ansible.builtin.stat` | built-in | Check file/dir existence | Pre-validation before sync |
| `ansible.builtin.template` | built-in | Generate sync script | Instead of copy with content |
| `ansible.builtin.lineinfile` | built-in | Modify config files | Add entries to /etc/fstab |
| `ansible.builtin.get_url` | built-in | Download files | Fetch rsync if missing |
| `community.general.archive` | `community.general` | Compress logs | Instead of shell gzip |
| `community.general.cron` | `community.general` | Advanced cron options | Complex schedules |

### Installing Optional Collections

```bash
# Install ansible.posix for synchronize and mount modules
ansible-galaxy collection install ansible.posix

# Install community.general for archive and other utilities
ansible-galaxy collection install community.general
```

## Logical Flow Map

```
╔═════════════════════════════════════════════════════════════════════════════╗
║                         SYNC_ORACLE_LOGS.YML                                ║
║                         Target: AIX Servers                                 ║
║                                                                             ║
║  PURPOSE: Discover and sync Oracle alert, listener, and audit logs to NFS  ║
║  DEFAULT NFS: /local/utils/aitdba/temp                                      ║
╚═════════════════════════════════════════════════════════════════════════════╝
                                    │
                    ┌───────────────┴───────────────┐
                    │  PLAYBOOK ENTRY POINT         │
║  DEFAULT NFS: /local/utils/AIX_ORA_LOGS                                     ║
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
│                                                                             │
│  INPUT VARIABLES:                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ nfs_log_path    : REQUIRED - Destination NFS path                   │   │
│  │                   Default: /local/utils/aitdba/temp                 │   │
│  │ oracle_user     : Optional - Override auto-detected oracle owner    │   │
│  │ db_sid          : Optional - Specific SID (else detect all)         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ANSIBLE MODULES USED:                                                      │
│  • ansible.builtin.fail   → Abort if nfs_log_path is empty                  │
│  • ansible.builtin.setup  → Gather date_time facts only (minimal)           │
│  • ansible.builtin.shell  → Run 'uname -s' and 'df -g'                      │
│  • ansible.builtin.debug  → Display status messages                         │
│                                                                             │
│  EXAMPLE USAGE:                                                             │
│  ansible-playbook playbooks/sync_oracle_logs.yml --limit myhost \           │
│    -e "nfs_log_path=/local/utils/aitdba/temp"                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 2: OPTIONAL NFS MOUNT                              [main.yml:61-80]    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CONDITION: mount_nfs=true AND nfs_server AND nfs_export provided   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                         │                                                   │
│                         ▼                                                   │
│  ┌─────────────┐     ┌────────────────┐     ┌─────────────────────────┐    │
│  │ Check if    │ NO  │ Create dir     │────▶│ Mount NFS:              │    │
│  │ mounted?    │────▶│ mkdir -p       │     │ nfs_server:nfs_export   │    │
│  └─────────────┘     └────────────────┘     │ → nfs_log_path          │    │
│        │ YES                                 └─────────────────────────┘    │
│        ▼                                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      SKIP (Already Mounted)                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  VARIABLES (when mount_nfs=true):                                           │
│  • nfs_server        : NFS server hostname/IP                               │
│  • nfs_export        : Export path on NFS server                            │
│  • nfs_mount_options : Mount options (default: rw,soft,intr)                │
│                                                                             │
│  ANSIBLE MODULE: ansible.builtin.shell (mount command)                      │
│  ALTERNATIVE:    ansible.posix.mount (idempotent, recommended)              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 3: AUTO-DETECT ORACLE ENVIRONMENT                  [main.yml:81-170]   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 3a. DETECT ORACLE USER FROM PMON PROCESS                            │   │
│  │     AIX Command:                                                    │   │
│  │     ps -eo user,args | grep ora_pmon | grep -v grep | head -1 |     │   │
│  │     awk '{print $1}'                                                │   │
│  │                                                                     │   │
│  │     Result: oracle                                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                         │                                                   │
│                         ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 3b. DETECT ALL DATABASE INSTANCES FROM PMON                         │   │
│  │     AIX Command:                                                    │   │
│  │     ps -ef | grep 'ora_pmon_' | grep -v grep | while read line; do  │   │
│  │       echo "$line" | sed 's/.*ora_pmon_//'                          │   │
│  │     done | sort -u                                                  │   │
│  │                                                                     │   │
│  │     Example Process: oracle 12345 /u01/.../ora_pmon_ORCL1          │   │
│  │     Result: ORCL1, ORCL2, TESTDB (list of running SIDs)             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                         │                                                   │
│                         ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 3c. BUILD ORACLE_HOME MAP FROM /etc/oratab                          │   │
│  │                                                                     │   │
│  │     Oratab Format: SID:ORACLE_HOME:Y/N                              │   │
│  │     ┌──────────────────────────────────────────────────────────┐    │   │
│  │     │ ORCL1:/u01/app/oracle/product/19c/dbhome_1:Y            │    │   │
│  │     │ ORCL2:/u01/app/oracle/product/19c/dbhome_1:Y            │    │   │
│  │     │ TESTDB:/u01/app/oracle/product/12c/dbhome_1:N           │    │   │
│  │     └──────────────────────────────────────────────────────────┘    │   │
│  │                              ↓                                      │   │
│  │     oracle_home_map = {                                             │   │
│  │       "ORCL1":  "/u01/app/oracle/product/19c/dbhome_1",             │   │
│  │       "ORCL2":  "/u01/app/oracle/product/19c/dbhome_1",             │   │
│  │       "TESTDB": "/u01/app/oracle/product/12c/dbhome_1"              │   │
│  │     }                                                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                         │                                                   │
│                         ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 3d. GET ADR BASE (diagnostic_dest) FOR LISTENER LOGS                │   │
│  │                                                                     │   │
│  │     SQL Query: SELECT value FROM v$parameter                        │   │
│  │                WHERE name = 'diagnostic_dest'                       │   │
│  │                                                                     │   │
│  │     Example Result: /u01/mod/backup                                 │   │
│  │                                                                     │   │
│  │     WHY: Listener logs are NOT in ORACLE_BASE!                      │   │
│  │          They use the ADR (Automatic Diagnostic Repository) path:   │   │
│  │          <diagnostic_dest>/diag/tnslsnr/<hostname>/<listener>/      │   │
│  │                                                                     │   │
│  │     Verify with adrci:                                              │   │
│  │     $ adrci                                                         │   │
│  │     ADR base = "/u01/mod/backup"                                    │   │
│  │     adrci> show homes                                               │   │
│  │     → diag/tnslsnr/dcup60/hzarcmo.1682                              │   │
│  │     → diag/tnslsnr/dcup60/mrptprs.1611                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                         │                                                   │
│                         ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 3e. DETECT RUNNING LISTENERS (Oracle user owned only)               │   │
│  │     AIX Command:                                                    │   │
│  │     ps -ef | grep tnslsnr | grep -v grep | grep -v MGMTLSNR |       │   │
│  │     while read line; do                                             │   │
│  │       owner=$(echo "$line" | awk '{print $1}')                      │   │
│  │       if [ "$owner" = "oracle" ]; then                              │   │
│  │         lsnr_name=$(echo "$line" | sed 's/.*tnslsnr //' |           │   │
│  │                     awk '{print $1}')                               │   │
│  │         # Skip grid LISTENER                                        │   │
│  │         if [ "$lsnr_name" != "LISTENER" ]; then echo "$lsnr_name"   │   │
│  │       fi                                                            │   │
│  │     done | sort -u                                                  │   │
│  │                                                                     │   │
│  │     EXCLUSIONS:                                                     │   │
│  │     • LISTENER   (grid infrastructure default listener)             │   │
│  │     • MGMTLSNR   (grid management listener)                         │   │
│  │     • grid user owned listeners                                     │   │
│  │                                                                     │   │
│  │     Example Output: hzarcmo.1682, mrptprs.1611, mafp1wp.1651        │   │
│  │     (listener name includes port suffix)                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ANSIBLE MODULES:                                                           │
│  • ansible.builtin.shell    → Run ps, grep, sed, awk, sqlplus               │
│  • ansible.builtin.set_fact → Store _oracle_user, _all_instances,           │
│                               _all_listeners, oracle_home_map, _adr_base    │
│  • ansible.builtin.fail     → Abort if no Oracle user detected              │
│  • ansible.builtin.debug    → Display detected values                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 4: CREATE NFS DIRECTORY STRUCTURE                  [main.yml:220-235]  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  DIRECTORY STRUCTURE CREATED:                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ /local/utils/aitdba/temp/                   (NFS mount point)       │   │
│  │ └── <hostname>/                             (per-host folder)       │   │
│  │     ├── <SID>/                              (per-instance)          │   │
│  │     │   ├── alert/                          (alert logs)            │   │
│  │     │   ├── audit/                          (audit files)           │   │
│  │     │   └── trace/                          (trace files)           │   │
│  │     └── listener/                                                   │   │
│  │         └── <listener_name>/                (per-listener)          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  EXAMPLE (host: dcup60, instance: hzarcmo, listener: hzarcmo.1682):         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ /local/utils/aitdba/temp/dcup60/hzarcmo/alert/                      │   │
│  │ /local/utils/aitdba/temp/dcup60/hzarcmo/audit/                      │   │
│  │ /local/utils/aitdba/temp/dcup60/listener/hzarcmo.1682/              │   │
│  │ /local/utils/aitdba/temp/dcup60/listener/mrptprs.1611/              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ANSIBLE MODULE: ansible.builtin.file (state: directory, mode: '0755')      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                  ┌─────────────────┴─────────────────┐
                  ▼                                   ▼
┌─────────────────────────────────────┐  ┌─────────────────────────────────────┐
│ STEP 5: SYNC INSTANCE LOGS          │  │ STEP 6: SYNC LISTENER LOGS          │
│ [sync_instance_logs.yml]            │  │ [sync_listener_logs.yml]            │
│ LOOP: for each SID in _all_instances│  │ LOOP: for each listener             │
├─────────────────────────────────────┤  ├─────────────────────────────────────┤
│                                     │  │                                     │
│ FOR EACH INSTANCE (e.g., ORCL1):    │  │ FOR EACH LISTENER:                  │
│ ┌─────────────────────────────────┐ │  │ (e.g., hzarcmo.1682)                │
│ │ 5a. SET ORACLE_HOME             │ │  │ ┌─────────────────────────────────┐ │
│ │     From oracle_home_map[SID]   │ │  │ │ 6a. GET ADR BASE (from Step 3)  │ │
│ │     e.g., /u01/app/.../dbhome_1 │ │  │ │     _adr_base = diagnostic_dest │ │
│ └─────────────────────────────────┘ │  │ │     e.g., /u01/mod/backup       │ │
│               │                     │  │ └─────────────────────────────────┘ │
│               ▼                     │  │               │                     │
│ ┌─────────────────────────────────┐ │  │               ▼                     │
│ │ 5b. QUERY LOG PATHS VIA SQLPLUS │ │  │ ┌─────────────────────────────────┐ │
│ │     Connect as: / as sysdba     │ │  │ │ 6b. BUILD LISTENER LOG PATH     │ │
│ │                                 │ │  │ │                                 │ │
│ │  ┌───────────────────────────┐  │ │  │ │  Path Formula:                  │ │
│ │  │ Alert Log Dir:           │  │ │  │ │  <adr_base>/diag/tnslsnr/       │ │
│ │  │ SELECT value             │  │ │  │ │  <hostname>/<listener>/trace/   │ │
│ │  │ FROM v$diag_info         │  │ │  │ │                                 │ │
│ │  │ WHERE name='Diag Trace'  │  │ │  │ │  Example:                       │ │
│ │  │                          │  │ │  │ │  /u01/mod/backup/diag/tnslsnr/  │ │
│ │  │ → /u01/app/oracle/diag/  │  │ │  │ │  dcup60/hzarcmo.1682/trace/     │ │
│ │  │   rdbms/orcl1/ORCL1/trace│  │ │  │ │                                 │ │
│ │  └───────────────────────────┘  │ │  │ │  Verified via adrci:            │ │
│ │  ┌───────────────────────────┐  │ │  │ │  diag/tnslsnr/dcup60/hzarcmo.  │ │
│ │  │ Audit Log Dir:           │  │ │  │ │  1682                           │ │
│ │  │ SELECT value             │  │ │  │ └─────────────────────────────────┘ │
│ │  │ FROM v$parameter         │  │ │  │               │                     │
│ │  │ WHERE name=              │  │ │  │               ▼                     │
│ │  │   'audit_file_dest'      │  │ │  │ ┌─────────────────────────────────┐ │
│ │  │                          │  │ │  │ │ 6c. CREATE NFS DIRECTORY        │ │
│ │  │ → /u01/app/oracle/       │  │ │  │ │     /<nfs>/<host>/listener/     │ │
│ │  │   admin/ORCL1/adump      │  │ │  │ │     <listener_name>/            │ │
│ │  └───────────────────────────┘  │ │  │ └─────────────────────────────────┘ │
│ └─────────────────────────────────┘ │  │               │                     │
│               │                     │  │               ▼                     │
│               ▼                     │  │ ┌─────────────────────────────────┐ │
│ ┌─────────────────────────────────┐ │  │ │ 6d. RSYNC LISTENER LOGS         │ │
│ │ 5c. CREATE NFS SUBDIRECTORIES   │ │  │ │                                 │ │
│ │     /<nfs>/<host>/<SID>/alert/  │ │  │ │  rsync -avz \                   │ │
│ │     /<nfs>/<host>/<SID>/audit/  │ │  │ │    --include='*.log' \          │ │
│ │     /<nfs>/<host>/<SID>/trace/  │ │  │ │    --include='*.xml' \          │ │
│ └─────────────────────────────────┘ │  │ │    --exclude='*' \              │ │
│               │                     │  │ │    <lsnr_log_dir>/              │ │
│               ▼                     │  │ │    → /<nfs>/<host>/listener/    │ │
│ ┌─────────────────────────────────┐ │  │ │      <listener_name>/           │ │
│ │ 5d. RSYNC ALERT LOGS            │ │  │ └─────────────────────────────────┘ │
│ │                                 │ │  │                                     │
│ │  rsync -avz \                   │ │  │ CONDITION: sync_listener_logs=true  │
│ │    --include='alert_*.log' \    │ │  │ (default: true)                     │
│ │    --include='alert_*.xml' \    │ │  │                                     │
│ │    --exclude='*' \              │ │  │ LISTENER NAME FORMAT:               │
│ │    <alert_dir>/ \               │ │  │ • hzarcmo.1682 (name.port)          │
│ │    → /<nfs>/<host>/<SID>/alert/ │ │  │ • mrptprs.1611                      │
│ └─────────────────────────────────┘ │  │ • mafp1wp.1651                      │
│               │                     │  │                                     │
│               ▼                     │  │ EXCLUDED LISTENERS:                 │
│ ┌─────────────────────────────────┐ │  │ • LISTENER (grid default)           │
│ │ 5e. RSYNC AUDIT LOGS            │ │  │ • MGMTLSNR (grid management)        │
│ │                                 │ │  │ • Any listener owned by grid user   │
│ │  rsync -avz \                   │ │  └─────────────────────────────────────┘
│ │    --include='*.aud' \          │ │
│ │    --include='*.xml' \          │ │
│ │    --exclude='*' \              │ │
│ │    <audit_dir>/ \               │ │
│ │    → /<nfs>/<host>/<SID>/audit/ │ │
│ └─────────────────────────────────┘ │
│               │                     │
│               ▼                     │
│ ┌─────────────────────────────────┐ │
│ │ 5f. RSYNC TRACE FILES           │ │
│ │     (last N days only)          │ │
│ │                                 │ │
│ │  find <trace_dir> -name "*.trc" │ │
│ │    -mtime -{{ trace_days }} \   │ │
│ │  | rsync --files-from=- \       │ │
│ │    → /<nfs>/<host>/<SID>/trace/ │ │
│ │                                 │ │
│ │  Default: trace_days=7          │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ANSIBLE MODULES:                    │
│ • shell (sqlplus, rsync)            │
│ • file (mkdir)                      │
│ • set_fact (store paths)            │
│ • include_tasks (loop instances)    │
│                                     │
│ ALTERNATIVES:                       │
│ • ansible.posix.synchronize         │
│ • ansible.builtin.find + fetch      │
└─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 7: OPTIONAL CRON SETUP                           [setup_cron.yml]      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  CONDITION: setup_cron=true (default: false)                                │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 7a. CREATE SYNC SCRIPT                                              │   │
│  │     Location: /usr/local/bin/oracle_log_sync.sh                     │   │
│  │     Permissions: 755 (executable)                                   │   │
│  │                                                                     │   │
│  │     Script contents:                                                │   │
│  │     ┌───────────────────────────────────────────────────────────┐   │   │
│  │     │ #!/bin/bash                                               │   │   │
│  │     │ # Auto-generated Oracle Log Sync Script                   │   │   │
│  │     │ # Target: AIX                                             │   │   │
│  │     │                                                           │   │   │
│  │     │ NFS_PATH="{{ nfs_log_path }}"                             │   │   │
│  │     │ HOSTNAME=$(hostname)                                      │   │   │
│  │     │ LOGFILE="/var/log/oracle_log_sync.log"                    │   │   │
│  │     │ RETENTION_DAYS={{ log_retention_days }}                   │   │   │
│  │     │                                                           │   │   │
│  │     │ # Detect instances (same logic as playbook)               │   │   │
│  │     │ INSTANCES=$(ps -ef | grep 'ora_pmon_' | grep -v grep |    │   │   │
│  │     │             sed 's/.*ora_pmon_//' | sort -u)              │   │   │
│  │     │                                                           │   │   │
│  │     │ # Detect listeners (same logic as playbook)               │   │   │
│  │     │ LISTENERS=$(ps -ef | grep tnslsnr | grep -v grep |        │   │   │
│  │     │             grep -v MGMTLSNR | grep oracle |              │   │   │
│  │     │             sed 's/.*tnslsnr //' | awk '{print $1}' |     │   │   │
│  │     │             grep -v '^LISTENER$' | sort -u)               │   │   │
│  │     │                                                           │   │   │
│  │     │ # For each instance: rsync alert/audit logs               │   │   │
│  │     │ # Cleanup old logs: find -mtime +$RETENTION_DAYS -delete  │   │   │
│  │     │ # Compress logs > 1 day: gzip *.log/*.aud                 │   │   │
│  │     └───────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                         │                                                   │
│                         ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 7b. ADD CRON ENTRY                                                  │   │
│  │                                                                     │   │
│  │     Cron Schedule: */{{ cron_interval }} * * * *                    │   │
│  │     Default: Every 15 minutes (cron_interval=15)                    │   │
│  │     User: root                                                      │   │
│  │                                                                     │   │
│  │     Example crontab entry:                                          │   │
│  │     */15 * * * * /usr/local/bin/oracle_log_sync.sh >> \             │   │
│  │                  /var/log/oracle_log_sync.log 2>&1                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  VARIABLES:                                                                 │
│  • cron_interval     : Minutes between sync (default: 15)                   │
│  • log_retention_days: Days to keep synced logs (default: 30)               │
│  • compress_logs     : Compress logs older than 1 day (default: true)       │
│                                                                             │
│  ANSIBLE MODULES:                                                           │
│  • ansible.builtin.copy → Deploy script with content: |                     │
│  • ansible.builtin.cron → Create scheduled job                              │
│                                                                             │
│  ALTERNATIVES:                                                              │
│  • ansible.builtin.template → For complex .j2 script templates              │
│  • community.general.cronvar → Set cron environment variables               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 8: GENERATE SUMMARY REPORT                       [generate_report.yml] │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  OUTPUT LOCATION: reports/YYYY-MM-DD/<hostname>/log_sync_summary.txt        │
│  (created on Ansible control node via delegate_to: localhost)               │
│                                                                             │
│  REPORT CONTENTS:                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ ═══════════════════════════════════════════════════════════════════ │   │
│  │ Oracle Log Sync Report                                              │   │
│  │ Host: dcup60                                                        │   │
│  │ Date: 2026-01-28                                                    │   │
│  │ ═══════════════════════════════════════════════════════════════════ │   │
│  │                                                                     │   │
│  │ DISK STATUS:                                                        │   │
│  │ Filesystem    GB blocks      Free %Used    Mounted on               │   │
│  │ /dev/nfs_lv       100.00    45.23   55%    /local/utils/aitdba/temp │   │
│  │                                                                     │   │
│  │ DETECTED ORACLE USER: oracle                                        │   │
│  │                                                                     │   │
│  │ DETECTED INSTANCES (3):                                             │   │
│  │   • ORCL1 → /u01/app/oracle/product/19c/dbhome_1                    │   │
│  │   • ORCL2 → /u01/app/oracle/product/19c/dbhome_1                    │   │
│  │   • TESTDB → /u01/app/oracle/product/12c/dbhome_1                   │   │
│  │                                                                     │   │
│  │ DETECTED LISTENERS (2):                                             │   │
│  │   • mrptprs.1611                                                    │   │
│  │   • mafp1wp.1651                                                    │   │
│  │                                                                     │   │
│  │ SYNC RESULTS:                                                       │   │
│  │   Instance ORCL1:                                                   │   │
│  │     Alert logs:  SYNCED (125 files)                                 │   │
│  │     Audit logs:  SYNCED (2,340 files)                               │   │
│  │     Trace files: SYNCED (45 files, last 7 days)                     │   │
│  │   Instance ORCL2:                                                   │   │
│  │     Alert logs:  SYNCED (98 files)                                  │   │
│  │     Audit logs:  SYNCED (1,890 files)                               │   │
│  │   Listener mrptprs.1611:                                            │   │
│  │     Listener logs: SYNCED                                           │   │
│  │                                                                     │   │
│  │ CRON STATUS: Enabled (every 15 minutes)                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ANSIBLE MODULES:                                                           │
│  • ansible.builtin.file → Create local report directory                     │
│  • ansible.builtin.copy → Write report content (delegate_to: localhost)     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
╔═════════════════════════════════════════════════════════════════════════════╗
║                              PLAYBOOK COMPLETE                              ║
╚═════════════════════════════════════════════════════════════════════════════╝


═══════════════════════════════════════════════════════════════════════════════
                           QUICK REFERENCE SUMMARY
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│ FILES STRUCTURE                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ playbooks/                                                                  │
│ └── sync_oracle_logs.yml          ← Entry point playbook                    │
│                                                                             │
│ roles/oracle_log_sync/                                                      │
│ ├── defaults/main.yml             ← Default variables                       │
│ ├── tasks/                                                                  │
│ │   ├── main.yml                  ← Orchestration (validation, detection)   │
│ │   ├── sync_instance_logs.yml    ← Per-instance alert/audit sync           │
│ │   ├── sync_listener_logs.yml    ← Per-listener log sync                   │
│ │   ├── setup_cron.yml            ← Cron job setup                          │
│ │   └── generate_report.yml       ← Summary report                          │
│ └── README.md                     ← This documentation                      │
│                                                                             │
│ reports/                                                                    │
│ └── YYYY-MM-DD/                                                             │
│     └── <hostname>/                                                         │
│         └── log_sync_summary.txt  ← Execution report                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ VARIABLES REFERENCE                                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ REQUIRED:                                                                   │
│ ┌───────────────────┬─────────────────────────────────────────────────────┐ │
│ │ nfs_log_path      │ Destination NFS path for synced logs                │ │
│ │                   │ Default: /local/utils/aitdba/temp                   │ │
│ └───────────────────┴─────────────────────────────────────────────────────┘ │
│                                                                             │
│ OPTIONAL:                                                                   │
│ ┌───────────────────┬─────────────────────────────────────────────────────┐ │
│ │ oracle_user       │ Override detected oracle owner (default: auto)      │ │
│ │ db_sid            │ Specific SID to sync (default: all instances)       │ │
│ │ sync_listener_logs│ Include listener logs (default: true)               │ │
│ │ sync_trace_files  │ Include trace files (default: true)                 │ │
│ │ trace_days        │ Days of trace files to sync (default: 7)            │ │
│ │ setup_cron        │ Create cron job for continuous sync (default: false)│ │
│ │ cron_interval     │ Minutes between cron runs (default: 15)             │ │
│ │ log_retention_days│ Days to keep synced logs (default: 30)              │ │
│ │ compress_logs     │ Compress old logs (default: true)                   │ │
│ │ mount_nfs         │ Mount NFS if not already mounted (default: false)   │ │
│ │ nfs_server        │ NFS server hostname (required if mount_nfs=true)    │ │
│ │ nfs_export        │ NFS export path (required if mount_nfs=true)        │ │
│ │ nfs_mount_options │ Mount options (default: rw,soft,intr)               │ │
│ └───────────────────┴─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ USAGE EXAMPLES                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ # Basic sync (all instances, all listeners)                                 │
│ ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers \       │
│   -e "nfs_log_path=/local/utils/aitdba/temp"                                │
│                                                                             │
│ # Sync specific instance only                                               │
│ ansible-playbook playbooks/sync_oracle_logs.yml --limit dcup60 \            │
│   -e "nfs_log_path=/local/utils/aitdba/temp" \                              │
│   -e "db_sid=ORCL1"                                                         │
│                                                                             │
│ # Setup continuous sync with cron (every 30 minutes)                        │
│ ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers \       │
│   -e "nfs_log_path=/local/utils/aitdba/temp" \                              │
│   -e "setup_cron=true" \                                                    │
│   -e "cron_interval=30"                                                     │
│                                                                             │
│ # Skip listener logs, only sync last 3 days of traces                       │
│ ansible-playbook playbooks/sync_oracle_logs.yml --limit dcup60 \            │
│   -e "nfs_log_path=/local/utils/aitdba/temp" \                              │
│   -e "sync_listener_logs=false" \                                           │
│   -e "trace_days=3"                                                         │
│                                                                             │
│ # Dry run (check mode)                                                      │
│ ansible-playbook playbooks/sync_oracle_logs.yml --limit dcup60 \            │
│   -e "nfs_log_path=/local/utils/aitdba/temp" --check                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ AIX-SPECIFIC COMMANDS USED                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ DETECT ORACLE USER:                                                         │
│   ps -eo user,args | grep ora_pmon | grep -v grep | head -1 | awk '{$1}'    │
│                                                                             │
│ DETECT INSTANCES:                                                           │
│   ps -ef | grep 'ora_pmon_' | grep -v grep | sed 's/.*ora_pmon_//'          │
│                                                                             │
│ DETECT LISTENERS (oracle user only, exclude grid):                          │
│   ps -ef | grep tnslsnr | grep -v grep | grep -v MGMTLSNR | \               │
│   while read line; do                                                       │
│     owner=$(echo "$line" | awk '{print $1}')                                │
│     if [ "$owner" = "oracle" ]; then                                        │
│       lsnr_name=$(echo "$line" | sed 's/.*tnslsnr //' | awk '{print $1}')   │
│       if [ "$lsnr_name" != "LISTENER" ]; then echo "$lsnr_name"; fi         │
│     fi                                                                      │
│   done | sort -u                                                            │
│                                                                             │
│ CHECK DISK SPACE:                                                           │
│   df -g <path>                                                              │
│                                                                             │
│ RSYNC OPTIONS:                                                              │
│   rsync -avz --include='pattern' --exclude='*' <src> <dest>                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Final NFS Structure

```
/local/utils/aitdba/temp/
└── <hostname>/
    ├── <SID_1>/
    │   ├── alert/
    │   │   ├── alert_<SID>.log
    │   │   └── alert_<SID>.xml
    │   ├── audit/
    │   │   ├── ora_12345_20260128.aud
    │   │   └── ...
    │   └── trace/
    │       └── <SID>_ora_*.trc
    ├── <SID_2>/
    │   ├── alert/
    │   ├── audit/
    │   └── trace/
    └── listener/
        ├── mrptprs.1611/
        │   └── listener.log
        └── mafp1wp.1651/
            └── listener.log
```

## Installation Requirements

```bash
# Required: ansible.posix collection for synchronize module (recommended)
ansible-galaxy collection install ansible.posix

# Optional: community.general for additional utilities
ansible-galaxy collection install community.general
```
- name: Setup cron job
  ansible.builtin.cron:
    name: "Oracle Log Sync"
    minute: "*/{{ cron_interval }}"
    job: "/usr/local/bin/oracle_log_sync.sh"
    user: root

# Alternative: Using template for script
- name: Deploy sync script from template
  ansible.builtin.template:
    src: oracle_log_sync.sh.j2
    dest: /usr/local/bin/oracle_log_sync.sh
    mode: '0755'

# Alternative: Using systemd timer (Linux only, not AIX)
- name: Create systemd timer
  ansible.builtin.template:
    src: oracle-log-sync.timer.j2
    dest: /etc/systemd/system/oracle-log-sync.timer
```

### Step 8: Report Generation
```yaml
# Current: Using copy with inline content
- name: Generate report
  ansible.builtin.copy:
    dest: "{{ report_path }}"
    content: |
      Report content here...
  delegate_to: localhost

# Alternative: Using template
- name: Generate report from template
  ansible.builtin.template:
    src: log_sync_report.txt.j2
    dest: "{{ report_path }}"
  delegate_to: localhost
```

## Module Comparison Table

| Task | shell | Native Module | Pros/Cons |
|------|-------|---------------|-----------|
| **Check disk** | `df -g` | `ansible.builtin.stat` | stat: no size info; shell: full output |
| **Read file** | `cat /etc/oratab` | `ansible.builtin.slurp` | slurp: cleaner, returns base64 |
| **Find files** | `find -name "*.log"` | `ansible.builtin.find` | find module: better filtering, returns list |
| **Copy files** | `rsync -avz` | `ansible.posix.synchronize` | synchronize: idempotent, cleaner |
| **Compress** | `gzip file` | `community.general.archive` | archive: multiple formats, cleaner |
| **Mount NFS** | `mount -o ...` | `ansible.posix.mount` | mount module: idempotent, fstab support |
| **Cron** | `crontab -e` | `ansible.builtin.cron` | cron module: idempotent, named entries |

## Why We Use Shell Module

For AIX compatibility and Oracle-specific operations, we primarily use `ansible.builtin.shell` because:

1. **Oracle sqlplus** - No native Ansible module for sqlplus (cx_Oracle modules need Python library)
2. **AIX compatibility** - Some ansible.posix modules have Linux-specific behavior
3. **Process detection** - `ps` command variations between OS types
4. **Complex pipelines** - Multiple commands with grep/awk are simpler in shell

## Recommended Improvements

To make the role more "Ansible-native", consider:

```yaml
# requirements.yml - Add to your project
collections:
  - name: ansible.posix
    version: ">=1.5.0"
  - name: community.general
    version: ">=6.0.0"
```

Then refactor to use:
- `ansible.posix.synchronize` instead of shell rsync
- `ansible.posix.mount` instead of shell mount
- `ansible.builtin.find` instead of shell find
- `ansible.builtin.template` for script generation

## Usage

### Basic Sync (One-time)
```bash
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers

# Override NFS path
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers -e "nfs_log_path=/other/path"
```

### Incremental Sync (Changes Only)
```bash
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers -e "sync_mode=incremental"
```

### Setup Continuous Sync (Cron)
```bash
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers \
  -e "setup_cron=true" \
  -e "cron_interval=15"
```

### With Log Retention & Compression
```bash
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers \
  -e "setup_cron=true" \
  -e "log_retention_days=30" \
  -e "compress_logs=true"
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nfs_log_path` | `/local/utils/aitdba/temp` | NFS destination path for logs |
| `sync_mode` | `initial` | `initial` (full) or `incremental` (changes only) |
| `setup_cron` | `false` | Create cron job for continuous sync |
| `cron_interval` | `15` | Cron interval in minutes |
| `log_retention_days` | `30` | Delete logs older than N days (0=disable) |
| `compress_logs` | `true` | Gzip logs older than 1 day |
| `sync_alert_logs` | `true` | Sync alert logs |
| `sync_listener_logs` | `true` | Sync listener logs |
| `sync_audit_logs` | `true` | Sync audit logs |
| `mount_nfs` | `false` | Mount NFS if not already mounted |
| `nfs_server` | - | NFS server hostname (for mount) |
| `nfs_export` | - | NFS export path (for mount) |

## Task Files

| File | Purpose |
|------|---------|
| `main.yml` | Orchestration, detection, validation |
| `sync_instance_logs.yml` | Sync alert & audit logs per database instance |
| `sync_listener_logs.yml` | Sync listener logs |
| `setup_cron.yml` | Configure cron job for continuous sync |
| `generate_report.yml` | Create sync summary report |

## Prerequisites

1. **NFS mount** pre-configured on target hosts, OR use `mount_nfs=true`
2. **rsync** installed on AIX hosts
3. Oracle user with access to log directories
4. SSH access to target hosts

## AIX-Specific Notes

- Uses `ps -eo user,args` for process detection (AIX compatible)
- Uses `df -g` for disk space check
- Cron uses `/usr/local/bin/oracle_log_sync.sh`
- Log file: `/var/log/oracle_log_sync.log`

## Integration with Log Aggregation

The synced logs can be consumed by:
- **ELK Stack**: Configure Filebeat to read from NFS path
- **Splunk**: Add NFS path as monitored directory
- **Graylog**: Use Sidecar collector on NFS server
- **Custom scripts**: Parse logs from centralized location
