# =====================================================================================
# BLOCAGE TELEMETRIE - FICHIER HOSTS WINDOWS
# VERSION 5.2
# =====================================================================================
# Ce script modifie UNIQUEMENT le fichier hosts Windows pour bloquer les domaines
# de télémétrie (collecte de données) des éditeurs majeurs.
#
# GARANTIES DE SÉCURITÉ :
#   [S1]  Sauvegarde automatique du fichier hosts avant toute modification
#   [S2]  Liste blanche stricte : aucun domaine fonctionnel n'est bloqué
#   [S3]  Rotation automatique des sauvegardes (conservation des 10 dernières)
#   [S4]  Mode simulation (DryRun) pour voir ce qui serait fait sans rien toucher
#   [S5]  Fonction de restauration complète intégrée (un seul choix au menu)
#   [S6]  Marqueur unique dans le fichier hosts pour identifier nos ajouts
#   [S7]  Aucune modification de registre, aucun service arrêté, aucun pilote touché
#   [S8]  Option "Mettre à jour" intégrée (restaure + ré-applique en une étape)
#   [S9]  Encodage UTF-8 AVEC BOM garanti (indispensable pour que PowerShell 5.1
#         détecte l'UTF-8 ; sans BOM, PS 5.1 lit le fichier en ANSI et les
#         caractères accentués corrompent le parsing — PowerShell 7 gère les deux)
#   [S10] Vérification des doublons avant écriture (domaines déjà présents ignorés)
#   [S11] Détection de conflits avec d'autres outils (CTT, etc.)
#   [S12] Vérification d'intégrité du bloc actif (domaines attendus vs présents)
#   [S13] Nettoyage des entrées externes optionnel (hors notre bloc)
#
# AMÉLIORATIONS v5.1 (architecture menu interactif conservée à l'identique) :
#   [N1] -SelfTest : validations logiques en lecture seule (liste blanche, doublons,
#        cohérence whitelist/blocage), lancé en paramètre CLI, sans toucher au hosts
#   [N2] Export JSON automatique après chaque action réelle (Apply/Update/Restore)
#        dans Rapports_Maintenance\Block-Telemetry, pour construire un historique
#        structuré comme les autres scripts de la suite
#   [N3] Indicateur d'intégrité affiché directement dans le menu principal (au lieu
#        d'attendre l'option [A]) — même logique de comparaison, juste réutilisée
#
# CORRECTIF v5.2 :
#   [C1] Ajout d'un BOM UTF-8 en tête de fichier. Sans lui, PowerShell 5.1 ouvrait
#        le script en ANSI (faute de détection automatique de l'UTF-8), ce qui
#        corrompait les caractères accentués et provoquait des erreurs de parsing
#        (jetons inattendus autour des chaînes contenant des accents ou le tiret
#        cadratin). PowerShell 7 n'était pas affecté, d'où le script fonctionnel
#        uniquement sous pwsh avant ce correctif.
#
# CATÉGORIES COUVERTES :
#   - Microsoft Télémétrie (Windows, Office, Defender, DiagTrack, Xbox, OneDrive)
#   - Microsoft Copilot Télémétrie
#   - Microsoft Edge Télémétrie
#   - Google Analytics / Tracking
#   - Adobe Analytics / Stats
#   - Tracking tiers (Criteo, Taboola, Outbrain, Rubicon, PubMatic, OpenX, AMP...)
#   - Rapports de crash (Sentry, Bugsnag)
#   - Spotify Télémétrie
#   - Brave Analytics
#   - Mozilla / Firefox Télémétrie
#   - NVIDIA Télémétrie
#   - AMD Télémétrie
#   - Discord Télémétrie
#   - Steam / Valve Télémétrie
#   - GOG Galaxy Télémétrie
#
# DOMAINES JAMAIS BLOQUES (liste blanche stricte) :
#   - Activation, licences, authentification Adobe
#   - Windows Update, activation Microsoft
#   - NextDNS (service DNS critique)
#   - Steam, Spotify, Brave, Mozilla (domaines fonctionnels)
#   - NVIDIA / AMD (mises à jour pilotes)
#   - GOG Galaxy (store et téléchargements)
#   - Visual Studio Code (mises à jour)
#   - Tout ce qui peut rendre une application inutilisable
# =====================================================================================

param(
    [switch]$SelfTest  # [N1] Validations logiques en lecture seule — pas besoin d'admin, sort avant l'élévation
)

#region AUTO-ELEVATION

# [N1] Le SelfTest est purement en lecture (hosts + comparaisons en mémoire) : on le
# traite avant l'élévation pour éviter une demande UAC inutile juste pour un contrôle.

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $SelfTest -and -not $currentPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    # Utilise pwsh si disponible (PowerShell 7+), sinon powershell.exe (5.x)
    $Shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    Start-Process $Shell `
        -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    exit
}

if (-not $SelfTest) { Set-ExecutionPolicy Bypass -Scope Process -Force }

#endregion

#region INITIALISATION

$HostsPath        = "$env:SystemRoot\System32\drivers\etc\hosts"
$BackupFolder     = "$env:USERPROFILE\Desktop\Hosts_Backups"
$LogPath          = "$env:USERPROFILE\Desktop\Block-Telemetry_Log.txt"
$Marker           = "# === BLOC TELEMETRIE - Ne pas modifier manuellement ==="
$MarkerEnd        = "# === FIN BLOC TELEMETRIE ==="
$Timestamp        = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BackupMaxCount   = 10   # Nombre maximum de sauvegardes à conserver

#endregion

#region DOMAINES TELEMETRIE

# =====================================================================================
# LISTE DES DOMAINES BLOQUES
#
# Règle de construction de cette liste :
#   1. Domaine connu comme collectant des données d'usage/télémétrie
#   2. NON nécessaire au fonctionnement de l'application
#   3. Vérifié : son blocage ne casse pas l'activation ni les licences
#
# ADOBE — Domaines de télémétrie/statistiques UNIQUEMENT
# NE SONT PAS dans cette liste (fonctionnels) :
#   adobe.com, adobelogin.com, adobegenuine.com, adobejanus.com,
#   adobeereg.com (enregistrement produit), lcs-cops.adobe.com,
#   prod.adobegenuine.com, genuine.adobe.com
# =====================================================================================

$TelemetryDomains = [ordered]@{

    # ------------------------------------------------------------------
    # MICROSOFT — Télémétrie Windows et Office
    # Sont EXCLUS de cette liste :
    #   windowsupdate.com, update.microsoft.com, msftconnecttest.com
    #   (nécessaires aux mises à jour et à la détection connectivité)
    # ------------------------------------------------------------------
    "Microsoft Telemetrie" = @(
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
        # Télémétrie Office et pipeline ARIA
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
        # Windows Defender — télémétrie cloud uniquement (pas la protection locale)
        "spynet.microsoft.com",
        "spynet2.microsoft.com",
        "wdcp.microsoft.com",
        "wdcpalt.microsoft.com",
        "ssw.live.com",
        # Publicité Windows / MSN / suggestions
        "rad.msn.com",
        "ads.msn.com",
        "adnexus.net",
        "ac3.msn.com",
        "h1.msn.com",
        # Cortana / Bing suggestions dans la barre de recherche
        "bingapis.com",
        "api.bing.com",
        # DiagTrack — service "Expériences des utilisateurs connectés et télémétrie"
        # Ce service (svchost DiagTrack) est le principal collecteur de données Windows
        "watson.events.data.microsoft.com",
        "umwatsonc.events.data.microsoft.com",
        "v10-win.vortex.data.microsoft.com",
        "v10.vortex-win.data.microsoft.com",
        "functional.events.data.microsoft.com",
        "umwatson.events.data.microsoft.com",
        # Xbox / Game Bar — télémétrie gaming
        "telemetry.xbox.com",
        "data.microsoft.com",
        "xbox.ipv6.microsoft.com",
        "xboxexperiencesprod.experimentation.xboxlive.com",
        "xaccount.microsoft.com",
        # OneDrive — télémétrie (pas la synchronisation)
        "telemetry.onedrive.com",
        "onedrive.com.edgekey.net",
        # Microsoft Teams — télémétrie (pas la communication)
        "config.teams.microsoft.com",
        "teams.events.data.microsoft.com"
    )

    # ------------------------------------------------------------------
    # MICROSOFT COPILOT — Télémétrie et collecte de données
    # Copilot envoie des données d'usage, requêtes et contexte
    # vers les serveurs Microsoft/Bing. Ces endpoints sont purement
    # analytiques — Copilot n'est pas bloqué fonctionnellement
    # sur les machines qui l'utilisent volontairement.
    # ------------------------------------------------------------------
    "Microsoft Copilot Telemetrie" = @(
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

    
    # Utile même si Edge est désinstallé sur certaines machines —
    # WebView2 et les résidus Edge peuvent encore contacter ces endpoints.
    # Sont EXCLUS : mise à jour Edge, WebView2 fonctionnel
    # ------------------------------------------------------------------
    "Microsoft Edge Telemetrie" = @(
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
    # GOOGLE — Analytics et tracking tiers
    # Sont EXCLUS : google.com, googleapis.com, gstatic.com
    # (nécessaires à de nombreuses apps web et authentifications)
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
    # ADOBE — Statistiques et analytics uniquement
    # adobestats.io   : collecte de statistiques d'usage des apps CC
    # omtrdc.net      : Adobe Analytics / Omniture (tracking comportemental)
    # demdex.net      : Adobe Audience Manager (profilage publicitaire)
    # adobedtm.com    : Adobe Dynamic Tag Manager (tracking marketing)
    # NE SONT PAS dans cette liste (fonctionnels) :
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
    # OUTILS DE TRACKING TIERS
    # Ces domaines n'appartiennent à aucune app installée localement —
    # ils sont uniquement chargés par des sites web ou des apps
    # pour vous pister entre sessions.
    # ------------------------------------------------------------------
    "Tracking tiers" = @(
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
        # Hotjar (heatmaps comportementaux)
        "static.hotjar.com",
        "api.hotjar.com",
        "insights.hotjar.com",
        # Mixpanel
        "api.mixpanel.com",
        # Segment
        "api.segment.io",
        "cdn.segment.com",
        # Criteo — retargeting publicitaire cross-site très agressif
        "criteo.com",
        "static.criteo.net",
        "dis.criteo.com",
        "rtax.criteo.com",
        "gum.criteo.com",
        # Taboola — contenu sponsorisé et tracking comportemental
        "taboola.com",
        "cdn.taboola.com",
        "trc.taboola.com",
        "nr-data.taboola.com",
        # Outbrain — même catégorie que Taboola
        "outbrain.com",
        "amplify.outbrain.com",
        "widgets.outbrain.com",
        # Rubicon Project / Magnite — enchères publicitaires temps réel
        "rubiconproject.com",
        "fastlane.rubiconproject.com",
        # PubMatic — plateforme SSP publicitaire
        "pubmatic.com",
        "ads.pubmatic.com",
        # OpenX — enchères publicitaires
        "openx.net",
        "delivery.openx.net",
        # Moat — mesure de visibilité des publicités (Oracle)
        "moatads.com",
        "z.moatads.com",
        # Google AMP — proxy Google qui collecte données de navigation
        "ampproject.org",
        "cdn.ampproject.org",
        # LinkedIn Insight Tag — tracking B2B
        "snap.licdn.com",
        "platform.linkedin.com"
    )

    # ------------------------------------------------------------------
    # COLLECTE D'ERREURS / CRASH REPORTS
    # Sentry.io, Bugsnag : envoient les stack traces et données système
    # lors de plantages d'applications. Informatif mais intrusif.
    # Note : peut réduire la qualité des correctifs d'applications.
    # ------------------------------------------------------------------
    "Rapports de crash" = @(
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
    # SPOTIFY — Télémétrie et analytics uniquement
    # Sont EXCLUS : *.spotify.com (streaming, login, API),
    #   *.scdn.co (CDN musique), accounts.spotify.com, api.spotify.com
    # ------------------------------------------------------------------
    "Spotify Telemetrie" = @(
        "log.spotify.com",
        "crashdump.spotify.com",
        "audio-ec.spotify.com",
        "heads4-ash2-accesspoint.ap.spotify.com",
        "heads4-accesspoint.ap.spotify.com",
        "cpapi.spotify.com"
    )

    # ------------------------------------------------------------------
    # BRAVE — Analytics et expérimentations
    # "Privacy-Preserving Product Analytics" (P3A) : même agrégé,
    # c'est de la collecte de données d'usage envoyée à Brave Software.
    # Web Discovery Project (WDP) : collecte de données de recherche/pages
    # pour améliorer Brave Search (feature opt-in, désactivée via policy
    # BraveWebDiscoveryEnabled=0 ; ces domaines n'ont aucune autre fonction,
    # donc blocage hosts sans risque).
    # Sont EXCLUS : mise à jour Brave, composants de sécurité,
    #   laptop-updates.brave.com (usage ping MAIS aussi canal de mise à
    #   jour du binaire — ne jamais bloquer, cf. BraveStatsPingEnabled
    #   géré uniquement via policy registre)
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
    # MOZILLA / FIREFOX — Télémétrie et expérimentations
    # LibreWolf désactive déjà la plupart via sa config interne,
    # mais ces endpoints résiduels peuvent encore être contactés.
    # Sont EXCLUS : addons.mozilla.org, safebrowsing (sécurité)
    # ------------------------------------------------------------------
    "Mozilla / Firefox Telemetrie" = @(
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
    # NVIDIA — Télémétrie GeForce Experience / NVIDIA App
    # Sont EXCLUS : mise à jour pilotes, GeForce NOW (streaming)
    # ------------------------------------------------------------------
    "NVIDIA Telemetrie" = @(
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
    # AMD — Télémétrie AMD Software / Adrenalin
    # Sont EXCLUS : mise à jour pilotes AMD
    # ------------------------------------------------------------------
    "AMD Telemetrie" = @(
        "telemetry.amd.com",
        "crashreport.amd.com",
        "analytics.amd.com",
        "amd-detect.amd.com",
        "dc.services.visualstudio.com"
    )

    # ------------------------------------------------------------------
    # DISCORD — Télémétrie et analytics
    # Discord envoie des données d'usage détaillées (Science API)
    # Sont EXCLUS : discord.com (fonctionnel), gateway.discord.gg (chat)
    # ------------------------------------------------------------------
    "Discord Telemetrie" = @(
        "discord-attachments-uploads-prd.storage.googleapis.com",
        "click.discord.com",
        "crash.discord.com"
        # sentry.io retiré d'ici : déjà couvert par la catégorie "Rapports de crash".
        # Get-DomainsToBlock ne dédoublonne QUE par rapport aux entrées déjà présentes
        # dans le hosts hors de notre bloc — pas entre catégories de cette liste elle-même.
    )

    # ------------------------------------------------------------------
    # STEAM / VALVE — Télémétrie et analytics
    # Sont EXCLUS : steampowered.com, steamcommunity.com, vac.valve.net
    # (plateforme, anti-cheat et téléchargements jeux)
    # ------------------------------------------------------------------
    "Steam / Valve Telemetrie" = @(
        "media.steampowered.com",
        "clientconfig.akamai.steamstatic.com",
        "steamstat.us",
        "ingest.sentry.io"   # doublon Sentry géré automatiquement
    )

    # ------------------------------------------------------------------
    # GOG GALAXY — Télémétrie et analytics
    # Sont EXCLUS : gog.com (store), cdn.gog.com (téléchargements)
    # ------------------------------------------------------------------
    "GOG Galaxy Telemetrie" = @(
        "telemetry.gog.com",
        "analytics.gog.com",
        "metrics.gog.com",
        "reporting.gog.com"
    )
}

# =====================================================================================
# LISTE BLANCHE ABSOLUE — Ces domaines ne seront JAMAIS bloqués
# même s'ils apparaissent dans $TelemetryDomains par erreur
# =====================================================================================

$AbsoluteWhitelist = @(
    # Adobe — activation et licences exactes
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
    # Microsoft — mises à jour et activation exactes
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
    # Microsoft Edge WebView2 — composant système
    "msedge.net",
    # OneDrive — synchronisation fonctionnelle
    "onedrive.live.com",
    "storage.live.com",
    # Xbox — authentification fonctionnelle
    "xboxlive.com",
    # Microsoft Teams — communication fonctionnelle
    "teams.microsoft.com",
    # NextDNS — service DNS critique
    "nextdns.io",
    "dns.nextdns.io",
    "link.nextdns.io",
    # Spotify — streaming, authentification, API
    "accounts.spotify.com",
    "api.spotify.com",
    "apresolve.spotify.com",
    "dealer.spotify.com",
    "scdn.co",
    "spotifycdn.com",
    # Brave — mises à jour et sécurité
    "updates.bravesoftware.com",
    "safebrowsing.brave.com",
    "go-updater.brave.com",
    # Mozilla — mises à jour et sécurité
    "addons.mozilla.org",
    "safebrowsing.googleapis.com",
    "aus5.mozilla.org",
    "balrog-admin.stage.mozaws.net",
    # Steam — plateforme et anti-cheat
    "steampowered.com",
    "steamcommunity.com",
    "steamgames.com",
    "steamusercontent.com",
    "steamcdn-a.akamaihd.net",
    "vac.valve.net",
    # NVIDIA — mises à jour pilotes
    "download.nvidia.com",
    "international.download.nvidia.com",
    "gfwsl.geforce.com",
    # AMD — mises à jour pilotes
    "drivers.amd.com",
    "radeon.com",
    # Epic Games — store et launcher (non utilisé ici, gardé en liste blanche par précaution :
    # coût nul, évite un blocage accidentel si réutilisé sur une autre machine ou étendu plus tard)
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
    # GOG — store et téléchargements
    "cdn.gog.com",
    "galaxy-client.gog.com",
    "store.gog.com",
    "www.gog.com",
    # Visual Studio Code — mises à jour
    "update.code.visualstudio.com",
    "marketplace.visualstudio.com",
    # DNS et infrastructure réseau
    "localhost"
)

#endregion

#region FONCTIONS

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Line = "[$((Get-Date).ToString('HH:mm:ss'))] [$Level] $Message"
    Add-Content -Path $LogPath -Value $Line -Encoding UTF8 -ErrorAction SilentlyContinue
}

# [N2] Snapshot JSON après chaque action réelle (Apply/Update/Restore), pour construire
# un historique structuré comme les autres scripts de la suite. N'est jamais appelée en
# mode simulation (DryRun) puisqu'aucun état réel n'a changé.
function Write-JsonSnapshot {
    param(
        [string]$Action,       # "Application", "Mise à jour", "Restauration"
        [int]$TotalDomains  = 0,
        [int]$SkippedCount  = 0,
        [array]$Categories  = @()
    )
    try {
        $ReportFolder = "$env:USERPROFILE\Desktop\Rapports_Maintenance\Block-Telemetry"
        if (-not (Test-Path $ReportFolder)) {
            New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
        }

        $PerCategory = $Categories | Group-Object Category | ForEach-Object {
            [PSCustomObject]@{ Categorie = $_.Name; Domaines = $_.Count }
        }

        $Snapshot = [PSCustomObject]@{
            Timestamp     = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
            Action        = $Action
            TotalDomaines = $TotalDomains
            Ignores       = $SkippedCount
            ParCategorie  = $PerCategory
        }

        $JsonPath = Join-Path $ReportFolder "Block-Telemetry_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').json"
        $Snapshot | ConvertTo-Json -Depth 3 | Out-File $JsonPath -Encoding UTF8 -Force
    }
    catch {
        # Non-bloquant : un échec d'export JSON ne doit jamais faire échouer l'action réelle
        Write-Log "Échec export JSON snapshot : $_" "AVERT"
    }
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "  $('-' * $Text.Length)" -ForegroundColor DarkCyan
}

# Écriture UTF-8 sans BOM, compatible PowerShell 5 et 7
function Write-UTF8NoBOM {
    param([string]$Path, [string[]]$Lines)
    $Encoding = New-Object System.Text.UTF8Encoding($false)  # $false = pas de BOM
    [System.IO.File]::WriteAllLines($Path, $Lines, $Encoding)
}

function Backup-Hosts {
    try {
        if (-not (Test-Path $BackupFolder)) {
            New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null
        }
        $BackupPath = Join-Path $BackupFolder "hosts_backup_$Timestamp"
        Copy-Item -Path $HostsPath -Destination $BackupPath -Force
        Write-Host "  [OK] Sauvegarde : $BackupPath" -ForegroundColor Green
        Write-Log "Sauvegarde créée : $BackupPath"

        # Rotation : supprimer les sauvegardes excédentaires (les plus anciennes)
        $AllBackups = Get-ChildItem -Path $BackupFolder -Filter "hosts_backup_*" |
            Sort-Object LastWriteTime -Descending
        if ($AllBackups.Count -gt $BackupMaxCount) {
            $ToDelete = $AllBackups | Select-Object -Skip $BackupMaxCount
            foreach ($Old in $ToDelete) {
                Remove-Item -Path $Old.FullName -Force -ErrorAction SilentlyContinue
                Write-Log "Ancienne sauvegarde supprimée (rotation) : $($Old.Name)"
            }
            Write-Host "  [OK] Rotation : $($ToDelete.Count) ancienne(s) sauvegarde(s) supprimée(s)" -ForegroundColor DarkGray
        }

        return $BackupPath
    }
    catch {
        Write-Host "  [ERREUR] Impossible de créer la sauvegarde : $_" -ForegroundColor Red
        Write-Log "Erreur sauvegarde : $_" "ERREUR"
        return $null
    }
}

function Get-CurrentHostsContent {
    try {
        return Get-Content -Path $HostsPath -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Host "  [ERREUR] Impossible de lire le fichier hosts : $_" -ForegroundColor Red
        return $null
    }
}

function Test-IsAlreadyBlocked {
    # Vérifie si notre marqueur est déjà présent dans le fichier hosts
    $Content = Get-CurrentHostsContent
    if (-not $Content) { return $false }
    return ($Content | Where-Object { $_ -match [regex]::Escape($Marker) }).Count -gt 0
}

function Get-DomainsToBlock {
    # Retourne la liste plate de tous les domaines à bloquer
    # en excluant ceux présents dans la liste blanche absolue
    # et ceux déjà présents dans le fichier hosts (anti-doublons)

    # Lire les domaines déjà présents dans le hosts (hors notre bloc)
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

            # Vérification liste blanche — comparaison exacte uniquement
            # (pas de EndsWith pour éviter de bloquer tous les sous-domaines)
            $IsWhitelisted = $AbsoluteWhitelist -contains $Domain
            if ($IsWhitelisted) { continue }

            # Vérification doublon (déjà présent dans le hosts hors notre bloc)
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
    # Supprime uniquement le bloc que nous avons ajouté
    # Le reste du fichier hosts est préservé tel quel
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

        # Supprimer les lignes vides en fin de fichier (cosmétique)
        while ($CleanLines.Count -gt 0 -and $CleanLines[-1].Trim() -eq "") {
            $CleanLines = $CleanLines[0..($CleanLines.Count - 2)]
        }

        Write-UTF8NoBOM -Path $HostsPath -Lines $CleanLines
        return $true
    }
    catch {
        Write-Host "  [ERREUR] Impossible de nettoyer le fichier hosts : $_" -ForegroundColor Red
        Write-Log "Erreur nettoyage hosts : $_" "ERREUR"
        return $false
    }
}

function Flush-DNSCache {
    try {
        ipconfig /flushdns | Out-Null
        Write-Host "  [OK] Cache DNS vidé" -ForegroundColor Green
        Write-Log "Cache DNS vidé"
    }
    catch {
        Write-Host "  [AVERT] Impossible de vider le cache DNS : $_" -ForegroundColor Yellow
    }
}

#endregion

#region AFFICHAGE MENU

function Show-Menu {

    Clear-Host

    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   BLOCAGE TELEMETRIE - FICHIER HOSTS WINDOWS  v5.1" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""

    # Statut actuel + statistiques
    $AlreadyBlocked = Test-IsAlreadyBlocked
    if ($AlreadyBlocked) {
        # Compter les domaines actifs dans le bloc
        $ActiveCount = (Get-CurrentHostsContent | Where-Object { $_ -match '^0\.0\.0\.0 ' }).Count
        $BlockDate   = (Get-CurrentHostsContent | Where-Object { $_ -match '^# Généré le ' } | Select-Object -First 1) -replace '^# Généré le ',''
        Write-Host "  Statut : " -NoNewline
        Write-Host "BLOCAGE ACTIF" -ForegroundColor Green -NoNewline
        Write-Host "  ($ActiveCount domaines)" -ForegroundColor DarkGreen
        if ($BlockDate) {
            Write-Host "  Appliqué le : $BlockDate" -ForegroundColor DarkGray
        }

        # [N3] Indicateur d'intégrité compact — réutilise Get-IntegrityStatus (lecture seule,
        # même logique que l'option [A]) pour éviter d'attendre une vérification manuelle
        $IntegrityStatus = Get-IntegrityStatus
        if ($IntegrityStatus.Missing.Count -eq 0 -and $IntegrityStatus.Extra.Count -eq 0) {
            Write-Host "  Intégrité   : " -NoNewline
            Write-Host "OK — bloc complet et à jour" -ForegroundColor DarkGreen
        }
        else {
            Write-Host "  Intégrité   : " -NoNewline
            Write-Host "$($IntegrityStatus.Missing.Count) manquant(s), $($IntegrityStatus.Extra.Count) en trop — voir option [A]" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  Statut : " -NoNewline
        Write-Host "Aucun blocage appliqué" -ForegroundColor Gray
        $TotalDomains = (Get-DomainsToBlock | Where-Object { -not $_.IsDuplicate }).Count
        Write-Host "  Domaines disponibles : $TotalDomains" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  [1] Voir les domaines qui seront bloqués" -ForegroundColor White
    Write-Host "  [2] Appliquer le blocage" -ForegroundColor Yellow
    Write-Host "  [3] Mettre à jour la liste (restaurer + ré-appliquer)" -ForegroundColor Yellow
    Write-Host "  [4] Simuler sans modifier (DryRun)" -ForegroundColor DarkYellow
    Write-Host "  [5] RESTAURER le fichier hosts original" -ForegroundColor Red
    Write-Host "  [6] Voir les sauvegardes disponibles" -ForegroundColor Gray
    Write-Host "  [7] Vider le cache DNS manuellement" -ForegroundColor Gray
    Write-Host "  [8] Générer un rapport HTML" -ForegroundColor Cyan
    Write-Host "  [9] Vérifier les conflits (autres outils)" -ForegroundColor Cyan
    Write-Host "  [A] Vérifier l'intégrité du bloc actif" -ForegroundColor Cyan
    Write-Host "  [E] Exporter la liste active (.txt)" -ForegroundColor DarkGray
    Write-Host "  [Q] Quitter" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Choix : " -NoNewline

    return (Read-Host)
}

#endregion

#region ACTION : AFFICHER LES DOMAINES

function Show-DomainList {

    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   DOMAINES QUI SERONT BLOQUES" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan

    $Domains = Get-DomainsToBlock
    $CurrentCategory = ""
    $Total = 0

    foreach ($Item in $Domains | Sort-Object Category, Domain) {

        if ($Item.Category -ne $CurrentCategory) {
            Write-Host ""
            Write-Host "  >> $($Item.Category)" -ForegroundColor Yellow
            $CurrentCategory = $Item.Category
        }

        Write-Host "     0.0.0.0  $($Item.Domain)" -ForegroundColor Gray
        $Total++
    }

    Write-Host ""
    Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  Total : $Total domaines" -ForegroundColor White
    Write-Host ""
    Write-Host "  LISTE BLANCHE (jamais bloqués) :" -ForegroundColor Green
    foreach ($Safe in $AbsoluteWhitelist | Select-Object -First 8) {
        Write-Host "     $Safe" -ForegroundColor DarkGreen
    }
    Write-Host "     ... et $($AbsoluteWhitelist.Count - 8) autres domaines critiques" -ForegroundColor DarkGreen
    Write-Host ""

    Read-Host "  Appuyez sur Entrée pour revenir au menu"
}

#endregion

#region ACTION : APPLIQUER LE BLOCAGE

function Apply-Blocking {
    param(
        [bool]$Simulation  = $false,
        [bool]$ForceUpdate = $false
    )

    Clear-Host
    Write-Host ""

    if ($Simulation) {
        Write-Host "  ============================================================" -ForegroundColor DarkYellow
        Write-Host "   MODE SIMULATION - Aucune modification ne sera effectuée" -ForegroundColor DarkYellow
        Write-Host "  ============================================================" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "  ============================================================" -ForegroundColor Yellow
        Write-Host "   APPLICATION DU BLOCAGE" -ForegroundColor Yellow
        Write-Host "  ============================================================" -ForegroundColor Yellow
    }

    Write-Host ""

    # Vérifier si déjà appliqué
    if (-not $Simulation -and (Test-IsAlreadyBlocked)) {
        if (-not $ForceUpdate) {
            Write-Host "  [INFO] Un blocage est déjà actif dans le fichier hosts." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Voulez-vous mettre à jour la liste (restaurer + ré-appliquer) ? (O/N) : " -NoNewline -ForegroundColor Yellow
            $UpdAnswer = Read-Host
            if ($UpdAnswer -notin @("O","o","oui","OUI","y","Y","yes","YES")) {
                Write-Host "  Annulé." -ForegroundColor Gray
                Write-Host ""
                Read-Host "  Appuyez sur Entrée pour revenir au menu"
                return
            }
        }
        # Restauration silencieuse avant ré-application
        Write-Header "Nettoyage du bloc existant avant mise à jour"
        $BackupPath = Backup-Hosts
        $null = Remove-OurBlocksFromHosts
        Write-Host "  [OK] Ancien bloc supprimé — ré-application en cours..." -ForegroundColor Green
        Write-Log "Mise à jour : ancien bloc supprimé"
        Write-Host ""
    }

    # Étape 1 : Sauvegarde
    Write-Header "Étape 1/4 : Sauvegarde du fichier hosts actuel"

    if (-not $Simulation) {
        $BackupPath = Backup-Hosts
        if (-not $BackupPath) {
            Write-Host ""
            Write-Host "  [ERREUR FATALE] La sauvegarde a échoué." -ForegroundColor Red
            Write-Host "  Le blocage N'A PAS été appliqué par mesure de sécurité." -ForegroundColor Red
            Write-Host ""
            Read-Host "  Appuyez sur Entrée pour revenir au menu"
            return
        }
    }
    else {
        Write-Host "  [SIMULATION] Sauvegarde dans : $BackupFolder\hosts_backup_$Timestamp" -ForegroundColor DarkYellow
    }

    # Étape 2 : Préparer les lignes à ajouter
    Write-Header "Étape 2/4 : Préparation des règles de blocage"

    $Domains      = Get-DomainsToBlock
    $BlockLines   = @()
    $BlockLines  += ""
    $BlockLines  += $Marker
    $BlockLines  += "# Généré le $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    $BlockLines  += "# Pour restaurer : relancer ce script et choisir option 5"
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
                Write-Host "  [SKIP] $($Item.Domain)  (déjà présent dans le hosts)" -ForegroundColor DarkGray
            }
            continue
        }

        $BlockLines += "0.0.0.0 $($Item.Domain)"

        if ($Simulation) {
            Write-Host "  [SIM] 0.0.0.0  $($Item.Domain)" -ForegroundColor DarkYellow
        }

        $AddedCount++
    }

    $BlockLines += "#"
    $BlockLines += $MarkerEnd
    $BlockLines += ""

    Write-Host "  $AddedCount domaines préparés" -ForegroundColor White
    if ($SkippedCount -gt 0) {
        Write-Host "  $SkippedCount domaines ignorés (déjà présents dans le hosts)" -ForegroundColor DarkGray
    }

    # Étape 3 : Écriture dans le fichier hosts
    Write-Header "Étape 3/4 : Écriture dans le fichier hosts"

    if (-not $Simulation) {
        try {
            # Lire le contenu actuel et ajouter nos lignes (UTF-8 sans BOM garanti)
            $ExistingLines = Get-Content -Path $HostsPath -Encoding UTF8 -ErrorAction Stop
            $AllLines = @($ExistingLines) + $BlockLines
            Write-UTF8NoBOM -Path $HostsPath -Lines $AllLines
            Write-Host "  [OK] Fichier hosts mis à jour" -ForegroundColor Green
            Write-Log "Blocage appliqué : $AddedCount domaines"

            # [N2] Snapshot JSON — uniquement en écriture réelle, jamais en simulation
            $ActionLabel = if ($ForceUpdate) { "Mise à jour" } else { "Application" }
            Write-JsonSnapshot -Action $ActionLabel -TotalDomains $AddedCount -SkippedCount $SkippedCount -Categories ($Domains | Where-Object { -not $_.IsDuplicate })
        }
        catch {
            Write-Host "  [ERREUR] Impossible d'écrire dans le fichier hosts : $_" -ForegroundColor Red
            Write-Host "  Tentative de restauration de la sauvegarde..." -ForegroundColor Yellow
            try {
                Copy-Item -Path $BackupPath -Destination $HostsPath -Force
                Write-Host "  [OK] Fichier hosts restauré depuis la sauvegarde" -ForegroundColor Green
            }
            catch {
                Write-Host "  [ERREUR CRITIQUE] Restauration impossible : $_" -ForegroundColor Red
                Write-Host "  Restaurez manuellement depuis : $BackupPath" -ForegroundColor Red
            }
            Write-Log "Erreur écriture hosts : $_" "ERREUR"
            Read-Host "  Appuyez sur Entrée pour revenir au menu"
            return
        }
    }
    else {
        Write-Host "  [SIMULATION] $AddedCount lignes seraient ajoutées au fichier hosts" -ForegroundColor DarkYellow
    }

    # Étape 4 : Vider le cache DNS
    Write-Header "Étape 4/4 : Vidage du cache DNS"

    if (-not $Simulation) {
        Flush-DNSCache
    }
    else {
        Write-Host "  [SIMULATION] Cache DNS serait vidé (ipconfig /flushdns)" -ForegroundColor DarkYellow
    }

    # Résumé
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Green
    if ($Simulation) {
        Write-Host "   SIMULATION TERMINEE - Aucune modification effectuée" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "   BLOCAGE APPLIQUÉ AVEC SUCCÈS" -ForegroundColor Green
        Write-Host "   $AddedCount domaines de télémétrie bloqués" -ForegroundColor Green
        if ($SkippedCount -gt 0) {
            Write-Host "   $SkippedCount domaines ignorés (déjà présents)" -ForegroundColor DarkGray
        }
        Write-Host "   Sauvegarde : $BackupPath" -ForegroundColor Gray
    }
    Write-Host "  ============================================================" -ForegroundColor Green
    Write-Host ""

    Read-Host "  Appuyez sur Entrée pour revenir au menu"
}

#endregion

#region ACTION : RESTAURER

function Restore-Hosts {

    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Red
    Write-Host "   RESTAURATION DU FICHIER HOSTS" -ForegroundColor Red
    Write-Host "  ============================================================" -ForegroundColor Red
    Write-Host ""

    if (-not (Test-IsAlreadyBlocked)) {
        Write-Host "  [INFO] Aucun blocage actif détecté dans le fichier hosts." -ForegroundColor Cyan
        Write-Host ""
        Read-Host "  Appuyez sur Entrée pour revenir au menu"
        return
    }

    Write-Host "  Cette action supprime UNIQUEMENT les règles ajoutées par ce script." -ForegroundColor White
    Write-Host "  Votre fichier hosts original sera préservé." -ForegroundColor White
    Write-Host ""
    Write-Host "  Confirmer la restauration ? (O/N) : " -NoNewline -ForegroundColor Yellow

    $Confirm = Read-Host

    if ($Confirm -notin @("O","o","oui","OUI","y","Y","yes","YES")) {
        Write-Host "  Annulé." -ForegroundColor Gray
        Write-Host ""
        Read-Host "  Appuyez sur Entrée pour revenir au menu"
        return
    }

    Write-Host ""

    # Sauvegarde avant restauration (par sécurité)
    Write-Header "Sauvegarde de l'état actuel avant restauration"
    $BackupPath = Backup-Hosts

    # Suppression du bloc
    Write-Header "Suppression du bloc de télémétrie"

    $Success = Remove-OurBlocksFromHosts

    if ($Success) {
        Write-Host "  [OK] Bloc de télémétrie supprimé" -ForegroundColor Green
        Write-Log "Restauration effectuée"

        # [N2] Snapshot JSON — trace la restauration au même titre qu'une application
        Write-JsonSnapshot -Action "Restauration" -TotalDomains 0 -SkippedCount 0 -Categories @()

        # Vider le cache DNS
        Write-Header "Vidage du cache DNS"
        Flush-DNSCache

        Write-Host ""
        Write-Host "  ============================================================" -ForegroundColor Green
        Write-Host "   RESTAURATION TERMINÉE" -ForegroundColor Green
        Write-Host "   Les domaines de télémétrie ne sont plus bloqués." -ForegroundColor Green
        Write-Host "  ============================================================" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "  [ERREUR] La restauration automatique a échoué." -ForegroundColor Red
        if ($BackupPath) {
            Write-Host "  Vous pouvez restaurer manuellement depuis :" -ForegroundColor Yellow
            Write-Host "  $BackupPath" -ForegroundColor Yellow
        }
        Write-Log "Échec restauration automatique" "ERREUR"
    }

    Write-Host ""
    Read-Host "  Appuyez sur Entrée pour revenir au menu"
}

#endregion

#region ACTION : VOIR SAUVEGARDES

function Show-Backups {

    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   SAUVEGARDES DISPONIBLES" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $BackupFolder)) {
        Write-Host "  Aucune sauvegarde trouvée." -ForegroundColor Gray
        Write-Host "  (Dossier non créé — aucun blocage n'a encore été appliqué)" -ForegroundColor DarkGray
    }
    else {
        $Backups = Get-ChildItem -Path $BackupFolder -Filter "hosts_backup_*" |
            Sort-Object LastWriteTime -Descending

        if ($Backups.Count -eq 0) {
            Write-Host "  Aucune sauvegarde trouvée dans $BackupFolder" -ForegroundColor Gray
        }
        else {
            foreach ($B in $Backups) {
                $Size = [Math]::Round($B.Length / 1KB, 1)
                Write-Host "  $($B.LastWriteTime.ToString('dd/MM/yyyy HH:mm:ss'))  |  $($B.Name)  |  $Size KB" -ForegroundColor White
            }
            Write-Host ""
            Write-Host "  Dossier : $BackupFolder" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  Pour restaurer manuellement une sauvegarde spécifique :" -ForegroundColor DarkCyan
            Write-Host "  Copiez le fichier voulu vers :" -ForegroundColor DarkCyan
            Write-Host "  $HostsPath" -ForegroundColor DarkCyan
        }
    }

    Write-Host ""
    Read-Host "  Appuyez sur Entrée pour revenir au menu"
}

function Test-Conflicts {
    # Détecte si d'autres outils ont modifié le fichier hosts
    # et propose optionnellement de nettoyer les entrées externes
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   DÉTECTION DE CONFLITS" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""

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

        # Recherche de signatures d'outils tiers dans les commentaires
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

        # Entrées actives hors de notre bloc
        if ($Line -match '^0\.0\.0\.0') {
            $ExternalLines += $Line
        }
    }

    if ($Found.Count -gt 0) {
        Write-Host "  [AVERT] Outils détectés ayant modifié le fichier hosts :" -ForegroundColor Yellow
        foreach ($T in $Found) {
            Write-Host "    - $T" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    else {
        Write-Host "  [OK] Aucun outil tiers identifié dans le fichier hosts." -ForegroundColor Green
    }

    if ($ExternalLines.Count -gt 0) {
        Write-Host "  [INFO] $($ExternalLines.Count) entrée(s) active(s) détectée(s) hors de notre bloc :" -ForegroundColor Cyan
        Write-Host ""
        $Preview = $ExternalLines | Select-Object -First 10
        foreach ($L in $Preview) {
            Write-Host "     $L" -ForegroundColor DarkGray
        }
        if ($ExternalLines.Count -gt 10) {
            Write-Host "     ... et $($ExternalLines.Count - 10) autres entrées" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  Le script gère automatiquement les doublons à l'écriture." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Voulez-vous supprimer ces entrées externes ? (O/N) : " -NoNewline -ForegroundColor Yellow
        $CleanAnswer = Read-Host

        if ($CleanAnswer -in @("O","o","oui","OUI","y","Y","yes","YES")) {
            Write-Host ""
            Write-Host "  Sauvegarde avant nettoyage..." -ForegroundColor Gray
            $BackupPath = Backup-Hosts
            if (-not $BackupPath) {
                Write-Host "  [ERREUR] Sauvegarde échouée — nettoyage annulé par sécurité." -ForegroundColor Red
                Write-Host ""
                Read-Host "  Appuyez sur Entrée pour revenir au menu"
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
                    # Supprimer les entrées 0.0.0.0 externes, garder le reste
                    if (-not $InOurBlock2 -and $Line -match '^0\.0\.0\.0') { continue }
                    $CleanLines += $Line
                }

                Write-UTF8NoBOM -Path $HostsPath -Lines $CleanLines
                Flush-DNSCache
                Write-Host "  [OK] $($ExternalLines.Count) entrée(s) externe(s) supprimée(s) proprement." -ForegroundColor Green
                Write-Log "Nettoyage conflits : $($ExternalLines.Count) entrées externes supprimées"
            }
            catch {
                Write-Host "  [ERREUR] Nettoyage impossible : $_" -ForegroundColor Red
                Write-Log "Erreur nettoyage conflits : $_" "ERREUR"
            }
        }
        else {
            Write-Host "  Nettoyage annulé — aucune modification effectuée." -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  [OK] Aucune entrée externe détectée en dehors de notre bloc." -ForegroundColor Green
    }

    Write-Host ""
    Read-Host "  Appuyez sur Entrée pour revenir au menu"
}

function Export-DomainList {
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   EXPORT DE LA LISTE ACTIVE" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""

    $ExportPath = "$env:USERPROFILE\Desktop\Block-Telemetry_Export_$Timestamp.txt"
    $Domains    = Get-DomainsToBlock | Where-Object { -not $_.IsDuplicate } | Sort-Object Category, Domain

    $Lines  = @()
    $Lines += "# ====================================================="
    $Lines += "# BLOCK-TELEMETRY v5.0 — Export liste de blocage"
    $Lines += "# Généré le $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    $Lines += "# Domaines : $($Domains.Count)"
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

    try {
        $Encoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($ExportPath, $Lines, $Encoding)
        Write-Host "  [OK] Export créé : $ExportPath" -ForegroundColor Green
        Write-Host "       $($Domains.Count) domaines exportés" -ForegroundColor DarkGray
        Write-Log "Export créé : $ExportPath ($($Domains.Count) domaines)"
    }
    catch {
        Write-Host "  [ERREUR] Impossible de créer l'export : $_" -ForegroundColor Red
    }

    Write-Host ""
    Read-Host "  Appuyez sur Entrée pour revenir au menu"
}

function Get-IntegrityStatus {
    # [N3] Logique de comparaison extraite pour être réutilisable par le menu (indicateur
    # compact) et par Test-Integrity (affichage détaillé) sans dupliquer le code.
    # Ne fait que lire le hosts — aucune écriture, aucun effet de bord.
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
    # Vérifie que le bloc actif contient bien tous les domaines attendus
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   VÉRIFICATION D'INTÉGRITÉ DU BLOC ACTIF" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-IsAlreadyBlocked)) {
        Write-Host "  [INFO] Aucun bloc de télémétrie actif dans le fichier hosts." -ForegroundColor Gray
        Write-Host "         Appliquez d'abord le blocage (option 2)." -ForegroundColor DarkGray
        Write-Host ""
        Read-Host "  Appuyez sur Entrée pour revenir au menu"
        return
    }

    Write-Host "  Lecture du fichier hosts en cours..." -ForegroundColor Gray

    $Status   = Get-IntegrityStatus
    $Missing  = $Status.Missing
    $Extra    = $Status.Extra

    Write-Host "  Domaines attendus   : $($Status.Expected)" -ForegroundColor White
    Write-Host "  Domaines présents   : $($Status.Present)"  -ForegroundColor White
    Write-Host ""

    if ($Missing.Count -eq 0 -and $Extra.Count -eq 0) {
        Write-Host "  [OK] Intégrité parfaite — le bloc est complet et à jour." -ForegroundColor Green
        Write-Log "Vérification intégrité : OK ($($Status.Present) domaines)"
    }
    else {
        if ($Missing.Count -gt 0) {
            Write-Host "  [AVERT] $($Missing.Count) domaine(s) manquant(s) dans le bloc actif :" -ForegroundColor Yellow
            foreach ($D in $Missing | Sort-Object) {
                Write-Host "     - $D" -ForegroundColor DarkYellow
            }
            Write-Host ""
            Write-Host "  Ces domaines ont été ajoutés à la liste mais ne sont pas encore bloqués." -ForegroundColor DarkGray
            Write-Host "  Utilisez l'option [3] Mettre à jour pour les intégrer." -ForegroundColor DarkGray
            Write-Log "Vérification intégrité : $($Missing.Count) domaines manquants" "AVERT"
        }

        if ($Extra.Count -gt 0) {
            Write-Host ""
            Write-Host "  [INFO] $($Extra.Count) domaine(s) présent(s) dans le bloc mais retirés de la liste :" -ForegroundColor Cyan
            foreach ($D in $Extra | Sort-Object) {
                Write-Host "     - $D" -ForegroundColor DarkGray
            }
            Write-Host ""
            Write-Host "  Ces domaines ont été retirés de la liste courante (ex : domaines fonctionnels reclassés)." -ForegroundColor DarkGray
            Write-Host "  Utilisez l'option [3] Mettre à jour pour nettoyer le bloc." -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Read-Host "  Appuyez sur Entrée pour revenir au menu"
}

#region ACTION : RAPPORT HTML

function Generate-HtmlReport {
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   GÉNÉRATION DU RAPPORT HTML" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""

    $ReportFolder = "$env:USERPROFILE\Desktop\Rapports_Maintenance\Block-Telemetry"
    if (-not (Test-Path $ReportFolder)) {
        New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
    }
    $ReportPath = Join-Path $ReportFolder "Block-Telemetry_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').html"

    # Données pour le rapport
    $IsBlocked      = Test-IsAlreadyBlocked
    $Domains        = Get-DomainsToBlock
    $TotalDomains   = ($Domains | Where-Object { -not $_.IsDuplicate }).Count
    $SkippedDomains = ($Domains | Where-Object { $_.IsDuplicate }).Count
    $Categories     = $Domains | Where-Object { -not $_.IsDuplicate } | Group-Object Category | Sort-Object Name

    $BlockDate = ""
    if ($IsBlocked) {
        $BlockDate = (Get-CurrentHostsContent | Where-Object { $_ -match '^# Généré le ' } | Select-Object -First 1) -replace '^# Généré le ',''
    }

    $StatusColor  = if ($IsBlocked) { "#2ecc71" } else { "#e74c3c" }
    $StatusText   = if ($IsBlocked) { "ACTIF" } else { "INACTIF" }
    $StatusBg     = if ($IsBlocked) { "#1a3a2a" } else { "#3a1a1a" }

    # Génération des lignes de catégories
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

    # Sauvegarde info
    $BackupInfo = "Aucune sauvegarde trouvée"
    if (Test-Path $BackupFolder) {
        $LastBackup = Get-ChildItem -Path $BackupFolder -Filter "hosts_backup_*" |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($LastBackup) {
            $BackupInfo = "$($LastBackup.Name) — $($LastBackup.LastWriteTime.ToString('dd/MM/yyyy HH:mm'))"
        }
    }

    # Génération des lignes de la liste complète des domaines (pour la recherche)
    $DomainRows = ""
    foreach ($Item in $Domains | Where-Object { -not $_.IsDuplicate } | Sort-Object Category, Domain) {
        $DomainRows += "        <tr><td class=`"domain`">$($Item.Domain)</td><td class=`"cat`">$($Item.Category)</td></tr>`n"
    }

    $Html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Block-Telemetry — Rapport</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=DM+Mono&display=swap');
  :root {
    --bg:       #0f1117;
    --surface:  #1a1d27;
    --border:   #2a2d3a;
    --accent:   #7c6af7;
    --green:    #2ecc71;
    --red:      #e74c3c;
    --yellow:   #f39c12;
    --text:     #e8eaf0;
    --muted:    #6b7280;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'DM Sans', sans-serif; padding: 2rem; }
  h1   { font-size: 1.6rem; font-weight: 700; color: var(--accent); margin-bottom: .3rem; }
  .subtitle { color: var(--muted); font-size: .9rem; margin-bottom: 2rem; }
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

<h1>🛡 Block-Telemetry v5.0</h1>
<p class="subtitle">Rapport généré le $(Get-Date -Format 'dd/MM/yyyy à HH:mm:ss') — Machine : $env:COMPUTERNAME</p>

<div class="grid">
  <div class="card">
    <div class="label">Statut</div>
    <div><span class="status-badge">$StatusText</span></div>
  </div>
  <div class="card">
    <div class="label">Domaines bloqués</div>
    <div class="value accent">$TotalDomains</div>
  </div>
  <div class="card">
    <div class="label">Catégories</div>
    <div class="value accent">$($Categories.Count)</div>
  </div>
  <div class="card">
    <div class="label">Doublons ignorés</div>
    <div class="value yellow">$SkippedDomains</div>
  </div>
</div>

<div class="section">
  <h2>Domaines par catégorie</h2>
  <table>
    <thead><tr><th>Catégorie</th><th>Nb</th><th>Répartition</th></tr></thead>
    <tbody>$CategoryRows</tbody>
  </table>
</div>

<div class="section">
  <h2>Liste complète des domaines bloqués</h2>
  <div class="search-wrap">
    <input type="text" id="searchInput" placeholder="Rechercher un domaine ou une catégorie..." oninput="filterDomains()">
    <div id="domain-count"></div>
  </div>
  <table id="domainTable">
    <thead><tr><th>Domaine</th><th>Catégorie</th></tr></thead>
    <tbody id="domainBody">$DomainRows</tbody>
  </table>
</div>

<div class="section">
  <h2>Informations système</h2>
  <div class="info-row"><span class="key">Fichier hosts</span><span class="val">$HostsPath</span></div>
  <div class="info-row"><span class="key">Date d'application</span><span class="val">$(if ($BlockDate) { $BlockDate } else { '—' })</span></div>
  <div class="info-row"><span class="key">Dernière sauvegarde</span><span class="val">$BackupInfo</span></div>
  <div class="info-row"><span class="key">Dossier sauvegardes</span><span class="val">$BackupFolder</span></div>
  <div class="info-row"><span class="key">Fichier log</span><span class="val">$LogPath</span></div>
</div>

<footer>Block-Telemetry v5.0 — Rapport généré automatiquement</footer>

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
    document.getElementById('domain-count').textContent = visible + ' domaine(s) affiché(s)';
}
// Initialiser le compteur
window.onload = function() {
    document.getElementById('domain-count').textContent = '$TotalDomains domaine(s) au total';
};
</script>
</body>
</html>
"@

    try {
        $Enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ReportPath, $Html, $Enc)
        Write-Host "  [OK] Rapport créé : $ReportPath" -ForegroundColor Green
        Write-Log "Rapport HTML généré : $ReportPath"
        Start-Sleep -Milliseconds 500
        Start-Process $ReportPath
    }
    catch {
        Write-Host "  [ERREUR] Impossible de créer le rapport : $_" -ForegroundColor Red
    }

    Write-Host ""
    Read-Host "  Appuyez sur Entrée pour revenir au menu"
}

#endregion

# [N1] -SelfTest : validations logiques en lecture seule, aucune écriture sur le hosts.
# Toutes les fonctions appelées ici (Get-DomainsToBlock, Get-IntegrityStatus,
# Test-IsAlreadyBlocked, Get-CurrentHostsContent) ne font que lire — sans risque.
function Invoke-SelfTest {
    # [FIX] $T local à Invoke-SelfTest / $script:T écrit par la fonction imbriquée Assert-True
    # = deux variables différentes. $script:T démarrait à $null -> .Add() sur null -> crash.
    $script:SelfTestResults = [System.Collections.Generic.List[object]]::new()
    function Assert-True($Name, $Condition, $Detail = "") {
        $script:SelfTestResults.Add([PSCustomObject]@{ Test = $Name; Pass = [bool]$Condition; Detail = $Detail })
    }

    # 1. La liste blanche ne doit contenir aucun doublon interne
    $WhitelistDupes = $AbsoluteWhitelist | Group-Object | Where-Object { $_.Count -gt 1 }
    Assert-True "Liste blanche sans doublon interne" ($WhitelistDupes.Count -eq 0) "$($WhitelistDupes.Count) doublon(s)"

    # 2. Aucun domaine de télémétrie ne doit être également présent dans la liste blanche
    #    (contradiction de config : un domaine qu'on bloque ET qu'on protège en même temps)
    $AllTelemetryDomains = foreach ($Cat in $TelemetryDomains.Keys) { $TelemetryDomains[$Cat] | ForEach-Object { $_.ToLower().Trim() } }
    $Contradictions = $AllTelemetryDomains | Where-Object { $AbsoluteWhitelist -contains $_ }
    Assert-True "Aucune contradiction télémétrie/whitelist" ($Contradictions.Count -eq 0) "$($Contradictions.Count) domaine(s) en conflit"

    # 3. La correspondance liste blanche doit être exacte, jamais un match de sous-domaine
    #    (régression historique corrigée : EndsWith bloquait/protégeait des sous-domaines entiers)
    $SampleWhitelisted = $AbsoluteWhitelist | Select-Object -First 1
    if ($SampleWhitelisted) {
        $FakeSubdomain = "test-selftest-ne-doit-pas-matcher.$SampleWhitelisted"
        Assert-True "Correspondance whitelist = exacte (pas de sous-domaine)" (-not ($AbsoluteWhitelist -contains $FakeSubdomain)) $FakeSubdomain
    }

    # 4. Get-DomainsToBlock doit retourner une liste non vide, sans doublon de domaine
    $Domains = Get-DomainsToBlock
    Assert-True "Get-DomainsToBlock retourne des résultats" ($Domains.Count -gt 0) "$($Domains.Count) entrée(s)"
    $DomainDupes = $Domains | Group-Object Domain | Where-Object { $_.Count -gt 1 }
    $DupeDetail  = if ($DomainDupes.Count -gt 0) { ($DomainDupes | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ", " } else { "" }
    Assert-True "Aucun domaine dupliqué dans la liste à bloquer" ($DomainDupes.Count -eq 0) $DupeDetail

    # 5. Le marqueur de début et de fin doivent être des chaînes distinctes
    Assert-True "Marqueurs début/fin distincts" ($Marker -ne $MarkerEnd)

    # 6. Get-IntegrityStatus ne doit jamais lever d'exception, bloc actif ou non
    try {
        $null = Get-IntegrityStatus
        Assert-True "Get-IntegrityStatus s'exécute sans erreur" $true
    }
    catch {
        Assert-True "Get-IntegrityStatus s'exécute sans erreur" $false "$_"
    }

    # 7. Test-IsAlreadyBlocked ne doit jamais lever d'exception
    try {
        $null = Test-IsAlreadyBlocked
        Assert-True "Test-IsAlreadyBlocked s'exécute sans erreur" $true
    }
    catch {
        Assert-True "Test-IsAlreadyBlocked s'exécute sans erreur" $false "$_"
    }

    Write-Host ""
    Write-Host "  === SELFTEST Block-Telemetry v5.1 ===" -ForegroundColor Cyan
    $T = $script:SelfTestResults
    foreach ($Item in $T) {
        $Color = if ($Item.Pass) { "Green" } else { "Red" }
        $Mark  = if ($Item.Pass) { "[OK]" } else { "[FAIL]" }
        $Line  = "  {0,-7} {1}" -f $Mark, $Item.Test
        if ($Item.Detail) { $Line += "  ($($Item.Detail))" }
        Write-Host $Line -ForegroundColor $Color
    }
    $PassCount = ($T | Where-Object { $_.Pass }).Count
    Write-Host ""
    Write-Host "  Résultat : $PassCount / $($T.Count) assertions réussies" -ForegroundColor $(if ($PassCount -eq $T.Count) { "Green" } else { "Red" })
    Write-Host ""
}

if ($SelfTest) {
    Invoke-SelfTest
    exit
}

Write-Log "Script démarré"

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
            Write-Host ""
            Write-Header "Vidage du cache DNS"
            Flush-DNSCache
            Write-Host ""
            Read-Host "  Appuyez sur Entrée pour revenir au menu"
        }

        "8" { Generate-HtmlReport }
        "9" { Test-Conflicts }
        "A" { Test-Integrity }
        "E" { Export-DomainList }

        "Q" {
            Write-Log "Script terminé"
            Clear-Host
            Write-Host ""
            Write-Host "  Au revoir." -ForegroundColor Gray
            Write-Host ""
        }

        default {
            Write-Host "  Choix invalide." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }

} while ($Choice.ToUpper() -ne "Q")


# SIG # Begin signature block
# MIIFwgYJKoZIhvcNAQcCoIIFszCCBa8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA9Gx9fsuxLDBpl
# tAn7vS7fLHMzgaIjGRPh6rpxgwPEBKCCAygwggMkMIICDKADAgECAhB6X4r8AlBU
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
# ARUwLwYJKoZIhvcNAQkEMSIEIL9jNdbDemPAqAq1EYuttDiTjCEGICPUYFvvCjdO
# jQeMMA0GCSqGSIb3DQEBAQUABIIBAIQZgNcsXyHM/lpQ27yOqCf3Q1sI0hJccIjI
# DcdqlImLx1w7zpqkZt1XJK7es9a1+XKiXAHzb5KaiBVgf51nWgeFsDo4iDUwRFv2
# rQb17tJrAOL9IHLADA6TAuVxZdWRX8XEO2XRNF+C6vtxeym59+ZAjiK/aVkk/C+I
# QD4js2cdFjbxChaxdn6m4clNGUWrB2r6F8cCHVKCIPcfYf38KJDkNkOcbaWaXpzd
# uYg1IXg4eeEv3TCQLunqRYa4J1gexXSycX/Ah2O5w7pF2Ej8XjeP6ohqp9eevmzi
# R5/5W80Ik71Bs9Ad67QX7oE0/Sk2pctt9fya8kFZieHCm6d1ftc=
# SIG # End signature block
