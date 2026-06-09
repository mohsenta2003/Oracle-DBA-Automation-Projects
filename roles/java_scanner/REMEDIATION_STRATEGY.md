# Java Footprint Audit — Remediation Strategy

**Goal:** Every JDK on every DB server we own ends in **GREEN** — no known
vulnerability, on a supported update path, and the inventory proves it.

This project is **recommendation-only**. We do **not** automate remediation
from this codebase. We produce a clear, per-host action plan and let the DBA
team execute it through normal change-management channels.

---

## 1. Scope

We are responsible for **every JDK** discovered on hosts in:

- `us_lnx_prod`, `us_lnx_nonprod` (US Linux DB servers)
- `all_eu_linux` (EU NL + UK, prod + nonprod)
- (future) AIX and Windows DB servers

This includes JDKs inside Oracle homes, Grid Infrastructure, OPatch, OEM (OMS
+ Agent), Oracle Gateway, OS-level (`/usr/lib/jvm/*`), and third-party agents
(Puppet, AWS, IBM WAS).

Most of our open vulnerability tickets trace back to one of these JDK
installations, which is why JDK currency is the central project goal.

---

## 2. Why findings sit in YELLOW today

YELLOW = "vendor-supported update path exists, but needs DBA / OEM
coordination". For DB servers we own, that coordination *is* us. The blocker
is process (change window + validation), not capability.

| Bucket | Why it's not green yet | What turns it green |
|---|---|---|
| OPatch's bundled JRE | Refreshed only when OPatch itself is updated | Update OPatch in every `ORACLE_HOME` / `GRID_HOME` to latest **p6880880** |
| Stale `OPatch_b4_update_*` dirs | Leftovers from prior patch runs | Cleanup after parent OPatch upgrade |
| 19c DB / GI JDK | Needs OPatch JDK BP + restart | Quarterly DBA change window, MOS 2843164.1 / 2118136.2 |
| Oracle Gateway JDK | Needs OPatch JDK BP + restart | Same — Gateway-specific BP |
| OEM OMS JDK | Needs OEM admin + OMS downtime | Quarterly OEM JDK BP |
| OEM Agent JDK | Bulk update | `emcli` deployment procedure |
| OS `/usr/lib/jvm` OpenJDK | Already GREEN | `dnf update java-*-openjdk` |
| 11.2 / 12.1 / 11g (RED) | EOL — no JDK patch path | Project: upgrade DB to 19c, or decommission |
| Java 1.6 / 1.7 packages | Nothing modern needs them | OS `dnf remove` where `rpm -q --whatrequires` is empty |
| Puppet / AWS / WAS bundled JREs | Vendor bundle | Update parent agent / fixpack |

---

## 3. Important caveat: OPatch upgrades are NOT one-size-fits-all

Two ORACLE_HOMEs at the same version can require **different** OPatch versions
or **different** JDK Bundle Patches because:

- The JDK BP package on MOS is keyed to `(release, RU level)`, e.g. 19.20 vs
  19.24 require different ZIPs.
- Some homes carry one-off patches that conflict with a generic "latest" BP
  and need conflict resolution (`opatch prereq CheckConflictAgainstOH`).
- Grid Infrastructure JDK BPs differ from DB Home JDK BPs even at the same
  RU level.
- OEM OMS / OEM Agent use their own JDK delivery channel — not OPatch JDK BP.
- Third-party JDKs (Puppet, AWS, WAS) are updated via their parent vendor
  package, never by overlaying a different JDK on top.

> **Therefore:** the per-host action plan must be **verified per-home** before
> any change is scheduled. Two hosts with the same Oracle release may still
> need different patch artefacts.

The recommendation report calls this out explicitly per row so the DBA
running the change knows they have to verify the BP artefact for that home.

---

## 4. Project phasing (recommendation only — no automated apply)

### Phase 0 — Visibility (in place today)

- `playbooks/scan_java_footprint.yml` — discovers all JDK installs and
  records them in `JAVA_SCAN_INSTALLS`.
- `JAVA_VERSION_REFERENCE` — track of "latest known" version per (vendor,
  major) for gap analysis.
- `JAVA_ACTION_RULES` — classification rules mapping each install path /
  major version → `(risk_tier, action_method, owner, precheck_notes)`.
- `playbooks/report_java_scan_run.yml` — emits HTML + text reports with:
  - By install context, by version, by application, by owner
  - Reference Gap Analysis (vs `JAVA_VERSION_REFERENCE`)
  - **Action Plan** section (rule-driven recommended method per finding)
  - Outdated detail aggregated by finding with hostname list + count
  - Email body is an **analyzed executive summary** (KPIs, RED/YELLOW/GREEN
    counts, prioritized next steps), with the full TXT + HTML attached.

### Phase 1 — Per-Host Action Plan (the next deliverable)

Add a **"Per-Host Action Plan"** section to the report that, for every host
in the latest scan, prints a checklist:

```
crlnxp1086 (PROD) — 9 findings, target = GREEN
  [GREEN]  dnf update java-1.8.0-openjdk            1 install
  [GREEN]  rm -rf /u01/app/oracle/.../OPatch_b4_*   2 stale dirs
  [YELLOW] OPatch self-update on /u01/.../19.20     1 home   (verify p6880880 latest)
  [YELLOW] Oracle 19c DB Home JDK BP                4 installs (verify BP for 19.20)
  [YELLOW] OEM Agent JDK update                     1 install (coordinate with OEM admin)
  ----------------------------------------
  Path to GREEN: 3 GREEN actions immediate, 6 YELLOW actions next change window
```

This is the operational artefact the DBA team uses. It is not auto-applied —
it is a **recommendation** they verify and execute manually, one home / one
host at a time.

### Phase 2 — OPatch refresh tracking (recommendation only)

- Report records the OPatch version detected per home alongside the latest
  known **p6880880** in `JAVA_VERSION_REFERENCE` (or a new
  `OPATCH_REFERENCE` row).
- Recommendation column tells the DBA whether the home's OPatch is current
  or behind, and which p6880880 ZIP to apply.
- DBA-owned, no DB downtime. Updating OPatch alone refreshes its bundled
  JRE — clearing every `OPATCH-BUNDLED-JRE` finding.

### Phase 3 — Quarterly Oracle JDK BP campaign (DBA-driven)

- Per home, recommendation includes the MOS-noted JDK BP ID for
  `(product, release, RU)`.
- DBAs verify the BP artefact, run `opatch prereq` on a TEST/MODEL home
  first, schedule per-rack change windows, apply, validate.
- Report's RED/YELLOW/GREEN counts re-baseline after each wave.

### Phase 4 — OEM bundle (OEM-admin-driven)

- One coordinated OMS BP + agent fleet update.
- Touches every host with an OEM agent.

### Phase 5 — RED-track project (separate stream)

- Hosts with EOL Oracle homes (11.2 / 12.1 / 11g) get tagged into a
  `JAVA_REMEDIATION_PROJECT` table (or a Jira tag) with target date / owner.
- They stay RED in the report until the underlying DB is upgraded or the
  host is decommissioned. That's a database project, not a Java project.

---

## 5. Per-host verification rules

For each YELLOW recommendation, the DBA must verify before applying:

| Recommendation | Verification step |
|---|---|
| OPatch self-update | `cd $OH/OPatch && ./opatch version` → compare to MOS p6880880 latest |
| Oracle 19c DB JDK BP | `opatch lspatches` on the home; `opatch prereq CheckConflictAgainstOH -ph <BP>` |
| Oracle 19c GI JDK BP | Same; rolling per-node; verify cluster health before/after |
| Gateway JDK BP | Verify Gateway home version; confirm BP applies to that release |
| OEM OMS JDK | Confirm OMS version; follow MOS-noted procedure for that OMS release |
| OEM Agent JDK | Confirm agent version; bulk update via emcli, validate target health post-update |
| OS OpenJDK update | `rpm -q --whatrequires` to confirm dependents tolerate update |
| Legacy Java removal | `rpm -q --whatrequires java-1.6.0-openjdk java-1.7.0-openjdk` returns empty |
| Stale OPatch backup cleanup | Parent `$OH/OPatch` exists and reports newer version than the backup |

The report includes a `precheck_notes` column from `JAVA_ACTION_RULES` so the
DBA sees the verification requirement next to each recommendation.

---

## 6. What this project does and does not do

**Does:**

- Inventories every JDK on every in-scope host.
- Classifies each install by risk tier and supported update method.
- Produces a per-finding and (Phase 1) per-host recommendation with the
  verification step the DBA must perform before applying.
- Sends an analyzed email summary on every run with prioritized next steps.

**Does not:**

- Apply OPatch updates, JDK Bundle Patches, OS package updates, or any
  remediation action automatically. Remediation playbooks (e.g.
  `remediate_java_safe.yml`) exist as **dry-run-by-default tools** for the
  DBA to use under their own change ticket — they are never run unattended
  from this project.
- Make decisions about Oracle DB upgrade or decommission projects. RED
  findings are surfaced; the resolution is owned elsewhere.
- Re-implement OEM, Puppet, or third-party update mechanisms. Those vendors
  own their own JDK delivery channels; we only report the gap.

---

## 7. File map

| Path | Role |
|---|---|
| [playbooks/scan_java_footprint.yml](../../playbooks/scan_java_footprint.yml) | Discovery scan — populates `JAVA_SCAN_INSTALLS` |
| [playbooks/_setup_java_scan_tables.yml](../../playbooks/_setup_java_scan_tables.yml) | Repo schema (servers, installs, runs, reference) |
| [playbooks/update_java_reference.yml](../../playbooks/update_java_reference.yml) | Loads `JAVA_VERSION_REFERENCE` from YAML |
| [vars/java_reference.yml](../../vars/java_reference.yml) | Latest-known JDK per track (Oracle, OpenJDK, IBM, Corretto) |
| [playbooks/update_java_action_rules.yml](../../playbooks/update_java_action_rules.yml) | Loads `JAVA_ACTION_RULES` from YAML |
| [vars/java_action_rules.yml](../../vars/java_action_rules.yml) | Path-pattern → (tier, method, owner, precheck) classification |
| [playbooks/report_java_scan_run.yml](../../playbooks/report_java_scan_run.yml) | Generates HTML + text report and analyzed email body |
| [vars/java_repo_snapshot.sql](../../vars/java_repo_snapshot.sql) | Ad-hoc diagnostic SQL for the repo |
| [playbooks/remediate_java_safe.yml](../../playbooks/remediate_java_safe.yml) | Tier-GREEN dry-run tool (manual use only) |

---

## 8. Operating model

1. Scanner runs on schedule (US + EU).
2. Reference and action-rules tables are reviewed and refreshed as new
   versions / patch paths become known (edit YAML, re-run update playbook).
3. Report runs after each scan and emails the analyzed summary; full HTML +
   TXT are attached for DBA review.
4. DBA team uses the **per-host action plan** to schedule changes, verifying
   each step's preconditions before opening a change ticket.
5. After DBA executes a change, re-scan picks up the improvement; the next
   email shows the updated RED / YELLOW / GREEN counts.
6. Goal is monotonic decrease in YELLOW + RED, with GREEN-only as the
   long-term steady state.

---

## 9. Run commands (US and EU)

Use these as copy-paste templates from repo root.

### 9.1 Visibility scan

US:

```bash
ansible-playbook playbooks/collect_java_footprint.yml \
  -i ansibleInventory/inv_key.yml \
  -e "repo_password=<repo-password-us>"
```

EU:

```bash
ansible-playbook playbooks/collect_java_footprint.yml \
  -i ansibleInventory/inv_key.yml \
  -e "@vars/java_scanner_config_eu.yml" \
  -e "repo_password=<repo-password-eu>"
```

TLP AIX (dcup\*, dcunx\*, cranxp016, cranxm006 — password: `<aix-group1-password>`):

```bash
ansible-playbook playbooks/collect_java_footprint.yml \
  -i ansibleInventory/inv_key.yml \
  --limit "tlp_aix_prod:tlp_aix_nonprod" \
  -e "ansible_ssh_pass=<aix-group1-password> repo_password=<repo-password-us>" \
  -e "ansible_shell_executable=/usr/bin/ksh"
```

> **Note:** All AIX hosts require `-e "ansible_shell_executable=/usr/bin/ksh"` because
> the scanner script uses constructs (e.g. `case` inside `$()`) that AIX `/bin/sh`
> and older ksh reject. This is now included in all AIX commands above.
> `dcup62` additionally has an interactive Oracle environment menu in its `.profile`
> that corrupts Ansible's SSH data channel — the ksh override also bypasses that.

TLP AIX (cranxp014 — password: `<aix-group2-password>`):

```bash
ansible-playbook playbooks/collect_java_footprint.yml \
  -i ansibleInventory/inv_key.yml \
  --limit "tlp_aix_prod2:tlp_aix_nonprod2" \
  -e "ansible_ssh_pass=<aix-group2-password> repo_password=<repo-password-us>" \
  -e "ansible_shell_executable=/usr/bin/ksh"
```

> **Scanning all non-EU hosts — why 3 separate runs are required:**
> The two AIX password groups cannot be combined in a single command because
> `-e "ansible_ssh_pass=..."` applies to every host in the run. Mixing them
> would apply the wrong password to half the AIX fleet. The correct sequence is:
>
> | Run | `--limit` | Auth |
> |-----|-----------|------|
> | 1 | `all_us_linux:tlp_lnx_prod:tlp_lnx_nonprod` | SSH key (no password needed) |
> | 2 | `tlp_aix_prod:tlp_aix_nonprod` | `ansible_ssh_pass=<aix-group1-password>` |
> | 3 | `tlp_aix_prod2:tlp_aix_nonprod2` | `ansible_ssh_pass=<aix-group2-password>` |
>
> All three runs write to the same US repo DB, so the consolidated report
> (`report_java_scan_run.yml`) covers the full non-EU fleet after all three
> complete.

### 9.2 Refresh action rules into repo

US:

```bash
ansible-playbook playbooks/update_java_action_rules.yml \
  -i "localhost," -c local \
  -e "repo_password=<repo-password-us>"
```

EU:

```bash
ansible-playbook playbooks/update_java_action_rules.yml \
  -i "localhost," -c local \
  -e "@vars/java_scanner_config_eu.yml" \
  -e "repo_password=<repo-password-eu>"
```

### 9.3 Generate report

Full non-EU fleet (US Linux + TLP Linux + all AIX — latest scan per host, all runs):

```bash
ansible-playbook playbooks/report_java_scan_run.yml \
  -e "repo_password=<repo-password-us>"
```

> When `report_run_id` is omitted (default), the report aggregates the **latest
> scan result per host** across all run IDs. After completing all 3 scan runs
> (Run 1 US/TLP Linux, Run 2 AIX group 1, Run 3 AIX group 2), this single
> command produces a consolidated report covering the entire non-EU fleet.

EU:

```bash
ansible-playbook playbooks/report_java_scan_run.yml \
  -e "@vars/java_scanner_config_eu.yml" \
  -e "repo_password=<repo-password-eu>"
```

Optional subset example (latest per host only for 2 servers):

```bash
ansible-playbook playbooks/report_java_scan_run.yml \
  -e "repo_password=<repo-password-us>" \
  -e "host_filter=crlnxp083,crlnxp140"
```

### 9.4 Tier-GREEN safe remediation (manual, dry-run first)

US dry-run:

```bash
ansible-playbook playbooks/remediate_java_safe.yml \
  -i ansibleInventory/inv_key.yml \
  --limit us_lnx_nonprod \
  -e "repo_password=<repo-password-us> do_update_openjdk=true do_remove_legacy_java=true do_clean_opatch_backups=true"
```

US apply:

```bash
ansible-playbook playbooks/remediate_java_safe.yml \
  -i ansibleInventory/inv_key.yml \
  --limit us_lnx_nonprod \
  -e "repo_password=<repo-password-us> do_update_openjdk=true do_remove_legacy_java=true do_clean_opatch_backups=true apply=true"
```

EU dry-run:

```bash
ansible-playbook playbooks/remediate_java_safe.yml \
  -i ansibleInventory/inv_key.yml \
  --limit all_eu_linux \
  -e "@vars/java_scanner_config_eu.yml" \
  -e "repo_password=<repo-password-eu> do_update_openjdk=true do_remove_legacy_java=true do_clean_opatch_backups=true"
```

After any apply, re-run scan + report for the same scope to verify outcome.
