# Sample Ansible Run Output

This document shows realistic execution output for the Oracle Options Audit project.

---

## STEP 1: Collection Playbook

```bash
$ ansible-playbook playbooks/collect_oracle_options.yml \
    -i inv_key.yml \
    -l "crlnxm145,crlnxt222"
```

### Output:

```
PLAY [Collect Oracle Options Audit Data] **************************************

TASK [Gathering Facts] *********************************************************
ok: [crlnxm145]
ok: [crlnxt222]

TASK [oracle_options_audit : Detect Oracle processes] *************************
ok: [crlnxm145]
ok: [crlnxt222]

TASK [oracle_options_audit : Set Oracle instances fact] ***********************
ok: [crlnxm145]
ok: [crlnxt222]

TASK [oracle_options_audit : Display detected instances] **********************
ok: [crlnxm145] => {
    "msg": [
        "Detected Oracle instances on crlnxm145:",
        "  - SID: aahd, ORACLE_HOME: /u01/app/oracle/product/19.0.0/dbhome_1"
    ]
}
ok: [crlnxt222] => {
    "msg": [
        "Detected Oracle instances on crlnxt222:",
        "  - SID: aahsb, ORACLE_HOME: /u01/app/oracle/product/19.0.0/dbhome_1"
    ]
}

TASK [oracle_options_audit : Include instance check tasks] ********************
included: /temp/project/ansible/Oracle-DBA-Automation-Projects-main/roles/oracle_options_audit/tasks/check_instance.yml for crlnxm145 => (item={'sid': 'aahd', 'home': '/u01/app/oracle/product/19.0.0/dbhome_1'})
included: /temp/project/ansible/Oracle-DBA-Automation-Projects-main/roles/oracle_options_audit/tasks/check_instance.yml for crlnxt222 => (item={'sid': 'aahsb', 'home': '/u01/app/oracle/product/19.0.0/dbhome_1'})

TASK [oracle_options_audit : Test connection to aahd] **************************
changed: [crlnxm145]

TASK [oracle_options_audit : Get database version for aahd] *******************
changed: [crlnxm145]

TASK [oracle_options_audit : Get v$option data for aahd] **********************
changed: [crlnxm145]

TASK [oracle_options_audit : Get feature usage statistics for aahd] ***********
changed: [crlnxm145]

TASK [oracle_options_audit : Auto-detect Partitioning usage for aahd] *********
ok: [crlnxm145]

TASK [oracle_options_audit : Auto-detect Compression usage for aahd] **********
ok: [crlnxm145]

TASK [oracle_options_audit : Auto-detect Security/TDE usage for aahd] *********
ok: [crlnxm145]

TASK [oracle_options_audit : Auto-detect In-Memory usage for aahd] ************
ok: [crlnxm145]

TASK [oracle_options_audit : Debug - Show auto-detection status for aahd] *****
ok: [crlnxm145] => {
    "msg": [
        "=== AUTO-DETECTION STATUS ===",
        "Partitioning: True (feature usage detected)",
        "Compression:  False",
        "Security/TDE: False",
        "In-Memory:    True (feature usage detected)",
        "",
        "Collection will proceed for auto-detected features even if collect_* flags are false"
    ]
}

TASK [oracle_options_audit : Collect Partitioning evidence for aahd] **********
changed: [crlnxm145]

TASK [oracle_options_audit : Collect Compression evidence for aahd] ***********
skipping: [crlnxm145]

TASK [oracle_options_audit : Collect Security/TDE evidence for aahd] **********
skipping: [crlnxm145]

TASK [oracle_options_audit : Collect In-Memory evidence for aahd] *************
changed: [crlnxm145]

TASK [oracle_options_audit : Detect RAC for aahd] *****************************
changed: [crlnxm145]

TASK [oracle_options_audit : Detect Active Data Guard for aahd] ***************
changed: [crlnxm145]

TASK [oracle_options_audit : Debug - Show evidence summary for aahd] **********
ok: [crlnxm145] => {
    "msg": [
        "=== EVIDENCE COLLECTION SUMMARY ===",
        "Host: crlnxm145, SID: aahd",
        "",
        "Partitioning rows: 264 [IN USE]",
        "Compression rows:  0",
        "Security rows:     0",
        "In-Memory rows:    0 [IN USE]",
        "RAC nodes:         0",
        "ADG standbys:      0",
        "",
        "Auto-detection: Part=True Comp=False Sec=False IM=True",
        "IM Auto-collected: True (no current objects found)",
        "",
        "Interpretation:",
        "  • Partitioning: 264 evidence rows - feature actively used NOW",
        "  • In-Memory: 0 evidence rows but IN USE flag - feature used historically",
        "  • Feature used in past but currently disabled = valid for compliance",
        "  • Historical evidence preserved in dba_feature_usage_statistics",
        "  • Timeline reports will show when objects existed"
    ]
}

TASK [oracle_options_audit : Test connection to aahsb] *************************
changed: [crlnxt222]

TASK [oracle_options_audit : Get database version for aahsb] ******************
changed: [crlnxt222]

TASK [oracle_options_audit : Get v$option data for aahsb] *********************
changed: [crlnxt222]

TASK [oracle_options_audit : Get feature usage statistics for aahsb] **********
changed: [crlnxt222]

TASK [oracle_options_audit : Auto-detect Partitioning usage for aahsb] ********
ok: [crlnxt222]

TASK [oracle_options_audit : Auto-detect Compression usage for aahsb] *********
ok: [crlnxt222]

TASK [oracle_options_audit : Auto-detect Security/TDE usage for aahsb] ********
ok: [crlnxt222]

TASK [oracle_options_audit : Auto-detect In-Memory usage for aahsb] ***********
ok: [crlnxt222]

TASK [oracle_options_audit : Debug - Show auto-detection status for aahsb] ****
ok: [crlnxt222] => {
    "msg": [
        "=== AUTO-DETECTION STATUS ===",
        "Partitioning: True (feature usage detected)",
        "Compression:  False",
        "Security/TDE: False",
        "In-Memory:    True (feature usage detected)",
        "",
        "Collection will proceed for auto-detected features even if collect_* flags are false"
    ]
}

TASK [oracle_options_audit : Collect Partitioning evidence for aahsb] *********
changed: [crlnxt222]

TASK [oracle_options_audit : Collect Compression evidence for aahsb] **********
skipping: [crlnxt222]

TASK [oracle_options_audit : Collect Security/TDE evidence for aahsb] *********
skipping: [crlnxt222]

TASK [oracle_options_audit : Collect In-Memory evidence for aahsb] ************
changed: [crlnxt222]

TASK [oracle_options_audit : Detect RAC for aahsb] ****************************
changed: [crlnxt222]

TASK [oracle_options_audit : Detect Active Data Guard for aahsb] **************
changed: [crlnxt222]

TASK [oracle_options_audit : Debug - Show evidence summary for aahsb] *********
ok: [crlnxt222] => {
    "msg": [
        "=== EVIDENCE COLLECTION SUMMARY ===",
        "Host: crlnxt222, SID: aahsb",
        "",
        "Partitioning rows: 156 [IN USE]",
        "Compression rows:  0",
        "Security rows:     0",
        "In-Memory rows:    0 [IN USE]",
        "RAC nodes:         0",
        "ADG standbys:      0",
        "",
        "Auto-detection: Part=True Comp=False Sec=False IM=True",
        "IM Auto-collected: True (no current objects found)",
        "",
        "Interpretation:",
        "  • Partitioning: 156 evidence rows - feature actively used NOW",
        "  • In-Memory: 0 evidence rows but IN USE flag - feature used historically",
        "  • Feature used in past but currently disabled = valid for compliance",
        "  • Historical evidence preserved in dba_feature_usage_statistics",
        "  • Timeline reports will show when objects existed"
    ]
}

TASK [oracle_options_audit : Test repository connection] **********************
changed: [localhost]

TASK [oracle_options_audit : Create RUN_ID in repository] *********************
changed: [localhost]

TASK [oracle_options_audit : Parse RUN_ID from output] ************************
ok: [localhost]

TASK [oracle_options_audit : Display RUN_ID] **********************************
ok: [localhost] => {
    "msg": "Created RUN_ID: 42"
}

TASK [oracle_options_audit : Generate SQL for crlnxm145] **********************
changed: [localhost]

TASK [oracle_options_audit : Generate SQL for crlnxt222] **********************
changed: [localhost]

TASK [oracle_options_audit : Execute SQL for crlnxm145] ***********************
changed: [localhost]

TASK [oracle_options_audit : Verify insert for crlnxm145] *********************
changed: [localhost]

TASK [oracle_options_audit : Execute SQL for crlnxt222] ***********************
changed: [localhost]

TASK [oracle_options_audit : Verify insert for crlnxt222] *********************
changed: [localhost]

TASK [oracle_options_audit : Display summary] *********************************
ok: [localhost] => {
    "msg": [
        "=====================================",
        "Oracle Options Audit - Collection Complete",
        "=====================================",
        "RUN_ID:       42",
        "Run Date:     2026-05-12 14:30:22",
        "Hosts:        2",
        "Instances:    2",
        "",
        "Data Location:",
        "  Repository: crlnxd1046:1535/d1hub (DBAORALIC_SCH)",
        "  SQL Files:  logs/oracle_options_audit/2026-05-12/",
        "",
        "Evidence Summary:",
        "  crlnxm145/aahd:  264 partitioning, 0 compression, 0 security, 0 inmemory",
        "  crlnxt222/aahsb: 156 partitioning, 0 compression, 0 security, 0 inmemory",
        "",
        "Auto-Detection:",
        "  ✓ Partitioning auto-detected on both instances",
        "  ✓ In-Memory auto-detected on both instances (historical usage)",
        "",
        "Next Steps:",
        "  1. Run report_audit_run.yml for current state HTML report",
        "  2. Run report_timeline.yml for historical timeline analysis",
        "",
        "Note: In-Memory shows 0 objects but IS_INUSE=Y because feature",
        "      was used historically. Timeline reports will show when",
        "      objects existed in previous collections."
    ]
}

PLAY RECAP *********************************************************************
crlnxm145                  : ok=25   changed=11   unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
crlnxt222                  : ok=25   changed=11   unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
localhost                  : ok=10   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

---

## STEP 2: Current State Report Playbook

```bash
$ ansible-playbook playbooks/report_audit_run.yml \
    -i "localhost," -c local \
    -e "repo_tns_alias=d1hub"
```

### Output:

```
PLAY [Generate Oracle Options Audit Report] ***********************************

TASK [Gathering Facts] *********************************************************
ok: [localhost]

TASK [Query latest RUN_ID] ****************************************************
changed: [localhost]

TASK [Parse RUN_ID] ***********************************************************
ok: [localhost]

TASK [Display RUN_ID] *********************************************************
ok: [localhost] => {
    "msg": "Generating report for RUN_ID: 42 (2026-05-12)"
}

TASK [Query audit data from repository] ***************************************
changed: [localhost]

TASK [Query instance summary] *************************************************
changed: [localhost]

TASK [Query option summary] ***************************************************
changed: [localhost]

TASK [Query evidence details] *************************************************
changed: [localhost]

TASK [Generate HTML report] ***************************************************
changed: [localhost]

TASK [Display report path] ****************************************************
ok: [localhost] => {
    "msg": [
        "Report generated successfully:",
        "  File: /tmp/oracle_options_audit_RUN42_2026-05-12.html",
        "  Size: 248 KB"
    ]
}

TASK [Send email with report] *************************************************
changed: [localhost]

TASK [Display email status] ***************************************************
ok: [localhost] => {
    "msg": [
        "========================================",
        "Email sent successfully!",
        "========================================",
        "From:    crlnxp1086@transamerica.com",
        "To:      Mohsen.Taheri@transamerica.com",
        "Subject: Oracle Options Audit Report - RUN42 - 2026-05-12",
        "SMTP:    mail1.us.aegon.com:25",
        "",
        "Report attached: oracle_options_audit_RUN42_2026-05-12.html (248 KB)"
    ]
}

PLAY RECAP *********************************************************************
localhost                  : ok=12   changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

---

## STEP 3: The Email You Receive

### Email Headers:
```
From:     crlnxp1086@transamerica.com
To:       Mohsen.Taheri@transamerica.com
Subject:  Oracle Options Audit Report - RUN42 - 2026-05-12
Date:     Mon, 12 May 2026 14:35:15 -0500
```

### Email Body (Plain Text):

```
Oracle Options Audit Report
===========================

Run ID:   42
Run Date: 2026-05-12 14:30:22
Scanned:  2 hosts, 2 Oracle instances

SUMMARY
-------
✓ Scan completed successfully
✓ Data stored in repository: crlnxd1046:1535/d1hub
✓ Historical timeline preserved (old data not deleted)

HIGH-RISK LICENSE FINDINGS
--------------------------
⚠️  Partitioning - IN USE on 2 instances:
    • crlnxm145/aahd  - 264 partitioned objects (Tables: 45, Indexes: 219)
    • crlnxt222/aahsb - 156 partitioned objects (Tables: 28, Indexes: 128)

ENABLED BUT NOT CURRENTLY IN USE
---------------------------------
ℹ️  In-Memory Column Store - Detected historical usage:
    • crlnxm145/aahd  - Used 2024-03-15 to 2024-08-22 (0 objects now)
    • crlnxt222/aahsb - Used 2024-05-10 to 2024-09-15 (0 objects now)
    
    Note: Feature shows usage statistics but no current objects.
          Timeline reports available for historical analysis.

OPTIONS WITH NO USAGE
---------------------
✓ Advanced Compression    - Not used
✓ Advanced Security / TDE - Not used
✓ Real Application Clusters - Not enabled
✓ Active Data Guard       - Not enabled

RECOMMENDATIONS
---------------
1. Partitioning: Review license compliance - feature actively in use
2. In-Memory: Run timeline report to verify when/why feature was disabled
3. Regular monitoring: Schedule monthly audits to track changes

DETAILED REPORT
---------------
See attached HTML file for complete details including:
  • All 88 v$option flags per instance
  • All 65 feature usage statistics per instance
  • Complete evidence tables (partitioned objects, owners, sizes)
  • Historical usage dates from Oracle's tracking
  • Auto-detection status

NEXT STEPS
----------
For historical timeline analysis:
  ansible-playbook playbooks/report_timeline.yml \
    -i "localhost," -c local \
    -e "repo_tns_alias=d1hub option=all"

Questions? Contact: DBA-Team@transamerica.com
Generated by: Ansible Oracle Options Audit v2.0
```

### HTML Report Attachment Preview:

The attached HTML file contains:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Oracle Options Audit Report - RUN42</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #0066cc; border-bottom: 3px solid #0066cc; }
        h2 { color: #0099cc; margin-top: 30px; }
        .warning { background-color: #fff3cd; padding: 15px; border-left: 5px solid #ffc107; }
        .info { background-color: #d1ecf1; padding: 15px; border-left: 5px solid #17a2b8; }
        .success { background-color: #d4edda; padding: 15px; border-left: 5px solid #28a745; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th { background-color: #0066cc; color: white; padding: 10px; text-align: left; }
        td { padding: 8px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .inuse { color: #dc3545; font-weight: bold; }
        .enabled { color: #ffc107; }
        .notused { color: #28a745; }
    </style>
</head>
<body>
    <h1>🔍 Oracle Options Audit Report</h1>
    
    <div class="info">
        <strong>Run Information</strong><br>
        Run ID: <strong>42</strong><br>
        Run Date: <strong>2026-05-12 14:30:22</strong><br>
        Hosts Scanned: <strong>2</strong><br>
        Oracle Instances: <strong>2</strong><br>
        Repository: crlnxd1046:1535/d1hub (DBAORALIC_SCH)
    </div>

    <h2>⚠️ HIGH-RISK LICENSE FINDINGS</h2>
    
    <div class="warning">
        <h3>Partitioning - IN USE (2 instances)</h3>
        <p>This feature requires separate licensing. Evidence found:</p>
    </div>

    <table>
        <tr>
            <th>Host</th>
            <th>SID</th>
            <th>Version</th>
            <th>Evidence</th>
            <th>Details</th>
        </tr>
        <tr>
            <td>crlnxm145</td>
            <td>aahd</td>
            <td>19.0.0.0.0</td>
            <td><span class="inuse">264 objects</span></td>
            <td>45 partitioned tables, 219 partitioned indexes</td>
        </tr>
        <tr>
            <td>crlnxt222</td>
            <td>aahsb</td>
            <td>19.0.0.0.0</td>
            <td><span class="inuse">156 objects</span></td>
            <td>28 partitioned tables, 128 partitioned indexes</td>
        </tr>
    </table>

    <h3>Partitioned Tables Details - crlnxm145/aahd (Top 10 by size)</h3>
    <table>
        <tr>
            <th>Owner</th>
            <th>Table Name</th>
            <th>Partitions</th>
            <th>Partition Type</th>
            <th>Size (GB)</th>
        </tr>
        <tr>
            <td>SALES_APP</td>
            <td>ORDERS_HISTORY</td>
            <td>48</td>
            <td>RANGE (MONTHLY)</td>
            <td>245.8</td>
        </tr>
        <tr>
            <td>SALES_APP</td>
            <td>TRANSACTIONS</td>
            <td>24</td>
            <td>RANGE (QUARTERLY)</td>
            <td>189.3</td>
        </tr>
        <tr>
            <td>HR_APP</td>
            <td>EMPLOYEE_AUDIT</td>
            <td>60</td>
            <td>RANGE (MONTHLY)</td>
            <td>87.2</td>
        </tr>
        <tr>
            <td>FINANCE_APP</td>
            <td>GL_JOURNAL</td>
            <td>120</td>
            <td>RANGE (MONTHLY)</td>
            <td>156.9</td>
        </tr>
        <tr>
            <td colspan="5"><em>... and 41 more partitioned tables</em></td>
        </tr>
    </table>

    <h2>ℹ️ ENABLED BUT NOT CURRENTLY IN USE</h2>
    
    <div class="info">
        <h3>In-Memory Column Store - Historical Usage Detected</h3>
        <p>Feature statistics show past usage, but no objects currently in memory.</p>
    </div>

    <table>
        <tr>
            <th>Host</th>
            <th>SID</th>
            <th>First Usage</th>
            <th>Last Usage</th>
            <th>Days Since</th>
            <th>Current Objects</th>
        </tr>
        <tr>
            <td>crlnxm145</td>
            <td>aahd</td>
            <td>2024-03-15</td>
            <td>2024-08-22</td>
            <td>264 days ago</td>
            <td><span class="enabled">0 (disabled)</span></td>
        </tr>
        <tr>
            <td>crlnxt222</td>
            <td>aahsb</td>
            <td>2024-05-10</td>
            <td>2024-09-15</td>
            <td>240 days ago</td>
            <td><span class="enabled">0 (disabled)</span></td>
        </tr>
    </table>

    <div class="info">
        <strong>Note:</strong> This is VALID and expected. Oracle's dba_feature_usage_statistics 
        preserves historical records even after features are disabled. To see when objects 
        existed in In-Memory, run the timeline report:
        <pre>ansible-playbook playbooks/report_timeline.yml -e "option=inmemory"</pre>
    </div>

    <h2>✓ OPTIONS WITH NO USAGE</h2>
    
    <div class="success">
        <strong>No licensing concerns for these features:</strong>
        <ul>
            <li>✓ Advanced Compression - Not detected</li>
            <li>✓ Advanced Security / TDE - Not detected</li>
            <li>✓ Real Application Clusters - Not enabled</li>
            <li>✓ Active Data Guard - Not detected</li>
            <li>✓ Database Vault - Not enabled</li>
            <li>✓ Label Security - Not enabled</li>
        </ul>
    </div>

    <h2>📊 COMPLETE FEATURE MATRIX</h2>
    
    <table>
        <tr>
            <th rowspan="2">Feature Name</th>
            <th colspan="2">crlnxm145/aahd</th>
            <th colspan="2">crlnxt222/aahsb</th>
        </tr>
        <tr>
            <th>Currently Used</th>
            <th>Detected Usages</th>
            <th>Currently Used</th>
            <th>Detected Usages</th>
        </tr>
        <tr>
            <td>Partitioning (system)</td>
            <td class="inuse">TRUE</td>
            <td class="inuse">3847</td>
            <td class="inuse">TRUE</td>
            <td class="inuse">2156</td>
        </tr>
        <tr>
            <td>In-Memory Column Store</td>
            <td class="enabled">FALSE</td>
            <td class="enabled">458</td>
            <td class="enabled">FALSE</td>
            <td class="enabled">312</td>
        </tr>
        <tr>
            <td>Advanced Compression</td>
            <td class="notused">FALSE</td>
            <td class="notused">0</td>
            <td class="notused">FALSE</td>
            <td class="notused">0</td>
        </tr>
        <tr>
            <td>Advanced Security</td>
            <td class="notused">FALSE</td>
            <td class="notused">0</td>
            <td class="notused">FALSE</td>
            <td class="notused">0</td>
        </tr>
        <tr>
            <td colspan="5"><em>... and 61 more features tracked</em></td>
        </tr>
    </table>

    <h2>🔧 AUTO-DETECTION STATUS</h2>
    
    <div class="success">
        <strong>Auto-Detection Feature (May 2026 Enhancement):</strong>
        <p>System automatically collects evidence when feature usage is detected, 
        preventing "missing evidence" issues even when collection flags are disabled.</p>
        
        <table>
            <tr>
                <th>Feature</th>
                <th>crlnxm145/aahd</th>
                <th>crlnxt222/aahsb</th>
            </tr>
            <tr>
                <td>Partitioning</td>
                <td>✓ Auto-detected (collected)</td>
                <td>✓ Auto-detected (collected)</td>
            </tr>
            <tr>
                <td>Compression</td>
                <td>Not detected (skipped)</td>
                <td>Not detected (skipped)</td>
            </tr>
            <tr>
                <td>Security/TDE</td>
                <td>Not detected (skipped)</td>
                <td>Not detected (skipped)</td>
            </tr>
            <tr>
                <td>In-Memory</td>
                <td>✓ Auto-detected (no objects)</td>
                <td>✓ Auto-detected (no objects)</td>
            </tr>
        </table>
    </div>

    <h2>📅 HISTORICAL TIMELINE</h2>
    
    <div class="info">
        <strong>Timeline Preservation:</strong>
        <p>This is RUN_ID 42. Previous runs (41, 40, 39...) remain in the repository 
        for historical analysis. To see how options usage changed over time:</p>
        <pre>ansible-playbook playbooks/report_timeline.yml -e "option=all"</pre>
        
        <p>Timeline reports show:</p>
        <ul>
            <li>When objects first appeared / last seen</li>
            <li>How partition counts changed over time</li>
            <li>When features were enabled/disabled</li>
            <li>Complete audit trail for compliance</li>
        </ul>
    </div>

    <hr>
    <p style="color: #666; font-size: 0.9em;">
        Generated by Ansible Oracle Options Audit v2.0 | Run ID: 42 | 2026-05-12 14:35:15<br>
        Repository: crlnxd1046:1535/d1hub | Schema: DBAORALIC_SCH<br>
        Questions? Contact: DBA-Team@transamerica.com
    </p>
</body>
</html>
```

---

## BONUS: Timeline Report Output

If you then run the timeline playbook:

```bash
$ ansible-playbook playbooks/report_timeline.yml \
    -i "localhost," -c local \
    -e "repo_tns_alias=d1hub option=inmemory"

PLAY [Generate Oracle Options Timeline Report] ********************************

TASK [Get run statistics] *****************************************************
changed: [localhost]

TASK [Display run statistics] *************************************************
ok: [localhost] => {
    "msg": [
        "Timeline Analysis:",
        "  Total runs: 42",
        "  Date range: 2025-11-15 to 2026-05-12",
        "  Days: 179",
        "  Option: inmemory"
    ]
}

TASK [Generate timeline report] ***********************************************
changed: [localhost]

TASK [Display report location] ************************************************
ok: [localhost] => {
    "msg": [
        "Timeline reports generated:",
        "  HTML: reports/timeline/timeline_inmemory_20260512_143522.html",
        "  Text: reports/timeline/timeline_inmemory_20260512_143522.txt",
        "",
        "Key findings:",
        "  • In-Memory objects last seen in RUN 39 (2026-04-25)",
        "  • Objects existed for 4 months (2025-12-20 to 2026-04-25)",
        "  • Complete removal detected 17 days ago",
        "  • Historical evidence preserved for compliance"
    ]
}

PLAY RECAP *********************************************************************
localhost                  : ok=4    changed=2    unreachable=0    failed=0
```

This shows the complete workflow with realistic output! 🎯
