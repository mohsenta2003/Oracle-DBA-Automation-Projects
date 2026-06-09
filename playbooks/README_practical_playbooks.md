# Practical cx_Oracle Playbooks - Usage Guide

This document provides detailed usage examples for all the practical Oracle administration playbooks that support **multi-instance** environments with automatic ORACLE_HOME detection and standardized reporting.

## Table of Contents

1. [Common Features](#common-features)
2. [Database Health Check](#database-health-check)
3. [Deploy Application Schema](#deploy-application-schema)
4. [Password Rotation](#password-rotation)
5. [Profile Management](#profile-management)
6. [Service Management](#service-management)
7. [Scheduler Jobs Management](#scheduler-jobs-management)
8. [PDB Management](#pdb-management)
9. [Clone Schema](#clone-schema)
10. [Provision Users](#provision-users)

---

## Common Features

All playbooks share these features:

### Automatic Detection
- **Oracle User**: Auto-detected from `/etc/passwd` (svcorat, svcorap, oracle)
- **ORACLE_HOME**: Auto-detected from `/etc/oratab` for each instance
- **Instances**: Auto-detected from running PMON processes

### Report Structure
All reports are saved to:
```
reports/
└── YYYY-MM-DD/
    └── hostname/
        └── report_SID.txt
```

### Targeting Options
```bash
# All instances on a host
ansible-playbook playbooks/<playbook>.yml --limit myhost

# Specific instance only
ansible-playbook playbooks/<playbook>.yml --limit myhost -e "db_sid=ORCL1"

# Multiple hosts
ansible-playbook playbooks/<playbook>.yml --limit "host1:host2:host3"
```

---

## Database Health Check

**Playbook**: `database_health_check.yml`

Comprehensive database health report covering instance info, SGA, PGA, tablespaces, sessions, wait events, and backup status.

### Usage
```bash
# Health check all instances on a host
ansible-playbook playbooks/database_health_check.yml --limit crlnxd2201

# Health check specific instance
ansible-playbook playbooks/database_health_check.yml --limit crlnxd2201 -e "db_sid=awdmld"
```

### Report Output
- `reports/YYYY-MM-DD/hostname/health_check_<SID>.txt`

### Report Sections
1. Instance Information (name, version, status, uptime)
2. SGA Configuration (shared pool, buffer cache, large pool)
3. PGA Statistics (aggregate, target, max allocated)
4. Tablespace Usage (with GB/TB display, auto-extend info)
5. Active Sessions (blocking sessions, long operations)
6. Wait Events (top waits, historical analysis)
7. RMAN Backup Status (last backup times by type)

---

## Deploy Application Schema

**Playbook**: `deploy_app_schema.yml`

Deploy a complete application environment: tablespaces, user account, roles/grants, and optionally execute DDL scripts.

### Usage
```bash
# Deploy basic application schema
ansible-playbook playbooks/deploy_app_schema.yml --limit crlnxd2201 \
  -e "app_name=MYAPP" \
  -e "app_password=SecurePass123!"

# Deploy with custom tablespace sizes
ansible-playbook playbooks/deploy_app_schema.yml --limit crlnxd2201 \
  -e "app_name=MYAPP" \
  -e "app_password=SecurePass123!" \
  -e "data_size_mb=10240" \
  -e "index_size_mb=5120"

# Deploy to specific instance
ansible-playbook playbooks/deploy_app_schema.yml --limit crlnxd2201 \
  -e "db_sid=awdmld" \
  -e "app_name=MYAPP" \
  -e "app_password=SecurePass123!"
```

### Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `app_name` | - | Application/schema name (required) |
| `app_password` | - | Password for the user (required) |
| `data_size_mb` | 500 | Data tablespace initial size in MB |
| `index_size_mb` | 250 | Index tablespace initial size in MB |
| `target_tablespace` | USERS | Default tablespace if not creating new |
| `create_tablespaces` | true | Whether to create dedicated tablespaces |
| `default_roles` | [CONNECT, RESOURCE] | Roles to grant |

### Report Output
- `reports/YYYY-MM-DD/hostname/deploy_schema_<SID>.txt`

---

## Password Rotation

**Playbook**: `password_rotation.yml`

Rotate passwords for Oracle users with optional connection verification.

### Usage
```bash
# Rotate single user password
ansible-playbook playbooks/password_rotation.yml --limit crlnxd2201 \
  -e "users_to_rotate=[{username: 'APP_USER', new_password: 'NewPass123!'}]"

# Rotate multiple users
ansible-playbook playbooks/password_rotation.yml --limit crlnxd2201 \
  -e "@rotation_list.yml"

# Report only (no changes)
ansible-playbook playbooks/password_rotation.yml --limit crlnxd2201 \
  -e "action=report"
```

### rotation_list.yml Example
```yaml
action: rotate
users_to_rotate:
  - username: APP_USER1
    new_password: "NewSecure#2024!"
  - username: APP_USER2
    new_password: "AnotherPass#2024!"
  - username: SVC_ACCOUNT
    new_password: "ServicePass#2024!"
```

### Report Output
- `reports/YYYY-MM-DD/hostname/password_rotation_<SID>.txt`

---

## Profile Management

**Playbook**: `manage_profiles.yml`

Create, modify, assign, and drop Oracle profiles for resource and password management.

### Usage
```bash
# List all profiles
ansible-playbook playbooks/manage_profiles.yml --limit crlnxd2201 -e "action=list"

# Create security profile
ansible-playbook playbooks/manage_profiles.yml --limit crlnxd2201 \
  -e "action=create" \
  -e "profile_name=SECURE_PROFILE" \
  -e "failed_login_attempts=3" \
  -e "password_lock_time=1" \
  -e "password_life_time=90"

# Assign profile to user
ansible-playbook playbooks/manage_profiles.yml --limit crlnxd2201 \
  -e "action=assign" \
  -e "profile_name=SECURE_PROFILE" \
  -e "target_user=APP_USER"

# Drop profile
ansible-playbook playbooks/manage_profiles.yml --limit crlnxd2201 \
  -e "action=drop" \
  -e "profile_name=OLD_PROFILE"
```

### Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `action` | list | list, create, modify, assign, drop |
| `profile_name` | "" | Profile name to manage |
| `failed_login_attempts` | 10 | Max login attempts before lock |
| `password_lock_time` | 1 | Days account locked after failed attempts |
| `password_life_time` | 180 | Days until password expires |
| `password_grace_time` | 7 | Grace period after expiry |
| `sessions_per_user` | UNLIMITED | Max concurrent sessions |

### Report Output
- `reports/YYYY-MM-DD/hostname/profiles_<SID>.txt`

---

## Service Management

**Playbook**: `manage_services.yml`

Manage Oracle database services for application connectivity and load balancing.

### Usage
```bash
# List all services
ansible-playbook playbooks/manage_services.yml --limit crlnxd2201 -e "action=list"

# Create new service
ansible-playbook playbooks/manage_services.yml --limit crlnxd2201 \
  -e "action=create" \
  -e "service_name=MYAPP_SVC"

# Start service
ansible-playbook playbooks/manage_services.yml --limit crlnxd2201 \
  -e "action=start" \
  -e "service_name=MYAPP_SVC"

# Stop service
ansible-playbook playbooks/manage_services.yml --limit crlnxd2201 \
  -e "action=stop" \
  -e "service_name=MYAPP_SVC"

# Delete service
ansible-playbook playbooks/manage_services.yml --limit crlnxd2201 \
  -e "action=delete" \
  -e "service_name=MYAPP_SVC"
```

### Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `action` | list | list, create, start, stop, delete |
| `service_name` | "" | Service name to manage |
| `failover_method` | BASIC | BASIC or NONE |
| `failover_type` | SELECT | NONE, SESSION, SELECT, TRANSACTION |
| `clb_goal` | SHORT | SHORT or LONG |

### Report Output
- `reports/YYYY-MM-DD/hostname/services_<SID>.txt`

---

## Scheduler Jobs Management

**Playbook**: `manage_scheduler_jobs.yml`

Manage Oracle DBMS_SCHEDULER jobs for automated database tasks.

### Usage
```bash
# List all jobs
ansible-playbook playbooks/manage_scheduler_jobs.yml --limit crlnxd2201 -e "action=list"

# Create a job
ansible-playbook playbooks/manage_scheduler_jobs.yml --limit crlnxd2201 \
  -e "action=create" \
  -e "job_name=DAILY_STATS" \
  -e "job_type=PLSQL_BLOCK" \
  -e "job_action='BEGIN DBMS_STATS.GATHER_DATABASE_STATS; END;'" \
  -e "repeat_interval='FREQ=DAILY;BYHOUR=2;BYMINUTE=0'"

# Enable job
ansible-playbook playbooks/manage_scheduler_jobs.yml --limit crlnxd2201 \
  -e "action=enable" \
  -e "job_name=DAILY_STATS"

# Run job immediately
ansible-playbook playbooks/manage_scheduler_jobs.yml --limit crlnxd2201 \
  -e "action=run" \
  -e "job_name=DAILY_STATS"

# Disable job
ansible-playbook playbooks/manage_scheduler_jobs.yml --limit crlnxd2201 \
  -e "action=disable" \
  -e "job_name=DAILY_STATS"

# Drop job
ansible-playbook playbooks/manage_scheduler_jobs.yml --limit crlnxd2201 \
  -e "action=drop" \
  -e "job_name=DAILY_STATS"
```

### Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `action` | list | list, create, enable, disable, run, drop |
| `job_name` | "" | Job name to manage |
| `job_type` | PLSQL_BLOCK | PLSQL_BLOCK, STORED_PROCEDURE, EXECUTABLE |
| `job_action` | "" | PL/SQL block or procedure to execute |
| `repeat_interval` | "" | DBMS_SCHEDULER repeat expression |
| `start_date` | SYSDATE | When to start the job |
| `job_owner` | "" | Schema that owns the job |

### Report Output
- `reports/YYYY-MM-DD/hostname/scheduler_jobs_<SID>.txt`

---

## PDB Management

**Playbook**: `manage_pdbs.yml`

Manage Pluggable Databases in Oracle Multitenant architecture.

### Usage
```bash
# List all PDBs
ansible-playbook playbooks/manage_pdbs.yml --limit crlnxd2201 -e "action=list"

# Create new PDB
ansible-playbook playbooks/manage_pdbs.yml --limit crlnxd2201 \
  -e "action=create" \
  -e "pdb_name=APPDEV" \
  -e "pdb_admin_user=PDBADMIN" \
  -e "pdb_admin_password=AdminPass123!"

# Clone existing PDB
ansible-playbook playbooks/manage_pdbs.yml --limit crlnxd2201 \
  -e "action=clone" \
  -e "source_pdb=APPDEV" \
  -e "pdb_name=APPDEV_CLONE"

# Open PDB
ansible-playbook playbooks/manage_pdbs.yml --limit crlnxd2201 \
  -e "action=open" \
  -e "pdb_name=APPDEV" \
  -e "save_state=true"

# Close PDB
ansible-playbook playbooks/manage_pdbs.yml --limit crlnxd2201 \
  -e "action=close" \
  -e "pdb_name=APPDEV"

# Drop PDB
ansible-playbook playbooks/manage_pdbs.yml --limit crlnxd2201 \
  -e "action=drop" \
  -e "pdb_name=APPDEV_CLONE"
```

### Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `action` | list | list, create, clone, open, close, drop |
| `pdb_name` | "" | PDB name to manage |
| `pdb_admin_user` | PDBADMIN | Admin user for new PDB |
| `pdb_admin_password` | "" | Password for admin user |
| `source_pdb` | "" | Source PDB for clone |
| `save_state` | true | Save state for auto-open on CDB restart |

### Report Output
- `reports/YYYY-MM-DD/hostname/pdbs_<SID>.txt`

---

## Clone Schema

**Playbook**: `clone_schema.yml`

Clone schemas using Oracle Data Pump (export/import) within or between instances.

### Usage
```bash
# Clone schema (export + import as new name)
ansible-playbook playbooks/clone_schema.yml --limit crlnxd2201 \
  -e "action=clone" \
  -e "source_schema=HR" \
  -e "target_schema=HR_DEV"

# Export only
ansible-playbook playbooks/clone_schema.yml --limit crlnxd2201 \
  -e "action=export" \
  -e "source_schema=HR"

# Estimate export size
ansible-playbook playbooks/clone_schema.yml --limit crlnxd2201 \
  -e "action=estimate" \
  -e "source_schema=HR"

# List existing dump files
ansible-playbook playbooks/clone_schema.yml --limit crlnxd2201 -e "action=list"

# Check Data Pump job status
ansible-playbook playbooks/clone_schema.yml --limit crlnxd2201 -e "action=status"

# Import from existing dump
ansible-playbook playbooks/clone_schema.yml --limit crlnxd2201 \
  -e "action=import" \
  -e "source_schema=HR" \
  -e "target_schema=HR_CLONE"
```

### Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `action` | clone | clone, export, import, estimate, list, status |
| `source_schema` | "" | Source schema name |
| `target_schema` | "" | Target schema name (for clone/import) |
| `datapump_dir` | DATA_PUMP_DIR | Oracle directory object |
| `parallel` | 4 | Parallel workers |
| `compression` | ALL | NONE, DATA_ONLY, METADATA_ONLY, ALL |
| `table_exists_action` | SKIP | SKIP, APPEND, REPLACE, TRUNCATE |

### Report Output
- `reports/YYYY-MM-DD/hostname/clone_schema_<SID>.txt`

---

## Provision Users

**Playbook**: `provision_users.yml`

Bulk create/manage users from a YAML definition file.

### Usage
```bash
# Create users from YAML file
ansible-playbook playbooks/provision_users.yml --limit crlnxd2201 \
  -e "action=create" \
  -e "@playbooks/sample_users.yml"

# Report only (no changes)
ansible-playbook playbooks/provision_users.yml --limit crlnxd2201 \
  -e "action=report" \
  -e "@playbooks/sample_users.yml"

# Validate user definitions
ansible-playbook playbooks/provision_users.yml --limit crlnxd2201 \
  -e "action=validate" \
  -e "@playbooks/sample_users.yml"

# Remove users
ansible-playbook playbooks/provision_users.yml --limit crlnxd2201 \
  -e "action=remove" \
  -e "@playbooks/sample_users.yml"
```

### Users Definition File Format
```yaml
# sample_users.yml
users:
  - username: APP_USER1
    password: "SecurePass#2024!"
    default_tablespace: USERS
    temp_tablespace: TEMP
    quota_mb: 500           # Use -1 for unlimited
    profile: DEFAULT
    account_status: UNLOCK  # UNLOCK or LOCK
    roles:
      - CONNECT
      - RESOURCE

  - username: DEV_USER1
    password: "DevPass#2024!"
    default_tablespace: USERS
    quota_mb: -1            # Unlimited quota
    roles:
      - CONNECT
      - RESOURCE
      - CREATE VIEW
```

### Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `action` | report | create, remove, report, validate |
| `users` | [] | List of users (from external file) |
| `cascade_on_drop` | true | CASCADE when dropping users |

### Report Output
- `reports/YYYY-MM-DD/hostname/provision_users_<SID>.txt`

---

## Troubleshooting

### Common Issues

**1. "No running Oracle instances found"**
- Check that Oracle databases are running: `ps -ef | grep ora_pmon`
- Verify you're targeting the correct host

**2. "ORACLE_HOME not found in oratab"**
- Verify `/etc/oratab` contains entries for your instances
- Check permissions on `/etc/oratab`

**3. "Permission denied" errors**
- Ensure `pipelining = True` in ansible.cfg
- Check that ansible user can become oracle user

**4. Reports not generated**
- Check `reports/` directory exists on control machine
- Verify write permissions

### Debug Mode
```bash
# Enable verbose output
ansible-playbook playbooks/<playbook>.yml --limit myhost -vvv

# Check connectivity
ansible myhost -m ping -vvv
```
