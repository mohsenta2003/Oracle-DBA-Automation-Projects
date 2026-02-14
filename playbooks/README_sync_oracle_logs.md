# sync_oracle_logs.yml

## Purpose
Discovers and continuously syncs Oracle alert logs, listener logs, and audit logs to an NFS share for centralized log aggregation. Designed for **AIX servers** but also works on Linux.

## Features
- **Auto-Discovery**: Automatically finds all Oracle instances and listeners
- **Alert Logs**: Syncs alert_*.log, alert_*.xml from ADR diagnostic trace
- **Listener Logs**: Syncs listener.log and related files from TNS ADR
- **Audit Logs**: Syncs *.aud files from audit_file_dest
- **Continuous Sync**: Optional cron job for automated sync every N minutes
- **Log Retention**: Automatic cleanup of old logs on NFS
- **Compression**: Optional gzip compression for logs older than 1 day
- **Multi-Instance**: Processes ALL instances on each host

## Usage

### Basic Sync (One-time)
```bash
# Sync all Oracle logs to NFS path
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers -e "nfs_log_path=/nfs/oracle_logs"

# Sync specific host
ansible-playbook playbooks/sync_oracle_logs.yml --limit myaixhost -e "nfs_log_path=/nfs/oracle_logs"

# Sync specific instance only
ansible-playbook playbooks/sync_oracle_logs.yml --limit myaixhost -e "nfs_log_path=/nfs/oracle_logs" -e "db_sid=ORCL1"
```

### Incremental Sync (Changes Only)
```bash
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers \
  -e "nfs_log_path=/nfs/oracle_logs" \
  -e "sync_mode=incremental"
```

### Setup Continuous Sync (Cron)
```bash
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers \
  -e "nfs_log_path=/nfs/oracle_logs" \
  -e "setup_cron=true" \
  -e "cron_interval=15"
```

### With Log Retention & Compression
```bash
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers \
  -e "nfs_log_path=/nfs/oracle_logs" \
  -e "setup_cron=true" \
  -e "log_retention_days=30" \
  -e "compress_logs=true"
```

### Mount NFS During Playbook (if not pre-mounted)
```bash
ansible-playbook playbooks/sync_oracle_logs.yml --limit aix_servers \
  -e "nfs_log_path=/nfs/oracle_logs" \
  -e "mount_nfs=true" \
  -e "nfs_server=nfsserver.domain.com" \
  -e "nfs_export=/export/oracle_logs"
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nfs_log_path` | (required) | NFS destination path for logs |
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

## NFS Directory Structure

```
/nfs/oracle_logs/
└── <hostname>/
    ├── <SID>/
    │   ├── alert/       # alert_<SID>.log, alert_<SID>.xml
    │   ├── audit/       # *.aud files
    │   └── trace/       # *.trc files (recent only)
    └── listener/
        └── <LISTENER>/  # listener.log, *.xml
```

## Reports

Reports saved to: `reports/YYYY-MM-DD/<hostname>/log_sync_summary.txt`

Contains:
- Disk space status on NFS
- Detected Oracle configuration (instances, listeners)
- Sync results for each instance and listener
- Cron configuration status

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

## Example Inventory

```ini
[aix_oracle]
aixdb01.domain.com
aixdb02.domain.com

[aix_oracle:vars]
ansible_user=ansible
ansible_connection=ssh
```

## Verification

```bash
# Check synced logs on NFS
ls -la /nfs/oracle_logs/<hostname>/<SID>/alert/
ls -la /nfs/oracle_logs/<hostname>/<SID>/audit/
ls -la /nfs/oracle_logs/<hostname>/listener/LISTENER/

# Check cron job (on target host)
crontab -l | grep oracle_log_sync

# Check sync log
tail -f /var/log/oracle_log_sync.log
```

## Integration with Log Aggregation

The synced logs can be consumed by:
- **ELK Stack**: Configure Filebeat to read from NFS path
- **Splunk**: Add NFS path as monitored directory
- **Graylog**: Use Sidecar collector on NFS server
- **Custom scripts**: Parse logs from centralized location
