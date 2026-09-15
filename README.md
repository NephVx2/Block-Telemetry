# Block-Telemetry

🇫🇷 [Version française](README_FRENCH.md)

Standalone PowerShell script that blocks telemetry, analytics, and third-party tracking domains on Windows via the `hosts` file — with automatic backups, a strict whitelist, a dry-run preview, one-click restore, and an integrity checker so the block never silently drifts out of sync.

> Nothing is guessed. A strict whitelist protects activation/licensing/update domains by exact match (never a substring match), every real change is backed up first, and the active block can be verified against the expected list at any time.

---

## Screenshots

<table>
<tr>
<td><img src="https://raw.githubusercontent.com/NephVx2/Block-Telemetry/main/screenshots/01-menu-preview.png" width="420"></td>
<td><img src="https://raw.githubusercontent.com/NephVx2/Block-Telemetry/main/screenshots/05-html-preview.png" width="420"></td>
</tr>
</table>

More screenshots (integrity check, backups list, full HTML report) in the [`screenshots/`](screenshots) folder.

---

## Table of contents

- [Screenshots](#screenshots)
- [Overview](#overview)
- [How it works](#how-it-works)
- [What gets blocked](#what-gets-blocked)
- [What is never blocked (whitelist)](#what-is-never-blocked-whitelist)
- [Safety guarantees](#safety-guarantees)
- [Prerequisites](#prerequisites)
- [First run](#first-run-step-by-step)
- [Menu reference](#menu-reference)
- [Command-line parameters](#command-line-parameters)
- [Files written by the script](#files-written-by-the-script)
- [Multi-machine deployment](#multi-machine-deployment)
- [Troubleshooting](#troubleshooting)

---

## Overview

`Block-Telemetry.ps1` edits **one file only**: the Windows `hosts` file (`C:\Windows\System32\drivers\etc\hosts`). It appends a clearly marked block of `0.0.0.0 <domain>` entries for known telemetry, analytics, and tracking domains, so that DNS resolution for those domains fails locally — no traffic reaches them.

It does **not** touch the registry, does not stop any Windows service, does not install anything, and does not modify any file other than `hosts` (plus its own backups/logs/reports on the Desktop).

The script runs as an **interactive menu** — there is no one-shot "just clean it" command line invocation for the blocking action itself (only `-SelfTest` is a pure CLI flag). This is intentional: modifying `hosts` is a standing change (unlike a one-off cleanup), so the script keeps a human in the loop for applying, updating, and restoring it.

---

## How it works

1. All changes live inside a single clearly delimited block in `hosts`:

   ```
   # === TELEMETRY BLOCK - Do not modify manually ===
   # Generated on 18 Aug 2026 10:00:00
   # To restore: rerun this script and choose option 5
   #
   # -- Microsoft Telemetry --
   0.0.0.0 vortex.data.microsoft.com
   0.0.0.0 telecommand.telemetry.microsoft.com
   ...
   # === END TELEMETRY BLOCK ===
   ```

   Everything outside these two markers is left completely untouched — your own manual `hosts` entries, entries from other tools, everything.

2. Before **any** write to `hosts`, a timestamped backup is created in `Hosts_Backups` (see [Files written by the script](#files-written-by-the-script)). If the backup fails, the script refuses to modify `hosts` at all.

3. Domains already present anywhere in your `hosts` file (added manually or by another tool) are detected and skipped rather than duplicated.

4. Restoring removes **only** the content between the two markers — your original `hosts` file (and anything else added since) is preserved exactly as it was outside that block.

---

## What gets blocked

15 categories, **228 domains** in total:

<img src="https://raw.githubusercontent.com/NephVx2/Block-Telemetry/main/screenshots/08-categories-covered.png" width="600">

<details>
<summary><strong>Microsoft Telemetry</strong> — 80 domains</summary>

Windows diagnostic data (DiagTrack / vortex / watson pipelines), Office/ARIA telemetry pipeline, Windows Defender **cloud telemetry only** (not local protection), MSN/Cortana/Bing ad and suggestion endpoints, Xbox/Game Bar telemetry, OneDrive telemetry (not sync), Teams telemetry (not communication).

*Excluded on purpose:* `windowsupdate.com`, `update.microsoft.com`, `msftconnecttest.com` (required for updates and connectivity detection).
</details>

<details>
<summary><strong>Microsoft Copilot Telemetry</strong> — 10 domains</summary>

Usage data, query and context telemetry sent to Microsoft/Bing servers. Copilot itself is not blocked functionally on machines that use it — only the analytics endpoints.
</details>

<details>
<summary><strong>Microsoft Edge Telemetry</strong> — 8 domains</summary>

Relevant even if Edge is uninstalled — WebView2 and Edge leftovers can still reach these endpoints.
</details>

<details>
<summary><strong>Google Analytics / Tracking</strong> — 14 domains</summary>

Google Analytics, Tag Manager, DoubleClick, Google Ad Services.

*Excluded on purpose:* `google.com`, `googleapis.com`, `gstatic.com` (required by many web apps and authentication flows).
</details>

<details>
<summary><strong>Adobe Analytics / Stats</strong> — 15 domains</summary>

Adobe Analytics/Omniture, Adobe Audience Manager, Adobe Dynamic Tag Manager, Adobe Marketing/Advertising Cloud.

*Excluded on purpose:* `adobe.com`, `adobelogin.com`, `adobegenuine.com`, `lcs-cops.adobe.com` (activation, licensing, functional endpoints).
</details>

<details>
<summary><strong>Third-party tracking</strong> — 46 domains</summary>

None of these belong to a locally installed app — they're only loaded by websites or apps to track you across sessions: ScorecardResearch, Quantcast, Chartbeat, Facebook/Meta tracking, Amazon Ads, Twitter/X Ads, Hotjar, Mixpanel, Segment, Criteo, Taboola, Outbrain, Rubicon/Magnite, PubMatic, OpenX, Moat, Google AMP, LinkedIn Insight Tag.
</details>

<details>
<summary><strong>Crash reports</strong> — 8 domains</summary>

Sentry.io, Bugsnag — send stack traces and system data on app crashes. Informative but intrusive; note this can reduce the quality of app bug fixes since developers lose that diagnostic data.
</details>

<details>
<summary><strong>Spotify Telemetry</strong> — 6 domains</summary>

*Excluded on purpose:* `*.spotify.com` (streaming, login, API), `*.scdn.co` (music CDN), `accounts.spotify.com`, `api.spotify.com`.
</details>

<details>
<summary><strong>Brave Analytics</strong> — 7 domains</summary>
</details>

<details>
<summary><strong>Mozilla / Firefox Telemetry</strong> — 9 domains</summary>
</details>

<details>
<summary><strong>NVIDIA Telemetry</strong> — 9 domains</summary>
</details>

<details>
<summary><strong>AMD Telemetry</strong> — 5 domains</summary>
</details>

<details>
<summary><strong>Discord Telemetry</strong> — 3 domains</summary>
</details>

<details>
<summary><strong>Steam / Valve Telemetry</strong> — 4 domains</summary>
</details>

<details>
<summary><strong>GOG Galaxy Telemetry</strong> — 4 domains</summary>
</details>

Use menu option **[1]** at any time to print the complete, current list grouped by category, or **[E]** to export it to a text file.

---

## What is never blocked (whitelist)

**71 domains** are hard-coded into an absolute whitelist, checked by **exact match only** (never a substring/subdomain match — see the SelfTest section) — even if one somehow ended up in the telemetry list by mistake, it would never be written to `hosts`:

- Adobe activation, licensing, registration (`activate.adobe.com`, `genuine.adobe.com`, `lcs-cops.adobe.com`...)
- Microsoft Windows Update, activation, sign-in (`update.microsoft.com`, `login.microsoftonline.com`, `msftconnecttest.com`...)
- OneDrive sync, Xbox Live auth, Teams communication
- NextDNS (critical DNS service)
- Spotify streaming/auth/API, `scdn.co` CDN
- Brave and Mozilla/Firefox update & safe-browsing endpoints
- Steam platform and anti-cheat, NVIDIA/AMD driver updates
- Discord, GOG Galaxy, Visual Studio Code updates
- Epic Games (kept whitelisted as a zero-cost precaution even though not actively used, to avoid an accidental block if the list is reused or extended on another machine later)

---

## Safety guarantees

| # | Guarantee |
|---|---|
| S1 | Automatic backup of `hosts` before any modification |
| S2 | Strict whitelist — no functional domain is ever blocked |
| S3 | Automatic backup rotation (last 10 kept) |
| S4 | Simulation mode (`-DryRun` from the menu) to preview without touching anything |
| S5 | Full built-in restore (single menu choice) |
| S6 | Unique marker in `hosts` to identify exactly what this script added |
| S7 | No registry changes, no services stopped, no drivers touched |
| S8 | Built-in "Update" option (restore + re-apply in one step) |
| S9 | Guaranteed UTF-8 **with BOM** encoding — required for PowerShell 5.1 to detect UTF-8 correctly (PowerShell 7 handles both, with or without BOM) |
| S10 | Duplicate check before writing (domains already present are skipped) |
| S11 | Conflict detection with other hosts-editing tools (CTT WinUtil, StevenBlack hosts, HostsMan, Spybot Anti-Beacon, MVPS Hosts...) |
| S12 | Active-block integrity check (expected domains vs. domains actually present) |
| S13 | Optional cleanup of external entries (outside this script's own block) |

---

## Prerequisites

- Windows 10 or 11.
- PowerShell 5.1 (built into Windows) or PowerShell 7+.
- Administrator rights. The script self-elevates if launched from a non-admin session (UAC prompt) — except for `-SelfTest`, which runs read-only and does **not** require elevation.
- Write access to `C:\Windows\System32\drivers\etc\hosts` (standard on any admin session).
- If the script is digitally signed (recommended in environments using `-ExecutionPolicy AllSigned`/`RemoteSigned`): the signing certificate must be trusted on the target machine, otherwise PowerShell will refuse to run it.

---

## First run (step by step)

1. Copy `Block-Telemetry.ps1` to the target machine.

2. Open a PowerShell terminal (no need to run it as admin manually — the script self-elevates, except for step 3 below).

3. Run the logic self-test first — this is read-only, requires **no** admin rights, and does not touch `hosts`:

   ```powershell
   .\Block-Telemetry.ps1 -SelfTest
   ```

   Runs 8 checks: whitelist has no internal duplicates, no domain is both blocked and whitelisted, whitelist matching is exact (not by subdomain), `Get-DomainsToBlock` returns a non-empty list, the domain list builds without duplicates, the two markers are distinct, and both `Get-IntegrityStatus` and `Test-IsAlreadyBlocked` run without throwing. The script then exits without touching any files.

4. Launch the script normally (it will prompt for elevation):

   ```powershell
   .\Block-Telemetry.ps1
   ```

5. From the menu, preview what would happen **without changing anything**:

   ```
   [4] Simulate without modifying (DryRun)
   ```

   This prints every domain that would be added and every one skipped as a duplicate, exactly as option [2] would do for real, but writes nothing.

6. Optionally review the full domain list and the whitelist preview:

   ```
   [1] View the domains that will be blocked
   ```

7. Apply the block for real:

   ```
   [2] Apply blocking
   ```

   This creates a backup, writes the block to `hosts`, flushes the DNS cache, and writes a JSON snapshot of the action.

8. Confirm it's working: check option **[A]** (integrity) any time afterward, or from a different terminal:

   ```powershell
   Resolve-DnsName vortex-win.data.microsoft.com
   ```

   should fail to resolve (or resolve to `0.0.0.0`) once the block is active and the DNS cache has been flushed.

9. To undo everything, use option **[5]** — this removes only this script's block, backing up the current state first, and leaves the rest of your `hosts` file untouched.

---

## Menu reference

| Option | Action |
|---|---|
| `[1]` | Print the full list of domains that would be blocked, grouped by category, plus a preview of the whitelist |
| `[2]` | Apply the block for real (backup → write → flush DNS → JSON snapshot). If a block is already active, offers to update instead |
| `[3]` | Update the list (restore, then re-apply) — use after pulling a newer version of the script with additional domains |
| `[4]` | Dry-run: simulate option [2] without writing anything |
| `[5]` | **Restore** — remove this script's block only, original `hosts` content preserved |
| `[6]` | List available backups (timestamp, filename, size) with manual-restore instructions |
| `[7]` | Flush the DNS cache manually (`ipconfig /flushdns`) |
| `[8]` | Generate an HTML report |
| `[9]` | Detect conflicts with other `hosts`-editing tools, and optionally clean up entries outside this script's own block |
| `[A]` | Check integrity of the active block (expected domains vs. domains actually present — flags anything missing or extra) |
| `[E]` | Export the current active domain list to a `.txt` file on the Desktop |
| `[Q]` | Quit |

The menu header always shows the current status at a glance: whether a block is active, how many domains, when it was applied, and a compact integrity indicator (reusing the same check as option `[A]`) so drift is visible without digging into the menu.

---

## Command-line parameters

| Parameter | Description |
|---|---|
| `-SelfTest` | Runs the 8 read-only logic checks described in [First run](#first-run-step-by-step) and exits. No admin rights required, no files touched. |

Every other action (apply, update, dry-run, restore, reports, exports) is menu-driven — there are intentionally no equivalent CLI switches, since these are standing changes to a system file rather than one-off maintenance tasks.

---

## Files written by the script

| File / folder | Content |
|---|---|
| `%SystemRoot%\System32\drivers\etc\hosts` | The only file actually modified — telemetry-blocking entries appended inside the marked block |
| `%USERPROFILE%\Desktop\Hosts_Backups\hosts_backup_<timestamp>` | Full copy of `hosts` taken before every real write (rotated automatically, last 10 kept) |
| `%USERPROFILE%\Desktop\Block-Telemetry_Log.txt` | Plain-text action log (append-only) |
| `%USERPROFILE%\Desktop\Maintenance_Reports\Block-Telemetry\Block-Telemetry_<timestamp>.json` | JSON snapshot written after every real action (Apply / Update / Restore) — action type, domain counts, per-category breakdown |
| `%USERPROFILE%\Desktop\Block-Telemetry_Export_<timestamp>.txt` | Only created via menu option `[E]` — plain-text export of the active domain list |
| HTML report (menu option `[8]`) | Visual report, generated on demand |

Nothing is written outside these locations. `-DryRun` (menu option `[4]`) and `-SelfTest` write **no** files at all — no backup, no log, no JSON snapshot.

---

## Multi-machine deployment

The script is self-contained (no external dependencies). For a multi-machine rollout:

1. **Distribute** the `.ps1` file to each target machine.

2. **Trust the signing certificate** if a strict execution policy is enforced (`-ExecutionPolicy AllSigned`/`RemoteSigned`), otherwise PowerShell refuses to run it.

3. **Run `-SelfTest` first** on each machine — it needs no admin rights and touches nothing, so it's safe to run before deciding whether to proceed.

4. Because this script is **interactive by design** (menu-driven, no CLI flag to apply the block), it is **not** a drop-in candidate for a silent scheduled task the way a cleanup script would be. For unattended multi-machine deployment, consider either:
   - running it once interactively per machine during provisioning/imaging, or
   - extracting the domain list (`$TelemetryDomains` / `$AbsoluteWhitelist`) into a separate non-interactive script tailored to your deployment pipeline if a fully silent rollout is required.

5. Backups, logs, and JSON snapshots are written to the profile of the user running the script — local to each machine, not centralized automatically.

---

## Troubleshooting

<details>
<summary><strong>A site or app stopped working after applying the block</strong></summary>

First check option `[9]` (conflict detection) to rule out another tool having modified `hosts`. If the issue is really caused by this script, the safest fix is option `[5]` (Restore) to fully undo the block, then report which domain seems to be causing the problem — legitimate functional domains should already be in the whitelist, so this would point to a domain that needs to be moved there.
</details>

<details>
<summary><strong>Option [A] reports missing or extra domains</strong></summary>

"Missing" means a domain from the current script's list isn't present in the active block — usually because the script was updated with new domains since the block was last applied. Use option `[3]` (Update) to resync. "Extra" means something is in the block that the current script's list doesn't expect — could be a manual edit or a newer/older version mismatch; option `[3]` also resolves this by rebuilding the block from scratch.
</details>

<details>
<summary><strong>The block doesn't seem to take effect right away</strong></summary>

The script flushes the DNS cache automatically after every real change (or via option `[7]` manually), but some applications cache DNS resolutions internally on top of the OS cache — a full restart of the application (or occasionally the machine) may be needed for it to pick up the change.
</details>

<details>
<summary><strong>-SelfTest reports a FAIL</strong></summary>

All 8 checks are internal consistency checks on the domain/whitelist lists themselves (duplicates, contradictions, exact-match logic) — a FAIL here means the domain lists were edited in a way that introduced an inconsistency, not a system-level problem. Read the check's `Detail` output for the specific domain or count involved.
</details>

<details>
<summary><strong>Restoring didn't fully clean up my hosts file</strong></summary>

Restore only removes what's between this script's own markers. If entries were added outside that block (manually, or by another tool), they are intentionally left alone — use option `[9]` to detect and optionally clean up those external entries separately.
</details>

<details>
<summary><strong>Script fails to parse on PowerShell 5.1 ("Unexpected token" near accented text)</strong></summary>

Fixed in v5.2. Without a UTF-8 BOM, PowerShell 5.1 falls back to the system ANSI codepage when reading a `.ps1` file, which corrupts accented characters (é, à, the em dash —, etc.) and can break string literals mid-parse. PowerShell 7 doesn't have this issue since it defaults to UTF-8 regardless of BOM — which is why the script could appear to "work fine" on `pwsh` while failing on `powershell.exe`. If you're on an older copy of the script, re-download v5.2 or later, or re-save the file as **UTF-8 with BOM** yourself.
</details>

---

<sub>Block-Telemetry — hosts-file based, no registry changes, no services stopped, nothing installed.</sub>
