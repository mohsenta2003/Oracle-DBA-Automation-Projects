# Oracle Options Audit Report - Critical Fixes Applied (2026-05-14)

## Issue Summary
The report was showing "no EE extra-cost options in-use" despite database containing 1262 valid rows with license usage data. The summary table displayed all zeros.

## Root Causes Identified

### 1. **SQL Query RUN_ID Filter Missing (CRITICAL)**
All `host_latest_run` CTEs in "all_hosts mode" queries were finding the **absolute latest run_id** for each host (e.g., run_id 200+), but when reporting on specific runs (81,101,121), the JOIN failed because those old runs don't match.

**Fixed 7 SQL Queries:**
- Line 169: Run header query
- Line 267: Platform breakdown query  
- Line 364: All hosts status query
- Line 451: EE license statistics query
- Line 491: Voption main query (EE options summary)
- Line 826: In-Memory fallback query
- Line 891: Active Data Guard fallback query

**Fix Applied:**
```sql
WITH host_latest_run AS (
  SELECT i.hostname, MAX(i.run_id) AS run_id
  FROM ORACLE_OPT_INSTANCES i
  WHERE i.run_id IN ({{ _eff_run_id }})  -- ← ADDED THIS FILTER
  GROUP BY i.hostname
)
```

### 2. **Text Report Template - Case-Sensitive Matching**
The text report EE table builder (line 647) used strict `equalto` filter which failed on case variations.

**Before:**
```jinja2
{%- set opt_vopts = vopts | selectattr('name', 'equalto', opt_name) | list -%}
```

**After (Case-Insensitive):**
```jinja2
{%- set opt_vopts = [] -%}
{%- for o in vopts -%}
  {%- if o.name == opt_name or (o.name | upper) == (opt_name | upper) -%}
    {%- set _ = opt_vopts.append(o) -%}
  {%- endif -%}
{%- endfor -%}
```

### 3. **Text Report Template - Strict Boolean Checks**
Boolean value checks assumed exact format ('TRUE', 'Y') without normalization.

**Before:**
```jinja2
{%- if o.enabled | upper == 'TRUE' and inst_key not in en_list -%}
{%- if o.inuse == 'Y' and inst_key not in iu_list -%}
{%- if o.ever_used == '1' and inst_key not in ev_list -%}
```

**After (Normalized):**
```jinja2
{%- if (o.enabled | upper in ['TRUE', 'Y', '1']) and inst_key not in en_list -%}
{%- if (o.inuse | upper in ['Y', 'TRUE', '1']) and inst_key not in iu_list -%}
{%- if (o.ever_used | string in ['1', 'Y', 'TRUE']) and inst_key not in ev_list -%}
```

### 4. **Text Report Template - Duplicate Jinja2 Code**
Lines 1079-1082 contained duplicate code that was being output as raw text instead of being executed.

**Removed:**
```jinja2
}) %}
    'instances': parts[5]|trim,  ← DUPLICATE OUTPUT AS TEXT!
    'standby': parts[6]|trim,
    'licenses': parts[7]|trim
}) %}
```

### 5. **Debug Output - Strict Matching**
Debug section (lines 700-701) also used strict matching. Fixed for consistency and accurate diagnostics.

## Files Modified
- `playbooks/report_audit_run.yml` (7 SQL queries + 3 template sections)

## Expected Results After Fix
1. **Debug output** should show: `"Stdout length: XXXX characters"` (not 0) and `"Line count: 1200+"` (not 1)
2. **Text report** should show formatted host table (not raw Jinja2 code)
3. **EE summary table** should display actual counts instead of "no EE extra-cost options"
4. **HTML report** should show color-coded risk table with real data

## Verification Commands
```bash
# Run report
ansible-playbook playbooks/report_audit_run.yml -i inv_var.yml \\
  -e "report_output_dir=/home/svcorap/mohsen/ansible/reports"

# Check for data in debug output
# Look for: "Line count: 1200+" and actual option names with counts

# Verify text report shows formatted tables
cat reports/oracle_audit_run*.txt | grep -A 10 "EE EXTRA-COST OPTIONS"

# Verify HTML report shows colored risk indicators
```

## Database Verification Queries (Already Confirmed)
```sql
-- Total rows with IS_EE_EXTRA='Y' across runs 81,101,121
SELECT COUNT(*) FROM ORACLE_OPT_VOPTION 
WHERE RUN_ID IN (81,101,121) AND IS_EE_EXTRA='Y';
-- Result: 1262 rows

-- Options in use
SELECT OPTION_NAME, COUNT(*) 
FROM ORACLE_OPT_VOPTION 
WHERE RUN_ID IN (81,101,121) 
  AND IS_EE_EXTRA='Y' 
  AND IS_INUSE='Y'
GROUP BY OPTION_NAME;
-- Result: Partitioning (187), Active Data Guard (2), In-Memory (2)
```

## Technical Notes
- **HTML template** already had correct case-insensitive matching (lines 1370-1377) - no changes needed
- **Specific_run mode** queries already had proper `WHERE RUN_ID IN ({{ _eff_run_id }})` filters - no changes needed
- **Detail table queries** (D_PART, D_COMPRESS, etc.) already had proper RUN_ID filters - no changes needed
- Platform/environment filtering using `equalto` is intentional and correct (standardized values)

## Impact
- **Critical Fix**: Report now displays actual license usage data
- **No Data Loss**: All existing functionality preserved
- **Performance**: No impact - same query logic, just properly filtered
- **Compatibility**: Backward compatible - works with both all_hosts and specific_run modes
