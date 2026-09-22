# Block-Telemetry

🇬🇧 [English version](README.md)

Script PowerShell autonome qui bloque les domaines de télémétrie, d'analytics et de tracking tiers sur Windows via le fichier `hosts` — avec sauvegardes automatiques, liste blanche stricte, simulation avant application, restauration en un clic, et vérificateur d'intégrité pour que le blocage ne dérive jamais silencieusement.

> Rien n'est laissé au hasard. Une liste blanche stricte protège les domaines d'activation/licence/mise à jour par correspondance exacte (jamais une correspondance de sous-chaîne), chaque modification réelle est sauvegardée avant écriture, et le blocage actif peut être vérifié par rapport à la liste attendue à tout moment.

---

## Captures d'ecran

<table>
<tr>
<td><img src="https://raw.githubusercontent.com/NephVx2/Block-Telemetry/main/screenshots/01-menu-preview.png" width="420"></td>
<td><img src="https://raw.githubusercontent.com/NephVx2/Block-Telemetry/main/screenshots/05-html-preview.png" width="420"></td>
</tr>
</table>

Plus de captures (verification d'integrite, liste des sauvegardes, rapport HTML complet) dans le dossier [`screenshots/`](screenshots).

---

## Sommaire

- [Captures d'ecran](#captures-decran)
- [Presentation](#presentation)
- [Fonctionnement](#fonctionnement)
- [Ce qui est bloque](#ce-qui-est-bloque)
- [Ce qui n'est jamais bloque (liste blanche)](#ce-qui-nest-jamais-bloque-liste-blanche)
- [Garanties de securite](#garanties-de-securite)
- [Prerequis](#prerequis)
- [Premier lancement](#premier-lancement-pas-a-pas)
- [Reference du menu](#reference-du-menu)
- [Parametres en ligne de commande](#parametres-en-ligne-de-commande)
- [Fichiers ecrits par le script](#fichiers-ecrits-par-le-script)
- [Deploiement multi-machines](#deploiement-multi-machines)
- [Depannage](#depannage)

---

## Presentation

`Block-Telemetry.ps1` modifie **un seul fichier** : le fichier `hosts` de Windows (`C:\Windows\System32\drivers\etc\hosts`). Il ajoute un bloc clairement delimite d'entrees `0.0.0.0 <domaine>` pour des domaines connus de telemetrie, d'analytics et de tracking, de sorte que la resolution DNS de ces domaines echoue localement — aucun trafic ne les atteint.

Il ne touche **pas** au registre, n'arrete aucun service Windows, n'installe rien, et ne modifie aucun autre fichier que `hosts` (a l'exception de ses propres sauvegardes/logs/rapports sur le Bureau).

Le script fonctionne comme un **menu interactif** — il n'existe pas de commande "nettoyer en un coup" en ligne de commande pour l'action de blocage elle-meme (seul `-SelfTest` est un vrai parametre CLI). C'est voulu : modifier `hosts` est une modification durable (contrairement a un nettoyage ponctuel), donc le script garde un humain dans la boucle pour appliquer, mettre a jour et restaurer.

> **Note :** depuis la v5.3, l'interface du script (console, menu interactif, rapport HTML) est entierement en anglais. Ce README reste en francais, mais tout ce que vous verrez a l'ecran en lancant le script sera en anglais.

---

## Fonctionnement

1. Toutes les modifications vivent dans un seul bloc clairement delimite dans `hosts` :

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

   *(Depuis la v5.3, le bloc et tout le texte affiché par le script — console et rapport HTML — sont entièrement en anglais ; seule cette documentation reste en français.)*

   Tout ce qui se trouve en dehors de ces deux marqueurs reste totalement intact — vos propres entrees manuelles dans `hosts`, les entrees d'autres outils, tout.

2. Avant **toute** ecriture dans `hosts`, une sauvegarde horodatee est creee dans `Hosts_Backups` (voir [Fichiers ecrits par le script](#fichiers-ecrits-par-le-script)). Si la sauvegarde echoue, le script refuse de modifier `hosts`.

3. Les domaines deja presents n'importe ou dans votre fichier `hosts` (ajoutes manuellement ou par un autre outil) sont detectes et ignores plutot que dupliques.

4. La restauration supprime **uniquement** le contenu entre les deux marqueurs — votre fichier `hosts` original (et tout ce qui a ete ajoute depuis en dehors du bloc) est preserve exactement tel quel.

---

## Ce qui est bloque

15 categories, **228 domaines** au total :

<img src="https://raw.githubusercontent.com/NephVx2/Block-Telemetry/main/screenshots/08-categories-covered.png" width="600">

<details>
<summary><strong>Microsoft Telemetrie</strong> — 80 domaines</summary>

Donnees de diagnostic Windows (pipelines DiagTrack / vortex / watson), pipeline de telemetrie Office/ARIA, telemetrie **cloud uniquement** de Windows Defender (pas la protection locale), points de collecte publicitaires/suggestions MSN/Cortana/Bing, telemetrie Xbox/Game Bar, telemetrie OneDrive (pas la synchronisation), telemetrie Teams (pas la communication).

*Exclus volontairement :* `windowsupdate.com`, `update.microsoft.com`, `msftconnecttest.com` (necessaires aux mises a jour et a la detection de connectivite).
</details>

<details>
<summary><strong>Microsoft Copilot Telemetrie</strong> — 10 domaines</summary>

Donnees d'usage, requetes et contexte envoyes vers les serveurs Microsoft/Bing. Copilot lui-meme n'est pas bloque fonctionnellement sur les machines qui l'utilisent — seuls les points de collecte analytiques le sont.
</details>

<details>
<summary><strong>Microsoft Edge Telemetrie</strong> — 8 domaines</summary>

Utile meme si Edge est desinstalle — WebView2 et les residus d'Edge peuvent encore contacter ces points de collecte.
</details>

<details>
<summary><strong>Google Analytics / Tracking</strong> — 14 domaines</summary>

Google Analytics, Tag Manager, DoubleClick, Google Ad Services.

*Exclus volontairement :* `google.com`, `googleapis.com`, `gstatic.com` (necessaires a de nombreuses applications web et flux d'authentification).
</details>

<details>
<summary><strong>Adobe Analytics / Stats</strong> — 15 domaines</summary>

Adobe Analytics/Omniture, Adobe Audience Manager, Adobe Dynamic Tag Manager, Adobe Marketing/Advertising Cloud.

*Exclus volontairement :* `adobe.com`, `adobelogin.com`, `adobegenuine.com`, `lcs-cops.adobe.com` (activation, licences, points fonctionnels).
</details>

<details>
<summary><strong>Tracking tiers</strong> — 46 domaines</summary>

Aucun de ces domaines n'appartient a une application installee localement — ils ne sont charges que par des sites web ou des applications pour vous pister d'une session a l'autre : ScorecardResearch, Quantcast, Chartbeat, tracking Facebook/Meta, Amazon Ads, Twitter/X Ads, Hotjar, Mixpanel, Segment, Criteo, Taboola, Outbrain, Rubicon/Magnite, PubMatic, OpenX, Moat, Google AMP, LinkedIn Insight Tag.
</details>

<details>
<summary><strong>Rapports de crash</strong> — 8 domaines</summary>

Sentry.io, Bugsnag — envoient les stack traces et donnees systeme lors de plantages d'applications. Informatif mais intrusif ; a noter que cela peut reduire la qualite des correctifs des applications puisque les developpeurs perdent ces donnees de diagnostic.
</details>

<details>
<summary><strong>Spotify Telemetrie</strong> — 6 domaines</summary>

*Exclus volontairement :* `*.spotify.com` (streaming, connexion, API), `*.scdn.co` (CDN musique), `accounts.spotify.com`, `api.spotify.com`.
</details>

<details>
<summary><strong>Brave Analytics</strong> — 7 domaines</summary>
</details>

<details>
<summary><strong>Mozilla / Firefox Telemetrie</strong> — 9 domaines</summary>
</details>

<details>
<summary><strong>NVIDIA Telemetrie</strong> — 9 domaines</summary>
</details>

<details>
<summary><strong>AMD Telemetrie</strong> — 5 domaines</summary>
</details>

<details>
<summary><strong>Discord Telemetrie</strong> — 3 domaines</summary>
</details>

<details>
<summary><strong>Steam / Valve Telemetrie</strong> — 4 domaines</summary>
</details>

<details>
<summary><strong>GOG Galaxy Telemetrie</strong> — 4 domaines</summary>
</details>

Utiliser l'option de menu **[1]** a tout moment pour afficher la liste complete et actuelle groupee par categorie, ou **[E]** pour l'exporter vers un fichier texte.

---

## Ce qui n'est jamais bloque (liste blanche)

**71 domaines** sont codes en dur dans une liste blanche absolue, verifiee par **correspondance exacte uniquement** (jamais une correspondance de sous-domaine/sous-chaine — voir la section SelfTest) — meme si l'un d'eux se retrouvait par erreur dans la liste de telemetrie, il ne serait jamais ecrit dans `hosts` :

- Activation, licences, enregistrement Adobe (`activate.adobe.com`, `genuine.adobe.com`, `lcs-cops.adobe.com`...)
- Windows Update, activation, connexion Microsoft (`update.microsoft.com`, `login.microsoftonline.com`, `msftconnecttest.com`...)
- Synchronisation OneDrive, authentification Xbox Live, communication Teams
- NextDNS (service DNS critique)
- Streaming/authentification/API Spotify, CDN `scdn.co`
- Points de mise a jour et de navigation securisee Brave et Mozilla/Firefox
- Plateforme Steam et anti-cheat, mises a jour pilotes NVIDIA/AMD
- Discord, GOG Galaxy, mises a jour Visual Studio Code
- Epic Games (garde en liste blanche par precaution a cout nul, meme si non utilise activement, pour eviter un blocage accidentel si la liste est reutilisee ou etendue sur une autre machine plus tard)

---

## Garanties de securite

| # | Garantie |
|---|---|
| S1 | Sauvegarde automatique du fichier hosts avant toute modification |
| S2 | Liste blanche stricte — aucun domaine fonctionnel n'est jamais bloque |
| S3 | Rotation automatique des sauvegardes (conservation des 10 dernieres) |
| S4 | Mode simulation (DryRun depuis le menu) pour previsualiser sans rien toucher |
| S5 | Fonction de restauration complete integree (un seul choix au menu) |
| S6 | Marqueur unique dans le fichier hosts pour identifier exactement ce que ce script a ajoute |
| S7 | Aucune modification de registre, aucun service arrete, aucun pilote touche |
| S8 | Option "Mettre a jour" integree (restaure + re-applique en une etape) |
| S9 | Encodage UTF-8 **avec BOM** garanti — indispensable pour que PowerShell 5.1 detecte correctement l'UTF-8 (PowerShell 7 gere les deux cas, avec ou sans BOM) |
| S10 | Verification des doublons avant ecriture (domaines deja presents ignores) |
| S11 | Detection de conflits avec d'autres outils modifiant hosts (CTT WinUtil, StevenBlack hosts, HostsMan, Spybot Anti-Beacon, MVPS Hosts...) |
| S12 | Verification d'integrite du bloc actif (domaines attendus vs domaines reellement presents) |
| S13 | Nettoyage optionnel des entrees externes (hors du bloc propre a ce script) |

---

## Prerequis

- Windows 10 ou 11.
- PowerShell 5.1 (integre a Windows) ou PowerShell 7+.
- Droits administrateur. Le script s'auto-eleve si lance depuis une session non-admin (fenetre UAC) — sauf pour `-SelfTest`, qui fonctionne en lecture seule et **ne necessite pas** d'elevation.
- Acces en ecriture a `C:\Windows\System32\drivers\etc\hosts` (standard sur toute session admin).
- Si le script est signe numeriquement (recommande en environnement `-ExecutionPolicy AllSigned`/`RemoteSigned`) : le certificat de signature doit etre approuve sur la machine cible, sans quoi PowerShell refusera l'execution.

---

## Premier lancement (pas a pas)

1. Copier `Block-Telemetry.ps1` sur la machine cible.

2. Ouvrir un terminal PowerShell (pas besoin de le lancer en admin a la main — le script s'auto-eleve, sauf pour l'etape 4 ci-dessous).

   Puis se placer dans le dossier qui contient le script (adapter le chemin ; garder les guillemets s'il contient des espaces) :

   ```powershell
   cd "$HOME\Downloads"
   ```

3. **Debloquer le script** s'il a ete telecharge depuis Internet. Windows marque les fichiers telecharges, et la politique d'execution de PowerShell (`RemoteSigned`, par exemple) refuse de lancer un script marque. Depuis le dossier du script :

   ```powershell
   Unblock-File .\Block-Telemetry.ps1
   ```

   Si PowerShell indique plutot que l'execution de scripts est desactivee sur ce systeme (la politique par defaut de Windows est `Restricted`), autoriser d'abord les scripts pour le compte courant (la modification ne s'applique qu'a ce compte, pas a toute la machine) :

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

   Toujours bloque ? Voir le [guide pas a pas](https://github.com/NephVx2/Script-blocked-Look-at-this/blob/main/README_POWERSHELL_FRENCH.md).

4. Lancer d'abord le self-test logique — il est en lecture seule, ne necessite **pas** de droits admin, et ne touche pas a `hosts` :

   ```powershell
   .\Block-Telemetry.ps1 -SelfTest
   ```

   Execute 8 verifications : la liste blanche n'a pas de doublons internes, aucun domaine n'est a la fois bloque et en liste blanche, la correspondance de la liste blanche est exacte (pas par sous-domaine), `Get-DomainsToBlock` retourne une liste non vide, la liste de domaines se construit sans doublon, les deux marqueurs sont distincts, et `Get-IntegrityStatus`/`Test-IsAlreadyBlocked` s'executent sans lever d'exception. Le script quitte ensuite sans avoir touche a aucun fichier.

5. Lancer le script normalement (il demandera l'elevation) :

   ```powershell
   .\Block-Telemetry.ps1
   ```

6. Depuis le menu, previsualiser ce qui se passerait **sans rien changer** :

   ```
   [4] Simulate without modifying (DryRun)
   ```

   Affiche chaque domaine qui serait ajoute et chaque doublon qui serait ignore, exactement comme le ferait l'option [2] pour de vrai, mais n'ecrit rien.

7. Optionnel : revoir la liste complete des domaines et l'apercu de la liste blanche :

   ```
   [1] View the domains that will be blocked
   ```

8. Appliquer le blocage pour de vrai :

   ```
   [2] Apply blocking
   ```

   Cree une sauvegarde, ecrit le bloc dans `hosts`, vide le cache DNS, et ecrit un instantane JSON de l'action.

9. Confirmer que ca fonctionne : verifier l'option **[A]** (integrite) a tout moment ensuite, ou depuis un autre terminal :

   ```powershell
   Resolve-DnsName vortex-win.data.microsoft.com
   ```

   devrait echouer a resoudre (ou resoudre vers `0.0.0.0`) une fois le blocage actif et le cache DNS vide.

10. Pour tout annuler, utiliser l'option **[5]** — supprime uniquement le bloc de ce script, en sauvegardant l'etat actuel avant, et laisse le reste de votre fichier `hosts` intact.

---

## Reference du menu

| Option | Action |
|---|---|
| `[1]` | Afficher la liste complete des domaines qui seraient bloques, groupes par categorie, plus un apercu de la liste blanche |
| `[2]` | Appliquer le blocage pour de vrai (sauvegarde → ecriture → vidage DNS → instantane JSON). Si un blocage est deja actif, propose une mise a jour a la place |
| `[3]` | Mettre a jour la liste (restaure, puis re-applique) — a utiliser apres avoir recupere une version plus recente du script avec des domaines supplementaires |
| `[4]` | Simulation : simule l'option [2] sans rien ecrire |
| `[5]` | **Restaurer** — supprime uniquement le bloc de ce script, contenu original de hosts preserve |
| `[6]` | Lister les sauvegardes disponibles (horodatage, nom de fichier, taille) avec instructions de restauration manuelle |
| `[7]` | Vider le cache DNS manuellement (`ipconfig /flushdns`) |
| `[8]` | Generer un rapport HTML |
| `[9]` | Detecter les conflits avec d'autres outils modifiant hosts, et nettoyer optionnellement les entrees hors du bloc propre a ce script |
| `[A]` | Verifier l'integrite du bloc actif (domaines attendus vs domaines reellement presents — signale tout element manquant ou en trop) |
| `[E]` | Exporter la liste de domaines active vers un fichier `.txt` sur le Bureau |
| `[Q]` | Quitter |

L'en-tete du menu affiche toujours le statut actuel en un coup d'oeil : si un blocage est actif, combien de domaines, quand il a ete applique, et un indicateur d'integrite compact (reutilisant la meme verification que l'option `[A]`) pour que toute derive soit visible sans avoir a fouiller dans le menu.

---

## Parametres en ligne de commande

| Parametre | Description |
|---|---|
| `-SelfTest` | Execute les 8 verifications logiques en lecture seule decrites dans [Premier lancement](#premier-lancement-pas-a-pas) puis quitte. Aucun droit admin requis, aucun fichier touche. |

Toutes les autres actions (appliquer, mettre a jour, simuler, restaurer, rapports, exports) passent par le menu — il n'existe volontairement pas de parametres CLI equivalents, puisqu'il s'agit de modifications durables d'un fichier systeme plutot que de taches de maintenance ponctuelles.

---

## Fichiers ecrits par le script

| Fichier / dossier | Contenu |
|---|---|
| `%SystemRoot%\System32\drivers\etc\hosts` | Le seul fichier reellement modifie — entrees de blocage ajoutees dans le bloc marque |
| `%USERPROFILE%\Desktop\Hosts_Backups\hosts_backup_<horodatage>` | Copie complete de hosts prise avant chaque ecriture reelle (rotation automatique, 10 dernieres conservees) |
| `%USERPROFILE%\Desktop\Block-Telemetry_Log.txt` | Journal d'actions en texte brut (ajout uniquement) |
| `%USERPROFILE%\Desktop\Maintenance_Reports\Block-Telemetry\Block-Telemetry_<horodatage>.json` | Instantane JSON ecrit apres chaque action reelle (Apply / Update / Restore) — type d'action, nombre de domaines, repartition par categorie |
| `%USERPROFILE%\Desktop\Block-Telemetry_Export_<horodatage>.txt` | Cree uniquement via l'option de menu `[E]` — export texte de la liste de domaines active |
| Rapport HTML (option de menu `[8]`) | Rapport visuel, genere a la demande |

Rien n'est ecrit en dehors de ces emplacements. `-DryRun` (option de menu `[4]`) et `-SelfTest` n'ecrivent **aucun** fichier — pas de sauvegarde, pas de log, pas d'instantane JSON.

---

## Deploiement multi-machines

Le script est autonome (aucune dependance externe). Pour un deploiement multi-machines :

1. **Distribuer** le fichier `.ps1` vers chaque machine cible.

2. **Approuver le certificat de signature** si une politique d'execution stricte est en place (`-ExecutionPolicy AllSigned`/`RemoteSigned`), sans quoi PowerShell refuse l'execution.

3. **Executer `-SelfTest` en premier** sur chaque machine — il ne necessite aucun droit admin et ne touche a rien, donc il est sans risque a lancer avant de decider de la suite.

4. Comme ce script est **interactif par conception** (pilote par menu, pas de parametre CLI pour appliquer le blocage), il n'est **pas** un candidat direct pour une tache planifiee silencieuse comme le serait un script de nettoyage. Pour un deploiement multi-machines non supervise, envisager soit :
   - de le lancer une fois de maniere interactive par machine lors du provisionnement/de l'imagerie, soit
   - d'extraire la liste de domaines (`$TelemetryDomains` / `$AbsoluteWhitelist`) dans un script non-interactif separe adapte a votre pipeline de deploiement si un rollout entierement silencieux est necessaire.

5. Les sauvegardes, logs et instantanes JSON sont ecrits dans le profil de l'utilisateur qui execute le script — propres a chaque machine, non centralises automatiquement.

---

## Depannage

<details>
<summary><strong>Un site ou une application a cesse de fonctionner apres l'application du blocage</strong></summary>

Verifier d'abord l'option `[9]` (detection de conflits) pour ecarter qu'un autre outil ait modifie `hosts`. Si le probleme vient reellement de ce script, la solution la plus sure est l'option `[5]` (Restaurer) pour annuler completement le blocage, puis signaler quel domaine semble poser probleme — les domaines fonctionnels legitimes devraient deja etre en liste blanche, donc cela pointerait vers un domaine a y ajouter.
</details>

<details>
<summary><strong>L'option [A] signale des domaines manquants ou en trop</strong></summary>

"Manquant" signifie qu'un domaine de la liste actuelle du script n'est pas present dans le bloc actif — generalement parce que le script a ete mis a jour avec de nouveaux domaines depuis la derniere application du bloc. Utiliser l'option `[3]` (Mettre a jour) pour resynchroniser. "En trop" signifie que quelque chose se trouve dans le bloc que la liste actuelle du script n'attend pas — peut venir d'une modification manuelle ou d'un decalage de version plus recente/ancienne ; l'option `[3]` resout aussi ce cas en reconstruisant le bloc depuis zero.
</details>

<details>
<summary><strong>Le blocage ne semble pas prendre effet immediatement</strong></summary>

Le script vide automatiquement le cache DNS apres chaque modification reelle (ou via l'option `[7]` manuellement), mais certaines applications mettent en cache leurs propres resolutions DNS en interne, en plus du cache du systeme — un redemarrage complet de l'application (voire occasionnellement de la machine) peut etre necessaire pour que le changement soit pris en compte.
</details>

<details>
<summary><strong>-SelfTest signale un FAIL</strong></summary>

Les 8 verifications sont des controles de coherence interne sur les listes de domaines/liste blanche elles-memes (doublons, contradictions, logique de correspondance exacte) — un FAIL ici signifie que les listes de domaines ont ete modifiees d'une maniere qui a introduit une incoherence, pas un probleme au niveau du systeme. Lire le detail affiche par la verification pour identifier le domaine ou le nombre concerne.
</details>

<details>
<summary><strong>La restauration n'a pas completement nettoye mon fichier hosts</strong></summary>

La restauration ne supprime que ce qui se trouve entre les marqueurs propres a ce script. Si des entrees ont ete ajoutees en dehors de ce bloc (manuellement, ou par un autre outil), elles sont volontairement laissees intactes — utiliser l'option `[9]` pour detecter et nettoyer separement, si souhaite, ces entrees externes.
</details>

<details>
<summary><strong>Le script echoue au parsing sous PowerShell 5.1 ("Jeton inattendu" pres d'un texte accentue)</strong></summary>

Corrige en v5.2. Sans BOM UTF-8, PowerShell 5.1 lit le fichier `.ps1` avec l'encodage ANSI par defaut du systeme, ce qui corrompt les caracteres accentues (é, à, le tiret cadratin —, etc.) et peut casser une chaine en plein milieu du parsing. PowerShell 7 n'a pas ce probleme car il utilise l'UTF-8 par defaut, avec ou sans BOM — d'ou le fait que le script pouvait sembler "fonctionner" sous `pwsh` tout en echouant sous `powershell.exe`. Si vous avez une ancienne copie du script, retelechargez la v5.2 ou plus recente, ou re-enregistrez le fichier vous-meme en **UTF-8 avec BOM**.
</details>

---

<sub>Block-Telemetry — base sur le fichier hosts, aucune modification de registre, aucun service arrete, rien d'installe.</sub>
