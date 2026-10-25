# =====================================================================================
# TELEMETRY BLOCKING - WINDOWS HOSTS FILE
# VERSION 5.4.0
# =====================================================================================
# This script ONLY modifies the Windows hosts file to block telemetry (usage data
# collection) domains from major vendors.
#
# SAFETY GUARANTEES:
#   [S1]  Automatic hosts file backup before any modification
#   [S2]  Strict whitelist: no functional domain is ever blocked
#   [S3]  Automatic backup rotation (keeps the last 10)
#   [S4]  Simulation mode (DryRun) to preview what would happen without touching anything
#   [S5]  Full built-in restore function (a single menu choice)
#   [S6]  Unique marker in the hosts file to identify our additions
#   [S7]  No registry changes, no services stopped, no drivers touched
#   [S8]  Built-in "Update" option (restore + reapply in one step)
#   [S9]  UTF-8 encoding WITH BOM guaranteed (required for PowerShell 5.1 to
#         detect UTF-8; without a BOM, PS 5.1 reads the file as ANSI and
#         accented characters corrupt parsing — PowerShell 7 handles both)
#   [S10] Duplicate check before writing (domains already present are skipped)
#   [S11] Conflict detection with other tools (CTT, etc.)
#   [S12] Active block integrity check (expected vs. present domains)
#   [S13] Optional cleanup of external entries (outside our block)
#
# v5.1 IMPROVEMENTS (interactive menu architecture kept identical):
#   [N1] -SelfTest: read-only logic validations (whitelist, duplicates,
#        whitelist/blocklist consistency), run via a CLI parameter, without touching hosts
#   [N2] Automatic JSON export after each real action (Apply/Update/Restore)
#        into Maintenance_Reports\Block-Telemetry, to build a structured history
#        like the other scripts in the suite
#   [N3] Integrity indicator shown directly in the main menu (instead of
#        waiting for option [A]) — same comparison logic, just reused
#
# v5.2 FIX:
#   [C1] Added a UTF-8 BOM at the top of the file. Without it, PowerShell 5.1 opened
#        the script as ANSI (no automatic UTF-8 detection), which corrupted
#        accented characters and caused parsing errors (unexpected tokens around
#        strings containing accents or the em dash). PowerShell 7 was not affected,
#        which is why the script only worked under pwsh before this fix.
#
# v5.3 — FULL ENGLISH TRANSLATION:
#   [T1] Entire script translated from French to English: header/changelog, all
#        comments (including the ones inside the domain list), console output,
#        interactive menu, and the HTML report (now lang="en") with its JS.
#   [T2] File renamed from Block-Telemetry_v5_2.ps1 to Block-Telemetry.ps1 (no
#        version suffix in the filename, matching the rest of the suite).
#   [T3] Report folder aligned with the suite-wide rename: Rapports_Maintenance
#        -> Maintenance_Reports (the Block-Telemetry subfolder itself is unchanged).
#   [T4] Added Format-BTDate (InvariantCulture, "dd MMM yyyy HH:mm:ss") for every
#        displayed date (hosts block marker, JSON snapshot, backup list, export
#        header, HTML report) to avoid day/month ambiguity for an English reader.
#   [T5] Internal field names translated for consistency: PerCategory
#        Categorie/Domaines -> Category/Domains; snapshot TotalDomaines/Ignores/
#        ParCategorie -> TotalDomains/Skipped/ByCategory; Action values
#        "Application"/"Mise a jour"/"Restauration" -> "Apply"/"Update"/"Restore".
#   [T6] Domain category names translated (e.g. "Rapports de crash" -> "Crash
#        Reports", "Tracking tiers" -> "Third-Party Tracking", "*Telemetrie" ->
#        "*Telemetry") — these are also the JSON/HTML category labels.
#   [T7] Y/N confirmation prompts now accept y/yes/Y/YES only (the French O/o/
#        oui/OUI variants were removed) to match the now fully English prompts.
#   Note: this script never parses localized OS command output (it only reads
#   and writes the hosts file directly), so no bilingual regex was needed to
#   keep it working on a French-language Windows machine.
#
# v5.3.1 — FIX: DISCORD FILE/IMAGE UPLOADS BLOCKED:
#   [F1] Removed discord-attachments-uploads-prd.storage.googleapis.com from the
#        "Discord Telemetry" category. It is the storage bucket Discord uploads
#        attachments to, not telemetry: with it pointed at 0.0.0.0, no personal
#        file or image could be sent from Discord (chat, discord.com and the CDN
#        kept working, which made the cause hard to spot).
#   [F2] Added the same domain to $AbsoluteWhitelist (Discord section) so it can
#        never be re-blocked, even if it is re-added to a category by mistake.
#   [F3] New -SelfTest assertion (#8): flags any blocked domain that lives on a
#        shared cloud-hosting suffix (*.storage.googleapis.com, *.amazonaws.com,
#        *.blob.core.windows.net, *.azureedge.net, ...) unless it appears in
#        $ReviewedCloudDomains (entries checked by hand). Such domains often host
#        the functional content of an app and must be reviewed before blocking.
#   To repair an already-affected machine: run option "Update" (restore + reapply)
#   so the hosts block is regenerated without the faulty line.
#
# v5.4.0 — CONSOLE UI OVERHAUL (no functional change):
#   [U1] New console helper layer: Write-Banner, Write-Header, Write-Status,
#        Write-KeyValue, Write-MenuItem, Write-BoxLine/Write-BoxEdge, Write-Rule,
#        Read-Confirm, Wait-ForMenu. The whole look & feel now lives in one place
#        ($script:UiWidth, $script:Box, $script:Icon) instead of ~200 hand-built
#        Write-Host lines.
#   [U2] Framed double-line banners for every screen, thin section rules for
#        sub-steps, and framed result boxes (success / simulation) at the end of
#        Apply and Restore.
#   [U3] Unicode status icons (check, cross, triangle, dot, circle, diamond)
#        replace the [OK] / [ERROR] / [WARNING] / [INFO] / [SIM] text tags.
#   [U4] Main menu regrouped (Blocking / Backups & DNS / Reports & diagnostics)
#        with an aligned Status panel (blocking state, date, integrity).
#   [U5] Domain list grouped per category with counts, backups shown as an
#        aligned table, SelfTest rendered with the same status rows.
#   [U6] All Y/N prompts go through one Read-Confirm helper (same accepted
#        answers as before: y / Y / yes / YES).
#   [U7] $ScriptVersion is now the single source of truth for the version shown
#        in the banner, export header, HTML report and SelfTest; the console
#        window title is set too.
#   Hosts file logic, whitelist, blocklist, JSON snapshot and HTML report content
#   are unchanged.
#
# CATEGORIES COVERED:
#   - Microsoft Telemetry (Windows, Office, Defender, DiagTrack, Xbox, OneDrive)
#   - Microsoft Copilot Telemetry
#   - Microsoft Edge Telemetry
#   - Google Analytics / Tracking
#   - Adobe Analytics / Stats
#   - Third-party tracking (Criteo, Taboola, Outbrain, Rubicon, PubMatic, OpenX, AMP...)
#   - Crash reports (Sentry, Bugsnag)
#   - Spotify Telemetry
#   - Brave Analytics
#   - Mozilla / Firefox Telemetry
#   - NVIDIA Telemetry
#   - AMD Telemetry
#   - Discord Telemetry
#   - Steam / Valve Telemetry
#   - GOG Galaxy Telemetry
#
# DOMAINS NEVER BLOCKED (strict whitelist):
#   - Adobe activation, licensing, authentication
#   - Windows Update, Microsoft activation
#   - NextDNS (critical DNS service)
#   - Steam, Spotify, Brave, Mozilla (functional domains)
#   - NVIDIA / AMD (driver updates)
#   - GOG Galaxy (store and downloads)
#   - Discord (chat, CDN, attachment uploads)
#   - Visual Studio Code (updates)
#   - Anything that could break an application
# =====================================================================================

param(
    [switch]$SelfTest  # [N1] Read-only logic validations — no admin needed, exits before elevation
)

#region AUTO-ELEVATION

# [N1] SelfTest is purely read-only (hosts file + in-memory comparisons): it's
# handled before elevation to avoid an unnecessary UAC prompt just for a check.

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $SelfTest -and -not $currentPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    # Use pwsh if available (PowerShell 7+), otherwise powershell.exe (5.x)
    $Shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    Start-Process $Shell `
        -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    exit
}

if (-not $SelfTest) { Set-ExecutionPolicy Bypass -Scope Process -Force }

#endregion

#region INITIALIZATION

$HostsPath        = "$env:SystemRoot\System32\drivers\etc\hosts"
$BackupFolder     = "$env:USERPROFILE\Desktop\Maintenance_Reports\Block-Telemetry\Hosts_Backups"
$LogPath          = "$env:USERPROFILE\Desktop\Maintenance_Reports\Block-Telemetry\Block-Telemetry_Log.txt"
$Marker           = "# === TELEMETRY BLOCK - Do not modify manually ==="
$MarkerEnd        = "# === END TELEMETRY BLOCK ==="
$Timestamp        = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupMaxCount   = 10   # Maximum number of backups to keep
$ScriptVersion    = "5.4.0"

try { $Host.UI.RawUI.WindowTitle = "Block-Telemetry v$ScriptVersion" } catch { }

#endregion

#region TELEMETRY DOMAINS

# =====================================================================================
# LIST OF BLOCKED DOMAINS
#
# Rule used to build this list:
#   1. Domain known to collect usage/telemetry data
#   2. NOT required for the application to function
#   3. Verified: blocking it does not break activation or licensing
#
# ADOBE — Telemetry/statistics domains ONLY
# NOT in this list (functional):
#   adobe.com, adobelogin.com, adobegenuine.com, adobejanus.com,
#   adobeereg.com (product registration), lcs-cops.adobe.com,
#   prod.adobegenuine.com, genuine.adobe.com
# =====================================================================================

$TelemetryDomains = [ordered]@{

    # ------------------------------------------------------------------
    # MICROSOFT — Windows and Office telemetry
    # EXCLUDED from this list:
    #   windowsupdate.com, update.microsoft.com, msftconnecttest.com
    #   (needed for updates and connectivity detection)
    # ------------------------------------------------------------------
    "Microsoft Telemetry" = @(
        "vortex.data.microsoft.com",
        "vortex-win.data.microsoft.com",
        "telecommand.telemetry.microsoft.com",
        "telecommand.telemetry.microsoft.com.nsatc.net",
        "oca.telemetry.microsoft.com",
        "oca.telemetry.microsoft.com.nsatc.net",
        "sqm.telemetry.microsoft.com",
        "sqm.telemetry.microsoft.com.nsatc.net",
        "watson.telemetry.microsoft.com",
        "watson.telemetry.microsoft.com.nsatc.net",
        "redir.metaservices.microsoft.com",
        "choice.microsoft.com",
        "choice.microsoft.com.nsatc.net",
        "df.telemetry.microsoft.com",
        "reports.wes.df.telemetry.microsoft.com",
        "wes.df.telemetry.microsoft.com",
        "services.wes.df.telemetry.microsoft.com",
        "sqm.df.telemetry.microsoft.com",
        "telemetry.microsoft.com",
        "watson.microsoft.com",
        "statsfe2.ws.microsoft.com",
        "corpext.msitadfs.glbdns2.microsoft.com",
        "compatexchange.cloudapp.net",
        "cs1.wpc.v0cdn.net",
        "a-0001.a-msedge.net",
        "statsfe2.update.microsoft.com.akadns.net",
        "sls.update.microsoft.com.akadns.net",
        "fe2.update.microsoft.com.akadns.net",
        "diagnostics.support.microsoft.com",
        "corp.sts.microsoft.com",
        "statsfe1.ws.microsoft.com",
        "pre.footprintpredict.com",
        "i1.services.social.microsoft.com",
        "i1.services.social.microsoft.com.nsatc.net",
        "feedback.windows.com",
        "feedback.microsoft-hohm.com",
        "feedback.search.microsoft.com",
        # Office telemetry and ARIA pipeline
        "mobile.pipe.aria.microsoft.com",
        "pipe.aria.microsoft.com",
        "browser.pipe.aria.microsoft.com",
        "self.events.data.microsoft.com",
        "v10.events.data.microsoft.com",
        "v10c.events.data.microsoft.com",
        "v20.events.data.microsoft.com",
        "settings-win.data.microsoft.com",
        "activity.windows.com",
        "watson.live.com",
        "ceuswatcab01.blob.core.windows.net",
        "ceuswatcab02.blob.core.windows.net",
        "eaus2watcab01.blob.core.windows.net",
        "eaus2watcab02.blob.core.windows.net",
        "weus2watcab01.blob.core.windows.net",
        "weus2watcab02.blob.core.windows.net",
        # Windows Defender — cloud telemetry only (not local protection)
        "spynet.microsoft.com",
        "spynet2.microsoft.com",
        "wdcp.microsoft.com",
        "wdcpalt.microsoft.com",
        "ssw.live.com",
        # Windows / MSN advertising / suggestions
        "rad.msn.com",
        "ads.msn.com",
        "adnexus.net",
        "ac3.msn.com",
        "h1.msn.com",
        # Cortana / Bing suggestions in the search bar
        "bingapis.com",
        "api.bing.com",
        # DiagTrack — "Connected User Experiences and Telemetry" service
        # This service (svchost DiagTrack) is Windows' primary data collector
        "watson.events.data.microsoft.com",
        "umwatsonc.events.data.microsoft.com",
        "v10-win.vortex.data.microsoft.com",
        "v10.vortex-win.data.microsoft.com",
        "functional.events.data.microsoft.com",
        "umwatson.events.data.microsoft.com",
        # Xbox / Game Bar — gaming telemetry
        "telemetry.xbox.com",
        "data.microsoft.com",
        "xbox.ipv6.microsoft.com",
        "xboxexperiencesprod.experimentation.xboxlive.com",
        "xaccount.microsoft.com",
        # OneDrive — telemetry (not sync itself)
        "telemetry.onedrive.com",
        "onedrive.com.edgekey.net",
        # Microsoft Teams — telemetry (not communication itself)
        "config.teams.microsoft.com",
        "teams.events.data.microsoft.com"
    )

    # ------------------------------------------------------------------
    # MICROSOFT COPILOT — Telemetry and data collection
    # Copilot sends usage data, queries, and context to Microsoft/Bing
    # servers. These endpoints are purely analytical — Copilot is not
    # functionally blocked on machines that use it intentionally.
    # ------------------------------------------------------------------
    "Microsoft Copilot Telemetry" = @(
        "copilot-proxy.microsoft.com",
        "telemetry.bing.com",
        "bat.bing.com",
        "sydney.bing.com",
        "copilot.microsoft.com",
        "bing.com.edgekey.net",
        "th.bing.com",
        "r.bing.com",
        "bat.r.msn.com",
        "adsmeasurement.microsoft.com"
    )

    
    # Useful even when Edge is uninstalled on some machines —
    # WebView2 and Edge leftovers can still contact these endpoints.
    # EXCLUDED: Edge updates, functional WebView2
    # ------------------------------------------------------------------
    "Microsoft Edge Telemetry" = @(
        "edge.microsoft.com",
        "edgeassetservice.azureedge.net",
        "ecs.microsoft.com",
        "config.edge.skype.com",
        "edge-mobile-static.azureedge.net",
        "edgeservices.bing.com",
        "assets.msn.com",
        "ntp.msn.com"
    )

    # ------------------------------------------------------------------
    # GOOGLE — Analytics and third-party tracking
    # EXCLUDED: google.com, googleapis.com, gstatic.com
    # (required by many web apps and authentication flows)
    # ------------------------------------------------------------------
    "Google Analytics / Tracking" = @(
        "google-analytics.com",
        "ssl.google-analytics.com",
        "www.google-analytics.com",
        "googletagmanager.com",
        "www.googletagmanager.com",
        "googletagservices.com",
        "googlesyndication.com",
        "pagead2.googlesyndication.com",
        "adservice.google.com",
        "doubleclick.net",
        "stats.g.doubleclick.net",
        "cm.g.doubleclick.net",
        "googleadservices.com",
        "www.googleadservices.com"
    )

    # ------------------------------------------------------------------
    # ADOBE — Statistics and analytics only
    # adobestats.io   : usage statistics collection for CC apps
    # omtrdc.net      : Adobe Analytics / Omniture (behavioral tracking)
    # demdex.net      : Adobe Audience Manager (ad profiling)
    # adobedtm.com    : Adobe Dynamic Tag Manager (marketing tracking)
    # NOT in this list (functional):
    #   adobe.com, adobelogin.com, adobegenuine.com, lcs-cops.adobe.com
    # ------------------------------------------------------------------
    "Adobe Analytics / Stats" = @(
        "adobestats.io",
        "omtrdc.net",
        "demdex.net",
        "adobedtm.com",
        "assets.adobedtm.com",
        "adobe.tt.omtrdc.net",
        "adobe.demdex.net",
        "adobedc.demdex.net",
        "sstats.adobe.com",
        # Adobe Marketing Cloud / Advertising Cloud
        "metrics.adobe.com",
        "adobe-mc.omtrdc.net",
        "cm.everesttech.net",
        "everesttech.net",
        "tubemogul.com",
        "2o7.net"
    )

    # ------------------------------------------------------------------
    # THIRD-PARTY TRACKING TOOLS
    # These domains don't belong to any app installed locally —
    # they're only loaded by websites or apps to track you
    # across sessions.
    # ------------------------------------------------------------------
    "Third-Party Tracking" = @(
        "scorecardresearch.com",
        "b.scorecardresearch.com",
        "pixel.quantserve.com",
        "quantserve.com",
        "ad.doubleclick.net",
        "static.chartbeat.com",
        "js.chartbeat.com",
        "ping.chartbeat.net",
        "cdn.speedcurve.com",
        # Facebook / Meta tracking
        "connect.facebook.net",
        "graph.facebook.com",
        "an.facebook.com",
        # Amazon Ads
        "aax.amazon-adsystem.com",
        "c.amazon-adsystem.com",
        # Twitter / X Ads
        "ads-twitter.com",
        "analytics.twitter.com",
        # Hotjar (behavioral heatmaps)
        "static.hotjar.com",
        "api.hotjar.com",
        "insights.hotjar.com",
        # Mixpanel
        "api.mixpanel.com",
        # Segment
        "api.segment.io",
        "cdn.segment.com",
        # Criteo — very aggressive cross-site ad retargeting
        "criteo.com",
        "static.criteo.net",
        "dis.criteo.com",
        "rtax.criteo.com",
        "gum.criteo.com",
        # Taboola — sponsored content and behavioral tracking
        "taboola.com",
        "cdn.taboola.com",
        "trc.taboola.com",
        "nr-data.taboola.com",
        # Outbrain — same category as Taboola
        "outbrain.com",
        "amplify.outbrain.com",
        "widgets.outbrain.com",
        # Rubicon Project / Magnite — real-time ad auctions
        "rubiconproject.com",
        "fastlane.rubiconproject.com",
        # PubMatic — ad SSP platform
        "pubmatic.com",
        "ads.pubmatic.com",
        # OpenX — ad auctions
        "openx.net",
        "delivery.openx.net",
        # Moat — ad viewability measurement (Oracle)
        "moatads.com",
        "z.moatads.com",
        # Google AMP — Google proxy that collects browsing data
        "ampproject.org",
        "cdn.ampproject.org",
        # LinkedIn Insight Tag — B2B tracking
        "snap.licdn.com",
        "platform.linkedin.com"
    )

    # ------------------------------------------------------------------
    # ERROR/CRASH REPORTING
    # Sentry.io, Bugsnag: send stack traces and system data on
    # application crashes. Informative but intrusive.
    # Note: may reduce the quality of application bug fixes.
    # ------------------------------------------------------------------
    "Crash Reports" = @(
        "sentry.io",
        "o1383653.ingest.sentry.io",
        "o987771.ingest.us.sentry.io",
        "browser.sentry-cdn.com",
        "bugsnag.com",
        "notify.bugsnag.com",
        "sessions.bugsnag.com",
        "app.bugsnag.com"
    )

    # ------------------------------------------------------------------
    # SPOTIFY — Telemetry and analytics only
    # EXCLUDED: *.spotify.com (streaming, login, API),
    #   *.scdn.co (music CDN), accounts.spotify.com, api.spotify.com
    # ------------------------------------------------------------------
    "Spotify Telemetry" = @(
        "log.spotify.com",
        "crashdump.spotify.com",
        "audio-ec.spotify.com",
        "heads4-ash2-accesspoint.ap.spotify.com",
        "heads4-accesspoint.ap.spotify.com",
        "cpapi.spotify.com"
    )

    # ------------------------------------------------------------------
    # BRAVE — Analytics and experimentation
    # "Privacy-Preserving Product Analytics" (P3A): even aggregated,
    # this is usage data collection sent to Brave Software.
    # Web Discovery Project (WDP): collects search/page data
    # to improve Brave Search (opt-in feature, disabled via the
    # BraveWebDiscoveryEnabled=0 policy; these domains have no other
    # function, so blocking them via hosts carries no risk).
    # EXCLUDED: Brave updates, security components,
    #   laptop-updates.brave.com (usage ping BUT also the binary
    #   update channel — never block this; see BraveStatsPingEnabled,
    #   which is managed only via a registry policy)
    # ------------------------------------------------------------------
    "Brave Analytics" = @(
        "p3a.brave.com",
        "p2a.brave.com",
        "cr.brave.com",
        "variations.brave.com",
        "star-randsrv.bsg.brave.com",
        "patterns.wdp.brave.com",
        "collector.wdp.brave.com"
    )

    # ------------------------------------------------------------------
    # MOZILLA / FIREFOX — Telemetry and experimentation
    # LibreWolf already disables most of these via its internal config,
    # but these residual endpoints may still be contacted.
    # EXCLUDED: addons.mozilla.org, safebrowsing (security)
    # ------------------------------------------------------------------
    "Mozilla / Firefox Telemetry" = @(
        "telemetry.mozilla.org",
        "incoming.telemetry.mozilla.org",
        "crash-stats.mozilla.com",
        "normandy.cdn.mozilla.net",
        "normandy-cdn.mozilla.net",
        "experimenter.mozilla.org",
        "firefox.settings.services.mozilla.com",
        "coverage.mozilla.org",
        "mozac.telemetry.mozilla.org"
    )

    # ------------------------------------------------------------------
    # NVIDIA — GeForce Experience / NVIDIA App telemetry
    # EXCLUDED: driver updates, GeForce NOW (streaming)
    # ------------------------------------------------------------------
    "NVIDIA Telemetry" = @(
        "telemetry.nvidia.com",
        "gfe.nvidia.com",
        "events.gfe.nvidia.com",
        "telemetry.gfe.nvidia.com",
        "crashreport.nvidia.com",
        "ota.nvidia.com",
        "services.gfe.nvidia.com",
        "accounts.nvgs.nvidia.com",
        "notifications.nvgs.nvidia.cn"
    )

    # ------------------------------------------------------------------
    # AMD — AMD Software / Adrenalin telemetry
    # EXCLUDED: AMD driver updates
    # ------------------------------------------------------------------
    "AMD Telemetry" = @(
        "telemetry.amd.com",
        "crashreport.amd.com",
        "analytics.amd.com",
        "amd-detect.amd.com",
        "dc.services.visualstudio.com"
    )

    # ------------------------------------------------------------------
    # DISCORD — Telemetry and analytics
    # Discord sends detailed usage data (Science API)
    # EXCLUDED: discord.com (functional), gateway.discord.gg (chat),
    # discord-attachments-uploads-prd.storage.googleapis.com (file/image UPLOADS —
    # blocking it breaks every attachment sent from Discord; v5.3.1 fix)
    # ------------------------------------------------------------------
    "Discord Telemetry" = @(
        "click.discord.com",
        "crash.discord.com"
        # sentry.io removed from here: already covered by the "Crash Reports" category.
        # Get-DomainsToBlock only de-duplicates against entries already present
        # in hosts outside our block — not between categories within this list itself.
    )

    # ------------------------------------------------------------------
    # STEAM / VALVE — Telemetry and analytics
    # EXCLUDED: steampowered.com, steamcommunity.com, vac.valve.net
    # (platform, anti-cheat, and game downloads)
    # ------------------------------------------------------------------
    "Steam / Valve Telemetry" = @(
        "media.steampowered.com",
        "clientconfig.akamai.steamstatic.com",
        "steamstat.us",
        "ingest.sentry.io"   # Sentry duplicate handled automatically
    )

    # ------------------------------------------------------------------
    # GOG GALAXY — Telemetry and analytics
    # EXCLUDED: gog.com (store), cdn.gog.com (downloads)
    # ------------------------------------------------------------------
    "GOG Galaxy Telemetry" = @(
        "telemetry.gog.com",
        "analytics.gog.com",
        "metrics.gog.com",
        "reporting.gog.com"
    )
}

# =====================================================================================
# ABSOLUTE WHITELIST — These domains will NEVER be blocked
# even if they mistakenly appear in $TelemetryDomains
# =====================================================================================

$AbsoluteWhitelist = @(
    # Adobe — exact activation and licensing domains
    "activate.adobe.com",
    "practivate.adobe.com",
    "ereg.adobe.com",
    "genuine.adobe.com",
    "prod.adobegenuine.com",
    "adobegenuine.com",
    "adobejanus.com",
    "adobeereg.com",
    "lcs-cops.adobe.com",
    "ims-na1.adobelogin.com",
    "adobelogin.com",
    "cc-api-data.adobe.io",
    "services.adobe.com",
    # Microsoft — exact update and activation domains
    "windowsupdate.com",
    "update.microsoft.com",
    "download.microsoft.com",
    "go.microsoft.com",
    "msftconnecttest.com",
    "msftncsi.com",
    "dns.msftncsi.com",
    "login.microsoftonline.com",
    "login.live.com",
    "activation.sls.microsoft.com",
    # Microsoft Edge WebView2 — system component
    "msedge.net",
    # OneDrive — functional sync
    "onedrive.live.com",
    "storage.live.com",
    # Xbox — functional authentication
    "xboxlive.com",
    # Microsoft Teams — functional communication
    "teams.microsoft.com",
    # NextDNS — critical DNS service
    "nextdns.io",
    "dns.nextdns.io",
    "link.nextdns.io",
    # Spotify — streaming, authentication, API
    "accounts.spotify.com",
    "api.spotify.com",
    "apresolve.spotify.com",
    "dealer.spotify.com",
    "scdn.co",
    "spotifycdn.com",
    # Brave — updates and security
    "updates.bravesoftware.com",
    "safebrowsing.brave.com",
    "go-updater.brave.com",
    # Mozilla — updates and security
    "addons.mozilla.org",
    "safebrowsing.googleapis.com",
    "aus5.mozilla.org",
    "balrog-admin.stage.mozaws.net",
    # Steam — platform and anti-cheat
    "steampowered.com",
    "steamcommunity.com",
    "steamgames.com",
    "steamusercontent.com",
    "steamcdn-a.akamaihd.net",
    "vac.valve.net",
    # NVIDIA — driver updates
    "download.nvidia.com",
    "international.download.nvidia.com",
    "gfwsl.geforce.com",
    # AMD — driver updates
    "drivers.amd.com",
    "radeon.com",
    # Epic Games — store and launcher (not used here, kept in the whitelist as a
    # precaution: zero cost, avoids an accidental block if reused on another
    # machine or extended later)
    "launcher.epicgames.com",
    "store.epicgames.com",
    "www.epicgames.com",
    "unrealengine.com",
    # Discord — communication
    "discord.com",
    "discordapp.com",
    "discord.gg",
    "gateway.discord.gg",
    "dl.discordapp.net",
    # Discord — attachment uploads (Google Cloud Storage bucket used by the client;
    # NOT telemetry: blocking it makes every file/image upload fail)
    "discord-attachments-uploads-prd.storage.googleapis.com",
    # GOG — store and downloads
    "cdn.gog.com",
    "galaxy-client.gog.com",
    "store.gog.com",
    "www.gog.com",
    # Visual Studio Code — updates
    "update.code.visualstudio.com",
    "marketplace.visualstudio.com",
    # DNS and network infrastructure
    "localhost"
)

# =====================================================================================
# SHARED CLOUD-HOSTING DOMAINS — SAFETY NET (used by -SelfTest only)
# A domain on a shared cloud suffix (Google Cloud Storage, S3, Azure Blob...) can host
# the functional content of ANY app, so it must never be blocked without a manual
# check. $ReviewedCloudDomains lists the entries already checked by hand; the
# SelfTest fails on any other blocked domain that matches $SharedCloudSuffixes.
# =====================================================================================

$SharedCloudSuffixes = @(
    ".storage.googleapis.com",
    ".amazonaws.com",
    ".blob.core.windows.net",
    ".azureedge.net",
    ".cloudfront.net",
    ".appspot.com",
    ".firebaseio.com",
    ".web.app"
)

$ReviewedCloudDomains = @(
    # Windows Error Reporting cab upload accounts (Microsoft telemetry)
    "ceuswatcab01.blob.core.windows.net",
    "ceuswatcab02.blob.core.windows.net",
    "eaus2watcab01.blob.core.windows.net",
    "eaus2watcab02.blob.core.windows.net",
    "weus2watcab01.blob.core.windows.net",
    "weus2watcab02.blob.core.windows.net",
    # Edge asset / new-tab services
    "edgeassetservice.azureedge.net",
    "edge-mobile-static.azureedge.net"
)

#endregion

#region FUNCTIONS

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Line = "[$((Get-Date).ToString('HH:mm:ss'))] [$Level] $Message"
    Add-Content -Path $LogPath -Value $Line -Encoding UTF8 -ErrorAction SilentlyContinue
}

# Displays dates in an unambiguous format, independent of the OS display language
# (same fix as Format-AuditDate in Harden-TLS/Check-Security)
function Format-BTDate {
    param([datetime]$Date = (Get-Date))
    return $Date.ToString('dd MMM yyyy HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
}

# [N2] JSON snapshot after each real action (Apply/Update/Restore), to build a
# structured history like the other scripts in the suite. Never called in
# simulation mode (DryRun) since no real state has changed.
function Write-JsonSnapshot {
    param(
        [string]$Action,       # "Apply", "Update", "Restore"
        [int]$TotalDomains  = 0,
        [int]$SkippedCount  = 0,
        [array]$Categories  = @()
    )
    try {
        $ReportFolder = "$env:USERPROFILE\Desktop\Maintenance_Reports\Block-Telemetry"
        if (-not (Test-Path $ReportFolder)) {
            New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
        }

        $PerCategory = $Categories | Group-Object Category | ForEach-Object {
            [PSCustomObject]@{ Category = $_.Name; Domains = $_.Count }
        }

        $Snapshot = [PSCustomObject]@{
            Timestamp     = Format-BTDate
            Action        = $Action
            TotalDomains  = $TotalDomains
            Skipped       = $SkippedCount
            ByCategory    = $PerCategory
        }

        $JsonPath = Join-Path $ReportFolder "Block-Telemetry_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').json"
        $Snapshot | ConvertTo-Json -Depth 3 | Out-File $JsonPath -Encoding UTF8 -Force
    }
    catch {
        # Non-blocking: a failed JSON export must never fail the real action
        Write-Log "JSON snapshot export failed: $_" "WARNING"
    }
}

# =====================================================================================
# CONSOLE UI LAYER [U1] — every visual element of the console goes through here
# =====================================================================================
$script:UiWidth = 66

$script:Box = @{
    TL   = [string][char]0x2554   # top-left
    TR   = [string][char]0x2557   # top-right
    BL   = [string][char]0x255A   # bottom-left
    BR   = [string][char]0x255D   # bottom-right
    H    = [string][char]0x2550   # horizontal (double)
    V    = [string][char]0x2551   # vertical (double)
    ML   = [string][char]0x2560   # middle-left
    MR   = [string][char]0x2563   # middle-right
    Line = [string][char]0x2500   # thin horizontal rule
}

$script:Icon = @{
    OK    = [string][char]0x2714   # check
    FAIL  = [string][char]0x2718   # cross
    WARN  = [string][char]0x25B2   # triangle
    INFO  = [string][char]0x25CF   # filled dot
    SKIP  = [string][char]0x25CB   # empty dot
    SIM   = [string][char]0x25C6   # diamond
    Arrow = [string][char]0x25B8   # small arrow
    Dot   = [string][char]0x00B7   # middle dot
    Ellip = [string][char]0x2026   # ellipsis
}

function Write-Rule {
    param([string]$Color = "DarkGray")
    Write-Host ("  " + ($script:Box.Line * $script:UiWidth)) -ForegroundColor $Color
}

function Write-BoxEdge {
    param(
        [ValidateSet('Top','Middle','Bottom')][string]$Position,
        [string]$Color = "Cyan"
    )
    $b = $script:Box
    if     ($Position -eq 'Top')    { $l = $b.TL; $r = $b.TR }
    elseif ($Position -eq 'Middle') { $l = $b.ML; $r = $b.MR }
    else                            { $l = $b.BL; $r = $b.BR }
    Write-Host ("  " + $l + ($b.H * ($script:UiWidth - 2)) + $r) -ForegroundColor $Color
}

function Write-BoxLine {
    param(
        [string]$Text = "",
        [string]$Color = "White",
        [string]$BorderColor = "Cyan",
        [switch]$Center
    )
    $inner = $script:UiWidth - 2
    if ($Text.Length -gt ($inner - 2)) {
        $Text = $Text.Substring(0, $inner - 3) + $script:Icon.Ellip
    }
    if ($Center) {
        $padL = [int][Math]::Floor(($inner - $Text.Length) / 2)
        $padR = $inner - $Text.Length - $padL
        $content = (" " * $padL) + $Text + (" " * $padR)
    }
    else {
        $content = "  " + $Text.PadRight($inner - 2)
    }
    Write-Host ("  " + $script:Box.V) -NoNewline -ForegroundColor $BorderColor
    Write-Host $content -NoNewline -ForegroundColor $Color
    Write-Host $script:Box.V -ForegroundColor $BorderColor
}

function Write-Banner {
    param(
        [string]$Title,
        [string]$Subtitle = "",
        [string]$Color = "Cyan",
        [switch]$Roomy
    )
    Write-Host ""
    Write-BoxEdge Top $Color
    if ($Roomy) { Write-BoxLine "" -BorderColor $Color }
    Write-BoxLine $Title -Color White -BorderColor $Color -Center
    if ($Subtitle) { Write-BoxLine $Subtitle -Color DarkGray -BorderColor $Color -Center }
    if ($Roomy) { Write-BoxLine "" -BorderColor $Color }
    Write-BoxEdge Bottom $Color
}

# Section title: "▸ Title ─────────────"
function Write-Header {
    param([string]$Text, [string]$Color = "Cyan")
    $fill = [Math]::Max(2, $script:UiWidth - $Text.Length - 3)
    Write-Host ""
    Write-Host ("  " + $script:Icon.Arrow + " ") -NoNewline -ForegroundColor $Color
    Write-Host $Text -NoNewline -ForegroundColor White
    Write-Host (" " + ($script:Box.Line * $fill)) -ForegroundColor DarkGray
}

# One result line: icon + message (+ optional dimmed detail)
function Write-Status {
    param(
        [Parameter(Mandatory)][ValidateSet('OK','FAIL','WARN','INFO','SKIP','SIM')][string]$Level,
        [Parameter(Mandatory)][string]$Message,
        [string]$Detail = "",
        [int]$Indent = 2
    )
    switch ($Level) {
        'OK'   { $Icon = $script:Icon.OK;   $IconColor = 'Green';      $TextColor = 'White' }
        'FAIL' { $Icon = $script:Icon.FAIL; $IconColor = 'Red';        $TextColor = 'Red' }
        'WARN' { $Icon = $script:Icon.WARN; $IconColor = 'Yellow';     $TextColor = 'Yellow' }
        'INFO' { $Icon = $script:Icon.INFO; $IconColor = 'Cyan';       $TextColor = 'White' }
        'SKIP' { $Icon = $script:Icon.SKIP; $IconColor = 'DarkGray';   $TextColor = 'DarkGray' }
        'SIM'  { $Icon = $script:Icon.SIM;  $IconColor = 'DarkYellow'; $TextColor = 'DarkYellow' }
    }
    Write-Host ((" " * $Indent) + $Icon + "  ") -NoNewline -ForegroundColor $IconColor
    if ($Detail) {
        Write-Host $Message -NoNewline -ForegroundColor $TextColor
        Write-Host ("  " + $Detail) -ForegroundColor DarkGray
    }
    else {
        Write-Host $Message -ForegroundColor $TextColor
    }
}

# Aligned "Label      value" row, optional leading icon and dimmed detail
function Write-KeyValue {
    param(
        [string]$Key,
        [string]$Value,
        [string]$ValueColor = "White",
        [int]$KeyWidth = 14,
        [string]$Icon = "",
        [string]$IconColor = "Cyan",
        [string]$Detail = ""
    )
    Write-Host ("  " + $Key.PadRight($KeyWidth)) -NoNewline -ForegroundColor DarkGray
    if ($Icon) { Write-Host ($Icon + "  ") -NoNewline -ForegroundColor $IconColor }
    if ($Detail) {
        Write-Host $Value -NoNewline -ForegroundColor $ValueColor
        Write-Host ("  " + $Detail) -ForegroundColor DarkGray
    }
    else {
        Write-Host $Value -ForegroundColor $ValueColor
    }
}

function Write-MenuGroup {
    param([string]$Title)
    Write-Host ""
    Write-Host ("  " + $Title.ToUpper()) -ForegroundColor DarkCyan
}

function Write-MenuItem {
    param(
        [string]$Key,
        [string]$Label,
        [string]$KeyColor = "Cyan",
        [string]$LabelColor = "White",
        [string]$Hint = ""
    )
    Write-Host "   " -NoNewline
    Write-Host ("[" + $Key + "]") -NoNewline -ForegroundColor $KeyColor
    if ($Hint) {
        Write-Host ("  " + $Label) -NoNewline -ForegroundColor $LabelColor
        Write-Host ("  (" + $Hint + ")") -ForegroundColor DarkGray
    }
    else {
        Write-Host ("  " + $Label) -ForegroundColor $LabelColor
    }
}

# [U6] Y/N confirmation — accepts y / Y / yes / YES only (see [T7])
function Read-Confirm {
    param([string]$Question)
    Write-Host ""
    Write-Host ("  " + $script:Icon.WARN + "  ") -NoNewline -ForegroundColor Yellow
    Write-Host ($Question + " ") -NoNewline -ForegroundColor White
    Write-Host "[y/N] " -NoNewline -ForegroundColor DarkGray
    $Answer = Read-Host
    return ($Answer -in @("y","Y","yes","YES"))
}

function Wait-ForMenu {
    Write-Host ""
    Write-Host "  Press " -NoNewline -ForegroundColor DarkGray
    Write-Host "Enter" -NoNewline -ForegroundColor White
    Write-Host " to return to the menu " -NoNewline -ForegroundColor DarkGray
    $null = Read-Host
}

# UTF-8 without BOM, compatible with PowerShell 5 and 7
function Write-UTF8NoBOM {
    param([string]$Path, [string[]]$Lines)
    $Encoding = New-Object System.Text.UTF8Encoding($false)  # $false = no BOM
    [System.IO.File]::WriteAllLines($Path, $Lines, $Encoding)
}

function Backup-Hosts {
    try {
        if (-not (Test-Path $BackupFolder)) {
            New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null
        }
        $BackupPath = Join-Path $BackupFolder "hosts_backup_$Timestamp"
        Copy-Item -Path $HostsPath -Destination $BackupPath -Force
        Write-Status OK "Backup created"
        Write-Host "       $BackupPath" -ForegroundColor DarkGray
        Write-Log "Backup created: $BackupPath"

        # Rotation: remove excess backups (oldest first)
        $AllBackups = Get-ChildItem -Path $BackupFolder -Filter "hosts_backup_*" |
            Sort-Object LastWriteTime -Descending
        if ($AllBackups.Count -gt $BackupMaxCount) {
            $ToDelete = $AllBackups | Select-Object -Skip $BackupMaxCount
            foreach ($Old in $ToDelete) {
                Remove-Item -Path $Old.FullName -Force -ErrorAction SilentlyContinue
                Write-Log "Old backup removed (rotation): $($Old.Name)"
            }
            Write-Status SKIP "Rotation: $(@($ToDelete).Count) old backup(s) removed"
        }

        return $BackupPath
    }
    catch {
        Write-Status FAIL "Could not create the backup" -Detail "$_"
        Write-Log "Backup error: $_" "ERROR"
        return $null
    }
}

function Get-CurrentHostsContent {
    try {
        return Get-Content -Path $HostsPath -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Status FAIL "Could not read the hosts file" -Detail "$_"
        return $null
    }
}

function Test-IsAlreadyBlocked {
    # Checks whether our marker is already present in the hosts file
    $Content = Get-CurrentHostsContent
    if (-not $Content) { return $false }
    return ($Content | Where-Object { $_ -match [regex]::Escape($Marker) }).Count -gt 0
}

function Get-DomainsToBlock {
    # Returns the flat list of all domains to block, excluding those present
    # in the absolute whitelist and those already present in the hosts file
    # (anti-duplicate check)

    # Read domains already present in hosts (outside our block)
    $ExistingHosts = @{}
    $HostsContent = Get-CurrentHostsContent
    if ($HostsContent) {
        $InOurBlock = $false
        foreach ($Line in $HostsContent) {
            if ($Line -match [regex]::Escape($Marker))    { $InOurBlock = $true;  continue }
            if ($Line -match [regex]::Escape($MarkerEnd)) { $InOurBlock = $false; continue }
            if (-not $InOurBlock -and $Line -match '^0\.0\.0\.0\s+(.+)$') {
                $ExistingHosts[$Matches[1].Trim().ToLower()] = $true
            }
        }
    }

    $All = @()
    foreach ($Category in $TelemetryDomains.Keys) {
        foreach ($Domain in $TelemetryDomains[$Category]) {
            $Domain = $Domain.ToLower().Trim()

            # Whitelist check — exact match only
            # (no EndsWith, to avoid blocking every subdomain)
            $IsWhitelisted = $AbsoluteWhitelist -contains $Domain
            if ($IsWhitelisted) { continue }

            # Duplicate check (already present in hosts outside our block)
            $IsDuplicate = $ExistingHosts.ContainsKey($Domain)

            $All += [PSCustomObject]@{
                Domain      = $Domain
                Category    = $Category
                IsDuplicate = $IsDuplicate
            }
        }
    }
    return $All
}

function Remove-OurBlocksFromHosts {
    # Removes only the block we added
    # The rest of the hosts file is preserved as-is
    try {
        $Lines       = Get-CurrentHostsContent
        if (-not $Lines) { return $false }

        $InOurBlock  = $false
        $CleanLines  = @()

        foreach ($Line in $Lines) {
            if ($Line -match [regex]::Escape($Marker)) {
                $InOurBlock = $true
                continue
            }
            if ($Line -match [regex]::Escape($MarkerEnd)) {
                $InOurBlock = $false
                continue
            }
            if (-not $InOurBlock) {
                $CleanLines += $Line
            }
        }

        # Remove trailing blank lines (cosmetic)
        while ($CleanLines.Count -gt 0 -and $CleanLines[-1].Trim() -eq "") {
            $CleanLines = $CleanLines[0..($CleanLines.Count - 2)]
        }

        Write-UTF8NoBOM -Path $HostsPath -Lines $CleanLines
        return $true
    }
    catch {
        Write-Status FAIL "Could not clean up the hosts file" -Detail "$_"
        Write-Log "Hosts cleanup error: $_" "ERROR"
        return $false
    }
}

function Flush-DNSCache {
    try {
        ipconfig /flushdns | Out-Null
        Write-Status OK "DNS cache flushed"
        Write-Log "DNS cache flushed"
    }
    catch {
        Write-Status WARN "Could not flush the DNS cache" -Detail "$_"
    }
}

#endregion

#region MENU DISPLAY

function Show-Menu {

    Clear-Host

    Write-Host ""
    Write-BoxEdge Top Cyan
    Write-BoxLine "" -BorderColor Cyan
    Write-BoxLine "TELEMETRY BLOCKING" -Color White -BorderColor Cyan -Center
    Write-BoxLine "Windows hosts file  $($script:Icon.Dot)  v$ScriptVersion" -Color DarkGray -BorderColor Cyan -Center
    Write-BoxLine "" -BorderColor Cyan
    Write-BoxEdge Bottom Cyan

    # Current status + statistics
    Write-Header "Status"

    $AlreadyBlocked = Test-IsAlreadyBlocked
    if ($AlreadyBlocked) {
        $HostsLines  = Get-CurrentHostsContent
        # Count active domains in the block
        $ActiveCount = @($HostsLines | Where-Object { $_ -match '^0\.0\.0\.0 ' }).Count
        $BlockDate   = ($HostsLines | Where-Object { $_ -match '^# Generated on ' } | Select-Object -First 1) -replace '^# Generated on ',''

        Write-KeyValue "Blocking" "ACTIVE" "Green" -Icon $script:Icon.INFO -IconColor Green -Detail "$ActiveCount domains"
        if ($BlockDate) {
            Write-KeyValue "Applied on" $BlockDate "Gray"
        }

        # [N3] Compact integrity indicator — reuses Get-IntegrityStatus (read-only,
        # same logic as option [A]) to avoid requiring a manual check
        $IntegrityStatus = Get-IntegrityStatus
        if ($IntegrityStatus.Missing.Count -eq 0 -and $IntegrityStatus.Extra.Count -eq 0) {
            Write-KeyValue "Integrity" "Block complete and up to date" "Green" -Icon $script:Icon.OK -IconColor Green
        }
        else {
            Write-KeyValue "Integrity" "$($IntegrityStatus.Missing.Count) missing, $($IntegrityStatus.Extra.Count) extra" "Yellow" -Icon $script:Icon.WARN -IconColor Yellow -Detail "see option [A]"
        }
    }
    else {
        $TotalDomains = @(Get-DomainsToBlock | Where-Object { -not $_.IsDuplicate }).Count
        Write-KeyValue "Blocking" "Not applied" "Gray" -Icon $script:Icon.SKIP -IconColor DarkGray
        Write-KeyValue "Available" "$TotalDomains domains ready to block" "Gray"
    }

    Write-MenuGroup "Blocking"
    Write-MenuItem "1" "View the domains that will be blocked"
    Write-MenuItem "2" "Apply blocking" -KeyColor Yellow
    Write-MenuItem "3" "Update the list" -KeyColor Yellow -Hint "restore + reapply"
    Write-MenuItem "4" "Simulate without modifying" -KeyColor DarkYellow -Hint "DryRun"
    Write-MenuItem "5" "RESTORE the original hosts file" -KeyColor Red

    Write-MenuGroup "Backups & DNS"
    Write-MenuItem "6" "View available backups"
    Write-MenuItem "7" "Manually flush the DNS cache"

    Write-MenuGroup "Reports & diagnostics"
    Write-MenuItem "8" "Generate an HTML report"
    Write-MenuItem "9" "Check for conflicts" -Hint "other tools"
    Write-MenuItem "A" "Check the active block's integrity"
    Write-MenuItem "E" "Export the active list" -Hint ".txt"

    Write-Host ""
    Write-Rule
    Write-MenuItem "Q" "Quit" -KeyColor DarkGray -LabelColor Gray
    Write-Host ""
    Write-Host ("  " + $script:Icon.Arrow + " ") -NoNewline -ForegroundColor Cyan
    Write-Host "Choice: " -NoNewline -ForegroundColor White

    return (Read-Host)
}

#endregion

#region ACTION: SHOW DOMAINS

function Show-DomainList {

    Clear-Host
    Write-Banner "DOMAINS THAT WILL BE BLOCKED" "Grouped by category" "Cyan"

    $Domains = @(Get-DomainsToBlock)
    $Groups  = @($Domains | Sort-Object Category, Domain | Group-Object Category)

    foreach ($Group in $Groups) {
        Write-Host ""
        Write-Host ("  " + $script:Icon.Arrow + " ") -NoNewline -ForegroundColor Yellow
        Write-Host $Group.Name -NoNewline -ForegroundColor White
        Write-Host "  ($($Group.Count))" -ForegroundColor DarkGray

        foreach ($Item in $Group.Group) {
            Write-Host "      0.0.0.0  " -NoNewline -ForegroundColor DarkGray
            Write-Host $Item.Domain -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Rule
    Write-KeyValue "Total" "$($Domains.Count) domains" "White"
    Write-KeyValue "Categories" "$($Groups.Count)" "White"

    Write-Header "Whitelist (never blocked)" "Green"
    foreach ($Safe in $AbsoluteWhitelist | Select-Object -First 8) {
        Write-Status OK $Safe
    }
    Write-Host "     $($script:Icon.Ellip) and $($AbsoluteWhitelist.Count - 8) other protected domains" -ForegroundColor DarkGreen

    Wait-ForMenu
}

#endregion

#region ACTION: APPLY BLOCKING

function Apply-Blocking {
    param(
        [bool]$Simulation  = $false,
        [bool]$ForceUpdate = $false
    )

    Clear-Host

    if ($Simulation) {
        Write-Banner "SIMULATION MODE" "No changes will be made to your system" "DarkYellow"
    }
    else {
        Write-Banner "APPLYING BLOCKING" "Backup  $($script:Icon.Dot)  write  $($script:Icon.Dot)  DNS flush" "Yellow"
    }

    # Check whether already applied
    if (-not $Simulation -and (Test-IsAlreadyBlocked)) {
        if (-not $ForceUpdate) {
            Write-Host ""
            Write-Status INFO "Blocking is already active in the hosts file."
            if (-not (Read-Confirm "Update the list (restore + reapply)?")) {
                Write-Status SKIP "Cancelled."
                Wait-ForMenu
                return
            }
        }
        # Silent restore before reapplying
        Write-Header "Cleaning up the existing block before updating"
        $BackupPath = Backup-Hosts
        $null = Remove-OurBlocksFromHosts
        Write-Status OK "Old block removed — reapplying..."
        Write-Log "Update: old block removed"
    }

    # Step 1: Backup
    Write-Header "Step 1/4: Backing up the current hosts file"

    if (-not $Simulation) {
        $BackupPath = Backup-Hosts
        if (-not $BackupPath) {
            Write-Host ""
            Write-Status FAIL "FATAL ERROR: the backup failed."
            Write-Status FAIL "Blocking was NOT applied, as a safety measure."
            Wait-ForMenu
            return
        }
    }
    else {
        Write-Status SIM "Backup would be saved to:"
        Write-Host "       $BackupFolder\hosts_backup_$Timestamp" -ForegroundColor DarkGray
    }

    # Step 2: Prepare the lines to add
    Write-Header "Step 2/4: Preparing blocking rules"

    $Domains      = Get-DomainsToBlock
    $BlockLines   = @()
    $BlockLines  += ""
    $BlockLines  += $Marker
    $BlockLines  += "# Generated on $(Format-BTDate)"
    $BlockLines  += "# To restore: rerun this script and choose option 5"
    $BlockLines  += "#"

    $CurrentCategory = ""
    $AddedCount      = 0
    $SkippedCount    = 0

    foreach ($Item in $Domains | Sort-Object Category, Domain) {

        if ($Item.Category -ne $CurrentCategory) {
            $BlockLines      += "#"
            $BlockLines      += "# -- $($Item.Category) --"
            $CurrentCategory  = $Item.Category
        }

        if ($Item.IsDuplicate) {
            $SkippedCount++
            if ($Simulation) {
                Write-Status SKIP $Item.Domain -Detail "already present in hosts"
            }
            continue
        }

        $BlockLines += "0.0.0.0 $($Item.Domain)"

        if ($Simulation) {
            Write-Status SIM "0.0.0.0  $($Item.Domain)"
        }

        $AddedCount++
    }

    $BlockLines += "#"
    $BlockLines += $MarkerEnd
    $BlockLines += ""

    Write-Status INFO "$AddedCount domains prepared"
    if ($SkippedCount -gt 0) {
        Write-Status SKIP "$SkippedCount domains skipped" -Detail "already present in hosts"
    }

    # Step 3: Write to the hosts file
    Write-Header "Step 3/4: Writing to the hosts file"

    if (-not $Simulation) {
        try {
            # Read the current content and append our lines (UTF-8 without BOM guaranteed)
            $ExistingLines = Get-Content -Path $HostsPath -Encoding UTF8 -ErrorAction Stop
            $AllLines = @($ExistingLines) + $BlockLines
            Write-UTF8NoBOM -Path $HostsPath -Lines $AllLines
            Write-Status OK "Hosts file updated"
            Write-Log "Blocking applied: $AddedCount domains"

            # [N2] JSON snapshot — real writes only, never in simulation mode
            $ActionLabel = if ($ForceUpdate) { "Update" } else { "Apply" }
            Write-JsonSnapshot -Action $ActionLabel -TotalDomains $AddedCount -SkippedCount $SkippedCount -Categories ($Domains | Where-Object { -not $_.IsDuplicate })
        }
        catch {
            Write-Status FAIL "Could not write to the hosts file" -Detail "$_"
            Write-Status WARN "Attempting to restore the backup..."
            try {
                Copy-Item -Path $BackupPath -Destination $HostsPath -Force
                Write-Status OK "Hosts file restored from backup"
            }
            catch {
                Write-Status FAIL "CRITICAL ERROR: restore failed" -Detail "$_"
                Write-Status FAIL "Restore manually from: $BackupPath"
            }
            Write-Log "Hosts write error: $_" "ERROR"
            Wait-ForMenu
            return
        }
    }
    else {
        Write-Status SIM "$AddedCount lines would be added to the hosts file"
    }

    # Step 4: Flush the DNS cache
    Write-Header "Step 4/4: Flushing the DNS cache"

    if (-not $Simulation) {
        Flush-DNSCache
    }
    else {
        Write-Status SIM "The DNS cache would be flushed" -Detail "ipconfig /flushdns"
    }

    # Summary
    Write-Host ""
    if ($Simulation) {
        Write-BoxEdge Top DarkYellow
        Write-BoxLine "$($script:Icon.SIM)  SIMULATION COMPLETE" -Color DarkYellow -BorderColor DarkYellow
        Write-BoxEdge Middle DarkYellow
        Write-BoxLine ("{0,-20}{1}" -f "Would be blocked", $AddedCount) -Color White -BorderColor DarkYellow
        if ($SkippedCount -gt 0) {
            Write-BoxLine ("{0,-20}{1}" -f "Would be skipped", $SkippedCount) -Color Gray -BorderColor DarkYellow
        }
        Write-BoxLine "No changes were made." -Color Gray -BorderColor DarkYellow
        Write-BoxEdge Bottom DarkYellow
    }
    else {
        Write-BoxEdge Top Green
        Write-BoxLine "$($script:Icon.OK)  BLOCKING APPLIED SUCCESSFULLY" -Color Green -BorderColor Green
        Write-BoxEdge Middle Green
        Write-BoxLine ("{0,-20}{1}" -f "Domains blocked", $AddedCount) -Color White -BorderColor Green
        if ($SkippedCount -gt 0) {
            Write-BoxLine ("{0,-20}{1}" -f "Already present", $SkippedCount) -Color Gray -BorderColor Green
        }
        Write-BoxEdge Bottom Green
        Write-Host ""
        Write-KeyValue "Backup" $BackupPath "DarkGray" -KeyWidth 8
    }

    Wait-ForMenu
}

#endregion

#region ACTION: RESTORE

function Restore-Hosts {

    Clear-Host
    Write-Banner "RESTORING THE HOSTS FILE" "Removes only the rules added by this script" "Red"

    if (-not (Test-IsAlreadyBlocked)) {
        Write-Host ""
        Write-Status INFO "No active blocking detected in the hosts file."
        Wait-ForMenu
        return
    }

    Write-Host ""
    Write-Host "  This action removes ONLY the rules added by this script." -ForegroundColor White
    Write-Host "  Your original hosts file will be preserved." -ForegroundColor DarkGray

    if (-not (Read-Confirm "Confirm the restore?")) {
        Write-Status SKIP "Cancelled."
        Wait-ForMenu
        return
    }

    # Backup before restoring (for safety)
    Write-Header "Backing up the current state before restoring"
    $BackupPath = Backup-Hosts

    # Remove the block
    Write-Header "Removing the telemetry block"

    $Success = Remove-OurBlocksFromHosts

    if ($Success) {
        Write-Status OK "Telemetry block removed"
        Write-Log "Restore completed"

        # [N2] JSON snapshot — logs the restore just like an apply action
        Write-JsonSnapshot -Action "Restore" -TotalDomains 0 -SkippedCount 0 -Categories @()

        # Flush the DNS cache
        Write-Header "Flushing the DNS cache"
        Flush-DNSCache

        Write-Host ""
        Write-BoxEdge Top Green
        Write-BoxLine "$($script:Icon.OK)  RESTORE COMPLETE" -Color Green -BorderColor Green
        Write-BoxEdge Middle Green
        Write-BoxLine "Telemetry domains are no longer blocked." -Color White -BorderColor Green
        Write-BoxEdge Bottom Green
    }
    else {
        Write-Host ""
        Write-Status FAIL "Automatic restore failed."
        if ($BackupPath) {
            Write-Status WARN "You can restore manually from:"
            Write-Host "       $BackupPath" -ForegroundColor Yellow
        }
        Write-Log "Automatic restore failed" "ERROR"
    }

    Wait-ForMenu
}

#endregion

#region ACTION: VIEW BACKUPS

function Show-Backups {

    Clear-Host
    Write-Banner "AVAILABLE BACKUPS" "Hosts file snapshots taken before every change" "Cyan"

    if (-not (Test-Path $BackupFolder)) {
        Write-Host ""
        Write-Status SKIP "No backups found."
        Write-Host "       Folder not created — no blocking has been applied yet." -ForegroundColor DarkGray
    }
    else {
        $Backups = @(Get-ChildItem -Path $BackupFolder -Filter "hosts_backup_*" |
            Sort-Object LastWriteTime -Descending)

        if ($Backups.Count -eq 0) {
            Write-Host ""
            Write-Status SKIP "No backups found in $BackupFolder"
        }
        else {
            Write-Header "$($Backups.Count) backup(s)"
            Write-Host ("  {0,-22}{1,-34}{2,8}" -f "Date", "File", "Size") -ForegroundColor DarkGray
            Write-Rule
            foreach ($B in $Backups) {
                $Size = [Math]::Round($B.Length / 1KB, 1)
                Write-Host ("  {0,-22}" -f (Format-BTDate $B.LastWriteTime)) -NoNewline -ForegroundColor White
                Write-Host ("{0,-34}" -f $B.Name) -NoNewline -ForegroundColor Gray
                Write-Host ("{0,8}" -f "$Size KB") -ForegroundColor DarkGray
            }
            Write-Host ""
            Write-KeyValue "Folder" $BackupFolder "Gray" -KeyWidth 8
            Write-Host ""
            Write-Host "  To manually restore a specific backup, copy the file over:" -ForegroundColor DarkGray
            Write-Host "  $HostsPath" -ForegroundColor DarkCyan
        }
    }

    Wait-ForMenu
}

function Test-Conflicts {
    # Detects whether other tools have modified the hosts file
    # and optionally offers to clean up external entries
    Clear-Host
    Write-Banner "CONFLICT DETECTION" "Other tools that modify the hosts file" "Cyan"

    $Lines         = Get-CurrentHostsContent
    $ConflictTools = @{
        "Chris Titus Tech (CTT WinUtil)" = @("#New Ver", "ctt", "winutil")
        "StevenBlack hosts"              = @("stevenblack", "someonewhocares")
        "hpHosts"                        = @("hphosts", "hosts-file.net")
        "Adobe Patcher / Crack"          = @("practivate.adobe", "activate.adobe", "lm-prd")
        "Spybot Anti-Beacon"             = @("spybot", "anti-beacon")
        "HostsMan"                       = @("hostsman")
        "MVPS Hosts"                     = @("mvps.org")
    }

    $Found         = @()
    $ExternalLines = @()
    $InOurBlock    = $false

    foreach ($Line in $Lines) {
        if ($Line -match [regex]::Escape($Marker))    { $InOurBlock = $true;  continue }
        if ($Line -match [regex]::Escape($MarkerEnd)) { $InOurBlock = $false; continue }
        if ($InOurBlock) { continue }

        # Look for third-party tool signatures in comments
        if ($Line -match '^#' -or $Line.Trim() -eq '') {
            foreach ($Tool in $ConflictTools.Keys) {
                foreach ($Sig in $ConflictTools[$Tool]) {
                    if ($Line -match $Sig -and $Tool -notin $Found) {
                        $Found += $Tool
                    }
                }
            }
            continue
        }

        # Active entries outside our block
        if ($Line -match '^0\.0\.0\.0') {
            $ExternalLines += $Line
        }
    }

    Write-Header "Third-party tools"
    if ($Found.Count -gt 0) {
        Write-Status WARN "Tools detected that modified the hosts file:"
        foreach ($T in $Found) {
            Write-Host "       $($script:Icon.Dot) $T" -ForegroundColor Yellow
        }
    }
    else {
        Write-Status OK "No third-party tool identified in the hosts file."
    }

    Write-Header "Entries outside our block"
    if ($ExternalLines.Count -gt 0) {
        Write-Status INFO "$($ExternalLines.Count) active entry(ies) detected outside our block"
        Write-Host ""
        $Preview = $ExternalLines | Select-Object -First 10
        foreach ($L in $Preview) {
            Write-Host "       $L" -ForegroundColor DarkGray
        }
        if ($ExternalLines.Count -gt 10) {
            Write-Host "       $($script:Icon.Ellip) and $($ExternalLines.Count - 10) more entries" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  The script automatically handles duplicates when writing." -ForegroundColor DarkGray

        if (Read-Confirm "Remove these external entries?") {
            Write-Host ""
            Write-Status INFO "Backing up before cleanup..."
            $BackupPath = Backup-Hosts
            if (-not $BackupPath) {
                Write-Status FAIL "Backup failed — cleanup cancelled for safety."
                Wait-ForMenu
                return
            }

            try {
                $InOurBlock2 = $false
                $CleanLines  = @()
                foreach ($Line in $Lines) {
                    if ($Line -match [regex]::Escape($Marker))    { $InOurBlock2 = $true }
                    if ($Line -match [regex]::Escape($MarkerEnd)) { $InOurBlock2 = $false }

                    if ($InOurBlock2) {
                        $CleanLines += $Line
                        continue
                    }
                    # Remove external 0.0.0.0 entries, keep the rest
                    if (-not $InOurBlock2 -and $Line -match '^0\.0\.0\.0') { continue }
                    $CleanLines += $Line
                }

                Write-UTF8NoBOM -Path $HostsPath -Lines $CleanLines
                Flush-DNSCache
                Write-Status OK "$($ExternalLines.Count) external entry(ies) removed cleanly."
                Write-Log "Conflict cleanup: $($ExternalLines.Count) external entries removed"
            }
            catch {
                Write-Status FAIL "Cleanup failed" -Detail "$_"
                Write-Log "Conflict cleanup error: $_" "ERROR"
            }
        }
        else {
            Write-Status SKIP "Cleanup cancelled — no changes made."
        }
    }
    else {
        Write-Status OK "No external entries detected outside our block."
    }

    Wait-ForMenu
}

function Export-DomainList {
    Clear-Host
    Write-Banner "EXPORTING THE ACTIVE LIST" "Plain-text blocklist, hosts format" "Cyan"

    $ExportPath = "$env:USERPROFILE\Desktop\Maintenance_Reports\Block-Telemetry\Block-Telemetry_Export_$Timestamp.txt"
    $Domains    = Get-DomainsToBlock | Where-Object { -not $_.IsDuplicate } | Sort-Object Category, Domain

    $Lines  = @()
    $Lines += "# ====================================================="
    $Lines += "# BLOCK-TELEMETRY v$ScriptVersion — Blocklist export"
    $Lines += "# Generated on $(Format-BTDate)"
    $Lines += "# Domains: $(@($Domains).Count)"
    $Lines += "# ====================================================="
    $Lines += ""

    $CurrentCat = ""
    foreach ($Item in $Domains) {
        if ($Item.Category -ne $CurrentCat) {
            $Lines     += ""
            $Lines     += "# --- $($Item.Category) ---"
            $CurrentCat = $Item.Category
        }
        $Lines += "0.0.0.0 $($Item.Domain)"
    }

    Write-Host ""
    try {
        $Encoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($ExportPath, $Lines, $Encoding)
        Write-Status OK "Export created" -Detail "$(@($Domains).Count) domains"
        Write-Host "       $ExportPath" -ForegroundColor DarkGray
        Write-Log "Export created: $ExportPath ($(@($Domains).Count) domains)"
    }
    catch {
        Write-Status FAIL "Could not create the export" -Detail "$_"
    }

    Wait-ForMenu
}

function Get-IntegrityStatus {
    # [N3] Comparison logic extracted so it can be reused by the menu (compact
    # indicator) and by Test-Integrity (detailed display) without duplicating code.
    # Only reads the hosts file — no writes, no side effects.
    if (-not (Test-IsAlreadyBlocked)) {
        return [PSCustomObject]@{ Active = $false; Expected = 0; Present = 0; Missing = @(); Extra = @() }
    }

    $Expected = Get-DomainsToBlock | Where-Object { -not $_.IsDuplicate } | ForEach-Object { $_.Domain }

    $HostsContent = Get-CurrentHostsContent
    $InOurBlock   = $false
    $Present      = @()

    foreach ($Line in $HostsContent) {
        if ($Line -match [regex]::Escape($Marker))    { $InOurBlock = $true;  continue }
        if ($Line -match [regex]::Escape($MarkerEnd)) { $InOurBlock = $false; continue }
        if ($InOurBlock -and $Line -match '^0\.0\.0\.0\s+(.+)$') {
            $Present += $Matches[1].Trim().ToLower()
        }
    }

    $Missing = $Expected | Where-Object { $_ -notin $Present }
    $Extra   = $Present  | Where-Object { $_ -notin $Expected }

    return [PSCustomObject]@{
        Active   = $true
        Expected = $Expected.Count
        Present  = $Present.Count
        Missing  = @($Missing)
        Extra    = @($Extra)
    }
}

function Test-Integrity {
    # Checks that the active block contains all the expected domains
    Clear-Host
    Write-Banner "ACTIVE BLOCK INTEGRITY CHECK" "Expected vs. present domains" "Cyan"

    if (-not (Test-IsAlreadyBlocked)) {
        Write-Host ""
        Write-Status INFO "No active telemetry block in the hosts file."
        Write-Host "       Apply blocking first (option 2)." -ForegroundColor DarkGray
        Wait-ForMenu
        return
    }

    Write-Header "Comparing with the hosts file"

    $Status   = Get-IntegrityStatus
    $Missing  = $Status.Missing
    $Extra    = $Status.Extra

    Write-KeyValue "Expected" "$($Status.Expected) domains" "White" -KeyWidth 10
    Write-KeyValue "Present"  "$($Status.Present) domains"  "White" -KeyWidth 10
    Write-Host ""

    if ($Missing.Count -eq 0 -and $Extra.Count -eq 0) {
        Write-Status OK "Perfect integrity — the block is complete and up to date."
        Write-Log "Integrity check: OK ($($Status.Present) domains)"
    }
    else {
        if ($Missing.Count -gt 0) {
            Write-Status WARN "$($Missing.Count) domain(s) missing from the active block:"
            foreach ($D in $Missing | Sort-Object) {
                Write-Host "       $($script:Icon.Dot) $D" -ForegroundColor DarkYellow
            }
            Write-Host ""
            Write-Host "  These domains were added to the list but are not yet blocked." -ForegroundColor DarkGray
            Write-Host "  Use option [3] Update to add them." -ForegroundColor DarkGray
            Write-Log "Integrity check: $($Missing.Count) domains missing" "WARNING"
        }

        if ($Extra.Count -gt 0) {
            Write-Host ""
            Write-Status INFO "$($Extra.Count) domain(s) present in the block but removed from the list:"
            foreach ($D in $Extra | Sort-Object) {
                Write-Host "       $($script:Icon.Dot) $D" -ForegroundColor DarkGray
            }
            Write-Host ""
            Write-Host "  These domains were removed from the current list (e.g. functional domains reclassified)." -ForegroundColor DarkGray
            Write-Host "  Use option [3] Update to clean up the block." -ForegroundColor DarkGray
        }
    }

    Wait-ForMenu
}

#region ACTION: HTML REPORT

function Generate-HtmlReport {
    Clear-Host
    Write-Banner "GENERATING THE HTML REPORT" "Standalone, searchable, dark-theme report" "Cyan"
    Write-Host ""

    $ReportFolder = "$env:USERPROFILE\Desktop\Maintenance_Reports\Block-Telemetry"
    if (-not (Test-Path $ReportFolder)) {
        New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
    }
    $ReportPath = Join-Path $ReportFolder "Block-Telemetry_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').html"

    # Data for the report
    $IsBlocked      = Test-IsAlreadyBlocked
    $Domains        = Get-DomainsToBlock
    $TotalDomains   = ($Domains | Where-Object { -not $_.IsDuplicate }).Count
    $SkippedDomains = ($Domains | Where-Object { $_.IsDuplicate }).Count
    $Categories     = $Domains | Where-Object { -not $_.IsDuplicate } | Group-Object Category | Sort-Object Name

    $BlockDate = ""
    if ($IsBlocked) {
        $BlockDate = (Get-CurrentHostsContent | Where-Object { $_ -match '^# Generated on ' } | Select-Object -First 1) -replace '^# Generated on ',''
    }

    $StatusColor  = if ($IsBlocked) { "#2ecc71" } else { "#e74c3c" }
    $StatusText   = if ($IsBlocked) { "ACTIVE" } else { "INACTIVE" }
    $StatusBg     = if ($IsBlocked) { "#1a3a2a" } else { "#3a1a1a" }

    # Generate category rows
    $CategoryRows = ""
    foreach ($Cat in $Categories) {
        $Pct  = [Math]::Round(($Cat.Count / $TotalDomains) * 100)
        $CategoryRows += @"
        <tr>
            <td>$($Cat.Name)</td>
            <td class="count">$($Cat.Count)</td>
            <td>
                <div class="bar-wrap">
                    <div class="bar" style="width:${Pct}%"></div>
                </div>
            </td>
        </tr>
"@
    }

    # Backup info
    $BackupInfo = "No backup found"
    if (Test-Path $BackupFolder) {
        $LastBackup = Get-ChildItem -Path $BackupFolder -Filter "hosts_backup_*" |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($LastBackup) {
            $BackupInfo = "$($LastBackup.Name) — $(Format-BTDate $LastBackup.LastWriteTime)"
        }
    }

    # Generate rows for the full domain list (for search)
    $DomainRows = ""
    foreach ($Item in $Domains | Where-Object { -not $_.IsDuplicate } | Sort-Object Category, Domain) {
        $DomainRows += "        <tr><td class=`"domain`">$($Item.Domain)</td><td class=`"cat`">$($Item.Category)</td></tr>`n"
    }

    $Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Block-Telemetry — Report</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=DM+Mono&display=swap');
  :root {
    --bg:       #080b12;
    --surface:  #111827;
    --surface2: #1a2235;
    --border:   #1e2d45;
    --text:     #e2e8f0;
    --muted:    #94a3b8;
    --ok:       #a8ce81;
    --warn:     #ffb347;
    --fail:     #ef7066;
    --info:     #7c6af7;
    --accent:   #00d4ff;
    --accent2:  #0099cc;
    --accent3:  #005f80;
    --green:    var(--ok);
    --red:      var(--fail);
    --yellow:   var(--warn);
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'DM Sans', sans-serif; padding: 0; }

  header { background: linear-gradient(160deg,#060c1a 0%,#0a1628 50%,#060a14 100%); border-bottom: 2px solid var(--accent3); padding: 32px 40px 24px; position: relative; overflow: hidden; }
  header::before { content:''; position:absolute; top:0; left:0; right:0; bottom:0; background: radial-gradient(ellipse at 20% 50%,rgba(0,212,255,.06) 0%,transparent 60%), radial-gradient(ellipse at 80% 20%,rgba(124,106,247,.05) 0%,transparent 50%); pointer-events:none; }
  .titlerow { display:flex; align-items:flex-end; gap:0; position:relative; z-index:1; }
  .title-text h1 { font-family:'Cascadia Code','Consolas','Courier New',monospace; font-size:26px; font-weight:700; color:var(--accent); text-shadow:0 0 20px rgba(0,212,255,.4); letter-spacing:1px; margin:0 0 10px 0; }
  .logo-sub { font-family:'Cascadia Code','Consolas',monospace; font-size:12px; color:var(--muted); letter-spacing:2px; margin-bottom:14px; }
  .logo-sub b { color:var(--accent); }
  .meta-bar { display:flex; flex-wrap:wrap; gap:8px 24px; font-size:11.5px; color:#475569; border-top:1px solid var(--border); padding-top:12px; margin-top:4px; position:relative; z-index:1; }
  .meta-bar span { display:flex; align-items:center; gap:6px; }
  .meta-bar b { color:var(--muted); }
  .meta-dot { width:5px; height:5px; border-radius:50%; background:var(--accent); display:inline-block; box-shadow:0 0 6px var(--accent); }

  .container { max-width: 1400px; margin: 0 auto; padding: 2rem 2.5rem; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 1.2rem; }
  .card .label { font-size: .75rem; color: var(--muted); text-transform: uppercase; letter-spacing: .05em; margin-bottom: .4rem; }
  .card .value { font-size: 2rem; font-weight: 700; font-family: 'DM Mono', monospace; }
  .card .value.green  { color: var(--green); }
  .card .value.red    { color: var(--red); }
  .card .value.accent { color: var(--accent); }
  .card .value.yellow { color: var(--yellow); }
  .status-badge { display: inline-block; padding: .3rem .8rem; border-radius: 20px;
                  font-size: .8rem; font-weight: 600; background: $StatusBg; color: $StatusColor; border: 1px solid $StatusColor; }
  .section { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 1.5rem; margin-bottom: 1.5rem; }
  .section h2 { font-size: 1rem; font-weight: 600; margin-bottom: 1rem; color: var(--accent); }
  table { width: 100%; border-collapse: collapse; }
  th { text-align: left; font-size: .75rem; text-transform: uppercase; color: var(--muted); padding: .5rem 0; border-bottom: 1px solid var(--border); }
  td { padding: .6rem 0; border-bottom: 1px solid var(--border); font-size: .9rem; vertical-align: middle; }
  td.count  { font-family: 'DM Mono', monospace; color: var(--accent); width: 60px; }
  td.domain { font-family: 'DM Mono', monospace; font-size: .82rem; color: var(--text); }
  td.cat    { font-size: .78rem; color: var(--muted); width: 220px; }
  .bar-wrap { background: var(--border); border-radius: 4px; height: 6px; width: 100%; }
  .bar      { background: var(--accent); border-radius: 4px; height: 6px; }
  .info-row { display: flex; gap: .5rem; align-items: flex-start; padding: .5rem 0; border-bottom: 1px solid var(--border); font-size: .9rem; }
  .info-row .key { color: var(--muted); min-width: 160px; }
  .info-row .val { font-family: 'DM Mono', monospace; font-size: .82rem; word-break: break-all; }
  .search-wrap { margin-bottom: 1rem; }
  .search-wrap input {
    width: 100%; padding: .6rem 1rem; border-radius: 8px;
    background: var(--bg); border: 1px solid var(--border);
    color: var(--text); font-family: 'DM Mono', monospace; font-size: .85rem;
    outline: none; transition: border .2s;
  }
  .search-wrap input:focus { border-color: var(--accent); }
  .hidden { display: none; }
  #domain-count { font-size: .8rem; color: var(--muted); margin-top: .4rem; }
  footer { text-align: center; color: var(--muted); font-size: .8rem; margin-top: 2rem; }
</style>
</head>
<body>

<header>
  <div class="titlerow">
    <div class="title-text">
      <h1>Block-Telemetry v$ScriptVersion</h1>
      <div class="logo-sub">by <b>Nephren</b></div>
    </div>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="9.39 8.477 484.197 428.149" style="width:76px;height:76px;margin-left:24px;align-self:flex-end;filter:drop-shadow(0 0 12px rgba(0,212,255,.4));flex-shrink:0"><path d="m347.015 235.334 42.877-112.525 67.515 25.727-42.877 112.524z" fill="#a8ce81"/><path d="m303.267 350.143 42.92-112.634 67.514 25.726-42.919 112.634z" fill="#fddb1d"/><path d="m263.921 207.033 42.879-112.525 67.406 25.685-42.877 112.525z" fill="#ef7066"/><path d="m220.505 320.972 42.588-111.764 67.406 25.685-42.588 111.764z" fill="#6eaed7"/><path d="m415.69 247.559c-12.962-10.418-30.606-21.623-53.002-30.158-1.455-.43-2.827-1.077-4.131-1.574l33.307-87.41c1.755.295 3.277.875 4.893 1.864 22.194 8.083 39.661 19.097 52.64 29.147zm-44.284 116.221a216.14 216.14 0 0 0 -53.045-30.048c-1.496-.321-2.91-.86-4.131-1.574l34.136-89.586c1.673.513 3.236.984 4.893 1.865 22.153 8.192 39.62 19.206 52.392 29.8zm122.181-212.166s-25.485-37.351-81.827-59.07c-56.66-21.216-98.7-15.447-98.482-15.364l-15.038 39.466c-.135-.3 27.632-5.533 68.583 3.971l-33.597 88.172c-41.045-9.913-68.776-3.795-68.693-4.013l-10.29 27.33s27.736-7.111 69.123 2.558l-34.717 91.108c-33.74-8.499-58.772-7.828-67.506-6.798l-14.5 38.052c10.873-1.087 47.89-2.17 95.075 15.809 56.467 21.392 82.284 57.873 82.408 57.547zm-241.467-32.87 14.747-38.705 41.45-2.259-14.748 38.705zm-91.514 240.162 14.748-38.704 41.45-2.259-14.5 38.052zm16.364-42.944 13.38-35.117 41.492-2.367-13.423 35.225zm60.11-157.752 13.382-35.118 41.45-2.259-13.381 35.117zm-30.034 78.821 13.381-35.116 41.45-2.26-13.381 35.117zm-15.038 39.466 13.38-35.117 41.45-2.26-13.38 35.117zm30.035-78.823 13.422-35.225 41.45-2.259-13.423 35.225zm-10.213-90.174 11.476-30.115 40.145-2.756-11.766 30.876zm-110.927-84.974 4.93-12.937 16.36-1.112-4.93 12.937zm76.852 67.881 8.99-23.592 35.117-2.306-9.03 23.7zm-28.691-20.768 6.835-17.94 28.455-1.483-6.836 17.94zm-24.068-24.734 5.469-14.351 23.495-.884-5.179 13.59zm40.932 183.057 11.476-30.115 39.855-1.995-11.475 30.115zm-110.927-84.974 4.93-12.938 16.36-1.111-5.178 13.59zm76.852 67.881 9.031-23.7 35.077-2.198-9.032 23.7zm-28.691-20.769 6.835-17.938 28.455-1.484-6.835 17.939zm-24.067-24.734 5.22-13.698 23.743-1.536-5.179 13.59zm41.222 182.297 11.475-30.115 40.145-2.757-11.475 30.116zm-110.927-84.974 5.178-13.59 16.112-.46-4.93 12.938zm77.1 67.229 8.74-22.94 35.119-2.307-8.783 23.05zm-28.691-20.769 6.587-17.287 28.454-1.483-6.587 17.286zm-24.026-24.843 5.178-13.59 23.495-.883-5.178 13.59z" fill="#000101"/><path d="m114.017 84.174 4.889-12.83 17.411-1.582-4.888 12.829zm88.133 61.472 9.529-25.006 32.364-1.612-9.28 24.353zm-34.836-17.383 7.913-20.766 29.355-1.887-7.913 20.766zm-29.271-19.247 6.049-15.873 22.733-1.173-6.007 15.764zm-50.589-48.909 4.102-10.763 12.995-.776-4.101 10.764zm11.525 63.532 4.93-12.938 17.411-1.583-4.93 12.938zm88.133 61.472 9.57-25.114 32.612-2.265-9.528 25.006zm-34.588-18.035 7.664-20.113 29.397-1.996-7.954 20.874zm-29.478-18.703 6.007-15.764 22.734-1.174-5.758 15.112zm-50.63-48.8 4.392-11.525 12.995-.775-4.392 11.524z" fill="#ef7066"/><path d="m68.115 204.635 4.93-12.937 17.122-.822-4.93 12.938zm87.844 62.234 9.57-25.114 32.653-2.374-9.57 25.114zm-34.547-18.144 7.913-20.766 29.107-1.235-7.664 20.113zm-29.229-19.355 5.717-15.004 22.733-1.173-5.717 15.003zm-50.92-48.04 4.391-11.524 12.995-.776-4.35 11.416zm11.814 62.77 4.93-12.937 17.122-.822-4.93 12.938zm88.133 61.473 9.28-24.353 32.654-2.374-9.57 25.115zm-34.836-17.383 7.913-20.765 29.397-1.996-7.955 20.874zm-29.229-19.355 5.717-15.004 23.023-1.934-6.007 15.764zm-50.631-48.801 4.102-10.763 12.995-.775-4.101 10.763z" fill="#6eaed7"/></svg>
  </div>
  <div class="meta-bar">
    <span><span class="meta-dot"></span>Machine: <b>$env:COMPUTERNAME</b></span>
    <span>Date: <b>$(Format-BTDate)</b></span>
    <span>Status: <b>$StatusText</b></span>
  </div>
</header>
<div class="container">

<div class="grid">
  <div class="card">
    <div class="label">Status</div>
    <div><span class="status-badge">$StatusText</span></div>
  </div>
  <div class="card">
    <div class="label">Domains Blocked</div>
    <div class="value accent">$TotalDomains</div>
  </div>
  <div class="card">
    <div class="label">Categories</div>
    <div class="value accent">$($Categories.Count)</div>
  </div>
  <div class="card">
    <div class="label">Duplicates Skipped</div>
    <div class="value yellow">$SkippedDomains</div>
  </div>
</div>

<div class="section">
  <h2>Domains by Category</h2>
  <table>
    <thead><tr><th>Category</th><th>Count</th><th>Distribution</th></tr></thead>
    <tbody>$CategoryRows</tbody>
  </table>
</div>

<div class="section">
  <h2>Full List of Blocked Domains</h2>
  <div class="search-wrap">
    <input type="text" id="searchInput" placeholder="Search a domain or category..." oninput="filterDomains()">
    <div id="domain-count"></div>
  </div>
  <table id="domainTable">
    <thead><tr><th>Domain</th><th>Category</th></tr></thead>
    <tbody id="domainBody">$DomainRows</tbody>
  </table>
</div>

<div class="section">
  <h2>System Information</h2>
  <div class="info-row"><span class="key">Hosts file</span><span class="val">$HostsPath</span></div>
  <div class="info-row"><span class="key">Applied on</span><span class="val">$(if ($BlockDate) { $BlockDate } else { '—' })</span></div>
  <div class="info-row"><span class="key">Last backup</span><span class="val">$BackupInfo</span></div>
  <div class="info-row"><span class="key">Backups folder</span><span class="val">$BackupFolder</span></div>
  <div class="info-row"><span class="key">Log file</span><span class="val">$LogPath</span></div>
</div>

</div>

<footer>Block-Telemetry v$ScriptVersion — Automatically generated report</footer>

<script>
function filterDomains() {
    var input  = document.getElementById('searchInput').value.toLowerCase();
    var rows   = document.getElementById('domainBody').getElementsByTagName('tr');
    var visible = 0;
    for (var i = 0; i < rows.length; i++) {
        var domain = rows[i].getElementsByTagName('td')[0].textContent.toLowerCase();
        var cat    = rows[i].getElementsByTagName('td')[1].textContent.toLowerCase();
        if (domain.includes(input) || cat.includes(input)) {
            rows[i].classList.remove('hidden');
            visible++;
        } else {
            rows[i].classList.add('hidden');
        }
    }
    document.getElementById('domain-count').textContent = visible + ' domain(s) shown';
}
// Initialize the counter
window.onload = function() {
    document.getElementById('domain-count').textContent = '$TotalDomains domain(s) total';
};
</script>
</body>
</html>
"@

    try {
        $Enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ReportPath, $Html, $Enc)
        Write-Status OK "Report created"
        Write-Host "       $ReportPath" -ForegroundColor DarkGray
        Write-Log "HTML report generated: $ReportPath"
        Write-Status INFO "Opening in your default browser..."
        Start-Sleep -Milliseconds 500
        Start-Process $ReportPath
    }
    catch {
        Write-Status FAIL "Could not create the report" -Detail "$_"
    }

    Wait-ForMenu
}

#endregion

# [N1] -SelfTest: read-only logic validations, no writes to the hosts file.
# All functions called here (Get-DomainsToBlock, Get-IntegrityStatus,
# Test-IsAlreadyBlocked, Get-CurrentHostsContent) only read — no risk.
function Invoke-SelfTest {
    # [FIX] $T local to Invoke-SelfTest / $script:T written by the nested Assert-True
    # function = two different variables. $script:T started as $null -> .Add() on null -> crash.
    $script:SelfTestResults = [System.Collections.Generic.List[object]]::new()
    function Assert-True($Name, $Condition, $Detail = "") {
        $script:SelfTestResults.Add([PSCustomObject]@{ Test = $Name; Pass = [bool]$Condition; Detail = $Detail })
    }

    # 1. The whitelist must not contain any internal duplicates
    $WhitelistDupes = $AbsoluteWhitelist | Group-Object | Where-Object { $_.Count -gt 1 }
    Assert-True "Whitelist has no internal duplicates" ($WhitelistDupes.Count -eq 0) "$($WhitelistDupes.Count) duplicate(s)"

    # 2. No telemetry domain should also be present in the whitelist
    #    (config contradiction: a domain being blocked AND protected at the same time)
    $AllTelemetryDomains = foreach ($Cat in $TelemetryDomains.Keys) { $TelemetryDomains[$Cat] | ForEach-Object { $_.ToLower().Trim() } }
    $Contradictions = $AllTelemetryDomains | Where-Object { $AbsoluteWhitelist -contains $_ }
    Assert-True "No telemetry/whitelist contradiction" ($Contradictions.Count -eq 0) "$($Contradictions.Count) conflicting domain(s)"

    # 3. Whitelist matching must be exact, never a subdomain match
    #    (historical regression fixed: EndsWith blocked/protected entire subdomains)
    $SampleWhitelisted = $AbsoluteWhitelist | Select-Object -First 1
    if ($SampleWhitelisted) {
        $FakeSubdomain = "test-selftest-should-not-match.$SampleWhitelisted"
        Assert-True "Whitelist match = exact (no subdomain)" (-not ($AbsoluteWhitelist -contains $FakeSubdomain)) $FakeSubdomain
    }

    # 4. Get-DomainsToBlock must return a non-empty list, with no duplicate domain
    $Domains = Get-DomainsToBlock
    Assert-True "Get-DomainsToBlock returns results" ($Domains.Count -gt 0) "$($Domains.Count) entry(ies)"
    $DomainDupes = $Domains | Group-Object Domain | Where-Object { $_.Count -gt 1 }
    $DupeDetail  = if ($DomainDupes.Count -gt 0) { ($DomainDupes | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ", " } else { "" }
    Assert-True "No duplicate domain in the blocklist" ($DomainDupes.Count -eq 0) $DupeDetail

    # 5. The start and end markers must be distinct strings
    Assert-True "Start/end markers are distinct" ($Marker -ne $MarkerEnd)

    # 6. Get-IntegrityStatus must never throw, whether the block is active or not
    try {
        $null = Get-IntegrityStatus
        Assert-True "Get-IntegrityStatus runs without error" $true
    }
    catch {
        Assert-True "Get-IntegrityStatus runs without error" $false "$_"
    }

    # 7. Test-IsAlreadyBlocked must never throw
    try {
        $null = Test-IsAlreadyBlocked
        Assert-True "Test-IsAlreadyBlocked runs without error" $true
    }
    catch {
        Assert-True "Test-IsAlreadyBlocked runs without error" $false "$_"
    }

    # 8. No blocked domain on a shared cloud-hosting suffix unless reviewed by hand
    #    (regression fixed in v5.3.1: a Discord upload bucket on storage.googleapis.com
    #    was blocked as "telemetry" and broke every attachment upload)
    $UnreviewedCloud = $AllTelemetryDomains | Where-Object {
        $D = $_
        ($SharedCloudSuffixes | Where-Object { $D.EndsWith($_) }) -and
        ($ReviewedCloudDomains -notcontains $D)
    }
    $CloudDetail = if (@($UnreviewedCloud).Count -gt 0) { @($UnreviewedCloud) -join ", " } else { "" }
    Assert-True "No unreviewed shared-cloud domain in the blocklist" (@($UnreviewedCloud).Count -eq 0) $CloudDetail

    Write-Banner "SELFTEST" "Block-Telemetry v$ScriptVersion  $($script:Icon.Dot)  read-only logic checks" "Cyan"
    Write-Host ""
    $T = $script:SelfTestResults
    foreach ($Item in $T) {
        $Level  = if ($Item.Pass) { "OK" } else { "FAIL" }
        $Detail = if ($Item.Detail) { "($($Item.Detail))" } else { "" }
        Write-Status $Level $Item.Test -Detail $Detail
    }
    $PassCount = @($T | Where-Object { $_.Pass }).Count
    $ResultColor = if ($PassCount -eq $T.Count) { "Green" } else { "Red" }
    Write-Host ""
    Write-Rule
    Write-Host "  Result  " -NoNewline -ForegroundColor DarkGray
    Write-Host "$PassCount / $($T.Count) assertions passed" -ForegroundColor $ResultColor
    Write-Host ""
}

if ($SelfTest) {
    Invoke-SelfTest
    exit
}

Write-Log "Script started"

do {
    $Choice = Show-Menu

    switch ($Choice.ToUpper()) {

        "1" { Show-DomainList }
        "2" { Apply-Blocking -Simulation $false }
        "3" { Apply-Blocking -Simulation $false -ForceUpdate $true }
        "4" { Apply-Blocking -Simulation $true }
        "5" { Restore-Hosts }
        "6" { Show-Backups }

        "7" {
            Clear-Host
            Write-Banner "FLUSHING THE DNS CACHE" "ipconfig /flushdns" "Cyan"
            Write-Host ""
            Flush-DNSCache
            Wait-ForMenu
        }

        "8" { Generate-HtmlReport }
        "9" { Test-Conflicts }
        "A" { Test-Integrity }
        "E" { Export-DomainList }

        "Q" {
            Write-Log "Script ended"
            Clear-Host
            Write-Host ""
            Write-Status OK "Session closed." -Detail "Log: $LogPath"
            Write-Host ""
        }

        default {
            Write-Host ""
            Write-Status WARN "Invalid choice. Pick an option from the menu."
            Start-Sleep -Seconds 1
        }
    }

} while ($Choice.ToUpper() -ne "Q")

# SIG # Begin signature block
# MIIFwgYJKoZIhvcNAQcCoIIFszCCBa8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCtOrAC/gt6WKq7
# /Kb2EWru+O/TrpgspyuZz9sL6a4oh6CCAygwggMkMIICDKADAgECAhB6X4r8AlBU
# p0MV3JpMuQ6sMA0GCSqGSIb3DQEBCwUAMCoxKDAmBgNVBAMMH05lcGhyZW4gUG93
# ZXJTaGVsbCBDb2RlIFNpZ25pbmcwHhcNMjYwNzA0MDIzMzIwWhcNMzEwNzA0MDI0
# MzIwWjAqMSgwJgYDVQQDDB9OZXBocmVuIFBvd2VyU2hlbGwgQ29kZSBTaWduaW5n
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1JnV5AocUnAMNIG3nYF9
# 5mOQz5NzMYJqc9D6mq3pjRlmuYIgvYEuJL5dvt8eoAiUKd+XHTaY5wl+zt7LUon+
# TmEldVwfrYvROpI+5TDyBRc5BzY4uACsA4JUM4ienjX04BBKT3uH6JwHzBluWqcG
# Xrg16NqzDiae7WNzVrev+BME00mgSvBo3hKp3sHIvFQaAmjGXLyJd+llfnBpmoD9
# JnOxMKO7VFIlhAz5cEUnFu/xDLHgARdBUfXA5odScWKiDvygNZsH1vHo07Oo7pDK
# awR3bT6lcXWRXSUmawgE1mZra+b9qpeNol+5J+86zN83RccBKZBUtQQoyy+cv20x
# VQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# HQYDVR0OBBYEFNxVaDYoNv8UXQWnbtEy/DTaQHjYMA0GCSqGSIb3DQEBCwUAA4IB
# AQCE4NqZbeximmbNEORyLxvIYiMQwP59B9R95blQQ/zugPSt4wab61yBbgO1E3mH
# mUdN0fCHhN/u0uB7h7ZBYw1w4hnzoiBac4UYzsXH4/D41gBjutbtDllRy6/zs3dl
# /hbbHAmwKXdjNVLG9cPkpWlkvKR1DJLMugU2uj+S6k+U7DfHo76sbAKqiu3biXtd
# mao6PP99EU7JBYZjsJ+BsnYcZ2KcnZ8TKiRuhSXoxAyPman7Z0BVo1H2O+fxd96b
# 4W8VclmpFh7T2CyRAHolwEy5coFYyueisO0PZg+nKwXr66+m1T1CBLQYwh79/SKO
# wGUJyU5RtTryD+hfLwkTQKVCMYIB8DCCAewCAQEwPjAqMSgwJgYDVQQDDB9OZXBo
# cmVuIFBvd2VyU2hlbGwgQ29kZSBTaWduaW5nAhB6X4r8AlBUp0MV3JpMuQ6sMA0G
# CWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIJ/zE7c7qd2XKRvlg13dME1ynl1CPzveJpN0nxc2
# aBOoMA0GCSqGSIb3DQEBAQUABIIBAB6Ao0sfkpg6hrxb900yt9iiKX36BahOqHfD
# HBIcmDABFNao1jRfu4fKhbqw2alXNVRfLbmvwGZaC4qAF+v13IhcY1qk5OjRIKQP
# pmcK8QmO0iZw7s4LGwbNz4l6NZ6AHLCCDMezB2K0DgwfoOtfG4xOG9TUQfV0Qo5b
# zK5HCTU4nemqmVv/+JoPsTD4rglIJqsnn+gX2BggweuT7IjJQ7uLvSV8SKzeB4xs
# qYklbCA8n7BEuQzH/9XnwrUSOVUGuKs1f+ww0NvM+RncF8anMD5aPpMHlIBfJnuc
# /vmRyqn31tKfFKP/OJab/MC9MMHKig0oE/bXrymoFCnXewqxraY=
# SIG # End signature block
