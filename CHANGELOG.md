# Changelog

All notable changes to TicketBrainy are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to a custom semantic versioning scheme (see
`feedback_versioning_scheme.md` in the project memory).

## [Unreleased]

## [1.11.527] — 2026-10-21

Sécurité : correctif Node.js du 21 octobre 2026 (bulletin
« October 2026 Security Releases »). Aucun changement fonctionnel.

### Sécurité
- **Node.js 22.23.3 → 22.23.4** dans les 5 images (web, ai-service,
  mail-service, telegram-bot, migrate) : base `node:22.23.4-alpine`
  désormais épinglée dans les Dockerfiles (plus de tag flottant `22-alpine`).
  Corrige notamment **CVE-2026-111497** (décodeur Brotli, écriture hors
  limites, exécution de code à distance, High) auquel l'instance était
  exposée via les requêtes sortantes `fetch()` du crawler RAG et du proxy
  d'images, ainsi que CVE-2026-105481 (keep-alive HTTP),
  CVE-2026-105482 (dns.resolve), CVE-2026-106069 / 106072 (validation
  d'hôte TLS en IP non canonique), CVE-2026-106073 (permission model) et
  CVE-2026-106074 (entropie des snapshots). Dépendances embarquées mises à
  jour : undici 6.29.1, c-ares 1.34.9, OpenSSL 3.5.9, retrait du CA
  intermédiaire eMudhra compromis.

### Mise à jour
- Installs existants : `cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d`
  puis vérifier `docker compose exec web node --version` → `v22.23.4`.

## [1.11.526] — 2026-10-20

Spam : sortir un ticket des spams + faux positif sur image mal nommée
(cas d'école prod : ticket #572, transfert interne d'une demande client
avec une image collée dans Outlook).

### Corrigé
- **« Non spam » absent de la page du ticket** : un ticket classé spam
  n'offrait aucune issue depuis sa propre page (seule la vue spam avait
  un bouton « Légitime », qui mettait l'expéditeur en liste blanche
  d'office). Nouveau bandeau rouge « Ce ticket est classé spam » avec le
  motif et un bouton **Non spam** ; même bouton dans la vue spam à côté
  de « Supprimer ». Le bouton ouvre une confirmation avec la case
  « Toujours accepter cet expéditeur » (ADMIN/SUPERVISOR). Le ticket
  réapparaît dans *Non assignés*, statut inchangé ; les compteurs de la
  barre latérale se rafraîchissent immédiatement.
- **Traçabilité** : l'opération crée une `TicketActivity` `spam_unmarked`
  (utilisateur, motifs d'origine, liste blanche ou non), visible dans
  l'onglet Activité.
- **Image `.png` contenant du JPEG → ticket forcé en spam** : tout
  décalage magic-bytes était classé « haut risque » au même niveau qu'un
  `.exe` déguisé. `validateMagicBytes` renvoie désormais une gravité
  (`info` pour un décalage inoffensif — images entre elles, PDF nommé
  `.jpg`, sans extension — ; `high` quand le contenu réel est un
  exécutable, un conteneur OLE ou une archive derrière une autre
  extension). Seule la gravité `high` est un signal spam ; un décalage
  `info` reste signalé sur la pièce jointe (badge) et ne saute plus le
  triage IA.
- **Expéditeurs internes** (agent actif de l'instance, ou domaine d'une
  boîte TicketBrainy) : une pièce jointe à risque ne les envoie plus en
  spam à elle seule (avertissement dans les logs). Le verdict antispam
  amont « spam » reste appliqué (usurpation).

### Technique
- `decideSpam()` centralise la règle (liste blanche > verdict amont >
  pièce jointe à risque sauf expéditeur interne) ; `summarizeEmailSecurity`
  lit un niveau de risque par pièce jointe au lieu d'une regex sur le texte
  du motif. Tests node:test (18) + vitest (8) ajoutés.
- `unmarkSpam` (doublon mort sans trace d'activité) supprimé de
  `favorite.actions.ts`.

## [1.11.525] — 2026-09-26

Sécurité : campagne de mise à jour des dépendances suite au rapport EPM
(≈150 avis GHSA sur les images construites, dont 7 critiques). Aucune
fonctionnalité nouvelle ; toutes les corrections sont des bumps de version.

### Sécurité
- **next 16.2.6 → 16.3.5** (GHSA-p293-qw3h-jr36 et GHSA-2xp9-vwfh-vxw4
  critiques, + 8 avis hauts/moyens). Override racine aligné.
- **next-auth 4.24.14 → 4.24.15** : abandonne le peer `@auth/core 0.34.3`
  (GHSA-7rqj-j65f-68wh critique, GHSA-xmf8-cvqr-rfgj) et `cookie 0.6.0` ;
  `@auth/core` forcé en 0.41.3 pour `@auth/prisma-adapter`.
- **node-telegram-bot-api 0.66 → 1.2.0** (réécriture TypeScript, transport
  `fetch`) : supprime la chaîne `request` obsolète qui embarquait
  `form-data 2.3.3` (GHSA-fjxv-7rqg-78g4 critique), `tough-cookie 2.5.0`,
  `uuid 3.4.0` et `qs 6.5.5`. Adaptations : type `InlineKeyboardMarkup`
  importé nommément, `link_preview_options` à la place de
  `disable_web_page_preview`.
- **@extractus/article-extractor 8 → 9.0.1** : n'embarque plus
  `sanitize-html` (GHSA-rpr9-rxv7-x643 critique + 3 moyens).
- **nodemailer 8.0.4 → 10.0.10** (web, mail-service, override racine ;
  8 avis hauts/moyens). Version identique à celle épinglée par mailparser,
  qui passe en **3.9.28** (`linkify-it` 5.0.2, GHSA-v245-v573-v5vm).
- **fastify 5.8.5 → 5.12.5** (`find-my-way` 9.9.0, `fast-uri` 3.1.8/4.2.1,
  2 avis fastify) ; **undici 7.25 → 7.29.1** (12 avis dont 4 hauts).
- **prisma / @prisma/client / @prisma/adapter-pg 7.7 → 7.10.0** : `valibot`
  1.4.2, `find-my-way` 9.7.0, `hono` et `@hono/node-server` disparaissent
  de l'arbre (19 avis) ; overrides `mysql2 3.24.4`, `deepmerge-ts 8.0.2`.
- **Images Docker : npm 11.19.1 épinglé** dans les 4 Dockerfiles. Le
  `node:22-alpine` embarque npm 10.9.9 avec `pacote 19.0.2`
  (GHSA-w4pp-8pjf-rmxw), `sigstore 3.1.0` / `@sigstore/core 2.0.0`
  (GHSA-52v5-jr5w-gjxr, GHSA-jfc7-64v2-mr8c) et un `tar` vulnérable ; npm 11
  livre pacote 21.5.1, sigstore 4.1.1, tar 7.5.22. Le script de release
  construit désormais avec `--pull`.
- **searxng** : digest passé de `2026.5.9` à `2026.9.25`
  (`sha256:5286edb3…`, lxml 6.1.3, Pygments 2.21.0, granian 2.8.3 ; 5 avis).
  Le moteur `reddit` a disparu de l'image amont (module supprimé) : retiré
  de `searxng/settings.yml`, les 7 autres moteurs RAG sont inchangés.
  La clé `redis.url` (dépréciée) devient `valkey.url` et la variable
  compose `SEARXNG_REDIS_URL` devient `SEARXNG_VALKEY_URL`.
- Autres bumps : `@tiptap/* 3.31.3`, `isomorphic-dompurify 4.2.0`
  (`dompurify 3.4.15`, 9 avis), `sharp 0.35.4`, `ip-address 10.7.2`,
  `postcss 8.5.28` (+ `nanoid 3.3.19`), `turbo 2.10.13`, `vitest 4.1.11`
  (`vite 8.0.16`), `tsx 4.23.13` (`esbuild 0.28.2`), `browserslist 4.29.0`,
  `baseline-browser-mapping 2.11.25`, `brace-expansion 1.1.21`,
  `tmp 0.2.7` et `uuid 11.1.1` sous exceljs.
- `.env` passe en mode `600` (secrets lisibles par tous signalés par EPM).
- `npm audit --omit=dev` : 0 vulnérabilité (68 avant).

### Notes techniques
- `prisma` ajouté en devDependency des 3 services Node (ai, mail, telegram) :
  leurs Dockerfiles font `npx prisma generate` sans dépendance locale et
  `npx` téléchargeait désormais `prisma@8.0.0-rc.17` (tag latest), qui n'a
  plus de commande `generate` → build cassé. La version verrouillée est
  maintenant utilisée.
- Le lockfile a été régénéré depuis zéro avec `--legacy-peer-deps`
  (peer optionnel `nodemailer ^7` de next-auth). `npm ci` strict reste OK.
- Toutes les transitives fraîches (< 7 jours) sont épinglées par overrides
  pour respecter la quarantaine supply-chain ; à relâcher lors du prochain
  bump.
- Non traité, à la charge du serveur : ports 22/80 exposés, conteneurs
  tiers démarrés en root (db, redis, searxng, embeddings), `web` et
  `ai-service` démarrent en root puis basculent sur uid 1001 via su-exec
  (lecture des credentials Claude montés depuis l'hôte).

## [1.11.524] — 2026-09-19

Page de connexion : nouveau visuel 3D animé « Neural Core ».

### Modifié
- **Visuel de la page de login remplacé.** L'ancienne animation 2D (logo +
  enveloppes en orbite) laisse place à un cerveau-réseau 3D de particules en
  rotation : des e-mails entrants arrivent de l'extérieur, descendent les
  synapses et font pulser le noyau — l'image du triage IA. Parallaxe à la
  souris, intro d'assemblage, palette violet → bleu du logo. Logo, nom et
  accroche passent en bas du panneau.
- Canvas 2D avec projection 3D maison, **aucune dépendance ajoutée** (pas de
  WebGL : fonctionne sur postes RDP/VM). Boucle arrêtée en mobile (panneau
  masqué) et onglet caché, image fixe si `prefers-reduced-motion`, DPR
  plafonné à 2.

### Mise à jour
`cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d`

## [1.11.523] — 2026-09-16

Rapports facturables : un agent peut désormais y accéder sans devenir superviseur.

### Corrigé
- **« An error occurred loading this page » pour un AGENT sur Statistiques →
  Rapports.** La page levait `Forbidden` (réservée ADMIN/SUPERVISOR), exception
  attrapée par le garde-fou RSC qui affichait une erreur générique avec bouton
  Reload. Une vraie page « Accès refusé » remplace ce comportement sur
  `/analytics/reports` et `/analytics/reports/print`.

### Ajouté
- **Permission « Accès aux rapports » par agent** (`User.canViewReports`,
  colonne booléenne, défaut `false`). Case à cocher dans Paramètres → Équipes
  (dialogue Ajouter/Modifier, visible pour le rôle Agent) + badge « Rapports »
  dans la liste. L'agent autorisé voit l'onglet Rapports et peut consulter,
  exporter (XLSX/impression) et envoyer par e-mail les rapports sur
  **l'ensemble** des tickets, sans autre changement de ses droits (tickets,
  recherche, tableau de bord restent filtrés comme avant). ADMIN/SUPERVISOR
  inchangés. Règle centralisée dans `canAccessReports()` (+ tests) et
  appliquée page, actions serveur et route d'export.
- L'onglet Rapports est masqué pour les personnes non autorisées.

### Mise à jour
`cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d`
(le service `migrate` ajoute la colonne automatiquement, aucune action manuelle).

## [1.11.522] — 2026-09-11

Réponses d'agent : les personnes en copie ne recevaient pas le mail (prod #431).

### Corrigé
- **Reply-all oubliait l'auteur du dernier message client.** Quand un tiers en
  copie répondait (from = Xavier, cc = Denis), le Cc pré-rempli ne contenait
  que Denis : Xavier, à qui l'agent répondait, disparaissait. `computeReplyAllCc`
  inclut désormais le `from` du dernier message client (sauf client du ticket
  et mailbox).
- **Champ CC texte libre jamais validé.** Une adresse ajoutée sans virgule
  (`Denis ROYER <d.royer@…>xavier@…`) était transmise telle quelle à nodemailer,
  qui n'en faisait qu'UN destinataire. Nouveau parseur partagé
  (`@ticketbrainy/shared` `normalizeAddressList`) : découpe `,` `;` et `>` collé,
  validation stricte. Champ CC/CCI en puces dans le composer et le modal
  « Nouveau ticket » (puce rouge = invalide), rejet côté serveur (`addReply`,
  `createTicket`) et refus côté mail-service (défense en profondeur).
- **Échec SMTP silencieux.** Un job perdu sur « Connection timeout » était
  affiché comme une réponse normale. Nouvelles colonnes
  `TicketMessage.deliveryStatus` (QUEUED/SENT/FAILED) + `deliveryError` ;
  le consumer réessaie 3× (3 s, 15 s) puis dead-letter `mail:outgoing:failed`
  et marque le message FAILED ; timeouts SMTP explicites (30/30/60 s) ; le fil
  affiche « Non envoyé » (ou « En attente d'envoi » après 2 min) avec un bouton
  « Renvoyer » (`resendReply`) ; le composer n'affiche plus « envoyé » si Redis
  est indisponible ; le log `Email sent` inclut cc / accepted / rejected.
- **Le listener IMAP écrasait le `To` entrant** par l'adresse de la mailbox :
  les collègues mis en To étaient perdus. La vraie liste To est stockée
  (listener et force-poll web).

### Migration
- `prisma db push` (service `migrate`) ajoute l'enum `DeliveryStatus` et deux
  colonnes nullable — aucune donnée existante modifiée.

## [1.11.521] — 2026-08-26

Backup monitor : un rapport Nakivo « Échec » s'affichait en vert.

### Corrigé
- **Un backup en échec était compté comme réussi, tous les jours.** Nakivo envoie
  ses rapports dans la langue du serveur : `Tâche "…": Échec (8 VM réussie(s),
  1 VM en échec, …)`. Les compteurs n'étaient reconnus qu'au format anglais
  (`N VMs successful … N VMs failed`), les patterns par défaut de la tâche sont
  anglais (`successful` / `failed`), et le dernier cas d'`analyzeBackupStatus`
  traduisait « e-mail trouvé, rien compris » par **`SUCCESS`**. Résultat en prod
  (`PVEITS01 ITCAM-RDS`, depuis au moins le 14/08) : coche verte quotidienne sur
  un job en échec — y compris quand **aucune** VM n'était sauvegardée
  (`0 VM réussie(s), 9 VM en échec` → `SUCCESS`). `parseVmCounts` lit désormais
  les deux langues (comparaison sans accents, un motif par compteur : un champ
  manquant ou déplacé n'annule plus toute l'analyse), une liste de mots-clés
  multilingues intégrée sert de **repli** quand aucun pattern de la tâche ne
  matche (la configuration de l'admin reste prioritaire), les patterns saisis
  sont insensibles aux accents (`echec` ↔ `Échec`), et un e-mail non interprété
  devient `WARNING` avec le sujet en détail — plus jamais un succès silencieux.
- **Un backup entièrement réussi pouvait être classé en erreur.** Le mot-clé
  d'échec était cherché dans **tout** le sujet, décompte compris : le « failed »
  de `Successful (9 VMs successful, 0 VMs failed, …)` matchait `failedPattern` et
  faisait tomber le rapport en `ERROR`. Le verdict est maintenant lu sur la partie
  du sujet **qui précède** le décompte — « 0 VM en échec » est une donnée, pas un
  verdict.
- **`WARNING` crée un ticket au même titre qu'`ERROR` et `MISSING`.** Un échec
  partiel (des VM en échec, d'autres réussies) ou un e-mail non interprété
  n'ouvrait aucun ticket. `isAlertingStatus()` centralise la règle, et
  `createBackupTicket` reçoit le statut réel : un ticket `WARNING` s'intitulait
  `[Backup Alert] … — ERROR`, le statut étant déduit de la seule présence d'un
  e-mail. La création reste attachée au **premier** enregistrement d'un jour :
  la fenêtre IMAP de 192 h rejoue 8 jours d'e-mails, et créer un ticket sur
  changement de statut déclencherait une rafale à chaque évolution de l'analyseur.
- 16 tests (`apps/mail-service/src/imap/backup-analyzer.test.ts`, le module n'en
  avait aucun) : sujets FR de prod, compteurs dans le corps, accents, priorité
  des patterns de la tâche, statuts alertants, non-régression anglaise.

## [Corrigé] — 2026-08-25 — redirect URIs Keycloak assemblés par des virgules

Correctif livré hors cycle (fichiers bind-montés `keycloak/`), **aucune image
reconstruite** — le pin GHCR reste `1.11.52`. Nécessite `--force-recreate`.

### Corrigé
- **Le callback OIDC en accès LAN direct ne pouvait jamais aboutir.** Le compose
  passe `LAN_HOST: ${LAN_HOSTS:-localhost}` à Keycloak, or `LAN_HOSTS` est une
  liste **séparée par des virgules** (`install.sh` écrit
  `localhost,<ip-serveur>[,<ip-admin>]`). Le template de realm interpolait cette
  liste dans **une seule** entrée — `http://10.0.0.5,localhost:3027/api/auth/callback/keycloak`
  — qui ne correspond à aucune requête navigateur : seul le callback public
  `APP_URL` fonctionnait, le chemin LAN renvoyait `400 invalid redirect`. Le
  `webOrigin` correspondant était cassé de la même façon.
  `keycloak/docker-entrypoint.sh` développe désormais la liste en **une URI par
  hôte** (bash pur — l'image Keycloak n'embarque pas `awk`), en ignorant les
  plages CIDR (légitimes dans `LAN_HOSTS` pour l'allowlist web, mais invalides
  comme hôte d'URI) et en dédupliquant.
- **Réparation des installations existantes.** Le realm n'est importé qu'une
  fois (`IGNORE_EXISTING`) : corriger le template ne suffisait pas, la valeur
  cassée restait en base indéfiniment. `keycloak/apply-config.sh` (Step 9) répare
  donc `redirectUris`/`webOrigins` du client `ticketbrainy-web` à chaque
  démarrage : toute entrée dont la partie hôte contient une virgule est éclatée
  en une entrée par hôte. Le découpage est ancré sur le `:<port>` pour ne pas
  confondre le `/` d'un CIDR avec le début du chemin. Passe sans écriture sur une
  installation saine (idempotent), et refuse d'écrire une liste vide.
- **`account-console` et `security-admin-console` échappaient au durcissement
  ROPC.** L'extraction de l'UUID client (`sed 's/.*"id":"\([^"]*\)".*/\1/p'`) est
  **gourmande** : elle retenait le **dernier** `"id"` de la représentation JSON —
  celui d'un protocolMapper ou d'un attribut sur les clients qui en ont — d'où un
  `PUT … HTTP 404 (non-fatal)` silencieux sur ces deux clients à chaque sync,
  qui gardaient donc ROPC et le flux implicite **activés**. Nouveau helper
  `kc_first_id` (première occurrence), appliqué aux 8 extractions du script. Les
  cinq clients par défaut sont désormais réellement durcis.

## [Sécurité] — 2026-08-25 — Keycloak CVE-2026-18963

Correctif de sécurité **critique** livré hors cycle : mise à jour d'image
Keycloak uniquement, **aucune image applicative TicketBrainy n'est reconstruite**
(le pin GHCR reste `1.11.52`).

### Sécurité
- **CVE-2026-18963 (CVSS 9.1) — prise de contrôle de compte non authentifiée via
  « mot de passe oublié ».** Le flux `reset-credentials` de Keycloak valide mal son
  propre état : un attaquant distant non authentifié pouvait atteindre l'étape
  « définir un nouveau mot de passe » pour n'importe quel utilisateur connu **sans
  jamais recevoir ni cliquer l'e-mail de réinitialisation**, puis s'approprier le
  compte. Aucune interaction utilisateur requise. Versions touchées : `26.0.0` →
  `26.7.1` ; corrigé en `26.7.2` (RHBK `26.4.15` / `26.6.6`).
  TicketBrainy épinglait `quay.io/keycloak/keycloak:26.2` et le realm
  `ticketbrainy` expose `resetPasswordAllowed: true` sur le frontend public
  `auth.<domaine>` : **toute installation ≤ 1.11.52 est concernée.**
- **Pin Keycloak `26.2` → `26.7.2`, désormais exact** (`docker-compose.prod.yml`,
  compose public, `scripts/keycloak-reset-admin.sh`). Le tag flottant `26.2` est
  abandonné pour qu'un `docker compose pull` ne puisse plus atterrir sur une
  version vulnérable.
- **Runbook post-incident** — nouvelle section 9 de `docs/admin/keycloak-recovery.md` :
  procédure de patch, mitigation temporaire (*Realm settings → Login → Forgot
  password = Off*, à ne garder que si le patch est impossible), rotation des
  identifiants admin, déconnexion globale du realm (`logout-all`) pour invalider
  les sessions et refresh tokens acquis avant le correctif, et signaux de détection
  à chercher dans les events Keycloak (`UPDATE_PASSWORD` sans
  `SEND_RESET_PASSWORD` correspondant, rafales de `RESET_PASSWORD_ERROR` depuis une
  même IP, `LOGIN` depuis une IP inédite juste après une réinitialisation).

### Corrigé
- `docs/admin/keycloak-recovery.md` documentait `otpPolicyAlgorithm = HmacSHA256`
  alors que `apply-config.sh` applique bien `HmacSHA1` (SHA256 casse Google/MS
  Authenticator) ; la doc suivait aussi un `up -d keycloak` sans `--force-recreate`.

## [1.11.52] — 2026-07-24

Correctif de threading des e-mails d'auto-fermeture (« Fermeture auto en attente »).

### Corrigé
- **Une réponse à une relance d'auto-fermeture créait un nouveau ticket.** Les
  e-mails d'auto-fermeture (relance et fermeture finale, côté mail-service) partaient
  en `Re: <sujet>` **brut** : sans tag `[Ticket #N]` dans le sujet, sans en-têtes
  `References`/`In-Reply-To`, et **sans être enregistrés** comme message du ticket.
  Le listener entrant ne pouvait donc rattacher la réponse ni par en-tête (Méthode 1)
  ni par numéro de ticket dans le sujet (Méthode 2) → `handleNewTicket` créait un
  ticket parasite (prod : #300 → #333). Les trois e-mails d'auto-fermeture (initial,
  relance, finale) adoptent désormais le sujet canonique `Re: [Ticket #N] …`, la
  chaîne `References` complète du fil, et sont **persistés dans le ticket d'origine**
  (visibles dans la timeline, `Message-ID` back-fillé pour l'appariement). Une réponse
  client **rouvre le ticket d'origine** (REOPENED) et annule l'auto-fermeture — jamais
  de nouveau ticket. Le texte de l'e-mail de fermeture finale promet désormais la
  **réouverture** du ticket au lieu de la création d'un nouveau. Nouveau helper testé
  `apps/mail-service/src/lib/auto-close-mail.ts` (`buildAutoCloseThread`,
  `buildAutoCloseMailJob`) ; `scheduler/auto-close.ts` et `auto-close.actions.ts`.

## [1.11.51] — 2026-07-17

Correctif de l'autocomplétion client livrée en 1.11.50.

### Corrigé
- **Autocomplétion client : recherche sur le contact et l'e-mail.** La recherche
  n'interrogeait que `name`/`email`/`company` du client — or un client est souvent
  enregistré sous un nom d'entreprise (« Heinrich&Bock ») alors que la personne que
  l'agent connaît est le **contact** (« Fabien Messa » / `fabien.messa@…`, champs
  `contactName`/`contactEmail`). Taper le nom d'un contact ne renvoyait donc aucune
  suggestion. La recherche porte désormais sur **nom client + e-mail + nom du contact
  + e-mail du contact** (le champ `company` n'est plus interrogé), et chaque client
  génère une suggestion **par identité** : rechercher un contact propose (et remplit)
  la personne — nom + e-mail du contact — plutôt que l'adresse générique de
  l'entreprise. `searchCustomersForTicket`.

## [1.11.50] — 2026-07-17

Deux améliorations du modal « Nouveau ticket » (création manuelle depuis la web UI).

### Ajouté
- **Autocomplétion client dans le modal « Nouveau ticket ».** En tapant le début
  du nom **ou** de l'adresse e-mail d'un client (≥ 2 caractères), une liste des
  clients déjà connus du système (concordance sur nom/e-mail/société) s'affiche
  sous le champ. Un clic remplit **les deux champs** (nom + e-mail) — plus besoin
  de retaper un client existant ; la saisie libre reste possible pour un nouveau
  client. Nouvelle server action `searchCustomersForTicket` (accessible aux
  agents, `requireAuth`), exclut le client système « AutresClients ». Navigation
  clavier (↑/↓/Entrée/Échap).
- **Assistant IA dans le modal « Nouveau ticket ».** Le panneau d'aide à la
  rédaction (baguette → instruction → génération, avec sélecteur de langue et
  Ctrl+Entrée), jusqu'ici réservé à la réponse à un ticket, est maintenant
  disponible à la création : l'agent décrit le message voulu et l'IA rédige le
  premier message sortant à partir du sujet/nom/e-mail déjà saisis. Gaté par le
  plugin `ai_email_gen` (cadenas → `/settings/plugins` sinon), à l'identique de la
  réponse. Nouvel endpoint `POST /email/compose` (ai-service, sans `ticketId`) et
  composant `AiComposePanel` partagé entre la réponse et la création (une seule
  UI IA à maintenir).

## [1.11.49] — 2026-07-12

Deux correctifs autour du mode abonnement Claude Code CLI, dans la continuité des
1.11.47/1.11.48.

### Corrigé
- **Détection « Claude Code CLI » grisée à tort** (« CLI non détecté sur le
  serveur ») : la sonde des réglages (`claude-cli-probe.ts`) basait l'état
  « connecté » sur `claudeAiOauth.expiresAt` — l'**access token**, à durée de vie
  courte (~heures). Dès que `ai-service` restait inactif assez longtemps pour ne
  pas rafraîchir l'access token, l'option se grisait alors que le CLI est
  parfaitement authentifié : le **refresh token** est valide et régénère un access
  token au prochain appel. La sonde se base désormais sur le refresh token
  (`refreshTokenExpiresAt`) — refresh valide ⇒ connecté ; refresh expiré ⇒
  re-login requis. Fin du faux négatif récurrent.
- **Mode Claude qui décrochait silencieusement vers la clé API** (« AI API key
  not configured ») : la valeur `ai.provider` en base (colonne `Json`) pouvait
  avoir dérivé (legacy `"claude"`, casse, espaces, double-encodage
  `"\"claude_cli\""`). Le formulaire la normalisait déjà, mais `ai-service` et le
  préflight web la comparaient en strict `=== "claude_cli"` : toute variante
  retombait sur le mode `api_key`. Un `normalizeProvider` canonique est maintenant
  appliqué à chaque point de décision back-end (`getAiProvider` d'`ai-service`,
  préflight web) — défense en profondeur, le mode sélectionné ne décroche plus.

### Note d'exploitation
Aucune action manuelle requise. Si l'option Claude reste grisée après mise à jour,
vérifier que le token n'est pas réellement expiré :
`docker compose exec -u appuser ai-service claude` → `/login`.

## [1.11.48] — 2026-07-11

Correction de la **cause racine** du 401 récurrent en mode abonnement Claude
Code CLI (le `refresh_token_reused` d'hier, le `401 Invalid credentials`
d'aujourd'hui). Les correctifs précédents (`cp -au` anti-clobber, suppression du
fallback Codex) ne traitaient qu'un symptôme : la vraie cause est une **course
au refresh du token OAuth**.

Le token d'abonnement est un OAuth à refresh token **à usage unique** : chaque
rafraîchissement le consomme et le remplace. Or `AI_MAX_CONCURRENCY=4` laissait
`ai-service` lancer jusqu'à 4 `claude` en parallèle, et la sonde de statut côté
`web` en lançait un de plus — tous sur le **même** fichier de credentials du
volume partagé `claude-config`. À l'expiration de l'access token (~8 h), ces
appels rafraîchissaient simultanément avec le **même** refresh token → le
serveur d'auth détectait la réutilisation et **révoquait toute la famille de
tokens** → 401 persistant jusqu'à re-login manuel. (Reproductible en prod sous
charge réelle, invisible en local faute de concurrence.)

### Corrigé
- **Sérialisation des appels au CLI Claude** : tous les spawns `claude` de
  `ai-service` passent désormais par un mutex FIFO in-process (`lib/serialize.ts`)
  — un seul processus CLI à la fois, donc **un seul refresh à la fois**. Le token
  rote proprement au lieu de se faire révoquer. Le débit de triage devient
  séquentiel (négligeable pour un volume support ; réglable ultérieurement).
- **Sonde de statut sans effet de bord** : le badge « Claude Code CLI connecté »
  des réglages ne lance plus `claude` (c'était une source de course
  supplémentaire, côté `web`, sur le token partagé). Il lit l'`expiresAt` du
  fichier de credentials : token présent et non expiré ⇒ connecté ; expiré ou
  absent ⇒ re-login requis. Honnête, zéro spawn, zéro refresh.

### Note d'exploitation
Après mise à jour, si le token est déjà révoqué (état actuel), faire **une**
reconnexion : `docker compose exec -u appuser ai-service claude` → `/login`.
Le volume `claude-config` étant partagé web ↔ ai-service, les deux voient
aussitôt le token frais, et la sérialisation empêche toute nouvelle révocation.

## [1.11.47] — 2026-07-11

Correctif de fond du bug récurrent « l'Assistant IA plante » avec une erreur
Codex `401 refresh_token_reused` — alors que le fournisseur sélectionné est
l'abonnement **Claude**, pas Codex. Trois causes qui se cumulaient sont
traitées (badge de statut trompeur, fallback Codex silencieux, token Claude
écrasé dans le conteneur), en plus de l'invalidation du cache fournisseur.

### Corrigé
- **Fournisseur IA figé en mémoire** : `ai-service` mettait en cache le mode
  fournisseur (`ai.provider`) et le client clé API (`ai.apiKey`) pour toute la
  durée de vie du process, sans aucune invalidation — la fonction de reset
  existante n'avait aucun appelant. Comme le réglage est écrit par `web` (un
  process distinct), basculer de fournisseur dans l'UI restait sans effet sur
  `ai-service` jusqu'au prochain redémarrage.
- **Badge « Claude Code CLI connecté » trompeur** : le statut affiché dans
  Settings ne testait que `claude --version` (présence du binaire), jamais
  l'authentification — il restait donc vert avec un token OAuth mort. Il
  exécute désormais une vraie sonde qui échoue si le token renvoie 401.
- **Fallback Codex silencieux** : en mode abonnement Claude, une erreur d'auth
  Claude basculait en douce sur Codex CLI, dont l'OAuth mort produisait le
  `refresh_token_reused` trompeur qui masquait le vrai 401 Claude. Le fallback
  est supprimé : le fournisseur sélectionné assume ses propres erreurs.
- **Token Claude écrasé dans le conteneur** : la boucle de synchronisation des
  credentials écrasait (`cp -f`) le token OAuth fraîchement rafraîchi/tourné
  dans le conteneur par la copie host périmée → 401 récurrent. Synchronisation
  passée en update-only (`cp -au`), comme le fait déjà Codex depuis la 1.10.147797.

### Ajouté
- **Invalidation cross-process du cache IA** : les caches de `ai-service`
  portent désormais un TTL de 60 s (filet auto-cicatrisant), et `web` publie un
  message Redis `ai:settings-changed` à chaque sauvegarde du fournisseur/clé ;
  `ai-service` y souscrit et vide son cache aussitôt → bascule effective
  immédiate, sans redémarrage. En l'absence de Redis, le TTL prend le relais.

## [1.11.46] — 2026-06-13

Correctif d'un blocage collaboratif majeur signalé par les agents : un ticket
laissé ouvert verrouillait la réponse pour tout le monde.

### Corrigé
- **Ticket verrouillé à vie pour les autres agents** : dès qu'un agent touchait
  le composer (frappe, brouillon IA, insertion d'un modèle ou d'un article KB),
  un verrou d'édition exclusif était posé — puis rafraîchi par un heartbeat
  toutes les 10 s **tant que l'onglet restait ouvert**, sans tenir compte de
  l'activité réelle. Le TTL serveur de 30 s n'expirait donc jamais : un agent
  qui ouvrait un ticket puis passait à autre chose **sans fermer l'onglet**
  bloquait la réponse pour tous les autres agents indéfiniment.
- Le verrou d'édition est désormais **purement informatif** : le composer des
  autres agents n'est plus jamais désactivé (une bannière « X rédige aussi une
  réponse » les avertit simplement). De plus, le verrou se **libère
  automatiquement après ~60 s d'inactivité**, donc un onglet abandonné ne
  laisse plus de signal résiduel pour les collègues.

## [1.11.45] — 2026-06-08

Suite des correctifs du flux e-mail : nettoyage des extraits de mails
entrants ré-injectés vers le client et les agents (cas d'école : ticket #99).

### Corrigé
- **Accusé de réception illisible (#99)** : le bloc « Message original » de
  l'accusé automatique ne ré-injecte plus le message brut du client. Sont
  désormais retirés les placeholders d'images inline (`[cid:…]`), les liens
  réécrits par les passerelles e-mail (Sophos/Proofpoint/Mimecast — le
  domaine de destination est restitué quand il est lisible, sinon le lien est
  supprimé) et le bloc signature (coupe conservatrice sur `-- ` ou la première
  ligne `[cid:…]`). La troncature se fait sur une frontière de mot avec « … »
  au lieu d'une coupe brute à 500 octets en plein milieu d'une URL.
- **Cohérence des extraits** : le même assainissement est appliqué aux aperçus
  envoyés aux agents (notifications « nouveau ticket » et « réponse client »),
  à l'aperçu Telegram et à la notification admin. Le corps complet stocké du
  message reste inchangé (la dé-citation à l'affichage, introduite en 1.11.21,
  n'est pas affectée).

## [1.11.44] — 2026-06-04

Correctifs majeurs du flux e-mail, en réponse aux plaintes clients et agents
(cas d'école : ticket #79).

### Corrigé
- **Changement de client (BUG 1)** : affecter ou changer le client d'un
  ticket n'envoie plus l'accusé de réception entrant « Nous avons bien reçu
  votre demande » — formulation fausse pour un contact qui n'a rien demandé,
  à l'origine du « Je ne vois pas qui est à l'origine de l'ouverture du
  ticket ? ». À la place, un message d'attribution dédié part vers le nouveau
  contact (« Le ticket #N « … » vous a été attribué… »), en citant la demande
  d'origine, et uniquement lorsque l'adresse change réellement.
- **Traçabilité des auto-réponses (BUG 2)** : tout envoi automatique (accusé
  de réception, message d'attribution) est désormais journalisé comme message
  `AUTO_REPLY`, visible dans le fil du ticket et auditable. Auparavant ces
  e-mails partaient sans laisser aucune trace côté agent, d'où la perception
  « le client n'a reçu aucune notification ».
- **Threading e-mail (BUG 3)** : l'en-tête `References` (chaîne RFC 5322
  complète) est maintenant émis sur les réponses agent et les accusés de
  réception, et le sujet des accusés générés par le listener IMAP est aligné
  sur `Re: [Ticket #N] …`. Évite les conversations dédoublées sous Outlook et
  fiabilise le rattachement des réponses client au bon ticket.

## [1.11.43] — 2026-06-02

Sécurité : montée de Next.js 16.2.4 → 16.2.6. La 16.2.4 était exposée à
plusieurs vulnérabilités (PoCs publics, dont CVE-2026-44578 / CVSS 8.6) ;
la 16.2.6 embarque les 13 correctifs de sécurité critiques publiés par
Vercel (déni de service, contournement middleware/proxy, SSRF, cache
poisoning, XSS, + une faille React amont). On reste volontairement en
16.2.6 plutôt que 16.2.7 : tout le contenu sécurité est dans 16.2.6, alors
que 16.2.7 (publiée la veille) n'apporte que des correctifs de bugs et
n'avait pas encore passé la quarantaine supply-chain de 7 jours.

Mise à jour : `docker compose pull && docker compose up -d`.

## [1.11.42] — 2026-06-01

Confort : la fenêtre « Nouveau ticket » (création manuelle) était trop étroite
pour rédiger un message à l'aise.

### Améliorations
- **Modal de création élargi** : largeur portée à `max-w-4xl` (~896 px,
  responsive `95vw` sur petit écran) et hauteur max `92vh` ; la zone de saisie
  du message passe de 150–260 px à 260–460 px de haut. Le contenu reste
  scrollable.

## [1.11.41] — 2026-06-01

Correctif : la création manuelle de ticket envoie désormais au client le
message rédigé par l'agent — et non plus un accusé de réception générique.
Repéré en prod sur un ticket créé depuis l'UI (canal WEB) : le client recevait
« Votre demande a bien été enregistrée sous le numéro #N… » au lieu du texte de
l'agent, qui n'apparaissait que dans la notification interne.

### Corrections
- **Message agent → client** : le job e-mail sortant de `createTicket` porte
  maintenant le corps rédigé par l'agent (`to`, `cc`, `bcc` et l'expéditeur de
  la boîte restent inchangés). Le numéro de ticket reste dans le sujet
  (`[Ticket #N] …`).
- **Sens du message dans le fil** : le message initial d'un ticket créé
  manuellement est désormais persisté comme une réponse sortante (agent →
  client) et s'affiche du bon côté de la conversation, avec gestion des images
  inline et de la signature de boîte comme une réponse normale.
- **Notification interne** : le bloc d'aperçu « nouveau ticket » affiche le
  premier message du fil quel que soit son type (libellé neutre « Message »),
  pour ne pas rester vide sur les tickets créés manuellement.

## [1.11.40] — 2026-05-31

Vues sauvegardées dans la file de tickets (finding produit #28 de l'audit
2026-05-29 — dernier item de l'audit). Chaque agent peut nommer et persister un
jeu de filtres et le rappeler en un clic.

### Fonctionnalités
- **Vues sauvegardées (privées par agent)** : bouton « Sauvegarder la vue » dans
  la toolbar de filtres (capture `status, priority, mailboxId, assignedToId,
  tagId, category, search` + tri non-défaut), et section « Vues sauvegardées »
  dans la sidebar pour les rappeler / supprimer. Réutilise le mécanisme de
  searchParams existant : cliquer une vue applique les filtres via l'URL.
- Nouveau modèle `SavedView` (table neuve, `userId` + `filters` JSON,
  `@@unique([userId, name])`). Server Actions scopées `userId` (ownership).

### Notes
- Portée volontairement bornée : vues privées (pas de partage équipe), pas de
  capture de vue prédéfinie. Table neuve → créée par `db push` au déploiement,
  aucune migration de données.

## [1.11.39] — 2026-05-31

Hotfix de la migration 1.11.38 : l'ajout de la contrainte `@@unique([ticketId,
messageId])` faisait échouer le conteneur `migrate` au déploiement. `prisma db
push` refuse d'ALTER une table existante pour y ajouter une contrainte unique
sans `--accept-data-loss` (garde-fou générique, levé même sans doublon) — et la
commande migrate utilise volontairement `db push` sans ce flag pour préserver ce
garde-fou sur tous les autres changements de schéma.

### Correctif
- L'index unique est désormais créé en **SQL brut** (`CREATE UNIQUE INDEX IF NOT
  EXISTS "TicketMessage_ticketId_messageId_key"`) à la fin de la migration de
  dédup, AVANT `db push`. db push le trouve déjà présent → « in sync », aucun
  ALTER, aucun flag. Nom = convention Prisma `@@unique`. Idempotent.
- La dédup (1.11.38) est inchangée ; sur une instance déjà passée par le migrate
  1.11.38, elle est un no-op (doublons déjà supprimés).

### Notes
- Pas de changement fonctionnel ni de nouvelle migration de données.
- Aucune action manuelle requise : le `migrate` au déploiement crée l'index puis
  passe « in sync ».

## [1.11.38] — 2026-05-31

Fiabilité du pipeline mail (finding P1 de l'audit 2026-05-29). Une course
force-poll/listener pouvait ré-ingérer le même email entrant deux fois dans un
même fil de ticket (lignes `TicketMessage` dupliquées partageant le Message-ID).

### Fiabilité
- Contrainte **`@@unique([ticketId, messageId])`** sur `TicketMessage` : backstop
  DB contre l'ajout en double d'un même Message-ID dans un fil. **Portée par
  ticket** (pas globale) pour rester compatible avec le soft-delete/fusion — les
  tickets supprimés conservent leurs messages, et l'unicité globale rejetterait
  une ré-ingestion légitime post-fusion. `messageId` NULL (brouillons / legacy)
  exempté (NULLs distincts en Postgres).
- Migration de **dédup idempotente** (`prisma/migrations/20260531_dedup_messageid_unique`,
  branchée dans `run-raw-migrations.mjs` → avant `prisma db push`) : normalise les
  Message-ID vides en NULL, puis pour chaque doublon `(ticketId, messageId)` garde
  le plus ancien en **re-pointant les pièces jointes** avant suppression (cascade-safe).
  S'exécute automatiquement au déploiement, politique fatal-on-error.

### Notes
- Les doublons **cross-ticket** (même email → deux tickets) ne sont pas fusionnés
  par cette migration (autorisés par la contrainte par-ticket) ; à traiter via la
  fusion de tickets si nécessaire. Non bloquant.
- Aucun changement fonctionnel visible.

## [1.11.37] — 2026-05-31

Durcissement sécurité (suite du sweep injection HTML de l'audit 2026-05-29) :
échappement systématique des valeurs **contrôlées par le client** (sujet du
ticket, nom du client, premier message) interpolées dans les corps d'emails
sortants.

### Sécurité
- Les emails de **notification aux agents**, de **résolution**, de **relance
  d'auto-clôture** et les **réponses automatiques** échappent désormais les
  champs fournis par le client. Un sujet ou un nom contenant du balisage HTML
  (`<img onerror=…>`, etc.) ne peut plus être injecté dans le rendu de l'email.
- Le gabarit (`wrapInTemplate`, mail-service) ne **devine** plus HTML vs texte à
  partir du contenu — une heuristique contournable : un champ client porteur de
  `<…>` faisait basculer un corps texte en mode HTML brut et court-circuitait
  l'échappement. Chaque émetteur déclare maintenant explicitement la nature du
  corps via le flag `bodyIsHtml` (`MailJob` → consumer → sender → wrapper) ;
  l'heuristique ne subsiste qu'en repli pour les appelants historiques.
- Nouvel util partagé `apps/web/src/lib/html-escape.ts` (`escapeHtml` 5 entités
  + `isHtmlTemplate`). Tests : `smtp/templates.test.ts` (node:test) +
  `lib/html-escape.vitest.ts` (vitest).

### Notes
- Aucun changement fonctionnel visible ni migration de base de données.

## [1.11.36] — 2026-05-31

Performance de l'ai-service (finding P2 de l'audit interne). Les appels au modèle
d'IA (triage automatique, analyse approfondie, génération de réponses) étaient lancés
sans aucune borne de simultanéité. Lors d'un afflux d'emails entrants (jusqu'à une
centaine de triages déclenchés d'un coup) ou de plusieurs analyses approfondies en
parallèle, cela pouvait saturer le CPU/RAM ou faire dépasser le quota de l'API (erreurs 429).

### Performance
- Un **limiteur de concurrence** plafonne désormais le nombre d'appels IA simultanés
  (par défaut **4**, configurable via la variable d'environnement `AI_MAX_CONCURRENCY`).
  Au-delà, les appels patientent qu'un créneau se libère : la charge est lissée, plus
  de saturation ni d'erreurs 429 sous pic.

### Notes
- Aucun changement de comportement fonctionnel : mêmes appels, mêmes résultats ; seule
  la simultanéité est bornée. Aucune migration de base de données.

## [1.11.35] — 2026-05-30

Performance du mail-service (finding P2 de l'audit 2026-05-29). Le consumer de la file
d'envoi (`queue/consumer.ts`) exécutait un `BRPOP "mail:outgoing" 5` **bloquant** sur la
**connexion Redis partagée** (`getRedis()`) — la même, dans le même process, que celle utilisée
par les producteurs pour `lpush "mail:outgoing"` (`imap/listener.ts` ×6, `scheduler/auto-close.ts`
×2), les `publish` et les `get`/`set` (lock journalier backup). Une commande bloquante tient sa
connexion ; comme la boucle re-bloque en continu, **toute** commande non-bloquante émise pendant
ce temps était mise en file derrière le BRPOP et stallait **jusqu'à 5 s**. 0 migration,
mail-service uniquement.

### Performance
- Le `BRPOP` tourne désormais sur une **connexion Redis dédiée** (`getBlockingRedis()`),
  séparée de la connexion partagée. Les `lpush`/`publish`/`get`/`set` ne stallent plus derrière
  lui — fin de la latence d'envoi (jusqu'à 5 s) et des stalls en cascade sur le lock backup et
  les notifications.
- `disconnectRedis()` ferme proprement les deux connexions au shutdown.

### Notes
- Aucun changement de comportement : même file `mail:outgoing`, même BRPOP timeout 5 s, mêmes
  producteurs. Pure isolation de connexion (pratique standard ioredis pour les commandes
  bloquantes). `poll-trigger.ts` et `backup-listener.ts` étaient déjà sur connexions dédiées.

### Tests
- Harnais runtime contre le vrai Redis : un `PING` émis pendant un `BRPOP` en vol mesuré à
  **~2027 ms** sur connexion partagée (bug) contre **0 ms** sur connexion dédiée (fix).

## [1.11.34] — 2026-05-30

Performance de la Deep Analysis (finding P2 de l'audit 2026-05-29). Le composant
`AnalysisStream` (`ai-sidebar/analysis-stream.tsx`) ouvrait, au clic « Run Deep Analysis »,
un flux **SSE** ET un **polling** concurrents : le `useEffect` de polling tapait
`/api/ai/analysis/<ticketId>` (lecture DB) **toutes les 1,5 s pendant toute la durée du SSE**
(~60-120 s), soit **~40-80 requêtes redondantes** avec le SSE qui streamait déjà la même
progression. Aucun changement de comportement visible, 0 migration, client-only.

### Performance
- Le **SSE est désormais le flux unique** quand l'utilisateur lance/relance une analyse — plus
  de polling concurrent. Suppression des ~40-80 lectures DB redondantes par analyse.
- Le polling reste réservé à deux cas mutuellement exclusifs du SSE : (a) **resume au montage**
  d'une analyse déjà en cours (autre onglet / après refresh) ; (b) **fallback** si le SSE tombe
  après l'ouverture de connexion — on rejoint le job via la DB (le worker continue côté
  ai-service) au lieu d'afficher une fausse erreur « service non démarré ».

### Fiabilité
- Helper pur `classifySseClose({completed, closed, started})` (testable) route la décision sur
  erreur/close. `started` bascule sur `es.onopen` (connexion ouverte = le backend a créé/va créer
  la ligne `DEEP_ANALYSIS`, même avant le 1er événement d'étape pendant le RAG-crawl), pour ne
  pas laisser un job orphelin ni risquer une analyse en double via Retry.
- `es.close()` conservé sur erreur (empêche l'auto-reconnect d'`EventSource` qui relancerait une
  analyse).

### Tests
- 4 tests unitaires (vitest) sur `classifySseClose` (table de décision complète). Aucun
  changement serveur (route SSE + route statut inchangées), aucune donnée.

## [1.11.33] — 2026-05-30

Performance de `backfillCustomerLinks` (finding P2 de l'audit 2026-05-29,
`customer.actions.ts:237-282`). L'action admin « Rattacher les orphelins » ré-exécutait
le résolveur `resolveCustomerIdByEmail` (jusqu'à **3 requêtes**) pour **chaque** ticket
candidat (orphelins + AutresClients), puis faisait **un `UPDATE` par ticket** — boucle N+1
séquentielle (`1 + 3N + N`) non bornée, pouvant scanner des milliers d'orphelins. Sortie
**inchangée** (même `preview`, mêmes `scanned`/`linked`, état final identique), 0 migration.

### Performance
- **Une seule requête** charge tous les `Customer` → 3 lookups en mémoire (email exact,
  domaine non-système le plus ancien, catch-all système) via `loadCustomerLookups`, reproduisant
  fidèlement les 3 stratégies du résolveur single. Résolution de chaque candidat désormais en
  mémoire (0 requête/ticket).
- Écritures **groupées par client cible** : `updateMany({ id: { in: [...] }})` découpé en chunks
  de 1000 ids (sous la limite de bind-params Postgres), au lieu de N `update` séquentiels.
- Bilan : `1 (clients) + 1 (candidats) + chunks d'updateMany` contre `1 + 3N + N`.

### Architecture
- Helper pur `resolveFromMaps(email, lookups)` (testable) + batch `loadCustomerLookups(db)`
  ajoutés à `auto-link.ts` ; `resolveCustomerIdByEmail` (3 hot-paths single) **intact**.

### Tests
- 6 tests unitaires (vitest) sur `resolveFromMaps` (3 stratégies, email l'emporte sur domaine,
  email invalide, pas d'autresId) + validation par **diff sur base réelle** (123 candidats :
  résolution batch identique au résolveur single ; apply groupé repositionne au bon client).
- Clés des lookups stockées **verbatim** (= match exact `findUnique`/`findFirst`, Postgres
  sensible à la casse), lookup avec email d'entrée normalisé.

## [1.11.32] — 2026-05-30

Performance du rapport de temps (finding P2 de l'audit 2026-05-29,
`time-reports.actions.ts:25-40`). `getTimeReport` (`settings/time-reports`)
chargeait **toutes** les `TimeEntry` filtrées en RAM — sans plafond, avec leurs
relations imbriquées (`user`, `ticket`, `customer`) — puis agrégeait en JS, sur une
table sans index `createdAt`. Résultat : seq-scan + tri en mémoire + matérialisation
non bornée. C'était le seul endpoint reporting sans cap (contre `REPORT_HARD_CAP`
ailleurs). Sortie **inchangée** (mêmes totaux), +1 champ `truncated`, 0 migration.

### Performance
- Totaux (`totalMinutes`, `billableMinutes`, `totalAmount`) désormais calculés en
  **une requête d'agrégat SQL** (`SUM("minutes")`, `SUM(…) FILTER (WHERE …)`,
  `SUM("minutes"*"hourlyRate") FILTER … / 60`) sur l'ensemble complet du filtre —
  KPI exacts, plus jamais matérialisés en RAM.
- Liste des entrées **plafonnée à 5000 lignes** (`take: REPORT_HARD_CAP + 1`) avec un
  drapeau `truncated` et un bandeau d'avertissement i18n dans l'UI (« affinez vos
  filtres », 5 locales), à l'identique du rapport tickets.
- Deux index ajoutés sur `TimeEntry` : `@@index([createdAt])` (filtre date + tri
  `createdAt DESC LIMIT`) et `@@index([userId, createdAt])` (filtre par agent + tri).

### Architecture
- Découpage en 3 couches comme #18/sidebar : `time-reports.actions.ts` (`"use server"`,
  `requireAuth` + délégation), `time-reports.queries.ts` (`computeTimeReport(db, …)` —
  agrégat `$queryRaw` + `findMany` borné en `Promise.all`), `time-reports.helpers.ts`
  (assemblage **pur** : cap/slice/`truncated`/arrondi, testé en vitest).

### Tests
- 4 tests unitaires (vitest) sur l'assemblage pur (boundaries cap/cap+1, arrondi, set
  vide) + validation par **diff ancien/nouveau sur base réelle** (4 filtres : aucun,
  facturable, par agent, par date — totaux identiques, `entries` identiques sous le cap).
- 0 migration : les index s'appliquent via le `prisma db push` du conteneur `migrate`
  au déploiement.

## [1.11.31] — 2026-05-30

Performance de la sidebar (finding N+1 de l'audit 2026-05-29). Les badges de
comptage par boîte mail (`getSidebarData`) étaient calculés via **4 requêtes SQL
par boîte**, chacune avec une sous-requête corrélée « dernier message », rejouées
toutes les 30 s pour chaque utilisateur connecté — la requête la plus chaude de
l'app, à risque de saturation Postgres. Sortie **inchangée** (compteurs identiques),
0 migration.

### Performance
- **Une seule requête groupée** remplace la boucle `4 × M` : `GROUP BY "mailboxId"`
  + `COUNT(*) FILTER (…)` pour les 4 compteurs (total/non-assignés/miens/spam).
- Le « dernier message » de chaque ticket est résolu via un `LEFT JOIN LATERAL …
  ORDER BY "createdAt" DESC LIMIT 1` **scopé aux boîtes concernées** (index
  `(ticketId, createdAt)`), au lieu d'une sous-requête corrélée rejouée 3×, et sans
  trier toute la table des messages.

### Tests
- 3 tests unitaires (vitest) sur l'assemblage pur + validation par diff
  ancien/nouveau sur base réelle (8 cas couvrant les 4 compteurs et le quirk spam,
  sortie identique).

## [1.11.3] — 2026-05-30

Performance et exactitude des analytics SLA et CSAT (finding #18 de l'audit
2026-05-29). Les rapports de conformité SLA et de satisfaction (CSAT) sont
recalculés via des agrégats SQL au lieu de charger jusqu'à 2000/1000 lignes en
mémoire et d'agréger en JavaScript. Le contrat d'affichage est inchangé ; aucune
migration de base.

### Corrigé
- **KPI faux sur gros volumes** : les anciens plafonds (`take: 2000` pour le SLA,
  `take: 1000` pour le CSAT) calculaient les taux de conformité, moyennes,
  histogrammes et distributions sur un sous-ensemble tronqué des tickets/réponses
  de la période, sans aucun signal. Les agrégats portent désormais sur l'ensemble
  complet de la fenêtre — les chiffres sont exacts quel que soit le volume.
- **Ordre déterministe** des tickets en dépassement SLA (tie-breaker `createdAt`).

### Performance
- Agrégation déplacée en base (`COUNT FILTER`, `GROUP BY`, `AVG`, jointures) :
  plus de matérialisation de milliers d'objets en RAM Node à chaque ouverture des
  pages Analytics SLA / CSAT.

### Tests
- 17 tests unitaires (vitest) sur les couches d'assemblage pures + validation
  par diff ancien/nouveau sur base réelle (sortie identique à isovolume,
  troncature corrigée au-delà du plafond).

## [1.11.21] — 2026-05-30

Correctif d'affichage : la dé-citation des mails entrants devient réellement
efficace dans le fil de tickets (le trim côté affichage existant — v147791 —
ratait des cas et masquait son propre toggle). Non-destructif (le brut reste en
base, toggle « Afficher le message complet »), sans migration ni changement
mail-service.

### Corrigé
- **Réponses courtes jamais tronquées** : le garde-fou abaissé (20 → 1 caractère,
  « vide seulement ») laisse enfin tronquer les réponses courtes (« Merci », un
  numéro) et affiche le toggle — c'était la cause n°1 du « toggle invisible ».
- **Citation Outlook non retirée** : nouveaux marqueurs Outlook Web/Exchange
  (`x_divRplyFwdMsg`, `OutlookMessageHeader`), séparateur desktop `border-top`
  (ancré sur l'unité `pt` pour ne pas toucher les dividers de newsletters/Word),
  et en-têtes allemands (`Von:`/`Gesendet:`). La réponse agent citée par le client
  ne s'affiche plus en doublon.
- **Bannières de passerelle** : la bannière Sophos préfixée est excisée (scan de
  `<div>` équilibré).
- **Périmètre** : le trim s'applique désormais aussi au premier message
  (`INITIAL`), plus seulement aux réponses client.

### Tests
- 19 tests unitaires (vitest) sur le module de dé-citation (marqueurs par vendor,
  garde-fou, bannière, composition, anti-faux-positifs). Validé sur 90 messages
  entrants réels (34/34 réponses client propres).

## [1.11.2] — 2026-05-29

Suite de la localisation (audit 2026-05-29) : code-split i18n côté serveur (#19)
et localisation de la chaîne CSAT destinataire (#11), plus deux correctifs issus
de la revue Codex gpt-5.5/xhigh.

### Ajouté
- **Code-split i18n (#19)** : la locale est désormais résolue côté serveur
  (cookie `tb-locale` → `Accept-Language` → `en`) dans le root layout, le
  dictionnaire actif est passé en props au `I18nProvider`. Les dictionnaires de
  traduction ne sont plus embarqués dans le bundle client (bundle JS allégé,
  locales absentes de `.next/static`). Migration one-shot localStorage → cookie
  pour les utilisateurs existants.
- **Localisation CSAT destinataire (#11)** : l'email d'enquête, l'interstitiel
  de confirmation et la page de remerciement publique respectent la langue de
  l'agent expéditeur, propagée via `&lang=` jusqu'aux pages publiques (sans
  session). 19 nouvelles clés `csat.*` par locale, parité stricte sur les 5.

### Corrigé
- **Injection HTML (CSAT)** : `ticket.subject` (contrôlé par le client) est
  désormais échappé avant interpolation dans le corps HTML de l'email d'enquête.
- **Locale IA (revue Codex P2)** : le triage et l'analyse approfondie lisent la
  locale active via le contexte i18n (cookie) au lieu de `localStorage`
  (clé périmée depuis #19) — l'IA répond dans la langue choisie de l'UI.

## [1.11.1] — 2026-05-29

Campagne de localisation P1 (audit 2026-05-29) : extraction des chaînes
codées en dur vers les 5 locales (FR/EN/DE/ES/IT) sur les écrans clés.

### Ajouté
- Localisation complète de la page de connexion (titre, sous-titre SSO,
  bannière bootstrap, libellés, boutons, erreurs, tagline) et de la cloche
  de notifications, avec temps relatif via `Intl.RelativeTimeFormat`.
- ~50 nouvelles clés i18n par locale, à parité stricte sur les 5 langues,
  couvrant badge SLA, recherche globale, dashboard, axes du graphique
  d'activité, file de tickets et composer.

### Modifié
- `getLicenseWarning` renvoie désormais un code (`expired` /
  `expiresInDays` + `days`) traduit côté composant, au lieu de chaînes
  anglaises codées en dur (audit #10).

### Corrigé
- Mismatch d'hydratation potentiel (React #418) sur le badge SLA après son
  passage en Client Component : le calcul temporel est différé après le
  montage. Findings P2 (cloche non câblée) et P3 (hydratation SLA) de la
  revue Codex gpt-5.5/xhigh corrigés.

### Différé en 1.11.2
- Localisation de la page CSAT publique (résolution de locale
  mailbox/customer, audit #11) et items Perf #18/#19.

## [1.11.0] — 2026-05-29

Release mineure : durcissement sécurité + fiabilité issu de l'audit P1
(batches A + B), revu en deux passes adversariales Codex (gpt-5.5/xhigh).

### Sécurité

- **Frontière d'autorisation** étendue : `getTicketsForMerge`, gestion des tags
  et CRUD clients réservés ADMIN/SUPERVISOR ; `linkCustomerToTicket`,
  `autoLinkCustomer`, `generateKbArticle` scopés par accès au ticket ;
  `shareKbArticle` scopé à la boîte mail de l'agent (anti-spoofing).
- **SSRF du crawler RAG** : blocage des adresses internes/metadata par
  classification d'IP (ipaddr.js), redirections suivies manuellement et
  re-validées à chaque saut, et **validation de l'IP au moment du connect**
  (dispatcher undici) qui ferme la fenêtre de DNS-rebinding.
- **PII → LLM** : redaction (sanitize) des corps de messages avant envoi au
  modèle en triage / deep analysis / résumé ; bloc de connaissances externes
  encadré comme « source non fiable » (anti prompt-injection de second ordre).
- **OAuth** : cache de token et verrou anti-stampede keyés par boîte mail (fin
  de la fuite de jeton cross-tenant) ; invalidation forçant un vrai refresh.
- **Divers** : `email_verified` exigé avant liaison/création de compte Keycloak
  SSO ; identifiant de log d'activation passé en HMAC-SHA256 keyé ; image
  SearXNG épinglée + secret généré ; sanitization du partage KB par e-mail.

### Performance

- Index composite `Ticket [deletedAt, isSpam, createdAt]` sur le hot path de
  la file par défaut.

### Fixed

- `getTickets` : le filtre de boîte mail explicite d'un agent est intersecté
  avec ses boîtes autorisées (au lieu d'être écrasé), sans jamais l'élargir.
- CSAT : top agents agrégés par identifiant (et non par nom, non unique) ;
  taux de réponse borné à 100 %.
- Hydration : heures relatives rendues côté client (fin des avertissements
  React #418 sur la file et le dashboard) ; carte de triage robuste aux
  données malformées.

### Tests

- Harnais **vitest** (mocks NextAuth + Prisma) : 45 tests — autorisations par
  action, verrou anti-fraude, helpers purs (scope mailbox, dates UTC backup,
  log-hash). Les tests `tsx` historiques restent inchangés.

### À vérifier au déploiement

- **SSO Keycloak** : le garde `email_verified` n'est pas testable hors d'un
  Keycloak réel — valider un login SSO sur staging avant la bascule prod, et
  s'assurer que le realm émet bien le claim `email_verified` (sinon les
  comptes sans claim sont refusés).

### Différé (v1.11.x)

- Contrainte unique `messageId` (migration + dédup des données existantes),
  index trigram ILIKE, agrégats SQL SLA/CSAT, code-split i18n, et le batch
  i18n/a11y/produit (localisation d'écrans, navigation clavier, colonne SLA,
  vues sauvegardées).

## [1.10.147802] — 2026-05-29

### Sécurité — Correctifs P0 (suite, re-review Codex gpt-5.5/xhigh)

Une seconde passe de review adversariale (modèle renforcé) avant déploiement a
identifié deux failles supplémentaires de la même famille que le P0, plus une
régression dans le correctif de relève manuelle :

- **OAuth credentials réservés aux ADMIN** : `initiateOAuth` exigeait
  ADMIN/SUPERVISOR — désormais ADMIN seul, comme les autres credentials de
  boîte mail (CWE-915). Un superviseur ne peut plus pointer une boîte vers une
  application OAuth tierce.
- **Création de ticket scopée par boîte** : `createTicket` vérifie désormais
  l'appartenance de l'agent à la boîte ciblée. Sans cela, un agent pouvait
  créer un ticket dans la boîte d'une autre équipe et déclencher un e-mail
  d'accusé envoyé *depuis* cette boîte (CWE-639 / anti-spoofing).

### Fixed

- **Relève manuelle (force-poll)** : la déduplication ignore désormais les
  tickets supprimés (`deletedAt`), alignée sur le listener — le flux de
  récupération « supprimer → marquer non-lu → re-fetch » fonctionne à nouveau
  par cette voie (régression introduite en 1.10.147801).

### Tests

- 2 nouveaux tests d'autorisation (création de ticket hors périmètre, OAuth
  réservé ADMIN). 30 tests vitest au total.

## [1.10.147801] — 2026-05-29

### Sécurité — Correctifs P0 (audit multi-agents)

Renforcement de la frontière d'autorisation intra-application : plusieurs
chemins faisaient confiance à un simple `requireAuth()` là où il fallait un
contrôle de scope mailbox (`assertTicketAccess`) ou de rôle (`requireRole`).

- **IDOR recherche** : `searchTickets` filtre désormais par mailbox pour les
  AGENT (un agent ne voit que les tickets de ses boîtes) ; les ADMIN/SUPERVISOR
  conservent la vue globale. Garde de débordement int4 sur la recherche par
  numéro de ticket.
- **IDOR ré-assignation client** : `changeTicketCustomer` vérifie l'accès au
  ticket avant de réécrire le client et de déclencher un auto-reply.
- **IDOR pièces jointes / verrou** : `/api/attachments/[id]` et
  `/api/tickets/[id]/lock` (POST/GET/DELETE) appliquent le scope mailbox AGENT
  (403 hors périmètre).
- **RBAC règles d'exclusion mail** : les 4 actions de `mailbox-exclusions`
  exigent ADMIN/SUPERVISOR (un AGENT ne peut plus faire disparaître
  silencieusement des mails entrants).
- **CWE-915 création de mailbox** : `createMailbox` réapplique le verrou ADMIN
  sur les champs credentials (hôtes/ports/mots de passe/OAuth), au même titre
  que `updateMailbox` — y compris contre l'envoi de champs dupliqués.
- **Anti-fraude** : `hasFeature()` refuse désormais les fonctionnalités premium
  quand l'instance est `fraud_locked` (le verrou n'était appliqué qu'au cœur).
- **SLA** : `applySlaToTicket` exige authentification + accès au ticket.

### Fixed

- **Relève manuelle (force-poll)** : déduplication par `messageId` (plus de
  tickets/notifications en double en cas de course avec le listener) et le
  threading ne ré-attache plus de réponse à un ticket supprimé (`deletedAt`).
- **Contexte IA** : les brouillons d'agent (`isDraft`) sont exclus du triage,
  de la deep analysis et du résumé (plus de fuite de brouillon dans le LLM).
- **Telegram `/backup`** : les rapports quotidien et hebdomadaire comparent les
  dates en **UTC**, alignés sur l'écriture UTC de `BackupCheck.date` par le
  mail-service (fin des faux `MISSING`/`ERROR` en fuseau ≠ UTC).

### Tests

- Mise en place d'un harnais de tests **vitest** (`apps/web`) avec mocks
  NextAuth + Prisma ; tests d'autorisation par action, du verrou anti-fraude,
  et des helpers purs (scope mailbox, dates UTC du backup). 28 tests vitest +
  helpers Telegram. Les tests `tsx` historiques restent inchangés.

## [1.10.147800] — 2026-05-28

### Changed — Pièces jointes affichées en haut du message

- Dans le fil de conversation, les pièces jointes (trombone + nom + taille +
  badge de scan) sont désormais affichées **en haut du message**, sous les
  badges SPF/DKIM/DMARC et à côté de la ligne « En copie : », au lieu d'être
  reléguées sous le corps. L'agent voit les PJ avant de lire le message.
  Changement UI ciblé dans `conversation.tsx`.

## [1.10.147799] — 2026-05-28

### Added — Reply-all automatique + brouillon de réponse auto-sauvegardé

**Reply-all (CC) sur les réponses**

- Quand un client crée un ticket avec des personnes en **copie (CC)** — ou
  adresse plusieurs équipes en `To` — le composer de réponse **pré-remplit
  désormais le champ CC** avec ces destinataires (vrai reply-all), panneau
  CC/BCC ouvert d'office pour qu'ils soient visibles et **éditables** : l'agent
  peut en retirer une avant d'envoyer (elle ne reçoit alors rien).
- Source = **dernier message entrant** du client (`INITIAL`/`CUSTOMER_REPLY`).
  Exclusions : l'adresse de la mailbox du ticket et l'e-mail du client (déjà
  dans `To`). Parsing `"Nom <email>"` + listes `,`/`;`, dédup insensible à la
  casse. Helper pur `apps/web/src/lib/reply-all-cc.ts` + 15 tests unitaires.
- Backend `addReply` inchangé : le CC reste piloté par l'UI (aucun forçage
  serveur d'une adresse retirée par l'agent).

**Brouillon de réponse auto-sauvegardé**

- Une réponse saisie mais non envoyée est **auto-sauvegardée en brouillon**
  (autosave débouncé 1,5 s + flush au changement d'onglet). Au retour sur le
  ticket — après refresh, navigation, ou depuis un autre poste — le texte
  (et les CC/BCC) est **restauré** dans le composer avec un badge
  **« Brouillon »** qui disparaît à la première modification.
- Implémenté sur l'infra existante `TicketMessage.isDraft` (aucune migration) :
  un brouillon par (ticket, agent), supprimé à l'envoi, purgé après 48 h par le
  scheduler `draft-cleanup` du mail-service.
- Server actions `getReplyDraft` / `saveReplyDraft` / `deleteReplyDraft`.
- Les brouillons sont **exclus partout** où ils pollueraient : fil de
  conversation (`getTicket`), compteur + aperçu de la liste tickets,
  threading `In-Reply-To` (`addReply`, `csat`, `ticket-notify`) et contexte
  LLM du générateur de réponse IA (`ai-service/drafter.ts`).

## [1.10.147798] — 2026-05-28

### Added — Cc / Cci à la création d'un ticket manuel

- Le formulaire **Nouveau ticket** affiche désormais un bouton
  « Ajouter Cc / Cci » dépliant deux champs CC et CCI (même UX que le
  composer de réponse).
- Les adresses saisies sont **copiées sur l'email d'accusé de réception**
  envoyé au client à la création (auparavant `cc`/`bcc` étaient forcés à
  `null`) et stockées sur le message initial du ticket — donc visibles dans
  le fil de conversation.

## [1.10.147797] — 2026-05-26

### Fixed — Assistant IA / Codex : erreur `refresh_token_reused` (401)

- **Cause racine** : le token OAuth Codex (`auth.json`) est tourné **dans le
  conteneur** quand le token d'accès expire — les refresh tokens OpenAI sont
  à usage unique (rotation). La copie host (`/root/.codex`, bind-mount RO)
  n'est jamais tournée. La boucle de re-sync de `docker-claude-init.sh` faisait
  un `cp -a` **inconditionnel** toutes les 5 min, écrasant le token fraîchement
  tourné du volume par la copie host **déjà consommée** → la prochaine
  génération IA rejouait un refresh token mort → `401 refresh_token_reused`.
- **Correctif** : passage à `cp -au` (update-only basé sur la mtime) pour la
  synchro Codex host→volume, au démarrage et dans la boucle. Un token tourné
  par le conteneur (volume plus récent) est désormais préservé ; un re-login
  host (host plus récent) ou un premier boot (volume vide) se propage toujours.
  Le conteneur devient auto-suffisant pour la rotation Codex.
- **Récupération** sur une instance déjà cassée : `codex login` sur le host
  puis `docker compose up -d --force-recreate ai-service web`.

## [1.10.147796] — 2026-05-26

### Fixed — Réponses ticket bloquées par le WAF (PowerShell, scripts, regex)

- **Cause racine** : sur une instance derrière Sophos XGS + Cloudflare, une
  réponse d'agent contenant un script technique (PowerShell
  `Get-WinEvent -FilterHashtable @{…} | Where-Object { $_.Id -in … }`,
  bash, regex avec `|` `\.`, SQL pédagogique) matche les règles managées
  OWASP CRS (RCE/XSS/SQLi) et le POST de la Server Action est 403 AVANT
  d'atteindre le container — aucune trace serveur, et l'UI ne signalait
  rien (l'agent croyait son message parti). Même cause que la sauvegarde
  KB corrigée en v1.10.147795.
- **Fix applicatif** (les règles WAF ne sont PAS relâchées) : nouveau
  helper partagé `apps/web/src/lib/waf-encoding.ts`
  (`encodeBodyForWaf` / `decodeBodyFromWaf`, préfixe `b64:`). Le contenu
  rédigé par l'agent est base64-encodé côté client et décodé côté serveur,
  rendant le payload opaque au pattern-matching du WAF. Appliqué à la
  **réponse publique** (`addReply`), la **note interne** (`createNote`) et
  la **création de ticket** (`createTicket`). Le KB réutilise désormais ce
  même helper. DB inchangée (HTML/texte clair), rendu identique,
  backwards-compatible avec les payloads non préfixés.
- **Remontée d'erreur** : si un POST échoue malgré l'encodage (autre
  pattern WAF, timeout, réponse non exploitable), un toast explicite
  « Envoi bloqué — … » s'affiche désormais sur la réponse, l'envoi-et-
  clôture, la note interne (qui avalait toute erreur silencieusement) et
  la création de ticket.

## [1.10.147795] — 2026-05-25

### Fixed — Sauvegarde KB bloquée par le WAF après reformatage IA

- **Cause racine** : le markdown généré par Claude (`/api/ai/kb/format`)
  utilise les callouts GitHub-style `> [!WARNING]`, `> [!TIP]`,
  `> [!INFO]`. La règle managée Cloudflare WAF "XSS/Injection" matche le
  pattern `[!XXX]` et 403 le POST Server Action AVANT qu'il n'atteigne
  le container — donc aucune trace côté serveur, juste un toast
  générique côté UI. Reproduisible aussi en collant manuellement le
  contenu IA dans un article neuf.
- **Fix** : `apps/web/src/app/(dashboard)/kb/[id]/article-editor.tsx`
  encode désormais le `content` markdown en `b64:<base64>` avant le
  POST. `apps/web/src/lib/actions/kb.actions.ts` (createArticle +
  updateArticle) détecte le préfixe `b64:` et décode transparently.
  Le DB stocke toujours du markdown clair, le rendu reste identique.
  Backwards-compatible avec les payloads non préfixés.

### Fixed — Server Actions 403 + duplicate Tiptap Link

- `experimental.serverActions.allowedOrigins` lit désormais
  automatiquement le host de `APP_URL` (plus besoin de config manuelle
  derrière un reverse proxy). Override possible via
  `SERVER_ACTIONS_ALLOWED_ORIGINS=host1,host2:port`.
- `experimental.serverActions.bodySizeLimit` passé à 2MB pour les
  articles KB longs.
- `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` (env var) passée au build via
  Docker build arg → IDs Server Actions stables entre rebuilds. Sans
  cette clé, chaque redeploy cassait tous les onglets ouverts (403
  "Failed to find Server Action" jusqu'au hard-refresh).
- `KbEditor` désactive explicitement le Link de StarterKit Tiptap v3
  pour ne plus avoir le warning `Duplicate extension names: ['link']`.
- Toast d'erreur du save expose le message Next.js réel au lieu du
  générique "Échec de l'enregistrement".

## [1.10.147793] — 2026-05-25

### Added — KB : bouton « ✨ Améliorer avec IA » dans l'éditeur d'article

- L'éditeur Tiptap (v147792) restait passif : un texte brut collé restait
  brut. L'utilisateur s'attendait à ce que la KB **retravaille** la mise
  en page. Ajout d'un bouton dégradé violet/fuchsia à droite de la
  toolbar qui POST le contenu courant à `/api/ai/kb/format` (proxy →
  `ai-service` `/kb/format`).
- `apps/ai-service/src/kb/formatter.ts` — appelle Claude avec un prompt
  système strict : structure `## 🔍 Contexte / ## 📋 Diagnostic /
  ## ✅ Procédure (### Étape N : <titre action-orienté>) / ## 💡 Conseils`,
  insertion de callouts `> [!TIP/WARNING/INFO]` aux bons endroits,
  préservation littérale des valeurs techniques (commandes, durées,
  paths), pas d'invention. Réutilise le model setting `ai.smartReplyModel`.
- `apps/ai-service/src/routes/kb.ts` — route `POST /kb/format`, garde-fou
  50 000 chars, registered dans `server.ts`.
- `apps/web/src/app/api/ai/[...path]/route.ts` — ajout de `kb/format` à
  l'allowlist (rate-limit AI standard appliqué).
- `apps/web/src/components/kb/kb-editor.tsx` — handler `enhanceWithAI` :
  confirm avant écrasement d'un article déjà structuré, loading spinner,
  toast success/error, conversion MD→HTML pour réinjecter dans Tiptap.

## [1.10.147792] — 2026-05-25

### Fixed — Génération KB depuis ticket résolu : HTML brut + résolution tronquée

- **Cause racine** : `generateKbArticle()` concaténait `m.bodyText || m.body`
  pour tous les messages du ticket, puis coupait à 300 caractères. Quand
  `bodyText` était vide (CUSTOMER_REPLY HTML mal parsé), le `body` HTML
  brut (`<html><head>…`) atterrissait dans l'article ; la coupure à 300
  caractères mangeait toutes les `Step 1..10` rédigées par l'agent ;
  enfin les brouillons (`isDraft=true`) polluaient la source.
- **Fix** : trois helpers isolés et testés
  (`apps/web/src/lib/kb-generator/content.ts`) :
  - `messageToPlainText(body, bodyText)` — strip HTML, decode entities,
    coupe signatures (`--`, `Sent from my iPhone`, etc.) ;
  - `pickResolutionSourceText(messages)` — prend la dernière REPLY agent
    non-draft (puis FORWARDED, puis INITIAL en dernier recours) ;
  - `buildFallbackResolutionMarkdown(text)` — détecte `Step 1:` … `Step N:`
    et émet `### Étape N : <première phrase>` + corps complet, sans
    troncature. Accepte aussi les marqueurs français `Étape N`.
- 19 tests unitaires (`apps/web/tests/kb-generator-content.test.mjs`),
  exécutables via `npx tsx --test`.

### Changed — KB : éditeur WYSIWYG Tiptap remplace le textarea Markdown

- L'écran d'édition d'article (`/kb/[id]`, `/kb/new`) figeait sur de longs
  contenus (re-render Markdown synchrone à chaque keystroke) et imposait
  la saisie Markdown brute aux agents non-développeurs.
- Nouveau composant `KbEditor` (`apps/web/src/components/kb/kb-editor.tsx`) :
  Tiptap 3 avec toolbar visuelle (B/I/Code, H2/H3, listes, citation, lien,
  + boutons Conseil/Attention/Info qui insèrent les callouts
  `> [!TIP/WARNING/INFO]`). Persistance toujours en Markdown :
  conversion `marked` (MD→HTML) à l'ouverture, `turndown` + plugin GFM
  (HTML→MD) débouncé à 250ms à la sortie. Les callouts existants
  survivent l'aller-retour et restent stylisés en lecture.
- Dépendances ajoutées : `marked@18.0.3`, `turndown@7.2.4`,
  `turndown-plugin-gfm@1.0.2`, `@types/turndown@5.0.6` (toutes
  ≥ 7 jours, quarantaine supply-chain OK).

## [1.10.147790] — 2026-05-21

### Fixed — Rapport backup quotidien : task hebdomadaire toujours "✅" tous les jours

- **Cause racine** : `runBackupCycle` (mail-service) ré-écrit
  `BackupCheck.checkedAt = now()` à chaque cycle (toutes les ~5 min)
  pour TOUTE ligne dont l'email correspondant est encore dans la
  fenêtre IMAP de 192h. Le rapport quotidien filtrait par
  `checkedAt >= now - 24h` → la ligne SUCCESS du vendredi 15/05
  apparaissait comme « fraîche de moins de 24h » tous les jours du
  samedi au vendredi suivant. Symptôme uniquement visible sur les
  tasks à planning hebdomadaire (vendredi-only) car les tasks
  Lun-Ven avaient toujours une ligne récente légitime qui poussait
  la stale via la dédup « dernier check par task ».
- **Fix** : le rapport ne filtre plus par `checkedAt` mais par
  `BackupCheck.date` (= date cible du backup, déterministe via
  `determineCheckDate()`). Pour chaque task activée, calcul de
  `lastCompletedScheduledDate(task, now)` = dernier jour planifié
  dont la fenêtre est fermée. Si cette fenêtre s'est fermée dans les
  dernières 24h → on remonte le `BackupCheck` correspondant et on
  rend son statut. Sinon → ligne `NOT_SCHEDULED` (➖).
  Résultat concret : SBTP EXT-USB (Vendredi 12-18) apparaît
  ✅/⚠️/❌ uniquement dans le rapport du **samedi matin** ; Lun-Dim
  → ➖ « SBTP EXT-USB — -- ». Mon-Fri overnight (21h-06h) apparaît
  Mar-Sam ; Lun/Dim → ➖.
- **Défensif** : Step 1 ne ré-écrit plus la ligne BackupCheck si
  rien n'a changé matériellement (status/emailSubject/found/detail
  identiques). Ceinture + bretelles : même si quelqu'un réintroduit
  un filtre `checkedAt` plus tard, l'aliasing ne pourra plus se
  manifester. Économise aussi ~7 writes inutiles par task par cycle.
- L'emoji `➖ NOT_SCHEDULED` était déjà supporté côté telegram-bot
  depuis v1.10.147783, aucun changement requis côté notif.

## [1.10.147789] — 2026-05-21

### Fixed — Visibilité de la fusion de tickets

- **Bandeau persistant sur le ticket cible** quand un merge a eu lieu :
  la page ticket lit les activités `tickets_merged` déjà chargées et
  affiche en tête un encart violet listant tous les tickets sources
  absorbés (« Tickets fusionnés — Ce ticket a absorbé #32 « Dylan » »).
  Reproduit le bug constaté en prod sur les tickets #29 / #32 :
  la fusion fonctionnait en base, mais l'UI n'affichait aucune trace
  visible côté ticket cible une fois la page rouverte.
- **Ligne dédiée dans le flux d'activité** : le composant
  `ActivityFeed` (apps/web/src/app/(dashboard)/tickets/[id]/activity-feed.tsx)
  ne savait pas rendre `action === "tickets_merged"` → la ligne tombait
  silencieusement dans le fallback générique. Ajout d'une branche
  `case "tickets_merged"` qui formatte la liste `mergedTickets`
  (`{ number, subject }[]`) et utilise les nouvelles clés i18n
  `activity.ticketsMerged` / `activity.ticketsMergedInto`.
- **Redirection 302 depuis le ticket source soft-supprimé** vers le
  ticket cible, avec toast explicite « Le ticket #N a été fusionné dans
  celui-ci. ». Le modèle `Ticket` gagne un champ
  `mergedIntoTicketId String?` (nullable, indexé) renseigné par
  `mergeTickets()` dans la même transaction que `deletedAt`. Sans ce
  champ, ouvrir l'URL d'un ticket source soft-supprimé rendait une
  page vide (messages/activities transférés vers la cible) sans
  indication de la fusion.
- Traductions ajoutées dans les 5 locales (fr/en/de/es/it) :
  `activity.ticketsMerged`, `activity.ticketsMergedInto`,
  `tickets.mergedBanner.title`, `tickets.mergedBanner.body`,
  `tickets.mergedRedirect.toast`, plus 3 clés
  `tickets.mergedSource.*` réservées pour un fallback futur.

### Schema

- `Ticket.mergedIntoTicketId String?` + `@@index([mergedIntoTicketId])`.
  Migration appliquée par le service `migrate` au démarrage
  (`prisma db push`). Aucune donnée existante n'est rétro-fillée :
  les tickets fusionnés avant cette release continueront d'afficher
  une page vide quand on ouvre leur URL source (l'activité
  `tickets_merged` côté cible, elle, reste visible grâce au bandeau).

## [1.10.147788] — 2026-05-20

### Security — Supply chain hardening (Phase 1)

- **Toutes les images Docker sont maintenant pinées par tag de version
  explicite.** Le `docker-compose.yml` public référençait jusqu'ici
  `ghcr.io/kr1s57/ticketbrainy-{web,ai,mail,telegram,migrate}:latest`
  pour les 5 services applicatifs, plus `searxng/searxng:latest` pour
  le moteur de recherche du builder RAG. Conséquence : un `docker
  compose pull` pouvait télécharger silencieusement une image que
  l'opérateur n'avait jamais validée (régression amont, ou pire,
  compromission de la chaîne d'approvisionnement). Le compose pin
  maintenant chaque image TB à la version exacte de la release
  (`:1.10.147788` ici) et SearXNG à son digest SHA-256
  (`@sha256:b5d4892d…`). Le workflow opérateur reste identique
  (`git pull && docker compose pull && docker compose up -d`) : le
  `git pull` synchronise le compose à la nouvelle version épinglée,
  puis `docker compose pull` télécharge exactement cette version.
  Aucune perte de reproductibilité, plus de pull silencieux d'image
  inconnue.
- **`scripts/release-lockstep.sh` réécrit automatiquement les tags
  épinglés du compose public à chaque release** (`sed` sur les 5
  lignes `ghcr.io/kr1s57/ticketbrainy-*`). Garantit que le `git pull`
  côté client tire bien la version qui vient d'être poussée, et qu'on
  ne dérive plus jamais sur des `:latest` non synchronisés.
- **Avertissement explicite au boot quand `SECURITY_ALLOWLIST_BYPASS=true`.**
  Le bypass break-glass de l'allowlist IP admin / geo-block / paramètres
  sécurité écrivait déjà une ligne dans le journal d'audit à chaque
  utilisation, mais ne signalait rien lors du démarrage du conteneur
  web. `apps/web/src/instrumentation.ts` affiche maintenant une
  bannière `console.warn` encadrée si la variable est active — visible
  immédiatement dans `docker logs aidesk-web-1`. Aucun impact
  fonctionnel sinon (la variable reste vide par défaut).

## [1.10.147787] — 2026-05-20

### Added

- **Visibilité des destinataires en copie (CC) sur les tickets.** Quand
  un client envoie un mail à l'helpdesk avec plusieurs personnes en
  copie, le ticket est désormais créé en conservant la liste complète
  des CC, et chaque message du fil affiche une ligne « En copie : … »
  sous l'en-tête expéditeur/date. Avant ce patch, la colonne
  `TicketMessage.cc` existait en base mais n'était jamais peuplée :
  `apps/mail-service/src/imap/parser.ts` n'extrayait que `from` et `to`
  depuis `mailparser`, et `apps/mail-service/src/imap/listener.ts`
  créait les messages INITIAL et CUSTOMER_REPLY sans `cc`/`bcc`. Le
  parser expose maintenant `cc` et `bcc` (typés comme `to`), le
  listener calcule la chaîne via `buildCcString()` (déduplication +
  exclusion de la mailbox et de l'expéditeur pour éviter le bruit) et
  `apps/web/src/app/(dashboard)/tickets/[id]/conversation.tsx` rend le
  bloc CC discrètement quand il est présent. Rétro-compatible : les
  anciens tickets dont la colonne `cc` est `NULL` ne montrent rien.
  Clé i18n `tickets.message.cc` ajoutée pour les 5 langues.

## [1.10.147786] — 2026-05-20

### Fixed

- **Régression critique — Notifications "Nouveau ticket" muettes pour
  les tickets créés via l'UI web.** Reproduit en prod : un agent crée
  un ticket à la main pour un client (appel téléphonique, mail vu dans
  Outlook avant que l'IMAP polle), aucun agent ne reçoit la notif email
  ni in-app ni Telegram. Seul l'accusé de réception au client part. La
  fan-out vivait uniquement dans `apps/mail-service/src/imap/listener.ts`
  et `notifyNewTicket()` côté web était défini mais jamais appelé (et
  cassé : `publishMailJob` avec `mailboxId: ""` faisait crasher
  `getTransporter` dans le mail-service). Réécriture de
  `notifyNewTicket()` pour mirror le bloc du listener (subscribers +
  fallback admins/supervisors, `mail:outgoing` par destinataire avec
  vrai `mailboxId`/`from`, `db.notification.createMany`, publish Redis
  `ticket:new` pour Telegram), et appel ajouté dans :
  - `apps/web/src/lib/actions/ticket.actions.ts` (`createTicket`) —
    chemin manuel UI.
  - `apps/web/src/lib/actions/mailbox-fetch.actions.ts` — chemin
    force-poll côté web (bypass mail-service).

## [1.10.147785] — 2026-05-19

### Fixed

- **Captures d'écran collées dans une réponse : enfin visibles dans le
  fil du ticket.** Depuis l'ajout du paste-from-clipboard (v1.10.147765),
  le client recevait bien la pièce jointe mais l'image n'apparaissait
  pas dans le bubble de réponse côté agent. Deux bugs en cascade :
  1. `html-sanitize.ts` n'autorisait que les `<img src="/api/uploads/…">`
     et `data:image/…` ; le tag `<img src="/api/attachments/view/drafts/…">`
     inséré par Tiptap était strippé avant stockage. Ajout de
     `/api/attachments/view/` à l'allowlist.
  2. `extractInlineImages` comparait l'URL du `<img>` (qui pointe sur
     `drafts/<userId>/<uuid>.<ext>`) à `Attachment.storagePath` (qui
     pointe sur `messages/<msgId>/<uuid>.<ext>` après le `linkDraftAttachments`),
     donc aucun match → aucune réécriture `cid:` → aucune inline image
     dans le mail sortant. `linkDraftAttachments` renvoie désormais
     `originalPath` (le chemin draft pré-déplacement) et `extractInlineImages`
     matche en priorité dessus.

  Résultat : la capture est désormais (a) visible dans le fil de
  conversation TB via le rewrite `cid: → /api/attachments/<id>`,
  (b) embedée inline dans l'email reçu par le client (et non plus
  envoyée comme PJ séparée), (c) toujours téléchargeable depuis la
  liste des PJ du ticket.

## [1.10.147784] — 2026-05-19

### Fixed

- **Sidebar mailbox : le dépliage ne se réinitialise plus en cliquant
  sur un ticket.** Les sets `expandedMailboxes` et `userCollapsed` sont
  désormais persistés en `localStorage` (`tb.sidebar.expanded` /
  `tb.sidebar.collapsed`) et hydratés via `useEffect` après mount pour
  éviter une mismatch SSR/CSR (anti React #418). L'auto-expand sur
  activité respecte les replis explicites de l'utilisateur : une boite
  fermée manuellement reste fermée même si un nouveau mail arrive,
  jusqu'à ce que l'utilisateur la rouvre.
- **Collision tickets : le lock d'édition ne peut plus être volé.**
  Bug : le POST `/api/tickets/[id]/lock?mode=editing` écrasait
  inconditionnellement `editingBy`. Conséquence : si l'agent A était
  en train de rédiger et que l'agent B ouvrait le même ticket (et
  qu'un événement Tiptap — paste, draft IA, focus — déclenchait
  `startEditing` chez B), A se voyait bloqué avec l'overlay « un autre
  agent est en cours d'édition ». Le serveur vérifie maintenant que
  le lock est libre / périmé / déjà détenu par l'appelant avant
  d'overwrite, sinon il renvoie **409** + identité du titulaire.
  Côté client, `useEditingLock.startEditing` lit le 409 et bascule le
  composer en read-only (Tiptap `editable: false`, overlay
  « Agent X en cours d'édition ») au lieu de démarrer le heartbeat.
  Le heartbeat lui-même revalide à chaque cycle et abandonne s'il
  perd la propriété.

## [1.10.147783] — 2026-05-19

### Fixed

- **Rapport backup Telegram : doublons par tâche (6-7 lignes par job).**
  Bug introduit en v1.10.14778 : la query filtrait sur
  `checkedAt: last 24h`, or le Step 1 du polling met à jour `checkedAt`
  sur **tous** les checks historiques (jusqu'à 8 jours) à chaque cycle
  pour les emails qui matchent. Résultat : tous les checks historiques
  remontaient dans le rapport, dupliqués par tâche. Corrigé : on liste
  toutes les tasks actives, puis pour chaque task on garde le check
  le plus récent (Map de dédup côté mail-service).
- **Rapport backup : format restauré à celui que les admins
  connaissent.** Header avec jour en français (`lundi 18/05/2026`),
  séparateur `━━━`, ligne par tâche au format
  `<emoji> <taskName> — <sujet email tronqué> (HH:MM)`, ligne `--`
  pour les tâches sans email du jour, séparateur de fin, résumé
  `Résultat: X/Y ✅ | Z/Y ⚠️ | W/Y ❌`.
- **Tâches sans check du jour désormais visibles.** Avant cette
  version, une tâche enabled sans email récent disparaissait du
  rapport. Désormais elle apparaît en `⚪ <taskName> — --`.

### Added

- **Bot Telegram : log explicite des erreurs 409 Conflict.** Si une
  autre instance polle avec le même token (vieux container, webhook
  actif), le bot log un message clair pointant vers `docker ps |
  grep telegram` et `getWebhookInfo`. Au démarrage, on appelle aussi
  `deleteWebHook` pour éliminer un webhook stale qui causerait le 409.

## [1.10.147782] — 2026-05-19

### Fixed

- **Bot Telegram : aucune notification ne partait quand `allowedChatIds`
  était saisi via l'UI.** L'UI envoyait une string brute
  (`"1602363121, 9999"`) mais le bot ne lisait que les arrays — l'envoi
  était silencieusement coupé. Corrigé des deux côtés :
  - Côté web : `saveTelegramConfig` normalise la string en
    `string[]` avant `db.setting.upsert`.
  - Côté bot : `parseChatIds` accepte string ou array (split sur
    virgules + espaces).
- **Toggle Telegram impossible à désactiver quand la valeur stockée
  était un boolean legacy.** Le code lisait
  `routing[key]?.enabled ?? true` — sur un boolean `false`, ça
  retournait `true` (impossible à éteindre). Désormais `parseRoutingFlag`
  reconnaît à la fois `boolean` (legacy) et `{enabled: bool}` (nouveau
  schéma).
- **Rapport backup quotidien : ré-émission sur restart du container.**
  Le drapeau « déjà tiré aujourd'hui » était en mémoire — chaque
  restart du `mail-service` le reset, donc le rapport pouvait repartir
  plusieurs fois. Persisté maintenant dans Redis avec `SET NX` atomique
  + TTL 48h. Plus de doublons.
- **`bot.sendMessage(...).catch(() => {})` silencieux.** Toute erreur
  Telegram (token invalide, chatId interdit, MarkdownV2 mal échappé)
  était avalée. Les trois subscribers loggent maintenant
  `console.warn` avec le message d'erreur.

### Refactored

- Factorisation de `getNotificationTargets()`, `isRoutingEnabled()` et
  `getTicketRouting()` dans `apps/telegram-bot/src/lib/telegram-config.ts`.
  Les trois subscribers (backup, ticket, security) utilisent maintenant
  la même implémentation robuste.

## [1.10.147781] — 2026-05-19

### Changed

- **Heure du rapport backup Telegram accessible depuis Paramètres →
  Telegram.** Le sélecteur de l'heure d'envoi (jusqu'ici uniquement
  dans Paramètres → Email backup) est désormais aussi visible juste
  sous le toggle « Rapports de backup », là où on l'attend. La donnée
  reste stockée dans `backup-email.checkTime` — les deux pages
  modifient le même paramètre. i18n fr/en/de/es/it.

## [1.10.14778] — 2026-05-19

### Changed

- **Notifications backup Telegram — un seul rapport quotidien groupé.**
  Plus aucune alerte individuelle au fil de l'eau : le bot publie un
  message unique à l'heure configurée (Settings → Email backup →
  « Heure du rapport Telegram »), avec emoji par statut et bloc
  Échecs / Avertissements / Réussis. Auto-création de tickets sur
  ERROR/MISSING conservée. La fenêtre du rapport couvre les dernières
  24h (capture les backups qui traversent minuit).
- **Fuseau horaire local pour le scheduler.** Ajout de
  `TZ=${TZ:-Europe/Paris}` sur `mail-service` et `telegram-bot` dans
  `docker-compose.prod.yml` + nouvelle variable `TZ` dans
  `.env.example`. L'heure choisie en UI est interprétée dans le fuseau
  du serveur (et non plus en UTC).

### Added

- **Notifications Telegram « Nouveau ticket » fonctionnelles** —
  publication d'un canal Redis `ticket:new` à la fois côté
  `mail-service` (mails entrants) et côté web (`engine.notifyNewTicket`,
  tickets créés via UI/API). Le bot souscrit et envoie un message
  formaté (sujet, expéditeur, boîte, extrait, lien direct).
- **Sélecteur de boîtes mail pour les notifications Telegram
  « Nouveau ticket »** : Settings → Telegram → toggle « Nouveaux
  tickets » affiche maintenant une liste de cases à cocher des boîtes
  actives. Aucune case cochée = toutes les boîtes. Persisté dans
  `routing.ticket_new = { enabled, mailboxIds[] }`.



### Reverted

- **Retour à l'auto-reload du `RSCErrorBoundary`** après la session
  diagnostique de v1.10.147772. Le build diagnostic a permis
  d'identifier la cause exacte : `Error: Connection closed.` lors
  du streaming RSC d'une page ticket, et **pas** un mismatch
  d'hydratation comme on l'avait supposé. C'est Cloudflare qui
  coupe ou corrompt le stream RSC en transit (suspects probables :
  Email Obfuscation, Auto Minify, Rocket Loader — chacun peut
  corrompre le framing texte d'un payload streamé).

  Le boundary retrouve son comportement initial (full document
  reload silencieux sur erreur, anti-boucle à 5 s), donc l'UX
  redevient celle de toujours : flash bref puis le ticket
  s'affiche. **Le bug de fond reste à fixer côté Cloudflare**
  (voir notes ci-dessous), mais on ne dégrade plus l'UX avec
  l'écran rouge diagnostic.

### Notes opérationnelles

Pour éliminer définitivement le `Error: Connection closed.` côté
production, désactiver depuis le **dashboard Cloudflare** (zone
`ticketbrainy.com`) :
- **Security → Settings → Scrape Shield → Email Address
  Obfuscation : Off**
- **Speed → Optimization → Auto Minify : tous Off** (HTML, CSS, JS)
- **Speed → Optimization → Rocket Loader : Off**
- **Speed → Optimization → Brotli** peut rester ON (compression
  pure, ne touche pas au framing)

L'application envoie déjà `Cache-Control: no-transform` via
`middleware.ts` mais CF n'honore pas tous les "no-transform" pour
ses features Apps/Scrape-Shield — il faut passer par le dashboard.

## [1.10.147772] — 2026-05-18

### Changed

- **Build diagnostique — `RSCErrorBoundary` n'auto-reload plus,
  affiche le message + stack + composant stack à l'écran.** Le
  bouton « Reload » qui apparaissait brièvement à l'ouverture de
  certains tickets persistait malgré les patches v1.10.147768,
  v1.10.147769 (hydration mismatch text + HTML). Le boundary
  attrapait toujours une erreur mais le reload auto effaçait la
  trace avant qu'on puisse la lire. Cette release retire le
  reload automatique et affiche directement à l'écran le message
  d'erreur, la stack JS et le component stack React. Le bouton
  Reload reste disponible pour un déclenchement manuel. À retirer
  dès que la vraie cause aura été identifiée et corrigée — c'est
  une release diagnostic temporaire.

## [1.10.147771] — 2026-05-18

### Fixed

- **`/api/proxy-image` retournait des 502 dans la console pour les
  logos cassés dans les signatures clients.** Quand un mail entrant
  embarque un logo société hébergé sur un serveur HTTP qui ne répond
  plus / refuse / renvoie une page d'erreur (cas le plus fréquent :
  domaines OVH/hosting compromis, certificats expirés, mauvais
  Content-Type), la route proxy renvoyait un `502 Bad Gateway` et
  laissait le navigateur afficher une icône d'image cassée. Effet
  visible : sur certains tickets (ceux qui contiennent une signature
  client cassée), la console DevTools affichait
  `GET https://…/api/proxy-image?url=… 502 (Bad Gateway)`,
  parfois confondu avec un bug de l'application.

  Fix : la route renvoie désormais une **image PNG transparente
  1×1 avec status 200** au lieu du 502/415/413 dans tous les cas
  d'échec upstream (fetch failed, hostname banni, content-type non
  image, redirect trop long, taille excessive). L'agent voit le
  contenu de l'email sans le logo mort, plus aucune erreur console
  ne pollue le diagnostic. Les bytes du placeholder sont cachés
  côté navigateur pendant 24 h (`Cache-Control: private, max-age=86400`)
  pour qu'un upstream mort ne soit pas re-sondé à chaque chargement
  de la page. Les en-têtes `X-Proxy-Status: placeholder` et
  `X-Proxy-Reason: …` restent disponibles pour debugger si besoin.

  Note : seul le cas « image inaccessible » est concerné. Les vraies
  réponses image valides continuent à passer en `200` avec leur
  Content-Type natif et leur cache de 1 h habituel.

## [1.10.14777] — 2026-05-18

### Fixed

- **Listes à puces / numérotées des réponses agent perdues dans
  l'aperçu du ticket (mais correctes dans l'email reçu par le
  client).** Quand un agent répondait avec une liste à puces dans
  l'éditeur Tiptap (`<ul><li>point 1</li><li>point 2</li></ul>`),
  l'aperçu du ticket affichait juste les items sur des lignes
  successives, sans puces ni indentation :
  ```
  point 1
  point 2
  point 3
  ```
  alors que le client recevait l'email avec les puces correctement
  formatées. Cause : `getDisplayHtml()` dans
  `apps/web/src/app/(dashboard)/tickets/[id]/conversation.tsx`
  retombait sur `bodyText` (texte brut, sans balises) pour les
  messages `REPLY` / `AUTO_REPLY` — un héritage de l'époque où
  l'ancien composer ajoutait un wrapper template HTML autour de
  la réponse. Depuis la migration vers Tiptap (v1.10.147765), le
  `body` stocké est de l'HTML propre sans wrapper, et la fallback
  texte n'a plus de raison d'être.

  Fix : `getDisplayHtml()` rend désormais le `body` HTML pour les
  replies agent, exactement comme pour les messages clients. La
  fallback `bodyText` est conservée uniquement pour les très
  vieux replies stockés sans HTML (avant Tiptap). Ajout aussi
  d'une routine `rewriteCidImages()` qui mappe les références
  `cid:att-<id>@ticketbrainy` (utilisées pour les images inline
  dans les emails sortants) vers `/api/attachments/<id>` pour
  que les images insérées dans une réponse apparaissent
  correctement dans l'aperçu — sans cette routine, le navigateur
  affichait une icône d'image cassée parce que le protocole
  `cid:` n'est compréhensible que par les clients email.

  Impact : les listes à puces, listes numérotées, en-têtes,
  blockquotes, gras/italique, liens et images inline des
  réponses agent s'affichent maintenant correctement dans
  l'aperçu du ticket. Aucun changement côté email envoyé au
  client (qui marchait déjà).

## [1.10.147769] — 2026-05-18

### Fixed

- **Page blanche + Reload auto à l'ouverture d'un ticket — patch 2/2
  (vraie cause racine identifiée).** Le patch v1.10.147768 avait
  éliminé les mismatches de **texte** (dates, traductions) mais
  l'erreur React #418 persistait en prod sous la forme
  `args[]=HTML` (mismatch de **structure HTML**, pas de texte).
  L'origine était dans `apps/web/src/app/(dashboard)/tickets/[id]/collapsible-ai-panel.tsx`
  : l'état initial du panneau IA collapsable lisait `localStorage`
  dans l'initializer d'un `useState(() => …)` avec un test
  `typeof window !== "undefined"`. Conséquence :
  - **Côté serveur** (SSR, pas de `window`) : `collapsed = false`
    → le composant rendait `{!collapsed && children}` → ENFANTS
    PRÉSENTS dans le HTML envoyé.
  - **Côté client** (hydratation) : `localStorage` était lu → si
    l'utilisateur avait déjà replié le panneau dans une session
    précédente, `collapsed = true` → `{!collapsed && children}`
    devenait `false` → ENFANTS ABSENTS dans l'arbre React du
    client.

  Résultat : le DOM serveur (avec les enfants) ne correspondait pas
  au DOM client (sans les enfants) → React détectait un mismatch
  de structure HTML → erreur #418 (`args[]=HTML`) → `RSCErrorBoundary`
  attrapait et déclenchait un `window.location.reload()`. Le
  symptôme « page blanche puis Reload puis ticket s'affiche »
  correspondait exactement à ce cycle.

  Fix : passer à un état initial déterministe (`useState(false)`
  partout) et déférer la lecture du `localStorage` dans un
  `useEffect()` qui s'exécute après le mount. Le serveur et le
  client rendent désormais le même HTML à l'hydratation ; si
  l'utilisateur avait collapsé le panneau, il se replie après le
  premier render (léger flash acceptable, exclusif à la première
  visite de la session).

  Note pour le futur : c'est un **anti-pattern** classique. Ne
  jamais lire `localStorage` / `sessionStorage` / `window.*` dans
  un initializer `useState(() => …)` d'un composant rendu côté
  serveur. Toujours passer par un `useEffect` post-mount. La
  même remarque vaut pour le `useI18n()` (déjà couvert en
  v1.10.147768 via `suppressHydrationWarning` ciblé).

## [1.10.147768] — 2026-05-18

### Fixed

- **Ouverture d'un ticket : page blanche + bouton « Reload » qui rafraîchit
  automatiquement avant d'afficher le ticket.** Symptôme observé surtout
  depuis la mise en service du WAF Sophos XGS : au clic sur un ticket
  (navigation client RSC), la page s'affiche en blanc pendant 1-2
  secondes, un bouton « Reload » apparaît brièvement puis le ticket
  finit par s'afficher. Cause : la console DevTools révèle
  `Uncaught Error: Minified React error #418` — c.-à-d. un **mismatch
  d'hydratation** entre le HTML rendu par le serveur et le HTML
  réhydraté par React côté client.

  Sources du mismatch identifiées sur la page ticket :
  - **`useI18n()` charge le locale depuis `localStorage` après le
    mount.** Le SSR rend donc systématiquement avec `locale = "en"` /
    `dateLocale = "en-GB"`, puis le client repasse en `"fr"` /
    `"fr-FR"` au premier `useEffect`. Tous les `Intl.DateTimeFormat`
    et toutes les chaînes `t("…")` produisent un texte différent
    SSR vs client → React jette #418. La page ticket est la plus
    touchée parce qu'elle empile des dizaines de dates formatées
    (chaque message, sidebar, activity feed) et de chaînes
    traduites.
  - **`relativeTime()` (activity-feed, notes-panel) compare
    `Date.now()`** entre l'instant SSR et l'instant client → texte
    « 5m ago » différent à chaque round-trip → #418.
  - **`isomorphic-dompurify` normalise le HTML email différemment
    sur JSDOM (server) et sur le DOM natif (client)** pour certains
    mails entrants mal formés ; combiné au buffering RSC du WAF
    XGS sur les chunks volumineux, le contenu HTML transmis ne
    correspond pas toujours à celui que le client reconstruit
    localement → #418.

  Fix retenu (surgical, sans flash, aligné sur le pattern déjà
  utilisé dans `layout.tsx` et `client-text.tsx`) : ajout de
  `suppressHydrationWarning` sur les nœuds DOM dont le contenu est
  attendu différent SSR vs client :
  - `apps/web/src/app/(dashboard)/tickets/[id]/conversation.tsx` :
    span de la date du message + div HTML email sanitisé.
  - `apps/web/src/app/(dashboard)/tickets/[id]/activity-feed.tsx` :
    spans d'action traduite + temps relatif.
  - `apps/web/src/app/(dashboard)/tickets/[id]/notes-panel.tsx` :
    span du temps relatif des notes internes.
  - `apps/web/src/app/(dashboard)/tickets/[id]/ticket-sidebar.tsx` :
    4 cellules de date dans la card « Détails » (créé / mis à jour
    / première réponse / fermé).

  `suppressHydrationWarning` est un mécanisme React standard qui dit
  « ce nœud peut légitimement diverger SSR vs client, accepte le
  contenu client après hydratation ». Aucune fonctionnalité changée,
  juste plus de tolérance sur les nœuds dont on sait qu'ils sont
  client-dépendants (locale, time-relative, HTML email). La page
  ticket se charge maintenant directement, sans l'aller-retour
  Reload-auto déclenché par `RSCErrorBoundary`.

  Note : la vraie correction de fond — passer le locale dans un
  cookie pour qu'il soit connu côté serveur — fera l'objet d'une
  release dédiée plus tard (refactor i18n complet).

## [1.10.147767] — 2026-05-18

### Added

- **Conversation ticket : le nom de l'agent qui a répondu s'affiche au-dessus
  de chaque réponse.** Avant, chaque réponse agent dans la vue
  conversation d'un ticket portait l'étiquette générique « Agent »,
  rendant impossible la traçabilité dans les fils multi-agents (un
  ticket peut être repassé entre plusieurs agents au cours de son
  cycle de vie). Désormais, chaque message de type `REPLY` est tagué
  avec l'`userId` de l'agent qui a cliqué « Envoyer », et le bandeau
  au-dessus de la bulle de message affiche son nom (`message.sender.name`)
  ainsi que ses initiales dans la pastille colorée. Les messages
  hérités (créés avant ce patch, `senderUserId` NULL) retombent
  gracieusement sur « Agent » / « AG », donc aucun écran ne casse.

  Modifications :
  - **DB** : ajout d'une colonne nullable
    `TicketMessage.senderUserId TEXT` avec
    `FOREIGN KEY → User(id) ON DELETE SET NULL ON UPDATE CASCADE` et
    un index `TicketMessage_senderUserId_idx`. Si un agent est
    supprimé du système, ses messages restent visibles mais perdent
    leur attribution (retour au fallback « Agent ») — pas de cascade
    destructive sur l'historique.
    Migration : `apps/web/prisma/migrations/20260518_message_sender_user/`.
  - **Server Action** : `addReply` (`apps/web/src/lib/actions/ticket.actions.ts`)
    écrit désormais `senderUserId: session.userId` à la création du
    message ; `getTicket` étend l'`include` des messages avec
    `sender: { select: { id: true, name: true } }`.
  - **UI** : `conversation.tsx` (`MessageBubble`) lit
    `message.sender?.name` pour les replies non-AUTO_REPLY, calcule
    les initiales correspondantes pour l'avatar, et conserve les
    libellés existants pour `INITIAL` / `CUSTOMER_REPLY` / `AUTO_REPLY`.

  Impact : aucun changement visible sur les threads existants tant
  qu'aucune nouvelle réponse n'est envoyée. Dès qu'un agent répond
  via la composer, son nom apparaît dans l'en-tête du message — y
  compris quand un autre agent reprend le ticket par la suite. Les
  vues client (par email) restent inchangées : la signature HTML
  reste celle de l'agent qui a posté la réponse.

## [1.10.147766] — 2026-05-18

### Fixed

- **Clic sur une pièce jointe agent renvoyait `{"error":"Forbidden"}` (403).**
  La colonne `Attachment.storagePath` est écrite sous deux formats selon
  l'origine :
  - `mail-service` (mails entrants) écrit un chemin **absolu**
    `/data/attachments/<uuid>.<ext>` (`apps/mail-service/src/imap/parser.ts`).
  - `linkDraftAttachments` (replies agent) écrit un chemin **relatif**
    `messages/<msgId>/<leaf>` (`apps/web/src/lib/attachments.ts`).

  Dans `apps/web/src/app/api/attachments/[id]/route.ts`, l'appel
  `resolve(att.storagePath)` produisait un chemin sous le CWD du process
  Node pour les chemins relatifs (`/app/messages/<msgId>/<leaf>`), qui
  sortait des deux roots autorisées (`/data/attachments` et
  `/data/uploads`) → branche `Forbidden` 403. Conséquence : chaque
  pièce jointe ou image inline uploadée par un agent dans un reply
  retournait 403 quand on cliquait dessus, y compris pour l'auteur du
  message. Les attachements venant des mails entrants (chemins
  absolus) fonctionnaient.

  Fix : si `storagePath` ne commence pas par `/`, on le résout sous
  `UPLOAD_ROOT` avant le contrôle de containment. Comportement
  inchangé pour les chemins déjà absolus.

## [1.10.147765] — 2026-05-18

### Fixed

- **Éditeur de réponse ticket — listes à puces enfin visibles + paste d'images
  presse-papier.** L'éditeur Tiptap utilisait les classes `prose prose-sm` mais
  le plugin `@tailwindcss/typography` n'est pas installé, donc le reset
  preflight de Tailwind (`ul, ol { list-style: none; padding: 0 }`) rendait
  toutes les listes invisibles. Trois symptômes pour la même cause :
  - Le bouton "Liste à puces" de la toolbar semblait sans effet (le `<ul><li>`
    était bien créé, mais sans marker ni indentation).
  - Taper `- ` au début d'une ligne déclenchait l'input rule, consommait le
    tiret, mais aucune puce ne s'affichait.
  - Le copier/coller depuis Gmail/Word préservait la structure de liste mais
    elle restait invisible.

  Fix : règles CSS ciblées sur `.ProseMirror` dans `globals.css` qui restaurent
  `list-style`, l'indentation, les tailles de heading (h1-h3), le rendu des
  blockquotes, code, code blocks, liens et la barre horizontale. Aucun nouveau
  package, pas de bump de dépendances.

- **Paste d'une capture d'écran dans la zone de réponse.** L'extension
  `@tiptap/extension-image` ne gère pas le presse-papier d'image par défaut.
  Ajout de `editorProps.handlePaste` et `handleDrop` dans
  `rich-text-editor.tsx` qui détectent les fichiers `image/*` dans
  `clipboardData` / `dataTransfer`, les uploadent via le handler
  `onImageUpload` déjà câblé sur `attachments.uploadInlineImage`, puis
  insèrent le node image au point d'insertion (paste) ou aux coordonnées du
  drop (drag-and-drop). Le texte/HTML continue d'être collé normalement.

## [1.10.147764] — 2026-05-18

### Changed

- **VigilanceKey — toutes les licences existantes migrées en annuel.**
  Suite à v1.10.147763 où Enterprise Pack est passé en annuel,
  l'admin VigilanceKey affichait encore les licences déjà émises
  comme "Permanent" (parce que leur `expires_at = 2099-12-31` est
  filtré par `service/license.go:767` qui omet le champ du payload
  signé quand l'année >= 2099). Migration appliquée :
  ```
  UPDATE licenses SET expires_at = NOW() + INTERVAL '1 year'
   WHERE product = 'ticketbrainy'
     AND expires_at >= '2099-01-01'
     AND plugin_slug NOT IN ('core', 'slack_connect');
  ```
  13 licences mises à jour. `core` reste permanent (plan gratuit
  baseline), `slack_connect` est laissé tel quel (plugin retiré).
  L'entité Go `entity/license.go` aligne aussi tous les plugins
  payants restants sur `"year"` (csat_feedback, time_tracking_pro,
  email_templates, telegram_bot, backup_monitor) — l'entité
  marketplace était la source de vérité côté backend, et certains
  plugins traînaient encore en `one-shot` désynchronisés de TB.

### Added

- **Settings > Plugins — affiche l'email d'activation.** Sous le
  sous-titre "Manage your licensed plugins and features",
  l'instance affiche maintenant `Licenses bound to <email>` (la
  valeur passée à `/api/activate` lors du fresh deploy). Utile
  pour le support et pour distinguer rapidement dev/prod.
  Persisté dans `SystemConfig.activationEmail` (nouvelle colonne,
  nullable, migration `20260518_systemconfig_activation_email`).
  L'instance dev a été backfillée manuellement avec
  `christophe.reitano@it-secure.lu` ; les instances clientes
  l'auront automatiquement après la prochaine activation ou
  peuvent être backfillées par SQL si besoin.

## [1.10.147763] — 2026-05-18

### Changed

- **Enterprise Pack — pricing harmonisé en annuel.** Le plugin
  Enterprise Pack passe de 99€ one-shot à 99€/an pour s'aligner sur
  tous les autres plugins payants (qui sont déjà en `year`). Modifié
  dans `apps/web/src/lib/license/features.ts` côté TB et dans le
  marketplace VGXKey (`/opt/vigilanceKey/frontend/src/App.tsx`
  ligne 112, `/opt/vigilanceKey/backend/internal/entity/license.go`
  ligne 30 — prix backend aussi aligné 89 → 99). VGXKey frontend +
  backend rebuild + restart effectués (`docker compose build
  frontend backend && up -d`).
  Instances clientes : un Sync Licence depuis Settings > Plugins
  remontera le nouveau modèle. Les licences `enterprise_pack` déjà
  émises en one-shot avant cette release restent valides
  indéfiniment (pas de migration agressive — on ne désactive aucune
  licence existante).

## [1.10.147762] — 2026-05-18

### Added

- **Liste tickets — "Marquer comme lu" + auto-clear sur Résolu/Fermé.**
  When an agent handles a ticket out-of-band (e.g. calls the customer
  and switches the status to Résolu/Fermé without typing a reply),
  the blue "awaiting response" dot used to keep showing because it
  was derived purely from the type of the last message. Now the
  Ticket model has an `agentReadAt: DateTime?` column. The dot logic
  becomes: `(last message is INITIAL or CUSTOMER_REPLY) AND
  (agentReadAt IS NULL OR last message createdAt > agentReadAt)`.
  Two ways to set the field:
  1. **Auto** — any transition to RESOLVED or CLOSED stamps
     `agentReadAt = now()` in the same `updateTicket` call.
  2. **Manual bulk** — a new "Marquer comme lu" button appears next
     to "Supprimer la sélection" when at least one ticket is checked
     in the list; clicking it calls the new
     `bulkMarkTicketsAsRead(ids)` server action which writes
     `agentReadAt = now()` on every accessible ticket in the
     selection (capped at 500, AGENT scope-restricted via the
     existing `filterTicketsByAccess`).
  The sidebar mailbox badges (awaiting / unassigned-awaiting /
  mine-awaiting) are also corrected via the same `agentReadAt`
  comparison in `sidebar.actions.ts`. A subsequent inbound
  CUSTOMER_REPLY whose `createdAt > agentReadAt` automatically
  re-triggers the dot — no state to reset.

### Files touched

- `apps/web/prisma/schema.prisma` + new migration
  `20260518_ticket_agent_read_at` — adds `Ticket.agentReadAt`.
- `apps/web/src/lib/actions/ticket.actions.ts` — auto-set in
  `updateTicket` on RESOLVED/CLOSED, new `bulkMarkTicketsAsRead`,
  list query includes `messages.createdAt`.
- `apps/web/src/lib/actions/sidebar.actions.ts` — 3 raw SQL
  badge queries amended with the `agentReadAt` comparison.
- `apps/web/src/app/(dashboard)/tickets/ticket-table.tsx` —
  recomputes `awaitingResponse`, new `MailOpen` button.
- `apps/web/src/lib/i18n/locales/{fr,en,de,es,it}.ts` —
  `tickets.markSelectedAsRead`, `tickets.bulkMarkReadSuccess`.

## [1.10.147761] — 2026-05-17

### Fixed

- **apply-config.sh — silent admin lockout failure visible at last.**
  v1.10.14776 added `emailTheme: ticketbrainy` to the realm hardening
  PUT, but on existing installs apply-config.sh could die invisibly at
  the admin token fetch (`curl -sf` + `set -e` swallowing 4xx
  responses), leaving `emailTheme` unset on the realm. Concrete trigger
  observed: master-realm brute-force protection (Step 7 — 5 fails,
  15 min lockout) accumulating from repeated keycloak-init recreations
  during a deployment cycle, then locking out `admin` for the rest of
  the window. The script now (1) always logs the actual HTTP status
  code + response body when the token endpoint rejects auth,
  (2) retries once with a 10s backoff to absorb cold-boot races on
  slow disks, (3) prints a clear, actionable hint pointing at
  `scripts/keycloak-reset-admin.sh --mode unlock` when it sees 401, or
  at `--mode recovery` when it sees 400/403 (password mismatch). The
  realm template `ticketbrainy-realm.json` also gets a baked-in
  `emailTheme: ticketbrainy` so fresh installs no longer depend on the
  admin token round-trip to wire up the activation email template.

### Update

> If your existing prod is on v1.10.14776 and the activation email
> still uses the base template (no portal section), the admin user
> is locked out. Run:
>
> ```bash
> cd /opt/ticketbrainy
> git pull
> bash scripts/keycloak-reset-admin.sh --mode unlock
> docker compose up -d --force-recreate --no-deps keycloak-init
> docker logs ticketbrainy-keycloak-init-1   # expect emailTheme=ticketbrainy
> ```

## [1.10.14776] — 2026-05-17

### Added

- **Keycloak activation email — section 2 with TicketBrainy portal link.**
  When an admin creates a new agent in Keycloak, the recipient
  receives a "Mise à jour du mot de passe" email containing only
  the account-update link — no hint about where to log in once
  activated. The new custom email theme (`keycloak/themes/
  ticketbrainy/email/`) extends the base `executeActions.ftl` to
  add a second section **"Connexion au portail TicketBrainy"**
  with a CTA button + cleartext URL. The placeholder
  `__TB_PORTAL_URL__` is substituted with `$APP_URL` by
  `keycloak/docker-entrypoint.sh` before Keycloak boots. The
  realm-config script (`keycloak/apply-config.sh`) now pins
  `emailTheme=ticketbrainy` on the realm. Available in FR/EN/DE/
  ES/IT.

- **Settings — read-only mode for SUPERVISOR role.**
  Until v1.10.14775, SUPERVISOR users were redirected out of any
  settings page that did `if (role !== "ADMIN") redirect()`
  (time-tracking, AI categories, Deploy & Security `mode`/
  `whitelist`/`audit`/`geo-block`). They can now **view** every
  settings page. The settings layout is split into a
  server-component `layout.tsx` (resolves `canEdit` from the
  session) wrapping a client-component `settings-shell.tsx` that
  renders the existing tabs + sidebar. When `canEdit=false`, a
  yellow "Mode lecture seule" banner appears and the page content
  wrapper uses the HTML `inert` attribute, which disables every
  interactive form element underneath (inputs, buttons, selects,
  switches) without breaking the tab/sidebar navigation. Server
  actions that mutate state keep their `requireRole("ADMIN")`
  guard as defense in depth — read-only loaders
  (`getLiveConfig`, `getSavedConfig`, `getConfigDrift`,
  `generateEnvFile`, `generateCaddyfile`, `getSecurityDashboardData`,
  `getRateLimitConfig`, `detectMyCountry`, `getGeoBlockStats`) are
  relaxed to `ADMIN + SUPERVISOR`. AGENT remains blocked from
  `/settings` by the upper dashboard guard.

### Files touched

- `keycloak/themes/ticketbrainy/email/` — new theme (theme.properties,
  html/executeActions.ftl, text/executeActions.ftl, messages_{fr,en,de,es,it}.properties)
- `keycloak/docker-entrypoint.sh` — render theme with TB_PORTAL_URL
- `keycloak/apply-config.sh` — pin `emailTheme: ticketbrainy` on realm
- `docker-compose.prod.yml`, public `docker-compose.yml` — mount as `themes-src`
- `apps/web/src/app/(dashboard)/settings/layout.tsx` — new server wrapper
- `apps/web/src/app/(dashboard)/settings/settings-shell.tsx` — banner + inert wrapper
- `apps/web/src/lib/i18n/locales/{fr,en,de,es,it}.ts` — `settings.readonly.*`
- 6 settings pages (time-tracking, ai/categories, deploy-security/audit, /geo-block, /mode, /whitelist)
- 4 action files (deployment, geo-block, rate-limit, security-dashboard)

## [1.10.147751] — 2026-05-17

### Fixed

- **XpertTeamIA : recommandations de modèle dépendantes du provider.**
  Les libellés "Recommandé : …" sous les 3 sélecteurs (Deep / Triage /
  SmartReply) étaient hardcodés sur les noms Claude (Opus/Sonnet/Haiku)
  même quand le provider actif était Codex CLI. Le sélecteur proposait
  bien GPT-5.x mais le texte d'aide parlait toujours d'Haiku, créant
  une incohérence visuelle. Trois nouvelles clés i18n
  `*RecommendedCodex` ont été ajoutées (Deep → GPT-5.4 ou GPT-5.5,
  Triage → GPT-5.4 Mini, SmartReply → GPT-5.4 Mini) ; la JSX bascule
  désormais entre la version Claude et la version Codex selon
  `provider === "codex_cli"`. Cohérent dans les 5 langues.

## [1.10.14775] — 2026-05-17

### Added

- **XpertTeamIA : sélecteurs de modèle IA par tâche.** Les admins
  peuvent maintenant choisir un modèle distinct pour la Deep
  Analysis, le Tri automatique et la rédaction SmartReply IA depuis
  Réglages → XpertTeamIA. Permet d'optimiser l'usage tokens :
  garder Opus (ou GPT-5.4) pour la Deep Analysis où le raisonnement
  est critique, utiliser Haiku (ou GPT-5.4 Mini) pour le triage et
  la rédaction d'emails où c'est largement suffisant. Trois clés
  Setting indépendantes : `ai.expertModel`, `ai.triageModel`,
  `ai.smartReplyModel`.
- Claude Haiku 4.5 ajouté au catalogue de modèles côté Claude
  (API Key + Claude Code CLI), aux côtés d'Opus 4 et Sonnet 4.
- Défauts intelligents par tâche appliqués au changement de
  provider : Opus/Sonnet pour Deep, Haiku/Mini pour Triage et
  SmartReply.

### Changed

- `apps/ai-service/src/email/drafter.ts` lit maintenant le réglage
  `ai.smartReplyModel` au lieu de hardcoder Haiku. Fallback Haiku
  4.5 si le réglage est absent.

## [1.10.14774] — 2026-05-16

### Changed

- **Assistant IA de rédaction des réponses : formatage HTML
  structuré au lieu de plain-text plat.** Le prompt système de
  `apps/ai-service/src/email/drafter.ts` demandait à Claude de
  produire du *plain text* avec `\n` pour les sauts de ligne — mais
  l'éditeur Tiptap côté agent attend du HTML et collapse tous les
  `\n` en espaces. Résultat : un brouillon généré arrivait dans la
  zone de composition en un seul bloc compact, sans paragraphes ni
  séparation, alors qu'un humain n'aurait jamais écrit ça. Le
  prompt impose maintenant un sous-ensemble HTML clair
  (`<p>`, `<br>`, `<ul>/<ol><li>`, `<strong>`, `<em>` — les autres
  balises sont explicitement interdites) avec un guide de style :
  un paragraphe par idée, listes à puces pour les énumérations de
  3+ items, gras parcimonieux sur 1-2 termes clés. Le brouillon
  s'affiche désormais comme un email écrit à la main par un agent
  pro. Filet défensif côté `reply-composer.tsx` : si Claude
  renvoyait quand même du plain-text (refusal, fallback), les
  `\n\n` sont convertis en `</p><p>` et les `\n` simples en `<br>`
  avant l'injection dans l'éditeur — robustesse garantie même en
  cas de dérapage du modèle.

## [1.10.14773] — 2026-05-16

### Fixed

- **Notifications aux agents sur nouveaux tickets entrants par email :
  trou de conception majeur comblé.** Quand un client envoyait un mail
  dans une boîte TB, le ticket était créé et le client recevait bien
  son accusé de réception — mais les agents abonnés à la boîte ne
  recevaient **aucune** notification email. Seules des notifs in-app
  étaient créées, et uniquement pour les rôles ADMIN/SUPERVISOR (les
  agents standards étaient totalement ignorés). Résultat : un agent
  absent de l'interface TB ne savait jamais qu'une demande était en
  attente — alors que c'est le principe de base d'un système de
  tickets. Le code mail-service à la création de ticket consulte
  maintenant `UserMailbox.notifyNewTicket=true` pour la boîte concernée
  et envoie pour chaque abonné (1) une notification in-app et (2) un
  email expédié depuis l'adresse de la boîte avec sujet, expéditeur,
  extrait du message et lien direct vers le ticket. Le préférence
  d'email par utilisateur (`notify.${userId}.email`) est respectée.
  Filet de sécurité : si aucun agent n'est abonné à la boîte, fallback
  automatique sur les admins+superviseurs pour ne jamais perdre un
  ticket. Aligne le comportement du mail-service sur celui de
  l'engine de notifications côté web (`notifyNewTicket()` dans
  `apps/web/src/lib/notifications/engine.ts`).

- **Email d'alerte à l'agent assigné sur réponse client.** Même cause,
  même conséquence : sur réponse d'un client à un ticket existant,
  l'agent assigné ne recevait qu'une notif in-app, jamais d'email.
  Désormais, en plus de la notif in-app, un email est expédié à
  l'agent assigné (et lui seul, pas d'arrosage de toute l'équipe).
  Respecte la préférence `UserMailbox.notifyReply` de l'agent et son
  opt-out global email.

## [1.10.14772] — 2026-05-16

### Fixed

- **Logos clients dans les signatures de mails entrants : images HTTP
  bloquées par le navigateur (mixed content).** Beaucoup de
  signatures embarquent leur logo via `<img src="http://cdn.client.com/…">`
  (HTTP simple). L'UI TB est servie en HTTPS, donc le navigateur
  bloque silencieusement le chargement HTTP et affiche un
  placeholder cassé — pas de message UI, juste un warning dans la
  console DevTools. Nouvelle route `/api/proxy-image?url=…` qui
  récupère l'image côté serveur et la sert en HTTPS au navigateur
  de l'agent connecté. Le rendu côté `conversation.tsx` réécrit
  automatiquement chaque `<img src="http://...">` vers le proxy
  juste avant DOMPurify, de sorte que les anciens messages déjà
  stockés en DB bénéficient aussi du fix sans aucune migration.

### Security

- **Proxy d'images : protection SSRF stricte.** `/api/proxy-image`
  exige une session agent (`requireAuth()`), n'accepte que
  `http://` / `https://`, résout l'hostname côté serveur et bloque
  toute IP dans une plage privée / loopback / link-local /
  unique-local / multicast / `*.localhost`. Limite de taille 5 MB,
  timeout 5 s, max 3 redirects, et chaque redirection est re-validée
  contre les mêmes règles. Ni cookie ni Referer transmis à
  l'upstream. Réponse en `image/*` only (sinon 415).

App image change uniquement — pull `:latest` (ou `:v1.10.14772`)
sur les 5 services. Pas de migration.

## [1.10.14771] — 2026-05-16

### Fixed

- **Sujets des emails sortants : numéro de ticket désormais
  toujours présent.** Auparavant, les réponses agents, les
  notifications de résolution, les mails d'auto-close, les
  enquêtes CSAT, les auto-replies sur création de ticket et les
  mails de changement de client utilisaient `Re: <subject>` sans
  référence au ticket — un client recevant plusieurs mails ne
  pouvait pas savoir lequel concernait quel ticket. Toutes les
  voies de sortie passent désormais par un helper canonique
  `buildOutboundSubject(ticketNumber, subject, mode)` qui
  produit `[Ticket #N] <subject>` (création) ou `Re: [Ticket #N]
  <subject>` (réponse). Le helper nettoie aussi les `Re:` /
  `[#N]` / `[Ticket #N]` accumulés au passage, donc le client ne
  verra jamais `Re: Re: [#7] [Ticket #7] ...`.
- **Threading par sujet : reconnaît désormais `[Ticket #N]`.** La
  méthode de fallback de thread-matching dans `mail-service`
  parsait uniquement le pattern `[#N]`. Elle accepte désormais
  aussi `[Ticket #N]` (la forme canonique). Cela renforce la
  robustesse face aux gateways qui strippent `In-Reply-To` /
  `References`.

App image change uniquement — pull `:latest` (ou `:v1.10.14771`)
sur les 5 services. Aucune migration.

## [1.10.14770] — 2026-05-15

### Fixed

- **Mail re-fetché silencieusement ignoré quand le ticket parent est
  dans la corbeille.** Quand un opérateur supprime un ticket dans TB
  (soft-delete, `Ticket.deletedAt`) puis remet le mail en non-lu sur
  le serveur IMAP pour le re-pousser, le mail-service le marquait
  `\Seen` sans créer de nouveau ticket. La dedup `messageId` et les
  deux méthodes de threading (In-Reply-To / References + match
  `[#N]` dans le sujet) ne filtraient pas sur `deletedAt`, donc le
  message se ré-attachait silencieusement au ticket en corbeille.
  Les trois requêtes ignorent désormais `ticket.deletedAt != null`,
  de sorte qu'un mail "ressuscité" après mise à la corbeille produit
  un nouveau ticket comme attendu.

App image change — pull `:latest` (ou `:v1.10.14770`) sur les 5
services. Pas de migration. Comportement strictly correctif —
n'altère pas les tickets actifs.

## [1.10.14769] — 2026-05-15

### Fixed

- **Modale "Nouveau ticket" : impossible de scroller dans le message
  ou la modale quand le contenu est long.** `DialogContent` n'avait
  pas de `max-height` ni d'`overflow`, et le `RichTextEditor` n'avait
  pas non plus de plafond. Un long message poussait la modale au-delà
  de la fenêtre du navigateur, masquant les boutons Annuler/Créer.
  La modale est désormais structurée en flex column avec corps
  scrollable et footer collant, et l'éditeur a une hauteur max
  (`maxHeight={260}`) avec scroll interne.
- **Logos / images de signature absents des emails entrants.** Le
  sanitizer côté mail-service strippait systématiquement tous les
  `src="https://…"` des `<img>` (anti pixel-tracker), ce qui faisait
  disparaître les logos hébergés sur le CDN du client. Le strip ne
  s'applique désormais qu'aux balises non-`<img>`. Pour préserver la
  posture anti-tracking, chaque `<img>` reçoit automatiquement
  `referrerpolicy="no-referrer" loading="lazy"` — le navigateur ne
  révèle plus la page TB au serveur de l'image, et l'image n'est
  chargée que si elle entre dans le viewport.
- **Images inline `<img src="cid:…">` cassées dans les emails.**
  Les images embedded via RFC 2392 Content-ID n'étaient jamais
  résolues vers les attachments stockés — le navigateur affichait
  un placeholder cassé. Nouvelle colonne `Attachment.contentId`,
  le parser mail capture le `cid` de chaque pièce inline, et après
  création du `TicketMessage` le mail-service réécrit les
  `src="cid:xxx"` vers `/api/attachments/<id>`.
- **Pièces jointes des emails entrants : 404 à l'ouverture.** Le
  rendu de la conversation construisait le href via
  `/api/uploads/${att.storagePath}` alors que `storagePath` est un
  absolute path (`/data/attachments/<uuid>.<ext>`). Le href généré
  était `/api/uploads//data/attachments/<uuid>.<ext>` → 404 pur sur
  toute pièce jointe d'email entrant. Nouvelle route
  `/api/attachments/[id]` qui résout par id Attachment, vérifie
  l'auth sur le ticket parent, et stream depuis `storagePath` avec
  Content-Disposition adapté (inline images/PDF, attachment pour le
  reste).
- **Création manuelle d'un ticket : le client ne recevait aucune
  notification.** Quand un agent ouvre un ticket pour un client par
  téléphone, walk-in ou escalation interne, aucun mail
  d'acquittement n'était envoyé — le client ne savait pas que sa
  demande était enregistrée. Le ticket de création manuelle envoie
  désormais le même email d'acquittement *"Votre demande a bien été
  enregistrée sous le numéro #N"* que pour les tickets nés d'un mail
  entrant, avec le logo et la signature de la mailbox correspondante.

### Added

- **`apps/web/prisma/schema.prisma`** — colonne `Attachment.contentId
  String?`. Migration appliquée automatiquement par le container
  `migrate` au prochain `up -d` (pas de migration manuelle requise).

### Upgrade

Pull `:latest` (ou `:v1.10.14769`) sur les 5 services. Migration
Prisma automatique au démarrage du container `migrate`. Aucun
nettoyage post-déploiement à exécuter (les anciens messages avec
des `<img src="cid:…">` cassés restent inchangés ; seuls les
nouveaux mails entrants bénéficient du rewrite).

## [1.10.14768] — 2026-05-15

### Fixed

- **RAG Knowledge Builder : sur-fragmentation des articles + pas de
  plafond par topic.** Avant ce fix, un seul article web pouvait
  remplir un topic avec 13 chunks redondants (cas observé sur
  `acronis.com/blog/posts/hard-drive-crash` dans le topic
  `data-recovery`), et chaque nouveau ticket ajoutait des chunks sans
  jamais purger : l'index grimpait à 210 chunks répartis sur 9 topics,
  avec énormément de doublons sémantiques.
  - `apps/ai-service/src/rag/topic-crawler.ts:103` : `chunkText()`
    plafonne désormais à `MAX_CHUNKS_PER_ARTICLE = 2` (au lieu de
    découper l'article entier en autant de chunks de 2400 chars qu'il
    en contient — jusqu'à 13 sur les articles longs).
  - `apps/ai-service/src/rag/topic-crawler.ts:415` : nouvelle fonction
    `pruneTopic()` appelée après chaque crawl. Maintient l'invariant
    *au plus 5 URLs par topic, 1 chunk par URL (le premier = intro)*,
    en privilégiant les sources les plus récentes.

### Changed

- Migration des données existantes effectuée manuellement au
  déploiement (210 chunks → 44, 1 par URL, max 5 URLs/topic). Les
  prod existantes doivent exécuter le SQL de cleanup décrit dans la
  doc de release v1.10.14768 (voir `docs/ops/rag-cleanup-v1.10.14768.sql`).

App image change — pull `:latest` (ou `:v1.10.14768`) sur les 5
services. Aucune migration Prisma (pas de schéma changé), mais le SQL
de cleanup ci-dessus est recommandé pour purger les chunks pré-fix.

## [1.10.14767] — 2026-05-14

### Removed

- **Slack / Teams Connect plugin retired.** The webhook-based notification
  integration for Slack and Microsoft Teams has been removed from
  TicketBrainy. Telegram remains the only first-class chat integration.
  Microsoft has been retiring the Office 365 Connectors (MessageCard
  format) since 2024, and the limited one-way notification surface no
  longer matched the product direction. Removed code: the
  `Settings → Integrations` page, the `WebhookIntegration` Prisma model,
  the webhook dispatcher, the `slack_connect` plugin entry in the
  marketplace registry, and ~37 i18n keys per locale (fr, en, es, de, it).
  The `WebhookIntegration` table is dropped by migration
  `20260514_drop_webhook_integration`; no customer data is lost on the
  reference deployment (table was empty).

## [1.10.14766] — 2026-05-12

### Fixed

- **"Assignés" view no longer includes the current user's own tickets.**
  The Tickets sidebar separates "Mes conversations" (assigned to me) from
  "Assignés" (assigned to someone else). The "Assignés" query was
  `assignedToId != null`, which incorrectly returned my own tickets too
  once I auto-assigned myself by replying to an unassigned ticket. The
  query is now `assignedToId != null AND assignedToId != currentUserId`,
  so each agent sees only their colleagues' assigned tickets in this
  view. A ticket belongs to exactly one of: "Non assignés", "Mes
  conversations", "Assignés" — no overlap.
- **Agent role no longer sees mailboxes outside their access.** The
  mailbox filter dropdown on the Tickets page loaded every active
  mailbox regardless of `UserMailbox` scoping. An agent with access to
  only one mailbox could pick another mailbox in the dropdown and (while
  the ticket query was already scoped) the UI exposed mailbox names they
  had no business seeing. The Tickets page now applies the same
  `UserMailbox` filter to the dropdown source for `AGENT` users that
  `getTickets()` already enforces on the data side.

### Removed

- **"Tous les tickets" global view.** The catch-all sidebar entry that
  aggregated tickets across every mailbox (resolved + unresolved + spam
  excluded) is removed from the navigation. Per-mailbox folders
  (Non assignés / Mes conversations / Assignés / Closed / Spam) and the
  Favorites / Deleted global views remain. Bookmarks pointing at
  `/tickets` with no `view` still resolve to a scoped list (filtered to
  the agent's mailboxes), but the entry no longer encourages cross-
  mailbox browsing.

## [1.10.14765] — 2026-05-11

### Fixed

- **AI Assistant draft no longer adds "Cordialement / Agent name".**
  The drafter prompt explicitly instructed the model to sign the email
  with the agent's name, which produced a duplicate because the mail
  system already appends the agent's signature block (name + mailbox
  signature + logo) on send. The prompt now forbids any closing
  salutation, agent name, team name or company name in both the
  Assistant AI draft (drafter.ts) and the "Generate email from
  resolution" path (generator.ts). The agent reviews a clean body and
  the system handles the sign-off.
- **CSAT thank-you page redirected customers to /login.** The
  middleware whitelisted `/api/csat` (the rating endpoint) but not the
  `/csat/[ticketId]` confirmation page, so after submitting their
  rating customers were bounced to the staff login screen — which they
  have no account for. The page was already designed to render
  publicly (no `requireAuth`, only branding + the rating param). The
  middleware now lets `/csat/*` through.

## [1.10.14764] — 2026-05-11

### Changed

- **Auto-triage no longer sends an email notification.** Auto-triage
  runs on every inbound ticket and was queuing a `[AI Auto-Triage]`
  email to every subscriber on the mailbox, which agents found noisy
  (the triage summary is already visible in the ticket UI and in the
  Telegram alert when enabled). Email notifications are now reserved
  for **Deep Analysis** (a manual agent action). Telegram notifications
  for auto-triage are unchanged — flip the channel off in
  Settings → Mailboxes if you don't want them.

## [1.10.14763] — 2026-05-11

### Fixed

- **Mailbox logo oversized in reply email signatures.** Outlook and many
  corporate mail clients ignore CSS `max-height`/`max-width` on `<img>`
  tags; the per-mailbox logo injected at the top of agent reply
  signatures was rendered at its native size (often filling the screen)
  in those clients. The logo now ships with an explicit HTML
  `height="48"` attribute alongside the existing CSS constraints, so it
  renders at ~48px tall everywhere (width auto-scaled proportionally).
- **DMARC badge falsely showing "valid" on senders with no DMARC
  record.** Microsoft 365 emits `dmarc=bestguesspass` in the
  `Authentication-Results` header when the sender domain publishes no
  DMARC record but SPF/DKIM pass — it is a heuristic guess, not a real
  DMARC pass. The parser was mapping `bestguesspass` to `pass`, causing
  inbound tickets from domains without published DMARC (e.g.
  heinrich-bock.com) to display a misleading green "valid" badge. We
  now map `bestguesspass` to `none`, so the badge correctly reads "non
  configuré" until the customer publishes a real DMARC record.

## [1.10.14762] — 2026-05-11

### Changed

- **AI rate limit per user raised from 60/h to 200/h.** The single
  `RL_AI_USER` bucket is shared across every AI feature (triage,
  deep analysis, email draft / rewrite / summarize, AI skills) so
  60/h was tripping during normal work as soon as 4-5 tickets were
  open in parallel. Fixed-window Redis bucket survives across
  features and across restarts, so the trip lingered for the full
  60-minute window. Default raised to 200/h. Instances that need
  a lower limit can still override via Settings → Security UI
  (cached 60s, no rebuild required).
  File: `apps/web/src/lib/rate-limit.ts`.

## [1.10.14761] — 2026-05-10

### Security

- **AGENT scoping sur tout le dashboard.** Avant : un agent voyait
  les compteurs (Ouvert / Nouveaux / Non assignés / Résolus aujourd'hui),
  les tickets récents, le chart d'activité 7 jours et la section
  "Boîtes mail connectées" pour TOUTES les boîtes — y compris celles
  dont il n'a pas accès. Désormais : un AGENT ne voit que les données
  des `userMailbox` qui lui sont associées. ADMIN et SUPERVISOR sont
  inchangés (ils voient tout). Le scoping s'applique aussi à la
  modale `getKpiTickets` (clic sur une case KPI). Fichiers :
  `apps/web/src/app/(dashboard)/dashboard/page.tsx`,
  `apps/web/src/lib/actions/dashboard.actions.ts`. Implémente le même
  pattern que `ticket.actions.ts:181-187`.

## [1.10.1476] — 2026-05-10

### Added

- **Cliquables : les 4 cases KPI du Dashboard** (Ouvert / Nouveaux
  aujourd'hui / Non assignés / Résolus aujourd'hui). Un clic ouvre
  une modale listant les tickets correspondants, filtre identique
  au compteur. Chaque ligne navigue vers `/tickets/[id]`.
  Fichiers : `apps/web/src/lib/actions/dashboard.actions.ts` (nouveau
  Server Action `getKpiTickets`), `apps/web/src/app/(dashboard)/dashboard/kpi-tickets-dialog.tsx`
  (nouveau composant Dialog + ScrollArea), `apps/web/src/app/(dashboard)/dashboard/dashboard-content.tsx`
  (KpiCard devient `<button>` cliquable, état `openKpi` centralisé).
  Cap de 200 tickets par modale avec bandeau "Affichage des 200 plus
  récents — ouvrez la liste des tickets pour voir la suite". 7 nouvelles
  clés i18n × 5 locales (FR / EN / ES / IT / DE).

### Fixed

- **Pas de re-fetch silencieux toutes les 30 s** dans la modale KPI :
  `useEffect` utilise un `useRef` pour `onOpenChange` afin que le
  polling `router.refresh()` du dashboard ne retrigger plus le chargement
  de la liste pendant que la modale est ouverte.

## [1.10.1475] — 2026-05-10

### Changed

- **Slack / Teams Connect and Telegram Bot switch from one-shot
  to annual subscription.** Same flip as v1.10.1473/1474 applied
  to `slack_connect` and `telegram_bot` in
  `apps/web/src/lib/license/features.ts`. Listed prices unchanged
  (29 € / 29 €) — now per year. Existing one-shot purchases are
  grandfathered (no `expires_at` on the issued envelopes, so
  `hasFeature()` keeps them granted indefinitely). After this
  release every premium plugin is on annual subscription except
  Enterprise Pack — which remains one-shot by design.
- **Enterprise Pack price raised from 89 € to 99 €** (still
  one-shot). Updates `apps/web/src/lib/license/features.ts`.
  No effect on customers who already purchased at 89 € — the
  price is read at checkout time, not from the licence row.

### Coordination required before next sale

VigilanceKey `slug → stripePriceId` mapping must be aligned for:
- `slack_connect` and `telegram_bot` → Stripe `Price` in
  `recurring/year` mode at 29 € each.
- `enterprise_pack` → Stripe `Price` in `one_time` mode at 99 €.

Stripe configuration is still pending overall (cf. project
memory `Stripe Pending`); this release does not break any live
purchase path.

## [1.10.1474] — 2026-05-10

### Changed

- **BackupMonitor switches from one-shot to annual subscription.**
  Same flip as v1.10.1473 applied to `backup_monitor` in
  `apps/web/src/lib/license/features.ts`: `priceModel`
  `"one-shot"` → `"year"`, listed price unchanged at 49 € — now
  per year. Existing one-shot purchases are grandfathered (no
  `expires_at` on the issued envelopes, so `hasFeature()` keeps
  them granted indefinitely). VigilanceKey `slug → stripePriceId`
  for `backup_monitor` must point to a Stripe `Price` in
  `recurring/year` mode before the next sale; same coordination
  caveat as v1.10.1473.

## [1.10.1473] — 2026-05-10

### Changed

- **Time Tracking Pro, Email Templates Pro and CSAT & Feedback
  switch from one-shot to annual subscription.** Pricing model
  (`priceModel`) flipped from `"one-shot"` to `"year"` on the
  three plugin entries in `apps/web/src/lib/license/features.ts`.
  Listed prices unchanged: 39 € / 39 € / 29 € — now per year.
  Existing one-shot purchases are grandfathered: the licences
  already issued carry no `expires_at`, so `hasFeature()` keeps
  granting them indefinitely. The plugin storefront UI already
  drives the badge label off `priceModel`, so the cards now
  display "/perYear" automatically.

### Coordination required before next sale

The license server (VigilanceKey) `slug → stripePriceId` mapping
for `csat_feedback`, `time_tracking_pro` and `email_templates`
must point to Stripe `Price` objects in `recurring/year` mode
before the first checkout for these plugins. Stripe configuration
is still pending overall (cf. project memory `Stripe Pending`),
so this release does not break any live purchase path.

## [1.10.1472] — 2026-05-10

### Security

- **`fast-uri` bumped past <=3.1.1.** Closes two HIGH advisories
  (CVSS 7.5) on the Fastify URL parser used by `ai-service`:
  GHSA-q3j6-qgpj-74h6 (path traversal via percent-encoded dot
  segments) and GHSA-v39h-62p7-jpjc (host confusion via
  percent-encoded authority delimiters). Pure transitive bump,
  no API change.

### Changed

- **`postcss` spec aligned to `^8.5.10`** in `apps/web/package.json`.
  The installed version was already 8.5.10 (covering the
  GHSA-qx2v-qp2m-jg93 XSS-via-`</style>` advisory), but the spec
  still pointed to `^8.5.8`, causing `npm audit` to flag the
  package as a false positive on every run.

## [1.10.1471] — 2026-05-10

### Fixed

- **Public branding logo + favicon now load for unauthenticated
  recipients.** The CSAT survey page and outbound email templates
  reference the global white-label logo via `/api/uploads/<file>`,
  but that route requires a TicketBrainy session — so external
  customers saw a broken image in their inbox and on the rating
  page. Two new public endpoints `/api/branding-logo` and
  `/api/branding-favicon` now serve those assets without auth.
  Filename is resolved server-side from the `Setting` table (never
  taken from the URL), with strict pattern + path-containment
  defenses inherited from the `[filename]` route. Same pattern as
  the per-mailbox logo fix in v1.10.1468/1469.
- **Raw migration failures are now fatal.** `run-raw-migrations.mjs`
  previously logged SQL errors and continued, letting `prisma db
  push` run on a half-applied schema. A failing `CREATE EXTENSION
  vector` or `AiKnowledgeChunk` migration would yield a green
  deploy with silently-broken RAG / Deep Analysis at runtime.
  Errors now propagate, the migrate container exits non-zero, and
  the rollout halts before the app comes up on a broken DB.

## [1.10.147] — 2026-05-09

### Added

- **Dashboard auto-refresh.** The dashboard counters (Open,
  Unassigned, Resolved Today, My Open) and Recent Tickets list now
  update in place every 30 s without a full page reload, via
  `router.refresh()` against the server component. The poll pauses
  when the browser tab is hidden and re-fires once on resume so
  operators don't burn DB CPU on a backgrounded tab.
- **"Refresh mailboxes" button in the left sidebar** next to the
  "Boîtes mail" / "Mailboxes" header. Clicking it forces the
  mail-service to run an IMAP poll right away instead of waiting
  for the next `IMAP_POLL_INTERVAL` tick (default 30 s). Useful
  when an operator knows a customer just sent an email and doesn't
  want to wait. Plumbing:
  - Web Server Action `pokeMailPoll()` publishes on Redis channel
    `tb:mail-poll-now` (rate-limited 6/min/user).
  - Mail-service subscribes to that channel and runs
    `pollAllMailboxes()` with a 5 s server-side debounce — multiple
    concurrent clicks coalesce into one poll.
  - The button shows a spinning `RefreshCw` icon for ~4 s after
    click while the IMAP fetch happens, then triggers a sidebar +
    dashboard refresh so the new tickets appear.
  - Translations in FR / EN / DE / ES / IT.

## [1.10.1469] — 2026-05-09

### Fixed

- **Middleware was returning 401 on /api/uploads/mailboxes/ before
  the route handler ran.** v1.10.1468 dropped the auth check inside
  the route handler itself, but the middleware (`middleware.ts`)
  still short-circuited the request for any `/api/uploads/*` path
  without a session token. The middleware now whitelists
  `/api/uploads/mailboxes/` so the (already-public) handler is
  reached for outbound-email logo loads. Validated end-to-end with
  a wget from the mail-service container.

## [1.10.1468] — 2026-05-09

### Fixed

- **Mailbox logos now display in outbound email headers.** Operator
  reports: the email header showed a "TicketBrainy" placeholder
  instead of the mailbox logo. Root cause: the route serving the
  per-mailbox logos (`/api/uploads/mailboxes/[filename]`) required a
  TicketBrainy session — but the customer's email client (Outlook,
  Gmail) has no session, so the `<img>` tag in the email template
  fetched 401 and rendered the alt-text fallback. The route now
  serves these logos publicly (filenames are strict-pattern matched
  to `mailbox-<id>[-<unix-ms>].(png|jpg|webp)`, so the asset surface
  is exactly the operator-uploaded branding files — no path
  traversal is possible). Cache-Control switched to
  `public, max-age=86400, immutable` so Gmail's image proxy and
  Outlook can cache the logo.

## [1.10.1467] — 2026-05-09

### Fixed

- **Deep Analysis "Proposed Resolutions" steps were truncated.**
  The expanded resolution wrapped its steps inside `<ScrollArea
  max-h-36>` which was itself wrapped in a `motion.div` with
  `overflow-hidden`. The combination clipped everything past the
  144 px height with no visible scrollbar — long step lists were
  unreachable. The wrapper no longer hides overflow and the steps
  list uses a native scrollable div (`max-h-80 overflow-y-auto`)
  with `whitespace-pre-wrap` so multi-line steps render correctly.

## [1.10.1466] — 2026-05-09

### Fixed

- **Dashboard search by ticket number now works.** Typing a bare
  number (e.g. "143") returned "No tickets found" because
  `searchTickets()` ran a tsquery against `searchVector` + ILIKE
  on subject/customer fields, but never looked at the `number`
  column. Numeric queries now also match `Ticket.number` and the
  exact match is sorted to the top of the results.

## [1.10.1465] — 2026-05-09

### Fixed

- **Crawler bypasses Incapsula / WAF anti-bot pages.** Vendor forums
  (community.sophos.com, Cisco support, etc.) return a JavaScript
  challenge page to any non-browser fetch — `@extractus/article-extractor`
  saw 842-byte challenge pages and rightfully discarded them as
  "no extractable content". The crawler now starts with the SearXNG
  snippet (which the search engines already extracted for the query)
  and only OVERRIDES it with the full article when extraction
  succeeds and yields > 800 chars. Empty-fetch sites still
  contribute their snippet — short but topical, and enough for the
  Expert agent to know "there's a thread about this exact issue".
  Result on ticket #143: the four community.sophos.com threads
  about Sophos XGS Safe Failed Mode + the v22 release notes are
  now indexed instead of skipped.
- **User-Agent updated to a real Chrome string.** Stops the rejection
  on sites that 403 anything that looks like a bot (Microsoft Learn,
  Cisco support).

## [1.10.1464] — 2026-05-09

### Fixed — RAG quality on real tickets

Diagnostic on ticket #143 (Sophos XGS Safe Failed Mode v22) showed
the Deep Analysis ran but no external sources surfaced. Three root
causes:

1. **SearXNG timeout was 8 s**, too tight when querying 4 categories
   in parallel. The crawler aborted before Google/Reddit/ServerFault
   could respond. **Bumped to 25 s + one retry on empty/failed.**
2. **The crawl query repeated tokens.** Triage emitted "Sophos XGS"
   in vendor + product AND in errorKeywords AND in subject, producing
   `"Sophos XGS Safe Failed Mode XGS v22.0.0 cluster appliance failure
   SOPHOS XGS down firewall …"` — a 200-char string with low signal
   density. `buildQuery()` now tokenizes, dedups case-insensitively,
   strips FR + EN stopwords, and preserves version strings (v22,
   v22.0.0) which are the most informative match for bug threads.
3. **The on-demand re-run had no recourse.** When triage's
   fire-and-forget crawl failed, the RAG stayed empty for that
   topic, and re-running the Deep Analysis manually would still
   inject zero chunks. Now: when retrieval finds 0 chunks but a
   vendor/product/domains is known, we trigger a synchronous crawl
   inline (60 s deadline) before calling the Expert agent, so the
   agent always sees external context if SearXNG can find any.

Manually verified: SearXNG returns the exact relevant Sophos
Community thread for "Sophos XGS Safe Failed Mode v22" — the issue
was always the timeout, not the source coverage.

## [1.10.1463] — 2026-05-09

### Changed

- **RAG promu en entrée de menu dédiée.** "RAG Knowledge Base" apparaît
  désormais sous "Compétences IA" dans la sidebar Settings → IA, avec
  son propre URL `/settings/ai/rag`. La RagSettingsCard (toggles,
  quotas, allowlist, health checks) est déplacée hors de la page
  XpertTeamIA et regroupée avec l'explorer dans la même page dédiée.
  Internationalisation FR/EN/DE/ES/IT.

## [1.10.1462] — 2026-05-09

### Fixed

- **Triage card surfaces real HTTP error.** Generic "Triage request
  failed. Try again." was hiding 401 (stale browser bundle), 429
  (rate limit), 502 (ai-service down) and other distinct conditions.
  Now the message is either dedicated copy ("Hard-refresh the
  page (Ctrl+Shift+R)" / "AI rate limit hit. Wait a minute") or the
  raw status + body so operators can debug in one click.

### Added

- **`/api/ai/*` proxy logs upstream errors.** The Next.js proxy used
  to swallow non-2xx responses and stream errors silently. Now any
  upstream failure is logged via `console.warn` / `console.error`
  with the path, status, body preview and userId, so operators can
  correlate a "Triage request failed" report in the UI with the
  exact server-side reason without grepping through ai-service logs.

## [1.10.1461] — 2026-05-09

### Added

- **`/settings/ai/rag` — RAG knowledge explorer.** Page admin (ADMIN
  + SUPERVISOR) listant tous les chunks indexés par le crawler avec
  filtres (topic, source, full-text), pagination, suppression par
  chunk, suppression par topic, et un formulaire de **crawl manuel**
  pour pré-charger la base avant qu'un ticket réel n'arrive (vendor,
  produit, query, mots-clés). Liée depuis la card RAG de
  `/settings/ai`.
- **External knowledge sources visibles dans la Deep Analysis
  sidebar.** Nouveau bloc "External sources used" qui liste chaque
  chunk injecté dans le prompt Expert avec lien clickable vers la
  source originale, badge engine, et score de similarité (% match).
  Persisté dans `AiAnalysis.knowledgeSources` (nouvelle colonne JSONB)
  pour survivre aux reloads.
- **`/rag/crawl` et `/rag/health` côté ai-service** + ouverture
  whitelist du proxy `/api/ai`. `manualCrawl()` Server Action côté
  web.

### Fixed

- **Query RAG trop générique.** Avant : un ticket "Sophos XGS firewall
  safe failed mode" produisait une recherche pour `firewall +
  intent`, qui ramenait du contenu trop large. Le triage extrait
  maintenant `vendor`, `product` et `errorKeywords` distincts, et le
  crawler les utilise en tête de query (`Sophos XGS safe failed mode
  cluster boot …`). Le topic devient `vendor-product` quand
  identifiable (ex. `sophos-xgs`) au lieu d'être collé sur
  `domains[0]`.
- **Crawler tué par un seul timeout TEI.** Avant : si l'embed batch
  dépassait 30 s (CPU bge-m3 sur 8+ chunks), tout le crawl partait à
  la poubelle (AbortError). Maintenant : timeout TEI 30 s → 90 s,
  embed découpé en sous-batches de 8 chunks, chaque sous-batch
  persiste indépendamment (un échec ne perd que sa slice). Les
  inserts SQL sont aussi isolés en try/catch.

### Migrations

- `20260509_aianalysis_knowledge_sources` — ajoute
  `AiAnalysis.knowledgeSources JSONB` (idempotent).

## [1.10.146] — 2026-05-09

### Added — RAG Knowledge Builder

A topic-driven, just-in-time knowledge base that enriches Deep Analysis
with public knowledge fetched on demand. Self-hosted, zero external
API keys.

- **Two new sidecar containers** in docker-compose.{yml,prod.yml}:
  - `searxng` (image `searxng/searxng:latest`) — meta-search aggregator
    over Reddit, ServerFault, StackOverflow, GitHub, NVD, MS Learn,
    Google/Bing/Brave/DuckDuckGo. Internal-only, queries via
    `http://searxng:8080`. Config in `searxng/settings.yml`.
  - `embeddings` (image `ghcr.io/huggingface/text-embeddings-inference:cpu-1.5`)
    — TEI hosting `BAAI/bge-m3` (1024 dims, multilingual FR/DE/IT/ES/EN).
    Named volume `tei-models` persists the ~2 GB model across releases.
- **Postgres** image switched from `postgres:16-alpine` to
  `pgvector/pgvector:pg16` (drop-in, same data volume) to provide the
  `vector` extension. Migration `20260509_rag_knowledge_chunk` enables
  the extension and creates the `AiKnowledgeChunk` table with an
  IVFFlat cosine index on the embedding column.
- **`apps/ai-service/src/rag`** module:
  - `searxng.ts` + `embeddings.ts` clients (graceful degradation when
    sidecars are unreachable).
  - `topic-crawler.ts` — fire-and-forget crawl triggered from the
    triage flow. Builds a query from `domains + intent + summary`,
    asks SearXNG across enabled categories, fetches top N URLs,
    extracts via `@extractus/article-extractor`, chunks (2400
    chars / 300 overlap), embeds via TEI, upserts into pgvector
    with `contentHash` dedup. Skips when the topic already has fresh
    chunks within `cacheTtlDays` or hits the daily quota.
  - `retriever.ts` — top-K cosine similarity search injected into the
    Deep Analysis Expert prompt as `EXTERNAL KNOWLEDGE`.
- **Settings UI** at `/settings/ai` — new RagSettingsCard:
  - master on/off, per-engine-category toggles (tech / vendor /
    security / general), max results per search, max crawls per topic
    per day, cache TTL, top-K, optional domain allowlist.
  - live health checks on the SearXNG and TEI containers.
  - chunk count + topic count + fresh-chunk count.
- **Sources surfaced in the AI sidebar.** Each knowledge chunk
  contributes a `kb:<source>` badge in the Deep Analysis "Skills Used"
  row (e.g. `kb:reddit`, `kb:stackoverflow`).

### Operator notes

- **RAM**: TEI with bge-m3 needs ~2 GB resident. Recommend 8 GB
  minimum on the host (16 GB ideal).
- **First boot**: TEI downloads the bge-m3 model (~2 GB) on its first
  start. The `tei-models` named volume keeps it across rebuilds, so
  this only happens once per fresh install.
- **No external API key**: SearXNG aggregates public engines and TEI
  runs locally — neither needs a key. The customer's `.env` has zero
  RAG-specific settings to fill out (the URLs default to the in-
  cluster service names).
- **Disable**: `ai.rag.enabled=false` from Settings → XpertTeamIA. The
  Deep Analysis flow then runs without external knowledge, exactly
  like before.

## [1.10.145044] — 2026-05-09

### Fixed

- **Deep Analysis "via &lt;model&gt;" footer now shows up.** Real bug,
  not a cache issue: the SSE handler in `analysis-stream.tsx` treated
  `{ status: "done", data.summary }` as a terminal event and closed
  the EventSource. The writer stage emits exactly that shape BEFORE
  the analyzer finalises the DB update and emits the real
  `stage: "complete"` event. We were closing on writer/done, so the
  `complete` event — the ONLY one carrying `agentModel`, `analysisId`,
  full `resolutions` and `skillsUsed` — never reached the React
  component. That is why model attribution shipped to Triage and
  Summary cards but never lit up on Deep Analysis. Triage and Summary
  read directly from the DB row, so they were unaffected. Only
  `stage === "complete"` is treated as terminal now; writer/done just
  paints the summary early and waits for the rest.

## [1.10.145043] — 2026-05-09

### Added

- **Model attribution everywhere.** SummaryCard now shows the model
  used to generate the summary, matching the triage/deep-analysis
  cards. Added `Ticket.aiSummaryModel` (migration
  `20260509_ticket_aisummary_model`) so it persists across reloads.
- **Triage model is now configurable.** Same pattern as the deep
  analysis stages: `ai.triageModel` setting key with the existing
  Haiku id as fallback. Lets admins point triage at a Codex/OpenAI
  model when the provider is `codex_cli`, instead of defaulting to a
  Claude id that Codex CLI silently substitutes.

### Fixed

- **Persisted `agentModel` now reflects the model that ACTUALLY ran,
  not the requested string.** When the AI provider was `codex_cli` we
  were storing `claude-haiku-4-5-…` (the requested id) on every
  triage/deep/summary row, even though Codex was actually running an
  OpenAI model. `createMessage` now returns `modelUsed`, computed
  from the active provider:
  - `api_key` → `params.model`
  - `claude_cli` → `params.model` (CLI honours the request)
  - `codex_cli` → `CODEX_MODEL` env, else `"codex-default"` for
    Claude-id requests; the requested id otherwise
  Each agent persists `response.modelUsed` instead of the requested
  string, so the sidebar shows "via gpt-5" (or whatever Codex ran)
  instead of mis-attributing to Haiku/Sonnet.

### Changed

- **Top action bar: 4 equal-width buttons.** Previously the row was a
  flex layout where the Merge button stretched the rest awkwardly.
  Now a 4-column grid (`grid-cols-4` on ≥sm, `grid-cols-2` below) so
  Billing/CSAT/Merge/Delete all share width regardless of label
  length. CSAT is disabled (instead of hidden) when the ticket isn't
  closed/resolved so the grid stays stable.
- **Time tracker moved into the right sidebar, under Status.** The
  inline placement in the top action bar wrapped to multiple lines
  on narrow viewports and looked cramped. It now lives in the
  metadata sidebar where it has full width and never wraps, freeing
  the top bar to be a clean four-button row.

### Migrations

- `20260509_ticket_aisummary_model`: adds `Ticket.aiSummaryModel TEXT`
  (idempotent).

## [1.10.145042] — 2026-05-09

### Added

- **Deep Analysis runs in the background and resumes on remount.** The
  three-stage analyzer (Expert → Engineer → Writer) now persists each
  stage transition to `AiAnalysis.stageProgress` (new JSON column) plus
  `currentStage`. The SSE handler tolerates client disconnects (page
  refresh, tab switch, navigation) without aborting the worker, and the
  React component polls `/api/ai/analysis/<ticketId>` every 1.5s to
  re-attach to an in-flight analysis on mount. Result: agents can leave
  the page during a long analysis and find it completed when they
  return, instead of having to start over.
- **AI model attribution surfaced in the sidebar.** Both the Auto Triage
  card and the Deep Analysis result block now show "via <model>" under
  the content. For Deep Analysis the string is composite
  (`expert:… | engineer:… | writer:…`) so the agent sees exactly which
  model produced each stage. Each agent now reads its model from a
  Setting key (`ai.expertModel`, `ai.engineerModel`, `ai.writerModel`)
  with hard-coded fallbacks identical to today's behaviour.

### Changed

- **Manual ticket creation closes the modal instantly.** Previously the
  modal stayed open until the auto-triage finished (a 5-15 s wait when
  the AI provider was Claude/Codex CLI). The Server Action now fires
  the triage in the background (`void` + `.catch()`), saves the ticket
  immediately, and returns to the client. The triage shows up in the
  XpertTeamIA sidebar a few seconds later when its `AiAnalysis` row
  reaches `COMPLETED`.

### Migrations

- `20260509_aianalysis_progress`: adds `currentStage TEXT`,
  `stageProgress JSONB` to `AiAnalysis`. Idempotent (`IF NOT EXISTS`).

## [1.10.145041] — 2026-05-09

### Fixed

- **Codex CLI deep-analyze ne plante plus quand le modèle demandé est
  un modèle Claude.** Le service IA passait `params.model`
  (`claude-sonnet-4-6-…`) tel quel à `codex exec --model …`. Codex
  avec un compte ChatGPT n'accepte que des modèles OpenAI et renvoyait
  `400 invalid_request_error: model is not supported`. Le triage et
  la deep-analyze échouaient silencieusement quand le provider IA
  basculait sur `codex_cli` (explicite ou en fallback depuis
  `claude_cli`). Le fix détecte les identifiants `claude-*` et utilise
  à la place `CODEX_MODEL` (env) ou laisse Codex utiliser son modèle
  par défaut.

## [1.10.14504] — 2026-05-07

### Changed

- **Theme + sidebar style are now global, admin-only.** Up to 14503
  these lived in localStorage per browser, so agents had to redo the
  styling on every device and the admin's choice never propagated.
  Four new Setting keys (`branding.theme`, `branding.sidebarColor`,
  `branding.sidebarStyle`, `branding.customSidebarColors`) hold the
  global values; the root layout fetches them server-side and paints
  `<html data-theme>` + sidebar CSS vars without a flash. The
  `/profile` Apparence card is removed — agents go to
  `/settings/appearance` (admin only) to change appearance, and the
  change applies to every authenticated user.

- **Ticket page top action bar replaces the in-sidebar controls.**
  The right-side ticket sidebar was carrying both metadata and
  operationally critical actions (time tracking, billing toggle,
  CSAT survey, merge, delete/restore) — operators reported it as
  messy. A new `TicketActionBar` mounts a horizontal toolbar above
  the ticket #number/subject hosting the TimeTracker (left) and the
  four action buttons (right). The sidebar now carries metadata
  only (status, agent, customer, tags, details, dates). The
  collapsible AI panel on the right is unchanged.

## [1.10.14503] — 2026-05-07

### Fixed

- **Mailbox + customer logos cached for 24 h after replacement.** Each
  upload reused the deterministic filename `(mailbox|customer)-<id>.<ext>`,
  so the canonical URL was identical between uploads. Combined with
  `Cache-Control: max-age=86400` on the serve route, an operator who
  uploaded a new logo kept seeing the old one until cache expiry.
  Filenames are now timestamped (`(mailbox|customer)-<id>-<unix-ms>.<ext>`),
  so the resulting URL changes on every upload and the browser/CDN
  treats it as a new resource. Cleanup also removes legacy and older
  timestamped variants. Cache-Control lowered to `60s, must-revalidate`
  as a belt-and-braces measure for legacy rows.

## [1.10.14502] — 2026-05-07

### Changed — Signature model reworked

The per-agent / per-mailbox signature overrides shipped in v1.10.1450
(T1-T8) didn't fit the operational model. The new model is admin-only:

- The admin defines the signature for each mailbox in
  `/settings/mailboxes` (the existing `Mailbox.signature` field).
- At reply time, the email body is auto-suffixed with a fixed
  three-block template:
  1. The per-mailbox logo (`Mailbox.logoPath`) as an inline CID image.
  2. The replying agent's first + last name in bold.
  3. The mailbox signature HTML.
- Each block is skipped silently when its source is empty so the
  template degrades cleanly.
- The previous **global** brand logo from
  `Setting.branding.logoPath` (gated by the white-label feature) is no
  longer prepended to outgoing replies — the **per-mailbox logo**
  replaces it.

Agents no longer have any self-service control over signatures; the
"Signatures" tab is removed from `/profile`.

### Removed

- `UserMailboxSignature` table + `User.defaultSignature` column
  (down migration `20260507_drop_user_signatures`).
- `lib/signatures/resolve.ts` cascade resolver + DB-backed verify script.
- `lib/actions/user-signature.{actions,types}.ts` (6 server actions).
- `profile/signatures-tab.tsx` + `signature-preview.tsx`.
- 30 i18n keys (`profile.tabs.*`, `profile.signatures.*`) across the
  5 supported locales.
- The `Tabs` wrapper around `/profile` (single section now).

### Upgrade notes

Existing operators don't need to do anything — the down migration
runs automatically on container restart. Any per-agent signature data
saved in the brief v1.10.1450 → v1.10.14501 window is dropped.

## [1.10.14501] — 2026-05-07

### Fixed

- **Language picker now reachable from `/profile`.** Agents without ADMIN
  role couldn't access `/settings/language` (settings tree is admin-only),
  so they had no way to change the WebUI language. The existing picker was
  extracted into a shared `LanguagePicker` component and mounted as a new
  card under the Profile tab. 10 new i18n keys (`profile.language`,
  `profile.languageDesc` × 5 locales).

## [1.10.1450] — 2026-05-07

### Added

- **Per-agent email signatures with cascade resolution.** Each agent can now
  manage their own signatures from `/profile` → onglet « Signatures »:
  - One default signature used across every mailbox the agent has access to.
  - Optional per-mailbox overrides for agents who need a different sign-off
    on specific mailboxes.
  - Cascade at reply time: per-(user, mailbox) override → user default
    → legacy mailbox signature + auto-injected agent name.
  - The mailbox logo is reused (no new upload UI). Tiptap rich editor with
    DOMPurify-based sanitization on save and on render. 30 new i18n keys
    in 5 locales. New table `UserMailboxSignature` (composite key, ON DELETE
    CASCADE) and a new nullable `User.defaultSignature` column.

- **Senior-engineer AI prompts** with prompt-injection guardrails: the
  Expert and Engineer agents now treat ticket content as untrusted input
  and ignore role-override instructions hidden in emails or quoted text.

- **Expert-skill weighted matching.** Skills triggered by subject hits rank
  above body hits, multi-word triggers above single-word; loaded skill
  names propagate into the resolution metadata for traceability.

- **Trusted-proxy mode** (`TRUSTED_PROXY_MODE` env: legacy/none/cloudflare/
  sophos/custom). Cloudflare and custom WAF country/IP headers are now
  trusted only when an explicit Caddy-injected proof header is present
  (`X-TicketBrainy-Trusted-Proxy`), preventing direct-origin spoofing.
  Cloudflare IPv6 ranges added to Caddy's `trusted_proxies`.

- **Geo-block auto-persistence.** Geo-blocked IPs are written to
  `IpBlocklist` for 24 h with structured metadata; admins can later remove
  them via the dashboard or via the new IP unban allowlist Setting.

- **Security dashboard period filter** (24h / 48h / 7d / 30d) drives all
  KPIs, the timeline, and the country chart. Blocked-IPs KPI gets a dialog
  showing live blocklist rows with a one-click unban action.

- **Inbound email security.** New `email-security` module classifies
  dangerous attachments (executables, macros, archives) and sanitizes
  inbound HTML before persistence.

### Fixed

- **Cloudflare email obfuscation no longer breaks hydration.** Email
  addresses in `UserMenu` now render via a `ClientText` component that
  delays output until after mount, and the root layout wraps the app in
  `<!--email_off-->` markers. Public-email-domains section was rewritten
  as a Server Component using native `<form action>` POSTs so that the
  delete button keeps working when CF email-decode injection breaks
  React hydration.

- **Public email domains can now be deleted** by ADMIN or SUPERVISOR.
  Legacy `isDefault=true` rows are silently migrated on read; the seed no
  longer re-applies the immutable flag.

- **Manual deep-analysis enforced.** `updateMailbox` always sets
  `autoDeepAnalysis=false` so legacy rows or stale clients can't re-enable
  automatic deep analysis behind the operator's back.

- **Claude CLI auth fallback.** When Claude CLI returns 401 / authentication
  errors, the AI service transparently falls back to Codex CLI instead
  of failing the analysis.

### Security

- **Keycloak device-flow + dynamic client-registration blocked at the
  edge.** Caddy now responds 404 on `/realms/*/device` and
  `/realms/*/clients-registrations` (defense-in-depth, IT-Secure pentest
  finding).

- Tighter CSP: `script-src-elem` allows the official Cloudflare
  email-decode script only; `Cache-Control: no-transform` defeats CDN
  HTML rewriting that previously corrupted nonce-protected scripts.

## [1.10.144923] — 2026-05-06

### Added

- **Customer salutation field (M./Mme.)** — new optional field on the
  Customer record (Mr / Mrs / —) plus a new email template placeholder
  `{%customer.salutation%}` that renders as `M.` / `Mme.` / `""`.
  Auto-replies can now greet recipients politely as
  `"Bonjour M. BELLO,"` or `"Bonjour Mme. DUPONT,"` instead of the bare
  `"Bonjour BELLO,"`. The default auto-reply template now includes the
  placeholder; existing user-edited templates keep working unchanged
  but must be edited manually to take advantage of the new placeholder.
  When the customer's salutation is null (default), the placeholder
  expands to an empty string and a post-substitution pass collapses
  any resulting double space.

  New i18n keys (`customers.salutation`, `customers.salutationMr`,
  `customers.salutationMrs`) added across all 5 supported languages.

  Migration: `add_customer_salutation` (nullable column, no backfill).

## [1.10.144922] — 2026-05-06

### Fixed

- **Keycloak TOTP enrollment now works with Google / Microsoft Authenticator**
  — the realm `otpPolicyAlgorithm` was set to `HmacSHA256` in an earlier
  hardening pass, but Google Authenticator and Microsoft Authenticator
  ignore the `algorithm` parameter in the QR-code `otpauth://` URI and
  always compute SHA-1. Result: every code generated by these apps was
  rejected with "Le code d'authentification est invalide" / "Invalid
  authentication code", regardless of the app used. Reverted to
  `HmacSHA1` (the RFC 6238 default, accepted by NIST 800-63B and used by
  Google, GitHub, AWS, etc.). Security is preserved by the 160-bit
  shared secret, not the HMAC variant. Affected: `keycloak/apply-config.sh`
  and `keycloak/ticketbrainy-realm.json`. Existing users who had enrolled
  TOTP under the old policy must reset their OTP credential and re-scan.

## [1.10.144921] — 2026-05-01

### Fixed

- **CSAT email now threads with the ticket conversation** — the satisfaction
  survey no longer creates a separate Gmail/Outlook conversation that
  appeared at the top of the inbox before the reply. Subject is now
  `Re: [#N] <ticket subject> — Votre avis` and `In-Reply-To` points at the
  last ticket message, so REPLY → CLOSURE → CSAT all live in the same
  thread, in chronological order. Pipeline ordering was already correct
  (queue is FIFO, sender is awaited); only the visible threading was off.

## [1.10.14492] — 2026-04-29

### Fixed

- **AI auth survives credential rotations** — bind-mount the host Claude
  directory (read-only) instead of a single file, so OAuth credential
  rotations on the host (atomic rename) become visible to the ai-service
  container immediately. `docker-claude-init.sh` re-syncs the volume copy
  every 5 minutes in a background loop, so AI features keep working
  without any container restart after the Claude CLI rotates its tokens.
  Resolves silent 401 "Invalid authentication credentials" failures on
  long-running deployments. Adds `HOST_CLAUDE_DIR` env var.

### Changed

- **Discrete AI thinking indicator** across the ticket sidebar (Auto Triage,
  Conversation Summary) and the in-composer AI Assistant draft panel:
  pulsing brain icon, cycling stage label (reading → consulting expert
  skills → reasoning → drafting), shimmer + 3-dot bounce, with i18n keys
  in 5 languages. Replaces silent skeleton placeholders that gave the
  impression nothing was happening during long AI calls.

### Added

- **Backup & disaster recovery system** — on-demand encrypted full backups via
  `npm run backup`, with rotation of the last 7 archives stored in the **private**
  repo only. Restore on a fresh server via `./scripts/restore.sh BACKUP/<archive>.tgz.gpg`.
  Targets < 30 min full disaster recovery on a brand-new Linux+Docker host.
  See `BACKUP/README.md` and `docs/RUNBOOK-DISASTER-RECOVERY.md`.
  Defense-in-depth ensures `BACKUP/` never reaches the public repo.

For prior version history, see `git log` and the project memory entries.
