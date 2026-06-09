# Oracle Options Audit - Configuration Management

## Repository Connection Settings - Single Source of Truth

### Configuration Architecture

All repository connection settings are managed in **TWO synchronized locations**:

1. **`roles/oracle_options_audit/defaults/main.yml`** 
   - Used by: `collect_oracle_options.yml` and any playbook that uses the role
   - This is the PRIMARY source

2. **`vars/repo_config.yml`**
   - Used by: All standalone utility playbooks (via `vars_files`)
   - Playbooks: `_validate_repo.yml`, `_setup_audit_tables.yml`, `_check_audit_tables.yml`, `_clean_repo_data.yml`, `report_audit_run.yml`, `test_*.yml`

### Current Configuration (DEV Environment)

```yaml
repo_host:      "crlnxd1046"
repo_port:      "1535"
repo_sid:       "d1hub"
repo_user:      "DBAORALIC_SCH"
repo_schema:    "DBAORALIC_SCH"
repo_password:  "PP1_mQo84M8G"
repo_tns_alias: ""              # Or set to "d1hub" if TNS configured
```

### Migrating to TEST/PROD

**When moving from DEV → TEST → PROD:**

1. **Edit BOTH files** (keep them in sync):
   - `roles/oracle_options_audit/defaults/main.yml`
   - `vars/repo_config.yml`

2. **Update these variables:**
   ```yaml
   repo_host:     "new-host"
   repo_port:     "new-port"
   repo_sid:      "new-sid"
   repo_user:     "new-user"
   repo_password: "new-password"  # Use ansible-vault encrypt_string!
   ```

3. **Test the connection:**
   ```bash
   ansible-playbook playbooks/_validate_repo.yml
   ```

4. **Run a small test collection:**
   ```bash
   ansible-playbook playbooks/collect_oracle_options.yml -i inventory_test
   ```

### Files Updated to Use Central Config

✅ **Playbooks using role defaults** (no changes needed):
- `playbooks/collect_oracle_options.yml`

✅ **Standalone playbooks now using `vars/repo_config.yml`**:
- `playbooks/_validate_repo.yml`
- `playbooks/_setup_audit_tables.yml`
- `playbooks/_check_audit_tables.yml`
- `playbooks/_clean_repo_data.yml`
- `playbooks/report_audit_run.yml`
- `playbooks/test_repo_features.yml`
- `playbooks/test_insert_debug.yml`

### Overriding at Runtime

You can still override any setting with `-e` flags:

```bash
# Override for a one-time test
ansible-playbook playbooks/collect_oracle_options.yml \
  -i inv_key.yml \
  -e "repo_host=test-server repo_password=temp-pass"
```

---

**Last Updated:** 2026-05-11  
**Current Environment:** DEV (d1hub)  
**Contact:** Mohsen.Taheri@transamerica.com
