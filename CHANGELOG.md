# Changelog

All notable releases of TicketBrainy.

## [1.11.52] — 2026-07-24

### Corrigé
- **Les réponses à une relance d'« Auto-fermeture » restent dans le ticket
  d'origine.** Les e-mails d'auto-fermeture (message initial, relances et fermeture
  finale) partaient sans le repère `[Ticket #N]` ni les en-têtes de conversation, et
  n'apparaissaient pas dans l'historique du ticket. Quand un client répondait à une
  relance, un **nouveau ticket** était créé au lieu de poursuivre l'échange. Désormais
  ces e-mails portent le numéro du ticket d'origine, sont visibles dans son historique,
  et **toute réponse rouvre le ticket d'origine** au lieu d'en créer un nouveau. Le
  texte de l'e-mail de fermeture indique maintenant qu'une réponse rouvrira le ticket.

## [1.11.51] — 2026-07-17

### Corrigé
- **Autocomplétion des clients : recherche sur le contact et l'e-mail.** Les
  suggestions du formulaire « Nouveau ticket » ne trouvaient pas un client
  enregistré sous un nom d'entreprise lorsqu'on tapait le nom de la personne à
  contacter. La recherche porte désormais sur le nom du client, son e-mail, ainsi
  que le **nom et l'e-mail du contact** ; sélectionner un contact remplit
  directement son nom et son adresse e-mail.

## [1.11.50] — 2026-07-17

Deux améliorations du formulaire « Nouveau ticket » (création manuelle par un agent).

### Ajouté
- **Autocomplétion des clients connus.** En tapant le début du nom ou de l'adresse
  e-mail d'un client déjà présent dans le système, une liste de suggestions
  apparaît : un clic remplit automatiquement le nom **et** l'e-mail. Plus besoin de
  ressaisir un client existant ; la saisie manuelle reste possible pour un nouveau
  contact.
- **Assistant IA à la création d'un ticket.** L'aide à la rédaction par IA
  (décrire le message souhaité, choisir la langue, générer), jusqu'ici disponible
  uniquement lors de la réponse à un ticket, l'est désormais aussi dans le
  formulaire de création. Nécessite le module IA de génération d'e-mails.

## [1.11.49] — 2026-07-12

Deux correctifs de fiabilité de l'Assistant IA en mode abonnement Claude Code CLI.

### Corrigé
- **Option « Claude Code CLI » indisponible à tort** (« CLI non détecté sur le
  serveur ») : l'indicateur de connexion pouvait signaler le CLI comme
  indisponible après une période d'inactivité, alors que l'abonnement restait
  parfaitement connecté. L'état affiché reflète désormais la connexion réelle de
  l'abonnement — l'option reste sélectionnable tant que la session est valide.
- **Assistant IA basculant vers « clé API non configurée »** : dans certains cas,
  le mode Claude sélectionné n'était pas reconnu et l'Assistant réclamait une clé
  API. Le mode choisi est désormais respecté de façon robuste — plus de décrochage
  silencieux.
- **Identifiants Claude figés sur un ancien instantané** (montage Docker) : les
  identifiants de l'abonnement étaient montés dans les conteneurs comme un
  **fichier unique**, ce qui épinglait l'inode au démarrage. Quand le CLI Claude
  fait tourner son jeton sur l'hôte (remplacement atomique du fichier), les
  conteneurs continuaient de lire l'ancien instantané expiré → l'option
  « Claude Code CLI » se grisait alors que l'abonnement restait valide. On monte
  désormais le **répertoire** `~/.claude` (au lieu du seul fichier) : les
  rotations de jeton sont visibles immédiatement, sans recréation de conteneur.

### Note de mise à jour
Ce correctif touche le montage des volumes : la mise à jour **doit recréer les
conteneurs**. Utiliser :
`cd /opt/ticketbrainy && git pull && docker compose up -d --force-recreate`
Si l'option Claude reste indisponible ensuite, c'est que la session d'abonnement a
réellement expiré : une simple reconnexion (`claude` sur l'hôte) suffit.

## [1.11.48] — 2026-07-11

Correctif de la cause racine des erreurs d'authentification récurrentes de
l'Assistant IA (mode abonnement Claude Code CLI).

### Corrigé
- **Fin des erreurs 401 récurrentes de l'Assistant IA** : sous charge, plusieurs
  requêtes IA simultanées pouvaient invalider le jeton de connexion et provoquer
  une erreur d'authentification persistante jusqu'à une reconnexion manuelle. Les
  appels au moteur IA sont désormais traités un à la fois, ce qui supprime la
  cause à la racine — l'Assistant reste disponible de façon fiable.
- **Indicateur de connexion IA fiable et sans effet de bord** : le badge de
  statut des réglages reflète l'état réel du jeton (connecté / expiré) en lisant
  simplement sa date d'expiration, sans solliciter le moteur — plus de faux
  négatifs ni de charge inutile.

### Note de mise à jour
Si l'Assistant affichait déjà l'erreur avant cette mise à jour, une reconnexion
unique reste nécessaire pour repartir d'un jeton sain ; ensuite, le problème ne
se reproduit plus.

## [1.11.47] — 2026-07-11

Correctif de fiabilité de l'Assistant IA, signalé de façon récurrente.

### Corrigé
- **Fin des erreurs intermittentes de l'Assistant IA** : dans certains cas,
  l'Assistant IA cessait de répondre et affichait une erreur d'authentification,
  alors que la configuration était correcte. La cause profonde est traitée et
  l'Assistant reste disponible de façon fiable.
- **Statut de connexion IA fiable** : l'indicateur de connexion dans les
  réglages reflète désormais l'état réel de l'authentification, et non la seule
  présence de l'outil — plus de faux « connecté ».
- **Changement de fournisseur IA immédiat** : basculer de fournisseur ou mettre
  à jour une clé dans les réglages prend effet aussitôt, sans redémarrage.

## [1.11.46] — 2026-06-13

Correctif d'un blocage signalé par les équipes de support.

### Corrigé
- **Plus de ticket « verrouillé » pour les autres agents** : lorsqu'un agent
  ouvrait un ticket et passait à autre chose sans fermer l'onglet, la zone de
  réponse devenait inaccessible à tous les autres agents. Désormais, le composer
  n'est plus jamais bloqué : si un collègue rédige déjà une réponse sur le même
  ticket, une simple bannière d'information l'indique. L'indicateur disparaît
  automatiquement après une minute d'inactivité.

## [1.11.45] — 2026-06-08

Suite des améliorations du flux e-mail.

### Corrigé
- **Accusé de réception plus lisible** : le rappel du message d'origine dans
  l'accusé automatique envoyé au client est désormais nettoyé — plus de codes
  d'images parasites (`[cid:…]`), de liens de passerelle de sécurité illisibles
  ni de bloc signature recopié, et la coupure se fait proprement en fin de mot.
- **Aperçus de tickets cohérents** : le même nettoyage s'applique aux aperçus
  des notifications agents (nouveau ticket, réponse client) et à l'aperçu
  Telegram. Le message complet conservé dans le ticket reste inchangé.

## [1.11.44] — 2026-06-04

Améliorations du flux e-mail des tickets, en réponse aux retours clients et
agents.

### Corrigé
- **Attribution d'un client** : changer le client d'un ticket envoie désormais
  un message d'attribution clair au nouveau contact (« Le ticket #N vous a été
  attribué… »), citant la demande d'origine, au lieu de l'accusé de réception
  générique « Nous avons bien reçu votre demande » qui prêtait à confusion.
- **Suivi des envois automatiques** : les accusés de réception et messages
  d'attribution apparaissent maintenant dans le fil du ticket, visibles et
  traçables côté agent.
- **Regroupement des e-mails** : réponses et accusés portent les bons en-têtes
  de conversation (References) et un objet « Re: [Ticket #N] … » cohérent, ce
  qui évite les conversations dédoublées (notamment sous Outlook).

### Mise à jour

```bash
cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d
```

## [1.11.43] — 2026-06-02

Sécurité : mise à jour de Next.js (16.2.4 → 16.2.6) intégrant les correctifs
de sécurité critiques publiés par Vercel. Mise à jour recommandée.

### Sécurité
- **Next.js 16.2.6** : 13 correctifs de sécurité (déni de service,
  contournement middleware/proxy, SSRF, empoisonnement de cache, XSS, plus
  une faille React amont), dont CVE-2026-44578 (CVSS 8.6). Aucun changement
  fonctionnel côté application.

### Mise à jour

```bash
cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d
```

## [1.11.42] — 2026-06-01

Confort : la fenêtre « Nouveau ticket » (création manuelle d'un ticket) était
trop étroite pour rédiger un message à l'aise.

### Améliorations
- **Fenêtre de création élargie** : modal nettement plus large et plus haut, et
  zone de saisie du message agrandie, pour rédiger confortablement.

### Mise à jour

```bash
cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d
```

## [1.11.41] — 2026-06-01

Correctif : lors de la création manuelle d'un ticket depuis l'interface, le
client reçoit désormais le message rédigé par l'agent — et non plus un accusé
de réception générique.

### Correctif
- Le message saisi par l'agent à la création d'un ticket est bien transmis au
  client (destinataire, copies Cc/Bcc et expéditeur de la boîte inchangés) et
  s'affiche du bon côté de la conversation, comme une réponse sortante.

### Mise à jour

```bash
cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d
```

## [1.11.40] — 2026-05-31

Vues sauvegardées dans la file de tickets. Chaque agent peut nommer et persister
un jeu de filtres et le rappeler en un clic depuis la barre latérale.

### Fonctionnalités
- **Vues sauvegardées (privées)** : un bouton « Sauvegarder la vue » dans la
  barre de filtres enregistre les filtres actifs (statut, priorité, boîte,
  assigné, tag, recherche, tri) sous un nom ; la barre latérale liste vos vues
  pour les rappeler ou les supprimer en un clic.

### Notes
- Vues privées à chaque agent. Aucune migration de données (nouvelle table créée
  automatiquement au déploiement).

### Mise à jour

```bash
cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d
```

## [1.11.39] — 2026-05-31

Correctif de déploiement pour la 1.11.38 : la création de la contrainte d'unicité
Message-ID pouvait faire échouer l'étape de migration au démarrage. L'index est
désormais créé directement par la migration (idempotente), sans interruption.

### Correctif
- La contrainte d'unicité (ticketId, Message-ID) est créée par la migration
  elle-même, évitant l'échec de l'étape de migration au déploiement.

### Notes
- Aucun changement fonctionnel. Aucune action manuelle requise.

### Mise à jour

```bash
cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d
```

## [1.11.38] — 2026-05-31

Fiabilité : protection contre la double-ingestion d'un même email dans un fil de
ticket, avec déduplication automatique des éventuels doublons déjà présents au
déploiement.

### Fiabilité
- Un même email entrant ne peut plus créer de message en double dans un fil de
  ticket (course de relève force-poll/listener), grâce à une contrainte
  d'unicité Message-ID par ticket.
- La mise à jour déduplique automatiquement les doublons existants (migration
  idempotente, sans intervention manuelle).

### Notes
- Aucun changement fonctionnel visible.

### Mise à jour

```bash
cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d
```

## [1.11.37] — 2026-05-31

Durcissement sécurité : les valeurs fournies par le client (sujet du ticket,
nom du client, premier message) sont désormais systématiquement échappées dans
les emails sortants (notifications aux agents, accusés de résolution, relances
d'auto-clôture, réponses automatiques). Un contenu porteur de balisage HTML ne
peut plus altérer le rendu d'un email envoyé.

### Sécurité
- Échappement systématique des champs contrôlés par le client interpolés dans
  les corps d'emails.
- Le gabarit d'email déclare explicitement la nature (HTML ou texte) de chaque
  corps, supprimant une heuristique de détection de contenu contournable.

### Notes
- Aucun changement fonctionnel visible ni migration de base de données.

### Mise à jour

```bash
cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d
```

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

### Mise à jour

```bash
cd /opt/ticketbrainy && git pull && docker compose pull && docker compose up -d
```

## [1.11.35] — 2026-05-30

> Correctif de performance — **service d'envoi d'emails**.

### Performance

- Le service de messagerie n'immobilise plus sa connexion Redis pendant l'attente de nouveaux
  emails à envoyer : la lecture bloquante de la file tourne désormais sur une connexion dédiée.
  Les opérations en parallèle (mise en file des emails sortants, notifications, supervision des
  sauvegardes) ne sont plus retardées (jusqu'à 5 secondes auparavant). Comportement d'envoi
  inchangé.

Aucune migration de base de données. Mise à jour applicative simple.

## [1.11.34] — 2026-05-30

> Correctif de performance — **analyse approfondie (Deep Analysis)**.

### Performance

- Lancer une analyse approfondie d'un ticket n'ouvre plus qu'**un seul flux temps réel** au lieu
  de deux requêtes concurrentes (le suivi en direct et une interrogation répétée de la base toutes
  les 1,5 s tournaient en parallèle). La charge sur la base et le service IA pendant une analyse
  est nettement réduite, sans changement visible côté interface.
- Si la connexion temps réel est interrompue en cours d'analyse, l'interface rejoint
  automatiquement l'analyse en arrière-plan (qui continue côté serveur) au lieu d'afficher une
  erreur — et un « Relancer » ne risque plus de déclencher une analyse en double.

Aucune migration de base de données. Mise à jour applicative simple.

## [1.11.33] — 2026-05-30

> Correctif de performance — **rattachement des tickets orphelins**.

### Performance

- L'outil « Rattacher les orphelins » (Réglages → Clients) traite désormais l'ensemble des
  tickets en **un nombre de requêtes constant** au lieu de plusieurs requêtes par ticket. Sur
  les installations avec un grand historique de tickets non rattachés, l'opération est nettement
  plus rapide et ne risque plus de saturer la base. Le résultat (tickets rattachés) est
  **strictement identique**.

Aucune migration de base de données. Mise à jour applicative simple.

## [1.11.32] — 2026-05-30

> Correctif de performance — **rapports de temps**.

### Performance

- Les totaux des rapports de temps (heures totales, heures facturables, montant) sont
  désormais calculés directement en base de données sur **l'ensemble** des entrées
  correspondant à vos filtres — plus rapides et exacts, même sur de très gros volumes.
- La liste affichée est limitée à 5000 lignes, avec un message d'avertissement invitant à
  affiner les filtres au-delà ; les totaux, eux, restent calculés sur l'ensemble.
- La table des temps est désormais indexée pour accélérer le filtrage par date et par agent.

Aucune migration de base de données. Mise à jour applicative simple.

## [1.11.31] — 2026-05-30

> Correctif de performance — **chargement de la barre latérale**.

### Performance

- Les compteurs de tickets par boîte mail affichés dans la barre latérale (rafraîchis
  automatiquement toutes les 30 secondes) sont désormais calculés en **une seule requête**
  au lieu de plusieurs par boîte. Sur les installations à fort volume, cela réduit
  nettement la charge base de données de l'écran le plus consulté. Les compteurs affichés
  sont **strictement identiques**.

Aucune migration de base de données. Mise à jour applicative simple.

## [1.11.3] — 2026-05-30

> Version mineure — **exactitude et performance des analyses SLA & CSAT**.

### Corrigé

- Les tableaux de bord **Conformité SLA** et **Satisfaction (CSAT)** calculent
  désormais leurs indicateurs (taux de conformité, moyennes, histogrammes,
  distributions) sur **l'intégralité** de la période sélectionnée. Auparavant, au-delà
  d'un certain volume de tickets ou de réponses, les chiffres étaient calculés sur un
  échantillon tronqué — et donc potentiellement inexacts — sans aucun avertissement.
- La liste des tickets en dépassement de SLA s'affiche dans un ordre stable.

### Performance

- Les pages Analyses SLA et CSAT s'appuient désormais sur des agrégations en base de
  données, réduisant l'empreinte mémoire et le temps de chargement sur les grands
  volumes.

Aucune migration de base de données. Mise à jour applicative simple.

## [1.11.21] — 2026-05-30

> Correctif — **lisibilité des fils de tickets** : meilleure suppression des
> citations recopiées dans les mails entrants.

### Corrigé

- Les citations de l'historique recopiées par le client (Outlook bureau et web,
  Gmail, Apple Mail, Thunderbird) sont désormais bien masquées dans les réponses
  entrantes — y compris sur les **réponses courtes** (« Merci », un numéro), qui
  affichaient auparavant tout l'historique. Un bouton « Afficher le message
  complet » reste disponible pour dérouler le message d'origine.
- Les bannières ajoutées par les passerelles de sécurité (ex. Sophos) en tête de
  message sont retirées de l'affichage.
- Le masquage s'applique aussi au premier message d'un ticket, pas seulement aux
  réponses.

Affichage uniquement : le message d'origine reste intégralement conservé.

## [1.11.2] — 2026-05-29

> Version mineure — **localisation des enquêtes de satisfaction** et
> internationalisation côté serveur.

### Ajouté

- Les enquêtes de satisfaction (CSAT) sont désormais entièrement localisées :
  email d'enquête, page de confirmation et page de remerciement s'affichent
  dans la langue de l'agent qui les déclenche, dans les 5 langues (français,
  anglais, allemand, espagnol, italien).
- Résolution de la langue côté serveur (cookie `tb-locale`, repli sur la langue
  du navigateur). Les dictionnaires de traduction ne sont plus embarqués dans le
  JavaScript envoyé au navigateur, ce qui allège le bundle client.

### Modifié

- Le triage et l'analyse IA respectent désormais la langue choisie dans
  l'interface.

### Sécurité

- Le sujet du ticket est échappé dans le corps HTML de l'email d'enquête CSAT
  (prévention d'injection de balises).

## [1.11.1] — 2026-05-29

> Version mineure — **localisation** des écrans clés.

### Ajouté

- Localisation complète de la page de connexion et de la cloche de
  notifications (temps relatif inclus) dans les 5 langues (français, anglais,
  allemand, espagnol, italien).
- Extraction des libellés codés en dur vers les traductions sur le badge SLA,
  la recherche globale, le tableau de bord, les axes du graphique d'activité,
  la file de tickets et l'éditeur de réponse.

### Modifié

- L'alerte d'expiration de licence respecte désormais la langue choisie.

### Corrigé

- Correction d'un scintillement possible du badge SLA au chargement de la page
  d'un ticket.

## [1.11.0] — 2026-05-29

> Version mineure — durcissement **sécurité & fiabilité recommandé**.

### Sécurité

- Cloisonnement par boîte mail renforcé sur l'ensemble des actions sensibles :
  fusion de tickets, gestion des tags et des clients réservées aux
  administrateurs / superviseurs ; liaison client, génération et partage
  d'articles de base de connaissances limités au périmètre de l'agent.
- Durcissement du crawler de la base de connaissances (RAG) contre les accès
  réseau internes (protection SSRF, y compris re-bind DNS).
- Les données clients envoyées à l'IA (tri, analyse, résumé) sont désormais
  expurgées de leurs informations personnelles ; le contenu web externe est
  traité comme une source non fiable.
- Jetons OAuth isolés par boîte mail (plus de partage entre boîtes) ;
  connexion SSO Keycloak refusée tant que l'e-mail n'est pas vérifié ;
  image du moteur de recherche interne épinglée et secret régénéré.

### Performance & fiabilité

- File de tickets : index optimisé pour la vue par défaut ; le filtre de boîte
  mail d'un agent n'est plus écrasé.
- Statistiques CSAT corrigées (agrégation par agent, taux borné à 100 %).
- Disparition des avertissements d'affichage (heures relatives) sur la file et
  le tableau de bord.

### À noter pour les administrateurs

- **SSO Keycloak** : assurez-vous que votre realm émet le claim
  `email_verified` (un compte sans e-mail vérifié sera refusé). Testez une
  connexion SSO après mise à jour.

## [1.10.147802] — 2026-05-29

> Mise à jour de sécurité **recommandée** (complète la 1.10.147801).

### Sécurité

- Les identifiants OAuth d'une boîte mail ne peuvent plus être définis que par
  un administrateur (auparavant aussi accessibles aux superviseurs), au même
  titre que les identifiants IMAP/SMTP.
- La création d'un ticket est désormais restreinte aux boîtes mail dont l'agent
  est membre : un agent ne peut plus créer de ticket — ni déclencher d'e-mail
  d'accusé — depuis la boîte d'une autre équipe.

### Corrigé

- Relève manuelle des e-mails : la récupération « supprimer un ticket →
  marquer le mail non lu → relancer la relève » recrée à nouveau le ticket
  (régression de la 1.10.147801).

## [1.10.147801] — 2026-05-29

> Mise à jour de sécurité et de fiabilité **recommandée**.

### Sécurité

- Renforcement du cloisonnement par boîte mail : un agent n'accède qu'aux
  tickets, pièces jointes et résultats de recherche de ses propres boîtes
  (corrections d'isolation inter-boîtes sur la recherche, les pièces jointes,
  le verrou d'édition et le changement de client d'un ticket).
- Les règles d'exclusion d'e-mails entrants, ainsi que la définition des
  identifiants IMAP/SMTP à la création d'une boîte mail, sont réservées aux
  administrateurs / superviseurs.
- Le verrou anti-fraude de licence s'applique désormais aussi aux modules
  premium, et non plus au seul cœur de l'application.

### Corrigé

- Relève manuelle des e-mails : plus de tickets ni de notifications en double,
  et une réponse n'est plus rattachée à un ticket supprimé.
- L'IA (tri, analyse, résumé) n'inclut plus les brouillons d'agent dans son
  contexte.
- Commande Telegram `/backup` : dates comparées en UTC — fin des faux
  « manquant » / « erreur » selon le fuseau horaire du serveur.

## [1.10.147800] — 2026-05-28

### Changed

- **Pièces jointes affichées en haut du message.** Dans un ticket, les pièces
  jointes (icône trombone, nom du fichier et taille) apparaissent désormais en
  haut du message — sous les indicateurs SPF/DKIM/DMARC et près de la ligne
  « En copie » — plutôt que sous le corps du message, pour les repérer
  immédiatement.

## [1.10.147799] — 2026-05-28

### Added

- **Réponse « à tous » automatique.** Lorsqu'un client met des personnes en
  copie (CC) en créant un ticket, votre réponse depuis l'interface inclut
  désormais ces destinataires d'office : le champ CC est **pré-rempli et
  visible**, et reste **modifiable** — vous pouvez retirer une adresse avant
  d'envoyer. Un ticket sans CC n'envoie qu'à l'expéditeur, comme avant.
- **Brouillon de réponse conservé automatiquement.** Si vous saisissez une
  réponse sans l'envoyer puis quittez le ticket, rafraîchissez la page ou
  changez de poste, votre texte (et les CC/BCC) est **restauré** à votre retour
  avec un badge « Brouillon ». Le badge disparaît dès que vous modifiez le
  message. Les brouillons sont automatiquement supprimés après 48 h.

## [1.10.147798] — 2026-05-28

### Added

- **Adresses Cc / Cci à la création d'un ticket manuel.** Le formulaire
  « Nouveau ticket » propose désormais un bouton « Ajouter Cc / Cci » qui
  déplie deux champs CC et CCI. Les destinataires renseignés reçoivent une
  copie de l'email d'accusé de réception envoyé au client et apparaissent
  dans le fil de conversation du ticket.

## [1.10.147797] — 2026-05-26

### Fixed

- **Assistant IA / génération de réponse en erreur `refresh_token_reused`.**
  Sur les instances utilisant le compte Codex/OpenAI du serveur, l'Assistant
  IA pouvait cesser de fonctionner au bout de quelques heures avec une erreur
  `401 refresh_token_reused`. Cause : le jeton d'authentification est
  renouvelé automatiquement à l'intérieur du conteneur, mais la synchronisation
  interne écrasait périodiquement ce jeton fraîchement renouvelé par l'ancienne
  copie (déjà consommée) présente sur le serveur hôte. La synchronisation passe
  désormais en mode « mise à jour uniquement » : le jeton renouvelé par le
  conteneur est préservé, tandis qu'un nouveau `codex login` sur l'hôte continue
  de se propager normalement.
  - *Récupération sur une instance déjà affectée* : exécuter `codex login` sur
    le serveur hôte, puis
    `docker compose up -d --force-recreate ai-service web`.

## [1.10.147796] — 2026-05-26

### Fixed

- **Réponses ticket contenant du code technique bloquées sans message.**
  Lorsqu'un agent envoyait une réponse (ou créait un ticket / une note
  interne) contenant un script PowerShell, une commande shell, une
  expression régulière ou une requête SQL, l'envoi pouvait échouer
  silencieusement : aucun message n'apparaissait dans le fil et l'agent
  pensait son message parti. Cause : votre WAF / Cloudflare considère ces
  patterns techniques comme des tentatives d'injection (RCE/XSS/SQLi) et
  rejette le POST en 403 avant qu'il n'atteigne l'application. Le contenu
  rédigé par l'agent est désormais encodé de façon transparente avant
  l'envoi et décodé côté serveur, ce qui contourne la règle WAF sans rien
  changer au stockage ni à l'affichage. Ce traitement, déjà appliqué aux
  articles de la base de connaissances en 1.10.147795, couvre maintenant
  les réponses publiques, les notes internes et la création de tickets.
- **Message d'erreur explicite en cas de blocage.** Si un envoi échoue
  malgré tout (autre motif côté WAF, coupure réseau), un message
  « Envoi bloqué — réessayez ou contactez l'administrateur » s'affiche
  désormais, au lieu d'un silence trompeur.

## [1.10.147795] — 2026-05-25

### Fixed

- **Sauvegarde d'article KB bloquée après reformatage IA.** Quand vous
  cliquiez sur **✨ Améliorer avec IA** puis sur **Mettre à jour
  l'article**, l'enregistrement échouait avec un toast générique
  « Échec de l'enregistrement ». Cause : votre WAF / Cloudflare bloque
  les patterns de callouts GitHub-style (`> [!WARNING]`, `> [!TIP]`,
  `> [!INFO]`) que Claude insère systématiquement dans le markdown
  reformaté, les considérant comme une tentative d'injection XSS — le
  POST était rejeté en 403 avant même d'atteindre l'application. Le
  contenu KB est désormais transparenté encodé avant l'envoi
  (préfixe `b64:`) et décodé côté serveur, ce qui contourne la règle
  WAF sans rien changer au stockage en base ni à l'affichage des
  articles.

### Changed — IMPORTANT pour les opérateurs

- **Nouvelle variable d'environnement requise** :
  `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`. Sans cette variable, chaque
  redéploiement Docker générait des identifiants de Server Actions
  différents, ce qui cassait tous les onglets actuellement ouverts
  par vos agents (erreur **403 / Failed to find Server Action** lors
  du premier clic après une mise à jour, résolu uniquement par un
  hard-refresh). Avec une clé stable, les onglets ouverts continuent
  de fonctionner après chaque redéploiement.
  - **À faire** : générer la clé une seule fois et l'ajouter dans
    votre `.env` :
    ```
    openssl rand -base64 32
    ```
    puis ajouter dans `/opt/ticketbrainy/.env` :
    ```
    NEXT_SERVER_ACTIONS_ENCRYPTION_KEY=<la-valeur-générée>
    ```
  - **Sans rotation** : gardez la même valeur. Ne la changez que si
    vous suspectez une fuite (auquel cas tous les onglets ouverts
    redeviendront invalides, comportement attendu).

- `SERVER_ACTIONS_ALLOWED_ORIGINS` (optionnelle) — l'hôte extrait de
  `APP_URL` est désormais autorisé automatiquement pour les Server
  Actions derrière reverse proxy / WAF. Définissez cette variable
  uniquement si vous servez l'application depuis plusieurs noms de
  domaine.

## [1.10.147793] — 2026-05-25

### Added

- **Bouton « ✨ Améliorer avec IA » dans l'éditeur d'article KB.**
  L'éditeur visuel introduit en v147792 restait passif : un texte brut
  collé (par exemple une procédure pas-à-pas) restait brut. Vous pouvez
  désormais cliquer sur **✨ Améliorer avec IA** en haut à droite de la
  barre d'outils pour que Claude reformate le contenu en article
  structuré : sections **Contexte / Diagnostic / Procédure / Conseils**,
  étapes numérotées avec titres d'action (`### Étape 1 : Vérifier
  l'alimentation`), encarts **Conseil / Attention / Info** insérés
  automatiquement aux bons endroits, valeurs techniques (commandes,
  chemins, durées) préservées à l'identique. Aucune invention de
  contenu. Utilise le même modèle que SmartReply (réglable dans
  *Paramètres → XpertTeamIA*).

## [1.10.147792] — 2026-05-25

### Fixed

- **Création KB depuis ticket résolu : contenu nettoyé et complet.** Le
  bouton « Résolu + Créer KB » générait un article qui (1) affichait du
  HTML brut (`<html><head>…`) quand la réponse agent n'avait pas de
  partie texte, et (2) tronquait la procédure à 300 caractères — les
  étapes `Step 1`, `Step 2`, etc. de la réponse agent étaient perdues.
  Désormais : l'HTML est nettoyé, les brouillons non envoyés sont
  ignorés, la dernière réponse réellement envoyée par l'agent est
  utilisée comme source, et les marqueurs `Step N` / `Étape N` sont
  convertis en sections Markdown `### Étape N : …` complètes.

### Changed

- **Éditeur d'articles KB désormais en mode visuel (WYSIWYG).** L'écran
  de création / édition d'article (`/kb/new`, `/kb/[id]`) utilisait un
  textarea Markdown brut, qui figeait sur les longs contenus et obligeait
  les agents à taper la syntaxe Markdown à la main. Remplacé par un
  éditeur Tiptap avec barre d'outils visuelle (gras, italique, code,
  titres, listes, citation, lien, et boutons dédiés pour insérer les
  encarts **Conseil / Attention / Info**). La sauvegarde reste en
  Markdown, donc les articles existants s'ouvrent sans conversion.

## [1.10.147790] — 2026-05-21

### Fixed

- **BackupMonitor — rapport Telegram quotidien : un job hebdomadaire
  apparaissait ✅ tous les jours.** Si vous aviez configuré un backup
  qui ne tourne qu'un seul jour de la semaine (ex. SBTP EXT-USB le
  vendredi), son ✅ du vendredi continuait d'apparaître sur le rapport
  quotidien de 06h00 tous les jours suivants, jusqu'au vendredi
  suivant. Les jobs Lun-Ven n'étaient pas concernés car ils avaient
  une ligne « légitime » du jour précédent qui poussait la stale via
  la dédup interne. Désormais, le rapport ne regarde plus
  « les lignes touchées dans les 24h » mais « la date cible du backup
  selon le planning configuré » :
  - SBTP EXT-USB (Vendredi 12-18) → apparaît dans le rapport du
    **samedi matin** uniquement, le reste de la semaine il est marqué
    `➖ SBTP EXT-USB — --` (NOT_SCHEDULED).
  - Backup Mon-Fri overnight (21h-06h) → apparaît du mardi matin au
    samedi matin. Lundi/Dimanche → `➖`.
  - Backup quotidien → apparaît tous les matins comme avant.
  Aucune action requise côté client : l'emoji `➖` était déjà
  supporté depuis v1.10.147783.

## [1.10.147789] — 2026-05-21

### Fixed

- **Fusion de tickets — la trace côté UI était invisible.** Quand
  vous fusionnez plusieurs tickets dans un seul (action « Fusionner »
  depuis la liste des tickets), le travail de regroupement (messages,
  notes, étiquettes, temps passé) était bien fait en base, mais
  l'interface n'affichait **aucune** indication visible une fois la
  page rouverte : pas de bandeau, pas de ligne dans l'historique
  d'activité, et l'URL d'un ticket fusionné renvoyait une page
  pratiquement vide sans message explicatif.
  Cette release ajoute :
  1. Un **bandeau violet persistant** en tête du ticket cible
     listant les tickets sources qui ont été absorbés
     (« Ce ticket a absorbé #32 « Dylan », #45 « … » »).
  2. Une **ligne dédiée dans le flux d'activité** (« a fusionné les
     tickets #32 « Dylan » dans celui-ci »).
  3. Une **redirection automatique** depuis l'URL d'un ticket fusionné
     vers le ticket cible, avec un message « Le ticket #N a été
     fusionné dans celui-ci. ». Plus de page vide ou de 404 obscur.
  4. Traduction complète FR/EN/DE/ES/IT.
  Note : les tickets déjà fusionnés avant cette release continueront
  d'afficher une page vide quand on ouvre leur URL source (pas de
  données rétroactives à reconstituer) — le bandeau côté cible, lui,
  reste visible pour toutes les fusions historiques grâce à
  l'historique d'activité.

## [1.10.147788] — 2026-05-20

### Security — Supply chain hardening (Phase 1)

- **Images Docker maintenant pinées par version exacte au lieu de
  `:latest`.** Le `docker-compose.yml` référence désormais
  `ghcr.io/kr1s57/ticketbrainy-{web,ai,mail,telegram,migrate}:1.10.147788`
  et `searxng/searxng@sha256:b5d4892d…` au lieu de `:latest`. Plus
  aucune image ne peut être tirée silencieusement par `docker compose
  pull` sans avoir été validée par une release TB explicite (anti
  supply-chain). Le workflow opérateur ne change pas :
  `cd /opt/ticketbrainy && git pull && docker compose pull && docker
  compose up -d` synchronise le compose à la nouvelle version épinglée,
  puis pull exactement cette version. Aucune action manuelle requise
  pour les installations existantes.
- **Avertissement au démarrage si `SECURITY_ALLOWLIST_BYPASS=true`** —
  bannière `console.warn` encadrée dans `docker logs aidesk-web-1` à
  chaque boot du conteneur web tant que le bypass break-glass de
  l'allowlist IP admin est actif. Évite de laisser le bypass actif par
  inattention après une intervention de récupération.

## [1.10.147787] — 2026-05-20

### Added

- **Visibilité des personnes en copie sur chaque ticket.** Quand un
  client envoie un mail à votre helpdesk en mettant plusieurs personnes
  en copie (Cc), le ticket conserve désormais la liste complète des
  destinataires et chaque message du fil affiche une ligne
  « En copie : … » sous le nom de l'expéditeur. Avant ce patch, ces
  contacts étaient perdus à la réception : votre agent n'avait aucun
  moyen de savoir qui d'autre suivait l'échange, ce qui pouvait poser
  problème pour les tickets multi-interlocuteurs (client + son
  prestataire, client + son responsable, etc.). Rétro-compatible : les
  tickets déjà reçus avant ce patch ne montrent rien (aucune donnée à
  rejouer), seuls les nouveaux mails entrants exposent les Cc.

## [1.10.147786] — 2026-05-20

### Fixed

- **Régression critique — vos agents ne recevaient plus aucune notif
  "Nouveau ticket" pour les tickets créés à la main depuis l'interface.**
  Cas reproductible : un agent voit un mail client dans Outlook avant
  que TicketBrainy n'ait fini son tour de relève IMAP, clique sur
  « Nouveau ticket » dans la barre d'outils pour ne pas attendre, le
  ticket est créé… mais aucun agent ne reçoit la notification email,
  ni la notification dans la cloche en haut à droite, ni l'alerte
  Telegram. Seul l'accusé de réception au client était envoyé.
  La fan-out était isolée dans le flux IMAP : tout ticket créé hors d'un
  mail entrant (création manuelle, bouton « Forcer la collecte »)
  passait à travers. La diffusion (cloche, email aux agents abonnés,
  Telegram) est désormais déclenchée depuis tous les points d'entrée —
  un tenant frais sans abonnement explicite tombe en fallback sur les
  admins et les superviseurs.

## [1.10.147785] — 2026-05-19

### Fixed

- **Captures d'écran collées dans une réponse : enfin visibles dans le
  fil du ticket.** Depuis l'ajout du collage de captures d'écran
  (1.10.147765), votre client recevait bien l'image mais celle-ci
  n'apparaissait pas dans votre réponse côté agent — seule une pièce
  jointe attachée au mail était visible. L'image collée est désormais
  (a) visible directement dans le bubble de réponse de la conversation,
  (b) intégrée inline dans le mail reçu par le client (et non plus
  envoyée comme pièce jointe séparée), (c) toujours téléchargeable
  depuis la liste des pièces jointes du ticket.

## [1.10.147784] — 2026-05-19

### Fixed

- **Sidebar mailbox : le dépliage ne se réinitialise plus quand vous
  cliquez sur un ticket.** L'état d'expansion (boîtes ouvertes / fermées)
  est désormais persisté dans le navigateur. Une boîte que vous avez
  fermée manuellement reste fermée même si un nouveau mail arrive,
  jusqu'à ce que vous la rouvriez explicitement.
- **Collision tickets : le lock d'édition ne peut plus être volé.**
  Auparavant, si un agent rédigeait une réponse et qu'un second agent
  ouvrait le même ticket, certaines actions du second (coller du
  contenu, déclencher un draft IA, ou simplement focus l'éditeur)
  pouvaient voler le verrou d'édition au premier — qui se voyait
  alors bloqué avec le message « un autre agent est en cours
  d'édition ». Le serveur protège désormais le verrou actif : le
  second agent voit le ticket en **mode consultation** avec un message
  clair indiquant qui détient l'édition, sans interférer avec l'agent
  qui travaille. Le verrou se libère automatiquement après 30 s sans
  heartbeat (fermeture d'onglet, crash navigateur).

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

## [1.10.147783] — 2026-05-19

### Fixed

- **Rapport backup Telegram : doublons par tâche (6-7 lignes par job).**
  Bug introduit en v1.10.14778. Le rapport listait désormais ligne par
  ligne chacun des checks historiques (jusqu'à 8 jours) à chaque cycle,
  d'où la duplication massive. Le rapport ne montre désormais que le
  check le plus récent de chaque tâche.
- **Rapport backup : format remis à celui que les admins
  connaissaient.** Header avec jour en français, séparateur `━━━`,
  ligne par tâche au format
  `<emoji> <taskName> — <sujet email tronqué> (HH:MM)`, résumé
  `Résultat: X/Y ✅ | Z/Y ⚠️ | W/Y ❌` en bas. Les tâches sans email
  du jour sont visibles en `⚪ <taskName> — --`.

### Added

- **Bot Telegram : détection explicite du 409 Conflict.** Si une autre
  instance polle avec le même token (ancien container, webhook actif),
  le bot log un message clair avec les commandes de diagnostic. Au
  démarrage, le bot supprime aussi tout webhook stale qui aurait pu
  causer le 409.

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

**Si vous voyez encore des doublons** ou si le bot logue 409 Conflict
en boucle, vérifiez qu'un seul container `telegram-bot` tourne :

```bash
docker ps | grep telegram
# devrait afficher UNE seule ligne
```

Si plusieurs containers tournent avec le même token, stoppez les
orphelins :

```bash
docker stop <container-id-orphelin>
docker rm <container-id-orphelin>
```

## [1.10.147782] — 2026-05-19

### Fixed

- **Bot Telegram : aucune notification ne partait quand les Chat IDs
  étaient saisis via l'UI.** L'UI envoyait une chaîne brute
  (`"1602363121, 9999"`) mais le bot ne lisait que les tableaux —
  l'envoi était silencieusement coupé. Désormais la chaîne est
  normalisée en tableau côté web ET le bot accepte les deux formats
  défensivement.
- **Toggle Telegram impossible à désactiver dans certains cas.**
  Pour les anciennes installations dont le routing était stocké en
  boolean simple, cliquer « off » dans l'UI n'avait aucun effet.
  Le code lit maintenant les deux schémas (boolean legacy ou
  `{ enabled }` actuel).
- **Rapport backup quotidien envoyé plusieurs fois après un restart.**
  Le drapeau « déjà envoyé aujourd'hui » était en mémoire — à chaque
  redémarrage du service mail, le rapport pouvait repartir. Il est
  désormais persisté dans Redis avec un verrou atomique : un seul
  rapport par jour, garanti.
- **Erreurs Telegram silencieuses.** Les échecs d'envoi (token
  invalide, Chat ID interdit, MarkdownV2 mal échappé) sont maintenant
  loggés dans `docker compose logs telegram-bot`, ce qui rend le
  diagnostic possible.

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

## [1.10.147781] — 2026-05-19

### Changed

- **Heure du rapport backup Telegram accessible depuis Paramètres →
  Telegram.** Jusqu'ici, l'heure d'envoi du rapport quotidien devait
  être configurée dans Paramètres → Email backup. Elle est désormais
  aussi visible juste sous le toggle « Rapports de backup », là où on
  s'attend à la trouver. Les deux pages éditent le même paramètre, la
  donnée reste unique.

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

## [1.10.14778] — 2026-05-19

### Changed

- **Notifications backup Telegram — un seul rapport quotidien groupé.**
  Plus aucune alerte individuelle au fil de l'eau quand les mails de
  backup arrivent. Le bot envoie maintenant un unique message à
  l'heure configurée (Paramètres → Email backup → « Heure du rapport
  Telegram »), avec emoji par statut et blocs Échecs / Avertissements
  / Réussis. L'auto-création de tickets sur ERROR/MISSING est
  conservée. La fenêtre du rapport couvre les dernières 24 heures, ce
  qui capture les backups qui traversent minuit.
- **Heure du rapport en fuseau local.** Nouvelle variable `TZ` dans
  `.env.example` (défaut `Europe/Paris`) propagée aux services
  `mail-service` et `telegram-bot`. L'heure sélectionnée dans l'UI
  est désormais interprétée dans le fuseau du serveur (et non plus
  en UTC).

### Added

- **Notifications Telegram « Nouveau ticket » réellement fonctionnelles.**
  Avant cette version, le toggle existait mais aucun événement
  n'était publié vers le bot. Maintenant, à chaque nouveau ticket
  (mail entrant ou création UI/API), un message formaté est envoyé
  sur Telegram : sujet, expéditeur, boîte mail, extrait, lien direct.
- **Sélecteur de boîtes mail pour les notifications « Nouveau ticket ».**
  Paramètres → Telegram → toggle « Nouveaux tickets » affiche
  désormais une liste de cases à cocher des boîtes mail actives.
  Aucune case cochée = notifications pour toutes les boîtes (ancien
  comportement). Cocher une ou plusieurs boîtes = notifications
  uniquement pour celles-là.

### Mise à jour

> **Nouvelle variable `TZ`** dans `.env.example`. Ajoutez-la à votre
> `.env` (sinon les containers tomberont sur la valeur par défaut
> `Europe/Paris`).

```bash
git pull
grep -q '^TZ=' .env || echo 'TZ=Europe/Paris' >> .env
docker compose pull
docker compose up -d --force-recreate
```

Le `--force-recreate` est nécessaire pour que la variable `TZ` ajoutée
au `docker-compose.yml` soit propagée aux containers `mail-service`
et `telegram-bot`.

## [1.10.147771] — 2026-05-18

### Fixed

- **Erreurs `502 Bad Gateway` dans la console pour les logos
  cassés des signatures clients.** Quand un mail entrant
  contenait un logo société hébergé sur un serveur HTTP cassé
  ou inaccessible, le proxy d'image renvoyait un 502 que le
  navigateur affichait comme une erreur console et une icône
  d'image cassée. Désormais, en cas d'échec upstream, le proxy
  renvoie silencieusement une image transparente 1×1 — l'agent
  voit le contenu du mail sans le logo mort, et la console
  reste propre. Aucun changement pour les images valides.

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

## [1.10.14777] — 2026-05-18

### Fixed

- **Listes à puces et listes numérotées perdues dans l'aperçu des
  réponses agent.** Quand un agent répondait à un ticket avec une
  liste à puces dans l'éditeur, l'aperçu du ticket dans
  l'interface affichait les items sans puces ni indentation (juste
  les textes sur des lignes successives), alors que le client
  recevait bien l'email avec les puces intactes. Les listes, les
  en-têtes, les blockquotes, le formatage gras/italique et les
  images insérées en ligne dans les réponses s'affichent désormais
  correctement dans l'aperçu, en cohérence avec ce que reçoit
  le destinataire.

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

## [1.10.147769] — 2026-05-18

### Fixed

- **Page blanche + Reload auto à l'ouverture d'un ticket — vraie
  cause racine.** Le patch précédent (v1.10.147768) avait éliminé
  une partie du mismatch d'hydratation, mais l'erreur persistait en
  production. Cause restante : le panneau IA collapsable du ticket
  lisait `localStorage` directement dans son rendu initial, ce qui
  faisait que le serveur rendait le panneau ouvert (sans accès au
  storage navigateur) tandis que le client rendait potentiellement
  le panneau fermé (storage lu) → structures DOM différentes → React
  refusait l'hydratation → recharge automatique du ticket. La page
  s'ouvre maintenant directement, sans aller-retour Reload, même
  quand le panneau IA a été replié dans une session précédente.

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

## [1.10.147768] — 2026-05-18

### Fixed

- **Ouverture d'un ticket : page blanche fugace + reload automatique
  avant que le ticket s'affiche.** Sur les déploiements derrière un
  WAF (Sophos XGS, Cloudflare en mode proxy strict, etc.), un ticket
  cliqué depuis la liste s'affichait en blanc pendant 1-2 secondes,
  un bouton « Reload » apparaissait, puis la page rechargeait toute
  seule avant d'afficher le ticket. Cause : erreur React #418
  (« hydration mismatch »), c.-à-d. divergence entre le HTML rendu
  côté serveur et celui réhydraté côté client. Plusieurs sources
  cumulées sur la page ticket : le locale utilisateur (FR/EN/…)
  n'était connu qu'après le mount client, les temps relatifs
  (« 5m ago ») étaient calculés à deux instants différents, et le
  buffering RSC du WAF désynchronisait les chunks volumineux du
  HTML email. Désormais, les nœuds dont le contenu est légitimement
  client-dépendant (dates, temps relatifs, HTML email sanitisé)
  acceptent la version client après hydratation sans déclencher
  d'erreur — la page s'ouvre directement, sans aller-retour Reload.

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

## [1.10.147767] — 2026-05-18

### Added

- **Nom de l'agent affiché au-dessus de chaque réponse dans un ticket.**
  Dans la vue conversation d'un ticket, chaque bulle de réponse agent
  était jusqu'ici étiquetée par le label générique « Agent ». Quand
  plusieurs agents se relayaient sur un même ticket, plus rien dans
  l'interface ne permettait de savoir qui avait posté quel message —
  obligeant à reconstituer la chronologie depuis le log ou le mail.
  Désormais, chaque nouvelle réponse est tagguée avec l'identifiant
  de l'agent qui l'a postée, et son nom + ses initiales s'affichent
  au-dessus de la bulle, à côté de la date/heure. Les messages
  envoyés avant cette version conservent le label « Agent » (aucune
  donnée historique n'est inventée), mais toutes les nouvelles
  réponses sont nominatives. Le contenu envoyé au client par email
  reste strictement inchangé (signature et corps identiques).

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

## [1.10.147766] — 2026-05-18

### Fixed

- **Pièce jointe agent retournait `{"error":"Forbidden"}` (403) au clic.**
  La colonne `storagePath` est écrite sous deux formats : chemin absolu
  côté mail-service (mails entrants) et chemin relatif côté reply agent.
  Le route handler résolvait les chemins relatifs sous le CWD du process
  au lieu de `/data/uploads`, ce qui faisait sortir le chemin des deux
  roots autorisées et déclenchait le `Forbidden`. Conséquence : toute
  pièce jointe ou image inline uploadée par un agent dans une réponse
  était inaccessible au clic. Les attachements venant des mails entrants
  fonctionnaient. Fix : résolution des chemins relatifs sous
  `UPLOAD_ROOT` avant le contrôle de containment.

### Mise à jour

```bash
docker compose pull
docker compose up -d
```

## [1.10.147765] — 2026-05-18

### Fixed

- **Éditeur de réponse ticket — listes à puces visibles + paste d'images
  presse-papier.** Les classes Tailwind `prose` n'étaient pas activées dans
  le build, donc le reset preflight rendait tous les `<ul>` / `<ol>`
  invisibles : bouton "liste à puces" sans effet apparent, raccourci `- `
  qui consommait le tiret sans rien afficher, et structure de liste perdue
  visuellement après un copier/coller depuis Gmail/Word. Ajout de styles
  CSS ciblés `.ProseMirror` qui restaurent listes, en-têtes, blockquotes,
  code et liens dans l'éditeur. Le HTML envoyé au destinataire n'a jamais
  été affecté.
- **Coller une capture d'écran dans la zone de réponse.** Tiptap ne gère
  pas l'image du presse-papier par défaut. Ajout de handlers `handlePaste`
  et `handleDrop` qui détectent les fichiers `image/*` dans le
  presse-papier ou un drag-and-drop, les uploadent via la route
  d'attachements existante, et insèrent l'image au point d'insertion.

### Mise à jour

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml pull
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## [1.10.147764] — 2026-05-18

### Added

- **Settings > Plugins — affiche l'email lié à votre licence.**
  Sous "Manage your licensed plugins and features" la page
  affiche désormais `Licenses bound to <email>` — l'adresse
  utilisée lors de l'activation initiale de l'instance.
  Pratique pour identifier rapidement un instance dev vs prod
  ou pour le support. L'information est persistée localement
  (table `SystemConfig`, colonne `activationEmail`) — pour les
  instances déjà déployées avant cette release, l'email n'est
  pas connu et restera vide tant qu'aucune réactivation n'a
  lieu. Si tu veux le backfill manuellement, l'administrateur
  peut le faire via :
  ```sql
  UPDATE "SystemConfig" SET "activationEmail" = 'your@email'
   WHERE id = 'global';
  ```

### Changed

- **Marketplace VigilanceKey — toutes les licences existantes
  affichent désormais une échéance annuelle.** Avant cette
  release, les licences `enterprise_pack` (et certaines autres)
  apparaissaient comme "Permanent" sur l'admin VigilanceKey
  parce que leur `expires_at` était fixé à 2099. Pour harmoniser
  avec le passage en abonnement annuel, toutes les licences
  TicketBrainy existantes ont été migrées vers une échéance à
  +1 an depuis aujourd'hui (sauf `core` qui reste permanent et
  `slack_connect` qui est retiré). Si tu remarques que ta
  licence "permanente" originale apparait soudain avec une
  échéance, c'est normal — au moment du renouvellement annuel,
  le tarif sera identique à celui annoncé sur la marketplace.

### Update

```bash
cd /opt/ticketbrainy
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.147763] — 2026-05-18

### Changed

- **Enterprise Pack — prix passé en annuel.** Le plugin
  Enterprise Pack devient **99€/an** (au lieu de 99€/unique
  jusqu'ici) pour s'aligner sur tous les autres plugins payants
  qui sont déjà en abonnement annuel. Côté marketplace VGXKey
  comme côté UI plugin store dans TB, l'affichage passe de
  "/unique" à "/an". Les licences `enterprise_pack` déjà émises
  en one-shot avant cette release restent **valides indéfiniment**
  — la modification ne s'applique qu'aux nouvelles activations.
  Un Sync Licence depuis Settings > Plugins remonte le nouveau
  modèle pour l'UI.

### Update

```bash
cd /opt/ticketbrainy
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.147762] — 2026-05-18

### Added

- **Liste des tickets — bouton "Marquer comme lu" et auto-clear du
  point bleu quand on Résout/Ferme un ticket.** Quand un agent
  traite un ticket par téléphone et bascule simplement le statut en
  **Résolu** ou **Fermé** sans rédiger de réponse, le point bleu
  "en attente de réponse" restait visible dans la liste — il était
  calculé uniquement à partir du type du dernier message
  (`INITIAL` ou `CUSTOMER_REPLY`). Le modèle `Ticket` a maintenant
  une colonne `agentReadAt` qui est :
  1. **automatiquement** mise à jour à `now()` lors de toute
     transition vers Résolu / Fermé ;
  2. **manuellement** mise à jour via un nouveau bouton
     **"Marquer comme lu"** qui apparaît dans la barre de
     sélection multiple (à côté de "Supprimer la sélection"),
     pour les tickets que l'agent veut acquitter sans changer
     leur statut.

  Le point bleu (et les compteurs latéraux de mailbox) restent
  affichés tant qu'aucun acquittement n'a eu lieu OU qu'un nouveau
  message client est arrivé après l'acquittement — c'est
  automatique, pas besoin de réinitialiser.

### Update

```bash
cd /opt/ticketbrainy
git pull
docker compose pull
docker compose up -d --force-recreate
```

> La migration Prisma `20260518_ticket_agent_read_at` ajoute
> la colonne `Ticket.agentReadAt` (nullable). Elle est appliquée
> automatiquement par le conteneur `migrate` au boot, aucune
> action manuelle requise.

## [1.10.147761] — 2026-05-17

### Fixed

- **Email d'activation Keycloak — `apply-config.sh` ne mourait plus
  silencieusement.** v1.10.14776 ajoutait `emailTheme: ticketbrainy`
  au PUT de hardening du realm, mais sur les installations existantes
  `apply-config.sh` pouvait sortir sans aucun log lors du fetch du
  token admin (combinaison `curl -sf` + `set -e` qui avalent les
  réponses 4xx). Conséquence : `emailTheme` jamais appliqué sur le
  realm → l'agent recevait l'ancien template (sans section
  "Connexion au portail"). Le déclencheur typique : la protection
  brute-force du realm master (5 échecs, lockout 15 min) qui
  s'accumule pendant un cycle de déploiement répété, et bloque
  ensuite tous les essais suivants. La nouvelle version (1) loggue
  toujours le code HTTP + le corps de réponse quand le token est
  refusé, (2) refait un essai après 10 s pour absorber les
  conditions de course au boot froid, (3) imprime une instruction
  claire `bash scripts/keycloak-reset-admin.sh --mode unlock` quand
  le code 401 indique un lockout, ou `--mode recovery <NEW_PASSWORD>`
  pour un 400/403 (password mismatch). Le template de realm
  (`keycloak/ticketbrainy-realm.json`) embarque aussi désormais
  `emailTheme: ticketbrainy` pour que les installations fraîches
  l'aient dès le `--import-realm`, sans dépendre du token admin.

### Update

```bash
cd /opt/ticketbrainy
git pull
docker compose pull
docker compose up -d --force-recreate
```

> **Si tu es resté sur l'ancien email après v1.10.14776 :** ton
> admin master est probablement lockout. Lance d'abord :
>
> ```bash
> bash scripts/keycloak-reset-admin.sh --mode unlock
> docker compose up -d --force-recreate --no-deps keycloak-init
> docker logs ticketbrainy-keycloak-init-1
> ```
>
> Tu dois voir la ligne `[apply-config] verification: ... emailTheme=ticketbrainy ...`.
> Recrée alors un user de test dans Keycloak → email avec les
> 2 sections.

## [1.10.14776] — 2026-05-17

### Added

- **Email d'activation Keycloak enrichi : portail TicketBrainy en clair.**
  Quand un administrateur crée un agent et déclenche l'envoi de
  l'email "Mise à jour du mot de passe", le courriel reçu était
  jusque-là incomplet : il proposait uniquement le lien Keycloak
  (mise à jour du compte) sans indiquer où se connecter ensuite.
  Le destinataire devait deviner l'URL du portail. Le nouveau
  template ajoute une seconde section **"2. Connexion au
  portail TicketBrainy"** sous l'action d'activation, avec un
  bouton CTA et l'URL en clair pour fallback. La première
  section reste identique (instructions Keycloak natives,
  expiration du lien à 12h). Disponible en FR / EN / DE / ES / IT.
  L'URL est injectée à partir d'`APP_URL` au démarrage du
  conteneur Keycloak — aucune configuration manuelle requise.

- **Rôle Superviseur : accès lecture seule à Paramètres.**
  Les utilisateurs Superviseur (SUPERVISOR) pouvaient déjà
  s'authentifier mais étaient redirigés vers `/settings` dès
  qu'ils cliquaient sur Time tracking, Catégories IA ou les
  pages Déploiement & Sécurité. Ils peuvent désormais
  **consulter** tous les paramètres (configuration mailbox,
  sécurité, équipes, plugins, etc.) sans pouvoir modifier quoi
  que ce soit — une bannière "Mode lecture seule" rappelle la
  restriction, et l'attribut HTML `inert` désactive toutes les
  interactions du formulaire (boutons Save, inputs, dropdowns).
  Les Server Actions de mutation conservent leur garde
  `requireRole("ADMIN")` en défense en profondeur. AGENT reste
  bloqué hors de Paramètres comme avant.

### Update

```bash
cd /opt/ticketbrainy
docker compose pull
docker compose up -d --force-recreate
```

> Le redémarrage de Keycloak régénère automatiquement le thème
> email avec votre `APP_URL`. Le rôle Superviseur n'a aucun
> changement de schéma BDD à appliquer.

## [1.10.147751] — 2026-05-17

### Fixed

- **XpertTeamIA : recommandations adaptées au provider IA actif.**
  Les libellés "Recommandé : …" sous les sélecteurs de modèle
  affichaient les noms Claude (Opus / Sonnet / Haiku) même quand
  le provider Codex CLI était sélectionné — la liste déroulante
  proposait bien GPT-5.x mais le texte d'aide parlait toujours
  d'Haiku, créant une incohérence visuelle. Les trois
  recommandations basculent maintenant automatiquement sur les
  équivalents Codex (Deep Analysis → GPT-5.4 ou GPT-5.5,
  Triage → GPT-5.4 Mini, SmartReply → GPT-5.4 Mini) selon le
  provider actif. Correction propagée dans les 5 langues.

### Update

```bash
cd /opt/ticketbrainy
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.14775] — 2026-05-17

### Added

- **XpertTeamIA : modèle IA configurable par tâche.** Jusqu'à
  présent un seul "Modèle expert" pilotait à la fois la Deep
  Analysis (raisonnement profond sur les tickets techniques),
  le Tri automatique (classification rapide à l'arrivée des
  mails) et la rédaction SmartReply IA (brouillons de
  réponses). Comme ces trois tâches n'ont pas du tout les
  mêmes exigences, c'était un compromis coûteux : payer Opus
  pour rédiger un accusé de réception est du gaspillage de
  tokens, et utiliser Haiku pour une analyse approfondie laisse
  de la qualité sur la table. Désormais, depuis
  **Réglages → XpertTeamIA**, vous choisissez un modèle distinct
  pour chacune des trois tâches, avec une recommandation
  affichée pour chacune (Opus/Sonnet pour Deep, Haiku pour
  Triage et SmartReply). Au changement de provider AI (API Key
  Anthropic / Claude Code CLI / Codex CLI), des défauts
  intelligents sont appliqués automatiquement par tâche. Claude
  Haiku 4.5 a été ajouté au catalogue côté Claude. Économies
  de tokens immédiates sur les déploiements API Key, et
  routage explicite sur les abonnements CLI.

### Update

```bash
cd /opt/ticketbrainy
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.14774] — 2026-05-16

### Changed

- **Assistant IA de rédaction : formatage propre des brouillons
  de réponses.** Le bouton "AI Draft" dans le composeur de
  réponse générait des messages en un bloc compact, sans
  paragraphes ni séparation visuelle — l'IA produisait du
  plain-text alors que l'éditeur attend du HTML. Le prompt
  impose désormais un sous-ensemble HTML clair (paragraphes,
  listes à puces, gras parcimonieux) avec un guide de style :
  un paragraphe par idée, listes pour les énumérations de 3+
  items, gras sur 1-2 termes clés maximum. Le brouillon
  s'affiche maintenant comme un email écrit par un agent
  professionnel. Filet de sécurité : si l'IA renvoie quand même
  du plain-text par erreur, conversion automatique des sauts
  de ligne avant insertion dans l'éditeur — robustesse garantie.

### Update

```bash
cd /opt/ticketbrainy
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.14773] — 2026-05-16

### Fixed

- **Notifications agents sur nouveaux tickets entrants : trou
  majeur comblé.** Quand un client envoyait un email à une boîte
  TB, le ticket était bien créé et l'accusé partait au client —
  mais les agents abonnés à la boîte ne recevaient **aucune**
  notification par email. Seules des notifs in-app étaient créées,
  et uniquement pour les rôles ADMIN / SUPERVISOR. Un agent
  standard absent de l'interface n'était jamais averti qu'une
  demande était en attente. Désormais, à chaque ticket entrant :
  notification in-app **et** email pour chaque agent abonné à la
  boîte (`Settings → Mailboxes → Subscribed users` avec
  `notifyNewTicket=true`). L'email est expédié depuis l'adresse
  de la boîte concernée, avec le sujet, l'expéditeur, l'extrait
  du message et un lien direct vers le ticket. La préférence
  d'email par utilisateur est respectée. Filet de sécurité : si
  aucun agent n'est abonné à la boîte, fallback automatique sur
  les admins et superviseurs pour ne jamais perdre un ticket.

- **Email d'alerte à l'agent assigné sur réponse client.** Même
  cause, même solution pour les réponses : l'agent assigné au
  ticket ne recevait qu'une notif in-app, jamais d'email. Il
  reçoit maintenant aussi un email (et lui seul — pas
  d'arrosage de toute l'équipe). Respecte la préférence
  `notifyReply` par boîte de chaque utilisateur.

### Update

```bash
cd /opt/ticketbrainy
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.14772] — 2026-05-16

### Fixed

- **Logos clients dans les signatures de mails entrants ne
  s'affichaient plus** quand l'URL était en HTTP simple. Le
  navigateur bloque les images HTTP sur une page HTTPS (mixed
  content) sans aucun message UI. Nouvelle route serveur
  `/api/proxy-image?url=…` qui ramène l'image en HTTPS via TB. Le
  rendu réécrit automatiquement chaque `<img src="http://...">`
  vers le proxy — fix rétroactif, les anciens messages déjà en
  base bénéficient aussi du correctif sans migration.

### Security

- Proxy d'images strictement défensif : session agent requise,
  scheme `http`/`https` uniquement, blocage de toute IP privée /
  loopback / link-local / multicast (anti-SSRF), 5 MB max,
  timeout 5 s, max 3 redirects revalidés, aucun cookie ni Referer
  transmis upstream, réponse `image/*` only.

App image change uniquement — pull `:latest` (ou `:v1.10.14772`)
sur les 5 services. Pas de migration.

## [1.10.14771] — 2026-05-16

### Fixed

- **Numéro de ticket désormais présent dans le sujet de tous les
  mails sortants.** Réponses agents, notifications de résolution,
  auto-close, enquêtes CSAT, auto-replies et notifications de
  changement de client utilisent désormais le format canonique
  `[Ticket #N] <subject>` ou `Re: [Ticket #N] <subject>`. Le helper
  unifié nettoie aussi les `Re:` et `[#N]` accumulés au fil des
  échanges. Le client peut maintenant identifier le ticket
  concerné dès l'aperçu de la boîte de réception.
- **Threading par sujet : reconnaît `[Ticket #N]`** en plus du
  legacy `[#N]`, pour les gateways qui strippent les headers
  `In-Reply-To` / `References`.

App image change uniquement — pull `:latest` (ou `:v1.10.14771`)
sur les 5 services. Aucune migration.

## [1.10.14770] — 2026-05-15

### Fixed

- **Re-fetcher un mail dont le ticket parent est dans la corbeille
  ne créait pas de nouveau ticket.** Si l'opérateur supprimait un
  ticket (soft-delete) puis remettait le mail en non-lu sur le
  serveur IMAP pour le re-pousser, le mail-service le marquait
  `\Seen` sans créer de nouveau ticket : la dedup `messageId` et le
  threading par `In-Reply-To` / `[#N]` se ré-attachaient
  silencieusement au ticket en corbeille. Les requêtes ignorent
  désormais `Ticket.deletedAt != null`. Le mail "ressuscité"
  produit maintenant un nouveau ticket comme attendu.

App image change uniquement — pull `:latest` (ou `:v1.10.14770`)
sur les 5 services. Pas de migration.

## [1.10.14769] — 2026-05-15

### Fixed

- **Modale "Nouveau ticket" : scroll cassé quand le message est
  long.** La modale et l'éditeur n'avaient ni `max-height` ni
  `overflow`, un message volumineux poussait la modale au-delà du
  viewport et masquait les boutons. Modale en flex column avec corps
  scrollable + footer collant, éditeur plafonné à 260px avec scroll
  interne.
- **Logos / images de signature absents dans les emails entrants.**
  Le sanitizer mail strippait tous les `src="https://…"` (anti
  pixel-tracker), supprimant aussi les logos CDN légitimes des
  signatures. Le strip ne touche désormais plus les `<img>` ; en
  contrepartie chaque `<img>` reçoit automatiquement
  `referrerpolicy="no-referrer" loading="lazy"` — le navigateur ne
  fuit pas la page TB au serveur image et ne charge l'image que si
  elle entre dans le viewport.
- **Images inline `<img src="cid:…">` cassées (placeholders dans le
  ticket).** Les images RFC 2392 Content-ID des mails entrants
  n'étaient pas résolues vers les attachments stockés. Le parser
  capture désormais le `cid` de chaque pièce inline et le
  mail-service réécrit `src="cid:xxx"` en `/api/attachments/<id>`
  après création du message.
- **Pièces jointes d'emails entrants : 404 à l'ouverture.** Le
  composant de conversation construisait
  `/api/uploads/${att.storagePath}` alors que `storagePath` est un
  chemin absolu sur disque (`/data/attachments/…`). Nouvelle route
  `/api/attachments/[id]` qui résout par ID Attachment, vérifie
  l'auth ticket parent, et stream le fichier (inline pour images /
  PDF, attachment pour le reste).
- **Création manuelle d'un ticket : aucun mail au client.** Quand
  un agent ouvre un ticket pour un client par téléphone ou walk-in,
  aucun email de confirmation n'était envoyé. Le ticket de création
  manuelle envoie désormais le même email d'acquittement *"Votre
  demande a bien été enregistrée sous le numéro #N"* que pour un
  ticket entrant, avec le logo et la signature de la mailbox.

### Added

- **Migration Prisma : `Attachment.contentId`.** Colonne TEXT
  nullable. Le container `migrate` l'applique automatiquement au
  prochain démarrage — pas de migration manuelle à exécuter.

### Upgrade

Pull `:latest` (ou `:v1.10.14769`) sur les 5 services (`web`,
`ai-service`, `mail-service`, `telegram-bot`, `migrate`). Migration
Prisma automatique au boot. Les anciens messages avec des CID
cassés restent inchangés (le rewrite ne s'applique qu'aux nouveaux
emails entrants).

## [1.10.14768] — 2026-05-15

### Fixed

- **RAG Knowledge Builder : sur-fragmentation et accumulation sans
  plafond.** Avant ce fix, un seul article web pouvait remplir un
  topic avec 13 chunks redondants (cas observé sur un article
  `acronis.com` dans le topic `data-recovery`), et chaque nouveau
  ticket déclenchait un nouveau crawl qui ajoutait des chunks **sans
  jamais purger** : l'index grimpait à 210+ chunks répartis sur 9
  topics, avec énormément de doublons sémantiques et de sources peu
  pertinentes.
  - Le découpage `chunkText()` plafonne désormais à **2 chunks
    maximum par article** (au lieu d'autant de chunks de 2400 chars
    qu'en contient l'article — jusqu'à 13 sur les articles longs).
  - Nouvelle fonction `pruneTopic()` appelée après chaque crawl :
    maintient l'invariant *au plus 5 URLs par topic, 1 chunk par URL
    (le premier = intro de l'article)*, en privilégiant les sources
    les plus récentes.

### Added

- **`docs/ops/rag-cleanup-v1.10.14768.sql`** — script SQL idempotent
  à exécuter une fois sur les instances existantes pour aligner la
  table `AiKnowledgeChunk` avec le nouvel invariant (sans attendre
  qu'un nouveau ticket re-déclenche un crawl). Voir l'en-tête du
  fichier pour les commandes `docker cp` + `psql`.

### Upgrade

Pull `:latest` (ou `:v1.10.14768`) sur les 5 services (`web`,
`ai-service`, `mail-service`, `telegram-bot`, `migrate`). Pas de
migration Prisma. Recommandé après `up -d` : exécuter
`docs/ops/rag-cleanup-v1.10.14768.sql` une seule fois pour purger
les chunks accumulés avant ce fix.

## Installer hotfix — 2026-05-15

### Fixed

- **`install.sh` Mode A : prompt manquant pour l'URL HTTPS publique.**
  En Mode A (reverse proxy externe — Sophos XGS, nginx, Traefik…), le
  wizard écrivait `APP_URL=http://${SERVER_IP}:4000` sans demander le
  FQDN HTTPS public devant le proxy. Conséquences :
    * **Microsoft 365 / Google Workspace OAuth refusait d'ajouter les
      mailboxes** — Azure AD et Google rejettent les redirect URIs HTTP
      hors `localhost`. L'écran d'erreur Microsoft générique *"Désolé,
      nous rencontrons des problèmes pour vous connecter"* après le 2FA
      vient quasi exclusivement de là.
    * Cookies de session NextAuth non marqués `Secure` (vol de session
      possible sur réseau partagé / hotspot).
    * Redirect URI Keycloak SSO pointait sur l'IP LAN HTTP — KO pour
      les clients qui se connectent depuis Internet.
  Le wizard demande désormais l'**URL HTTPS publique optionnelle** en
  Mode A. Si renseignée, elle alimente `APP_URL`, et donc par effet
  d'héritage `NEXTAUTH_URL` et `KEYCLOAK_URL`. Si vide, comportement
  identique à avant (LAN-only direct).
- **Docs `INSTALL.md` + `deployment-modes.md` + `DEPLOYMENT-MODES.md` :**
  notes dédiées au scénario Mode A + reverse proxy externe avec OAuth.
  Précise explicitement la contrainte Azure / Google sur le HTTP
  non-localhost et la procédure de rattrapage si le prompt n'a pas été
  saisi à l'install (`.env` + `docker compose up -d --force-recreate
  web keycloak`).

Pas de changement d'image — installer script et documentation
uniquement, aucun rebuild Docker requis. Les déploiements existants
qui ont déjà patché manuellement `APP_URL` n'ont rien à faire.

## [1.10.14767] — 2026-05-14

### Removed

- **Slack / Teams Connect plugin retired.** The webhook-based notification
  integration for Slack and Microsoft Teams is removed from TicketBrainy.
  Telegram remains the only first-class chat integration. Microsoft has
  been retiring the Office 365 Connectors (MessageCard format) since 2024
  and the limited one-way notification surface no longer matched the
  product direction. Removed: the `Settings → Integrations` page, the
  `WebhookIntegration` Prisma model (dropped by migration
  `20260514_drop_webhook_integration`), the webhook dispatcher, and the
  `slack_connect` plugin entry in the marketplace registry.

App image change only — pull `:latest` (or `:v1.10.14767`) on the
`web`, `ai-service`, `mail-service`, `telegram-bot`, and `migrate`
services. The migrate container drops the now-orphaned
`WebhookIntegration` table automatically on first run; the table holds
no production data on any known deployment.

## [1.10.14766] — 2026-05-12

### Fixed

- **"Assignés" no longer shows the current user's own tickets.** The
  Tickets sidebar separates "Mes conversations" (assigned to me) from
  "Assignés" (assigned to someone else). The "Assignés" query was
  `assignedToId != null`, which included my own tickets once I auto-
  assigned myself by replying to an unassigned ticket. The query is
  now `assignedToId != null AND assignedToId != currentUserId`. A
  ticket belongs to exactly one of: "Non assignés", "Mes
  conversations", "Assignés" — no overlap.
- **AGENT role no longer sees mailboxes outside their access.** The
  mailbox filter dropdown on `/tickets` loaded every active mailbox
  regardless of `UserMailbox` scoping. The dropdown is now scoped to
  the agent's assigned mailboxes (same rule already enforced on the
  ticket data side).

### Removed

- **"Tous les tickets" global sidebar entry.** The cross-mailbox
  catch-all view is removed from the navigation. Per-mailbox folders
  (Non assignés / Mes conversations / Assignés / Closed / Spam) and
  the Favorites / Deleted global views remain.

App image change only — pull `:latest` (or `:v1.10.14766`) on the
`web` service to receive the fixes.

## [1.10.14765] — 2026-05-11

### Fixed

- **AI Assistant draft no longer adds "Cordialement / Agent name".**
  The drafter prompt explicitly instructed the model to sign the email
  with the agent's name, which produced a duplicate because the mail
  system already appends the agent's signature block (name + mailbox
  signature + logo) on send. The prompt now forbids any closing
  salutation, agent name, team name or company name in both the
  Assistant AI draft and the "Generate email from resolution" path.
- **CSAT thank-you page redirected customers to /login.** The
  middleware whitelisted `/api/csat` (the rating endpoint) but not
  the `/csat/[ticketId]` confirmation page, so after submitting their
  rating customers were bounced to the staff login screen. The
  middleware now lets `/csat/*` through.

App image change only — pull `:latest` (or `:v1.10.14765`) on the
`web` service to receive the fixes.

## [1.10.14764] — 2026-05-11

### Changed

- **Auto-triage no longer sends an email notification.** Auto-triage
  runs on every inbound ticket and was queuing a `[AI Auto-Triage]`
  email to every subscriber on the mailbox, which agents found noisy
  (the triage summary is already visible in the ticket UI and in the
  Telegram alert when enabled). Email notifications are now reserved
  for **Deep Analysis** (a manual agent action). Telegram
  notifications for auto-triage are unchanged.

App image change only — pull `:latest` (or `:v1.10.14764`) on the
`web` service to receive the change.

## [1.10.14763] — 2026-05-11

### Fixed

- **Mailbox logo oversized in reply email signatures.** Outlook and
  many corporate mail clients ignore CSS `max-height`/`max-width` on
  `<img>` tags; the per-mailbox logo injected at the top of agent
  reply signatures was rendered at its native size in those clients.
  The logo now ships with an explicit HTML `height="48"` attribute
  alongside the existing CSS constraints, so it renders at ~48px tall
  everywhere.
- **DMARC badge falsely showing "valid" on senders with no DMARC
  record.** Microsoft 365 emits `dmarc=bestguesspass` in the
  `Authentication-Results` header when the sender domain publishes no
  DMARC record but SPF/DKIM pass — it is a heuristic guess, not a
  real DMARC pass. The parser was mapping `bestguesspass` to `pass`,
  causing inbound tickets from domains without published DMARC to
  display a misleading green "valid" badge. We now map
  `bestguesspass` to `none`.

App image change only — pull `:latest` (or `:v1.10.14763`) on the
`web` and `mail-service` services to receive the fixes.

## [1.10.14762] — 2026-05-11

### Changed

- **AI rate limit per user raised from 60/h to 200/h.** The single
  bucket is shared across every AI feature (triage, deep analysis,
  email assistant, AI skills). 60/h was tripping during normal
  multi-ticket work. Default raised to 200/h. Instances that need
  a lower limit can still narrow it via Settings → Security UI
  (no rebuild required).

App image change only — pull `:latest` (or `:v1.10.14762`) on the
`web` service to receive the change.

## [1.10.14761] — 2026-05-10

### Security

- **AGENT users are now properly scoped on the dashboard.** Before
  this release, an AGENT could see KPI counters, recent tickets, the
  7-day activity chart, the "Connected mailboxes" list, AND the new
  KPI modal for ALL mailboxes — including ones they were not assigned
  to. Now, every dashboard query is scoped to the user's `UserMailbox`
  memberships when `role === "AGENT"`. ADMIN and SUPERVISOR roles see
  everything (unchanged). Same scoping pattern already in use on the
  `/tickets` page.

App image change only — pull `:latest` (or `:v1.10.14761`) on the
`web` service to receive the fix. No deployment-file changes.

## [1.10.1476] — 2026-05-10

### Added

- **Clickable Dashboard KPI cards.** Click any of the four KPI cards
  (Open / New today / Unassigned / Resolved today) to open a modal
  listing the matching tickets. Each row links to the ticket page.
  Filter strictly mirrors the counter for consistency. Cap of 200
  per modal with a banner that points to the full tickets list when
  exceeded. 5 locales supported (FR / EN / ES / IT / DE).

App image change only — pull `:latest` (or `:v1.10.1476`) on the
`web` service to receive the feature. No deployment-file changes.

## [1.10.14751] — 2026-05-10

### Security

Hardening pass on the deployment kit (no app image changes, no GHCR
re-tag — public repo files only). Driven by an external audit of the
install/secrets/proxy surface.

- **`install.sh` writes `.env` (and `.env.backup.*`) with
  `umask 077` + explicit `chmod 600`.** Previously the file inherited
  the operator's default umask; on a fresh VPS that is usually `0022`,
  i.e. world-readable secrets. Other local users on the host could
  read `DB_PASSWORD`, `NEXTAUTH_SECRET`, `ENCRYPTION_MASTER_KEY`, etc.
- **`scripts/generate-secrets.sh` adopts the same posture** (`umask
  077`, `chmod 600` before AND after the sed pass) and is now
  protected by an `flock`-based single-writer lock. Two concurrent
  runs racing on `sed -i` could otherwise corrupt secrets silently.
- **SearXNG `secret_key` is now generated, not shipped.**
  `scripts/generate-secrets.sh` produces a fresh `openssl rand -hex
  32` value and replaces the placeholder
  (`tb-rag-searxng-replace-on-deploy`) in
  `searxng/settings.yml` on first run. Sessions and form signatures
  in the internal SearXNG instance are no longer predictable across
  installs.

  *Existing installs:* re-run `bash scripts/generate-secrets.sh` and
  `docker compose up -d --force-recreate searxng` to rotate the key.

- **`scripts/keycloak-reset-admin.sh` no longer accepts the new
  password as a command-line argument.** It is read from a masked
  `read -rs` prompt (or from the `KC_NEW_ADMIN_PASSWORD` env var for
  non-interactive use), validated for ≥ 12 chars, and is never echoed
  back. Argv leaks via `ps`, shell history, and terminal logs are
  closed.

  *Migration:* drop the trailing positional `<NEW_PASSWORD>` from any
  automation. CI callers should set `KC_NEW_ADMIN_PASSWORD` from a
  secret store and unset it after the call.

- **`README.md` Quick Start replaces `curl … get.docker.com | sh`
  with the official Docker APT repository install** (signed by the
  `download.docker.com` GPG key, package-manager checksum verified).
  The previous one-liner ran an unsigned remote script as root.
- **`docs/INSTALL.md` § Firewall split mode-aware.** Mode B (built-in
  Caddy) and mode C (external reverse proxy) now show 80/443-only
  rules; mode A (direct exposure) is documented as LAN/VPN-only with
  source-IP-restricted UFW / firewalld snippets. The previous text
  recommended opening 4000/8180 to the public internet, which contradicted
  the Caddy hardening and exposed the Keycloak admin console
  (`:8180/admin/`) over plain HTTP.

No findings classified as **High** in the audit but deemed deliberate
trade-offs were changed in this pass: image `:latest` tags
(documented upgrade path), `KC_PORT` default bind, `TRUSTED_PROXY_MODE`
default, root-uid containers + bind-mounted Claude credentials, and
the Caddy admin API on `0.0.0.0:2019` (origin allowlist already in
place; localhost would break in-network reload from `web:`). Those
require larger design discussions and are tracked separately.

## [1.10.1475] — 2026-05-10

### Changed

- **Slack / Teams Connect and Telegram Bot switch from one-shot
  to annual subscription.** Listed prices unchanged at 29 € each
  — now per year. Existing one-shot purchases are grandfathered:
  the licences already issued have no expiry, so the gating layer
  keeps granting them indefinitely.
- **Enterprise Pack price raised from 89 € to 99 €** (still
  one-shot). Applies to new checkouts only; customers who bought
  at 89 € are unaffected.

After this release every premium plugin except Enterprise Pack is
on annual subscription.

## [1.10.1474] — 2026-05-10

### Changed

- **BackupMonitor switches from one-shot to annual subscription.**
  Listed price unchanged at 49 € — now per year. Existing one-shot
  purchases are grandfathered: licences already issued have no
  expiry, so the gating layer keeps granting them indefinitely.
  Same flip pattern as v1.10.1473.

## [1.10.1473] — 2026-05-10

### Changed

- **Time Tracking Pro, Email Templates Pro and CSAT & Feedback
  switch from one-shot to annual subscription.** Listed prices
  unchanged: 39 € / 39 € / 29 € — now per year. Existing one-shot
  purchases are grandfathered: licences already issued have no
  expiry, so the gating layer keeps granting them indefinitely.
  The plugin storefront UI updates the badge from "/once" to
  "/perYear" automatically based on the new pricing model.

## [1.10.1472] — 2026-05-10

### Security

- **`fast-uri` bumped past <=3.1.1.** Closes two HIGH advisories
  (CVSS 7.5) on the Fastify URL parser used by `ai-service`:
  GHSA-q3j6-qgpj-74h6 (path traversal via percent-encoded dot
  segments) and GHSA-v39h-62p7-jpjc (host confusion via
  percent-encoded authority delimiters). Pure transitive bump,
  no API change.

### Changed

- **`postcss` spec aligned to `^8.5.10`.** The installed module
  was already 8.5.10 (covering GHSA-qx2v-qp2m-jg93,
  XSS via unescaped `</style>`), but the spec still pointed at
  `^8.5.8`, so `npm audit` flagged the package as a false
  positive on every run. Spec bumped to silence it without any
  code change.

## [1.10.1471] — 2026-05-10

### Fixed

- **Global branding logo + favicon now load for unauthenticated
  recipients.** Two new public endpoints `/api/branding-logo` and
  `/api/branding-favicon` serve the white-label assets without a
  TicketBrainy session, so the CSAT survey page (external customer
  clicking the rating link) and outbound email templates (recipient
  in Gmail/Outlook) no longer show a broken image. Filename is
  resolved server-side from the `Setting` table, never from the
  URL — strict pattern + path-containment defenses identical to
  the auth-gated `/api/uploads/<file>` route. Same pattern as the
  per-mailbox logo fix in v1.10.1468/1469, now extended to the
  global brand.
- **Raw migration failures are now fatal.** `run-raw-migrations.mjs`
  used to log SQL errors and continue, letting `prisma db push`
  run on a half-applied schema. A failing `CREATE EXTENSION
  vector` or `AiKnowledgeChunk` migration would yield a green
  deploy with silently-broken RAG / Deep Analysis at runtime.
  Errors now propagate, the migrate container exits non-zero,
  and the rollout halts before the app comes up on a broken DB.

## [1.10.147] — 2026-05-09

### Added

- **Dashboard auto-refresh.** Counters and Recent Tickets list
  refresh in place every 30 s without a full page reload. Pauses
  while the browser tab is hidden and resumes on focus.
- **"Refresh mailboxes" button in the left sidebar** (next to the
  Mailboxes header). Forces an immediate IMAP poll instead of
  waiting for the next 30 s interval. Useful when an operator
  knows a customer just sent an email and wants the ticket to
  appear right away. Server-side debounce (5 s) prevents fan-out
  on multiple concurrent clicks. Translated to FR / EN / DE / ES /
  IT.

## [1.10.1469] — 2026-05-09

### Fixed

- **Mailbox logos now display in outbound email headers.** Outlook
  / Gmail / Mac Mail showed a "TicketBrainy" placeholder instead of
  the operator's mailbox logo because the route serving the logos
  required a TicketBrainy session — but the customer's mail client
  has no session. The route + middleware now allow `/api/uploads/
  mailboxes/<file>` publicly, with a strict filename pattern
  bounding the asset surface to operator-uploaded branding logos.

## [1.10.1467] — 2026-05-09

### Fixed

- **Deep Analysis "Proposed Resolutions" steps were truncated.**
  Expanding a resolution showed the first few lines of steps but
  the rest was clipped with no visible scrollbar. Long resolutions
  are now fully scrollable, and multi-line model output renders
  correctly with preserved line breaks.

## [1.10.1466] — 2026-05-09

### Fixed

- **Dashboard search now matches ticket number.** Typing a bare
  number (e.g. "143") used to return "No tickets found" because
  the search query never looked at the `number` column. Numeric
  searches now match the ticket number and the exact match is
  sorted to the top.

## [1.10.1465] — 2026-05-09

### Fixed — RAG Knowledge Builder now actually surfaces external sources

The first end-to-end test on a real ticket (Sophos XGS Safe Failed
Mode v22) showed the Deep Analysis ran but the "External sources
used" card stayed empty even though the answer was 100% available
on Sophos Community. Three layered failures fixed in this release:

1. **SearXNG timeout was 8 s.** Querying 4 categories in parallel
   regularly takes >10 s. Now 25 s + a single retry on empty
   responses.
2. **Crawl query was repeating tokens.** "Sophos XGS … XGS v22 …
   SOPHOS XGS …" wasted the search budget. The query builder now
   tokenises, dedups case-insensitively, drops FR + EN stopwords,
   and preserves version strings (v22, v22.0.0).
3. **Vendor forums behind anti-bot WAFs were silently skipped.**
   community.sophos.com is behind Incapsula — it returns a
   challenge page to any non-browser fetch. The crawler now keeps
   the SearXNG snippet as the chunk content by default and only
   overrides it with the article when extraction succeeds. Empty
   fetches still contribute their snippet.
4. **Deep Analysis re-runs now trigger an on-demand crawl** when
   the RAG turns up empty for the topic, with a 60 s deadline.

Manually validated on ticket #143: 8 Sophos-specific chunks indexed
(Sophos Community threads + Sophos Support KBs incl. "Advisory:
Sophos Firewall goes into failsafe mode when the firmware…").

## [1.10.1463] — 2026-05-09

### Changed

- **RAG Knowledge Base now has its own sidebar entry** under
  Settings → IA → Compétences IA. The RAG settings (toggles, quotas,
  allowlist, sidecar health checks) and the chunk explorer are
  grouped on the same dedicated page at `/settings/ai/rag`.
  Translated to FR / EN / DE / ES / IT.

## [1.10.1462] — 2026-05-09

### Fixed

- **Triage error message is now diagnostic.** Generic "Triage request
  failed. Try again." was hiding 401 (stale browser bundle), 429
  (rate limit), 502 (ai-service down). The card now shows the
  precise reason — including a "Hard-refresh the page" hint when
  the browser bundle is out of sync with the server build.
- **`/api/ai/*` proxy now logs upstream errors.** Operators can grep
  the web container logs to correlate any UI failure with its
  precise HTTP status + body preview, without digging into
  ai-service logs.

## [1.10.1461] — 2026-05-09

### Added

- **RAG Knowledge Explorer** at `Settings → XpertTeamIA → RAG → Explorer
  la base`. Lists every chunk indexed by the topic-driven crawler with
  filters (topic, source, full-text search), pagination, per-chunk
  delete, per-topic delete. Includes a **manual crawl form** so
  admins can pre-warm the RAG for a vendor + product + query before
  any matching ticket arrives.
- **Sources visible in the AI sidebar.** Each Deep Analysis now lists
  the external pages it consulted in a dedicated "External sources
  used" card — clickable URL + source badge + similarity score.
  Persisted on the analysis row so the information survives reloads.

### Fixed

- **RAG queries used to be too generic.** A "Sophos XGS firewall safe
  failed mode" ticket would search for "firewall" alone — too broad.
  The triage now extracts vendor + product + error keywords as
  separate fields, and the crawler builds a precise query
  ("Sophos XGS safe failed mode cluster") leading to far better
  Reddit / ServerFault / vendor-doc hits.
- **Crawler resilience.** Embed timeout raised to 90 s, work sliced
  into independent sub-batches so a single TEI hiccup (e.g. CPU lag
  on bge-m3) no longer kills the whole crawl.

### Migrations

- Adds `AiAnalysis.knowledgeSources JSONB` (idempotent).

## [1.10.146] — 2026-05-09

### Added — RAG Knowledge Builder (XpertTeamIA)

A topic-driven, just-in-time knowledge base that enriches Deep
Analysis with public knowledge fetched on demand. **Self-hosted, zero
external API keys required.**

- **Two new sidecar containers** in `docker-compose.yml`:
  - `searxng` (image `searxng/searxng:latest`) — privacy-first meta-
    search aggregator over Reddit, ServerFault, StackOverflow,
    GitHub, NVD, Microsoft Learn, Google, Bing, DuckDuckGo, Brave.
    Internal-only on the docker network.
  - `embeddings` (image `ghcr.io/huggingface/text-embeddings-inference:cpu-1.6`)
    hosting `BAAI/bge-m3` (multilingual: FR/DE/IT/ES/EN). The model
    (~2 GB) downloads on first start into a named volume
    (`tei-models`) so it survives container rebuilds.
- **Postgres** image switched from `postgres:16-alpine` to
  `pgvector/pgvector:pg16` (drop-in compatible with the existing
  `pg-data` volume) to enable the `vector` extension. The
  `vector` extension is enabled and the `AiKnowledgeChunk` table
  is created automatically by the migrate container at first boot.
- **How it works**: when a new ticket is triaged, the AI service
  queries SearXNG in the background using keywords derived from the
  triage, fetches a handful of authoritative sources, embeds them
  via the local TEI sidecar, and stores them in pgvector under the
  detected topic. When an agent runs a Deep Analysis on a similar
  ticket later, the top-K most relevant passages are injected into
  the Expert prompt as `EXTERNAL KNOWLEDGE`. The base grows
  organically with your real ticket flow — there is no upfront crawl.
- **Settings UI** at `Settings → XpertTeamIA → RAG Knowledge Builder`:
  master on/off, per-engine-category toggles (Tech / Vendor docs /
  Security-CVE / Generalist), max results per search, max crawls
  per topic per day, cache TTL, top-K, optional domain allowlist.
  Health checks on both sidecars are surfaced live.
- **Source attribution**: each Deep Analysis result lists the
  external sources it used as `kb:<source>` badges in the "Skills
  Used" row of the AI sidebar.

### Operator notes

- **RAM**: TEI with bge-m3 needs about 2 GB resident memory.
  **Recommend 8 GB minimum** on the host (16 GB ideal). On 4 GB
  hosts, disable the RAG (`Settings → XpertTeamIA → RAG enabled = OFF`).
- **First boot**: TEI downloads the bge-m3 model (~2 GB) on its
  first start. Subsequent restarts reuse the named volume.
- **No external API keys**: SearXNG aggregates public engines and
  TEI runs locally — neither needs a key. The `.env` file has zero
  RAG-specific entries to fill in.
- **Disable**: set `ai.rag.enabled=false` from the Settings UI. The
  Deep Analysis flow then runs without external knowledge, exactly
  like before.

## [1.10.145044] — 2026-05-09

### Fixed

- **Deep Analysis "via &lt;model&gt;" attribution now displays.** The
  SSE handler was prematurely closing the stream on the writer
  stage's intermediate event, before the terminal event carrying the
  model id arrived. Triage and Summary cards were unaffected because
  they read attribution directly from the database. Only Deep
  Analysis was relying on the stream. Now the handler waits for the
  actual completion event before closing.

## [1.10.145043] — 2026-05-09

### Added

- **Model attribution everywhere in the AI sidebar.** The Summary card
  now shows "via &lt;model&gt;" under the generated text, matching the
  Triage and Deep Analysis cards. The model used is persisted on the
  ticket so it survives reloads.
- **Triage model is now configurable.** Admins can set
  `ai.triageModel` from the Settings UI. Defaults to Haiku as before.

### Fixed

- **The model attribution now reflects the model that ACTUALLY ran.**
  When the AI provider was set to Codex CLI, the sidebar still showed
  the requested Claude id (e.g. "claude-haiku-4-5-…") even though
  Codex was running an OpenAI model under the hood. The service now
  resolves the effective model from the active provider — Codex CLI
  reports `CODEX_MODEL` (env) or `codex-default`, so agents see the
  correct attribution.

### Changed

- **Top action bar uses an equal-width 4-column grid** for Billing,
  CSAT, Merge and Delete/Restore. The Merge button no longer
  stretches the row; all four controls keep matching widths. CSAT is
  disabled (greyed out) instead of hidden when the ticket is still
  open, so the layout stays stable as the ticket lifecycle progresses.
- **Time tracking is now in the right metadata sidebar** under the
  Status card, where it has full sidebar width and never wraps. It
  used to live in the top action bar and wrapped to multiple lines on
  narrow viewports.

### Migrations

- Adds `Ticket.aiSummaryModel TEXT` (idempotent).

## [1.10.145042] — 2026-05-09

### Added

- **Deep Analysis runs in the background and resumes on remount.** The
  three-stage analyzer (Expert → Engineer → Writer) now persists each
  stage to the database as it advances. Agents can refresh the page,
  switch tabs, or navigate away during a long analysis and find it
  completed (or still progressing) when they return — instead of
  having to start over. The XpertTeamIA sidebar polls the analysis
  state every 1.5 s while it is in flight and reattaches transparently.
- **AI model attribution surfaced in the sidebar.** Both the Auto
  Triage card and the Deep Analysis result block now show "via
  &lt;model&gt;" under the content. For Deep Analysis the value is
  composite (`expert:… | engineer:… | writer:…`) so agents see exactly
  which model produced each stage. Each agent reads its model from a
  Setting key (`ai.expertModel`, `ai.engineerModel`, `ai.writerModel`)
  with the previous defaults (Sonnet/Sonnet/Haiku) as fallbacks —
  meaning admins can swap models from Settings without a redeploy.

### Changed

- **Manual ticket creation closes the modal instantly.** Previously the
  modal stayed open until auto-triage finished, which could take 5-15 s
  on Claude/Codex CLI providers. The modal now closes as soon as the
  ticket row is saved, and the triage runs in the background and shows
  up in the sidebar a few seconds later.

### Migrations

- Adds two nullable columns to `AiAnalysis`: `currentStage TEXT`,
  `stageProgress JSONB`. The migration is idempotent (`IF NOT EXISTS`)
  so existing installs upgrade cleanly without manual intervention.

## [1.10.145041] — 2026-05-09

### Fixed

- **AI deep-analyze and triage no longer fail when Codex CLI is the
  active AI provider.** Earlier builds passed the configured Claude
  model id (`claude-sonnet-4-…`) directly to `codex exec --model …`.
  Codex with a ChatGPT account only accepts OpenAI model ids, so the
  request was rejected with `400 invalid_request_error: model is not
  supported` and AI features silently failed when the provider was
  set to Codex CLI (either explicitly in Settings → XpertTeamIA, or
  via the automatic fallback when the Claude CLI session expires).
  The AI service now detects `claude-*` ids and uses `CODEX_MODEL`
  (env) or Codex's default model instead.

  **Operator note:** if you run TicketBrainy with the Codex CLI
  provider, set `CODEX_MODEL` in `.env` (e.g. `CODEX_MODEL=gpt-5`)
  to pin the Codex-side model deterministically. Without it, the
  Codex CLI default applies.

### Hardening (rolled up from the development branch)

- **Keycloak default clients now have implicit flow disabled** in
  addition to ROPC. `keycloak/apply-config.sh` updates `admin-cli`,
  `account`, `account-console`, `broker`, and `security-admin-console`
  to disable both `directAccessGrantsEnabled` and `implicitFlowEnabled`.
  The application client `ticketbrainy-web` already had implicit
  flow disabled in the realm template; the realm JSON now declares
  it explicitly.
- **Caddy blocks the `/protocol/openid-connect/auth/device` Keycloak
  device-authorization endpoint** in addition to `/device` and
  `/clients-registrations`, closing a phishing-grade vector that
  bypassed the previous regex.

## [1.10.14504] — 2026-05-07

### Changed

- **Theme + sidebar style are now global, admin-only.** Up to 14503
  these lived in localStorage per browser, so agents had to redo the
  styling on every device and the admin's choice never propagated to
  the team. Four new Setting keys back the global values; the root
  layout fetches them server-side and paints `<html data-theme>` plus
  sidebar CSS variables without a flash. The `/profile` Apparence
  card is removed — agents go to `/settings/appearance` (admin only)
  to change appearance, and the change applies to every authenticated
  user.

- **Ticket page top action bar replaces the in-sidebar controls.**
  The right-side ticket sidebar mixed metadata with operationally
  critical actions (time tracking, billing toggle, CSAT survey,
  merge, delete/restore), which made it cluttered. A new
  `TicketActionBar` mounts a horizontal toolbar above the
  `#number/subject` heading hosting the TimeTracker (left) and the
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
didn't fit the operational model. The new model is admin-only:

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
  (down migration runs automatically on container restart).
- 30 i18n keys (`profile.tabs.*`, `profile.signatures.*`) across the
  5 supported locales.

### Upgrade notes

Existing operators don't need to do anything — the down migration
runs automatically on container restart. Any per-agent signature data
saved in the brief v1.10.1450 → v1.10.14501 window is dropped.

## [1.10.14501] — 2026-05-07

### Fixed

- **Language picker now reachable from `/profile`.** Agents without ADMIN
  role couldn't access `/settings/language` (settings tree is admin-only),
  so they had no way to change the WebUI language. The existing picker is
  now mounted as a new card under the Profile tab, available to every
  authenticated agent. 10 new i18n keys added across the 5 supported
  locales.

## [1.10.1450] — 2026-05-07

### Added

- **Per-agent email signatures with cascade resolution.** Each agent can
  now manage their own signatures from `/profile` → "Signatures" tab:
  - One default signature reused across every mailbox the agent has access to.
  - Optional per-mailbox overrides for agents who need a different sign-off.
  - Cascade at reply time: per-(user, mailbox) override → user default →
    legacy mailbox signature + auto-injected agent name.
  - The mailbox logo is reused (no extra upload UI). Tiptap rich editor
    with HTML sanitization on save and on render. 30 new i18n keys in
    5 locales. New table `UserMailboxSignature` and a new nullable
    `User.defaultSignature` column.

- **Senior-engineer AI prompts** with prompt-injection guardrails: the
  Expert and Engineer agents now treat ticket content as untrusted input
  and ignore role-override instructions hidden in emails or quoted text.

- **Expert-skill weighted matching.** Skills triggered by subject hits
  rank above body hits, multi-word triggers above single-word; loaded
  skill names propagate into the resolution metadata for traceability.

- **Trusted-proxy mode** (`TRUSTED_PROXY_MODE` env: legacy/none/cloudflare/
  sophos/custom). Cloudflare and custom WAF country/IP headers are now
  trusted only when an explicit Caddy-injected proof header is present
  (`X-TicketBrainy-Trusted-Proxy`), preventing direct-origin spoofing.
  Cloudflare IPv6 ranges added to Caddy's `trusted_proxies`.

- **Geo-block auto-persistence.** Geo-blocked IPs are written to
  `IpBlocklist` for 24 h with structured metadata; admins can later
  remove them via the dashboard.

- **Security dashboard period filter** (24h / 48h / 7d / 30d) drives
  all KPIs, the timeline, and the country chart. Blocked-IPs KPI gets
  a dialog showing live blocklist rows with a one-click unban action.

- **Inbound email security.** New module classifies dangerous attachments
  (executables, macros, archives) and sanitizes inbound HTML before
  persistence.

### Fixed

- **Cloudflare email obfuscation no longer breaks hydration.** Email
  addresses now render via a delayed-mount component, and the root
  layout is wrapped in `<!--email_off-->` markers (the official CF
  opt-out comment). The public-email-domains section was rewritten as
  a Server Component using native `<form action>` POSTs so the delete
  button keeps working when CF email-decode breaks React hydration.

- **Public email domains can now be deleted** by ADMIN or SUPERVISOR.

- **Manual deep-analysis enforced.** `updateMailbox` always sets
  `autoDeepAnalysis=false` so legacy rows or stale clients can't
  re-enable automatic deep analysis behind the operator's back.

- **Claude CLI auth fallback.** When Claude CLI returns 401 /
  authentication errors, the AI service transparently falls back to
  Codex CLI instead of failing the analysis.

### Security

- **Keycloak device-flow + dynamic client-registration blocked at the
  edge.** Caddy now responds 404 on `/realms/*/device` and
  `/realms/*/clients-registrations` (defense-in-depth, IT-Secure
  pentest finding).

- Tighter CSP: `script-src-elem` allows only the official Cloudflare
  email-decode script; `Cache-Control: no-transform` defeats CDN HTML
  rewriting that previously corrupted nonce-protected scripts.

### Upgrade notes

If your instance is fronted by Cloudflare and you want to harden
header trust, set `TRUSTED_PROXY_MODE=cloudflare` and
`TRUSTED_PROXY_HEADER_VALUE=$(openssl rand -hex 32)` in `.env`, then
`docker compose up -d --force-recreate`. The default `legacy` mode
keeps the previous header-trust behavior so existing installs
upgrade without configuration changes.

## [1.10.144923] — 2026-05-06

### Added — Customer salutation in auto-reply emails

Auto-reply emails can now greet recipients politely as
`"Bonjour M. BELLO,"` or `"Bonjour Mme. DUPONT,"` instead of the bare
`"Bonjour BELLO,"`.

A new optional **Salutation** field (`—` / `M.` / `Mme.`) was added to
the customer record (visible in the customer create/edit dialog under
"Key Contact"). A new template placeholder `{%customer.salutation%}`
renders as `M.`, `Mme.`, or empty when unset.

The default auto-reply template now includes the placeholder. Existing
user-edited templates keep working unchanged but must be edited
manually to take advantage of the new placeholder. When the
salutation is empty, a post-substitution pass collapses any double
space so output stays clean.

Schema migration `add_customer_salutation` runs automatically on
container restart (nullable column, no backfill).

## [1.10.144922] — 2026-05-06

### Fixed — TOTP enrollment with Google / Microsoft Authenticator

The realm `otpPolicyAlgorithm` was set to `HmacSHA256`, but the most
widely deployed TOTP apps (Google Authenticator, Microsoft
Authenticator) silently ignore the `algorithm` parameter in the QR-code
`otpauth://` URI and always compute SHA-1. Result: every code those
apps generated was rejected with "Le code d'authentification est
invalide" / "Invalid authentication code".

Reverted to `HmacSHA1`, the RFC 6238 default and the variant accepted
by NIST SP 800-63B. TOTP security is provided by the 160-bit shared
secret, not the HMAC variant.

After updating, users who had enrolled TOTP under the old policy must:
1. Have their OTP credential reset (admin → user → Credentials → delete OTP)
2. Re-add the **Configure OTP** required action
3. Re-scan the QR code at next login

## [1.10.1449] — 2026-04-19

### Fixed — Caddy mode (VPS / public install) restored

Operators who picked **Mode B (Caddy + Let's Encrypt)** in the install
wizard ended up with a stack where nothing bound ports 80/443. The
`install.sh` invoked `docker compose --profile with-proxy up`, but the
compose file **never defined a `caddy` service nor a `with-proxy`
profile** — so the flag was silently a no-op. Browsers hitting the
configured `APP_DOMAIN` received a Cloudflare **521 (Web server is
down)** because the origin accepted TCP but refused 443.

- **`caddy` service added** to `docker-compose.yml`, gated behind
  `profiles: [with-proxy]` so LAN/WAF installs still skip it and
  nothing binds 80/443 on those setups.
- Bind-mounts `proxy/Caddyfile` + `proxy/caddy-entrypoint.sh`, mounts
  the existing `caddy-data` volume read-write (web container already
  mounts it read-only for cert inspection), exposes admin API on
  `caddy:2019` inside the `internal` network for runtime reloads
  from the web container.
- Depends on `web` and `keycloak` so the reverse proxy only starts
  once its upstreams are ready.

No source/image change in this release — patch is compose-only.
Existing Mode B installs simply need `git pull && docker compose
--profile with-proxy up -d` to get a working reverse proxy.

## [1.10.1448] — 2026-04-16

### Fixed — Install wizard UX (customer feedback)

Operators following the on-site install wizard reported that the
questions were unclear — they did not know which IP to enter at which
step, and on at least one install a mis-entered Del key left an ANSI
escape sequence in the `.env` that later crashlooped Keycloak on
realm import (`Illegal unquoted character CTRL-CHAR code 27`).

This release reworks the wizard end-to-end:

- **Step 1 split in two sub-questions** — "Server IP" (the network
  address where the service runs, used for URLs) and "Administrator
  IP" (the IP *from which you will administer the server*). Each
  sub-question now shows on-premise vs VPS / remote-server examples
  so operators know exactly what to type.
- **Old Step 4 "LAN hosts" removed** — its role is covered by the
  new Administrator IP sub-prompt (same `LAN_HOSTS` env var; extra
  IPs and CIDR ranges can be added later by editing `.env`).
- **All 9 questions rewritten** in plain language with concrete
  examples for every deployment mode.
- **Input sanitization and re-prompt validation** — every answer is
  stripped of ASCII control characters, then validated against the
  expected format (IPv4, email, domain, URL, A/B, y/n). Invalid
  input is rejected with a clear error and the question is asked
  again. Silent acceptance of garbage can no longer happen.
- **Explicit default handling** — the welcome banner and every prompt
  now state that `[brackets]` is the default and `[Enter]` accepts
  it, which removes the Del-key confusion at the root.

### Fixed — Keycloak realm template

The realm template used `${LAN_HOST:-localhost}` / `${APP_PORT:-3027}`
(bash default syntax) but the `docker-entrypoint.sh` `sed` only
matched the bare `${LAN_HOST}` / `${APP_PORT}` forms, so those
placeholders survived substitution and Keycloak's own SmallRye Config
expanded them at realm-import time with the raw container env value.
Combined with a poisoned `.env`, this produced the CTRL-CHAR crash.

- Template now uses bare placeholders that match the `sed` pattern.
- `docker-entrypoint.sh` now sanitizes every env var before `sed`
  substitution — defense in depth so a bad `.env` edited by hand
  cannot reach the rendered JSON.

### Upgrade

Existing installs must refresh the bind-mounted wizard + Keycloak
config, then re-pull images:

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

---

## [1.10.1447] — 2026-04-13

### Security — Pentest findings (IT-Secure.lu)

Addresses four Keycloak hardening items flagged during an external
pentest of a customer install. Three additional defense-in-depth
layers are added for each finding.

- **Block OAuth 2.0 Device Authorization Flow** — the flow was enabled
  by default on the `ticketbrainy` realm. Device-code phishing is a
  real attack vector with no business need here. Flow is now refused
  at the realm level *and* at the Caddy layer (returns 404 on
  `/realms/ticketbrainy/protocol/openid-connect/auth/device`).
- **Master realm lockdown** — middleware + Caddy now refuse any HTTP
  request that targets the `master` realm. Master is only reachable
  via the direct LAN admin URL (`http://<lan-ip>:${KC_PORT}/admin/`),
  which the WAF blocks externally anyway. Prevents the "oh, the
  master realm is indexable" surprise reported by the pentester.
- **Disable ROPC on default realm clients** — Resource Owner Password
  Credentials flow is disabled on `ticketbrainy-web` and the
  admin-read client (`directAccessGrantsEnabled: false`). ROPC lets
  a client exchange a username/password for tokens, bypassing SSO
  controls. No legitimate internal code path relies on it.
- **Disable client-registration policy** — the anonymous client
  registration endpoint is locked down so untrusted parties cannot
  self-register clients against the realm.

See `keycloak/apply-config.sh` for the full post-start hardening
script (runs on every `up -d` — idempotent).

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

---

## [1.10.1446] — 2026-04-11

### Added — AI Expert Skills

- **Specialized expert skills** — admins can create AI skills (e.g.,
  Office 365, Active Directory, Network) in Settings → AI Expert → Skills.
  Each skill contains a detailed expert prompt and trigger keywords.
- **AI-assisted generation** — click "Generate with AI" after entering a
  skill name and description, and Claude Sonnet writes the full expert
  instructions automatically. The admin can edit before saving.
- **Automatic activation** — when a ticket matches a skill's trigger
  keywords (e.g., "outlook", "exchange"), the expert instructions are
  injected into the deep analysis prompt, giving Claude specialized
  knowledge for that domain.
- **Mailbox scoping** — a skill can apply to all mailboxes or be restricted
  to specific ones (e.g., Office 365 skill only on the IT support mailbox).
- **Enable/disable toggle** — skills can be turned off temporarily without
  deletion.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.1445] — 2026-04-11

### Added — AI Conversation Summary

- **On-demand summary** — agents can generate a 3-5 line AI summary of any
  ticket conversation with one click. Covers what was asked, what was tried,
  and current status. Ideal for long threads or ticket handoffs.
- **Smart refresh** — the summary card shows how many new messages arrived
  since the last generation, with a refresh button to update.
- **AI Sidebar** — new "Conversation Summary" card appears alongside the
  existing Auto Triage and Deep Analysis cards.
- Available in all 5 languages.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.1444] — 2026-04-11

### Added — Spam Management Module

- **Spam detection** — incoming emails are scored using upstream MTA
  headers (Exchange SCL, Forefront anti-spam, SpamAssassin). Emails
  flagged as spam are automatically routed to the Spam folder with no
  auto-reply sent to the sender.
- **Whitelist / Blacklist** — manage email addresses and domains in
  Settings → Spam. Customer domains are automatically whitelisted.
  Blacklisted senders are silently blocked (no ticket created) with
  a detailed notification to admins.
- **Spam folder** — sidebar badge shows spam count. Each spam ticket
  has a "Legitimate" button (moves to inbox + auto-whitelists sender)
  and a "Delete" button.
- Available in all 5 languages (EN/FR/ES/IT/DE).

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.1443] — 2026-04-11

### Added — Ticket Notifications

- **Toast alerts** — when a new ticket arrives or a customer replies, a
  toast notification appears in the top-right corner with the ticket title
  and a "Voir" button to jump straight to the ticket.
- **Bell badge** — the notification bell in the header now shows real-time
  unread count that updates every 30 seconds (aligned with IMAP polling).
- **Smart routing** — new tickets notify all admins and supervisors;
  customer replies notify the assigned agent (or admins if unassigned).

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.1442] — 2026-04-11

### Added — Email Authentication Badges + Attachment Warning

- **SPF / DKIM / DMARC badges** — every inbound email message now displays
  3 small colour-coded badges showing the authentication status of the
  sender's email server. Green = pass, red = fail, grey = not available.
  Tooltips explain what each protocol checks. Visible to all roles.
- **Attachment warning badge** — if the magic-bytes scan detects that a
  file's content does not match its declared extension (e.g., an `.exe`
  disguised as `.pdf`), an orange "Suspect" badge appears next to the
  attachment filename with the detection reason in a tooltip.
- **Purely informational** — no emails are blocked, no attachments are
  rejected. The badges help agents assess email legitimacy at a glance.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.144] — 2026-04-11

### Added — Multilanguage Support (Spanish, Italian, German)

TicketBrainy now supports 5 languages: English, French, Spanish, Italian,
and German. Users choose their language in Settings → Language.

- **i18n architecture refactored** — the monolithic 137 KB translations
  file is now split into per-language files (`locales/{en,fr,es,it,de}.ts`),
  improving maintainability and git diff readability
- **1358 keys translated** into each new language via AI, with automatic
  English fallback for any approximate translations
- **Date formatting localised** — all dates throughout the application
  (analytics charts, reports, ticket timestamps) now format in the user's
  chosen language instead of hardcoded French/English
- **Default language:** English (unchanged). Each operator can switch in
  Settings → Language

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

No schema migration — locale is stored client-side in localStorage.

## [1.10.143] — 2026-04-11

### Added — System Clock Diagnostic

New card in Settings → General showing real-time system clock status:
server time, timezone, UTC offset, database time, and clock drift
between Node.js and PostgreSQL. Drift alerts at 2s (warning) and
5s (critical) — important for Keycloak token validation.

New CLI script `scripts/configure-time.sh` for interactive timezone
and NTP management via SSH (show status, change timezone, force NTP
sync, configure NTP server).

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

## [1.10.142] — 2026-04-11

### Added — Rate-Limit UI + Analytics Deltas + Telegram Security Alerts + Draft Cleanup

#### Rate-Limit Configuration UI

New page under Settings → Deploy & Security → Rate Limits. Operators can
now adjust the 6 rate-limit presets (login, AI, CSAT, upload, activate)
from the UI instead of hardcoded values. Each preset can be enabled/disabled,
with configurable max requests and window duration. Changes stored in
`SecuritySettings.rateLimitConfig` JSON with 60-second cache.

#### Analytics Period Comparison

KPI cards on the Overview and SLA tabs now show comparison deltas (▲/▼)
against the previous period. For example, if viewing 30 days, the delta
compares against the 30 days before that. Response time deltas use
inverted colors (green when faster). CSAT already had this feature.

#### Telegram Security Alerts

Real-time security event notifications via Telegram. The bot now
subscribes to a `security:alert` Redis channel and sends formatted
alerts for: honeypot hits, IP auto-blocks, geo-blocks, and auth
failures (3+ in 5min from same IP). Each alert includes inline
keyboard buttons to mute by event type (1h/6h/24h/permanent) or
by IP. Mute configuration stored in the Setting table. Four new
routing toggles added to Settings → Telegram.

#### Draft Cleanup Scheduler

New scheduler in the mail-service that runs every 6 hours and
hard-deletes draft messages (`isDraft=true`) older than 48 hours.
Prevents abandoned drafts from accumulating in the database.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

No schema migration — all features use existing tables.

## [1.10.141] — 2026-04-11

### Added — Security Dashboard + Reports v2

#### Security Dashboard

New page under Settings → Deploy & Security → Dashboard showing real-time
security metrics:

- **KPI row:** Events (24h), Blocked IPs, Blocked Countries, Honeypot Hits
- **Event timeline:** Stacked area chart showing security events by hour
  (auth failures, geo blocks, honeypot hits, IP auto-blocks)
- **Top blocked IPs:** Table with reason, hit count, expiration, country
- **Top blocked countries:** Horizontal bar chart (requires Geo Block)
- **Critical events feed:** Last 20 danger-severity events

No license required — operational security feature available to all.

#### Reports v2 — Statistiques refondues

The sidebar is consolidated: a single "Statistiques" item replaces the
former "Statistiques" + "Rapports" entries. The analytics section now
uses internal tab navigation with four tabs:

- **Vue d'ensemble** — existing dashboard with a new period selector
  (7 days / 30 days / 90 days) replacing the hardcoded 30-day view
- **SLA** — new tab with SLA compliance metrics: compliance by priority,
  breach trend, response time distribution histogram, resolution time
  distribution histogram, and tickets-in-breach table
- **Satisfaction** — new tab with CSAT analytics: average score, star
  distribution, trend over time, top agents by satisfaction, and
  lowest-rated tickets
- **Rapports** — existing reports table, now integrated as a tab

All analytics tabs require Enterprise Pack license.

#### Feature gating fix

The reports page now checks `analytics_reports` (not `analytics_dashboard`)
for its feature gate, matching the Enterprise Pack feature registry.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

No schema migration in this release — all features use existing tables
(AuditLog, IpBlocklist, SecuritySettings, Ticket, SlaPolicy, CsatResponse).

## [1.10.14] — 2026-04-10

### Added — Settings restructure + Geo Block + security hardening Phase 2

This release reorganises the Settings menu around a new top-level
"Deploy & Security" section, introduces the **Geo Block** feature
that lets operators block or allow access by country at the
application layer, and ships several Phase 2 security hardenings
recommended by the v1.10.131 pentest follow-up.

#### Settings menu restructure

The "General" tab no longer mixes deployment + security with the
unrelated configuration items (language, notifications, tags, …).
A new top-level tab **Deploy & Security** sits between General and
Workspace and groups the security-relevant pages:

- **Mode** — network exposure mode + Keycloak posture + rate-limit
  posture + SSL certificate panel + the Caddy/HTTPS deployment form
  (former /settings/deployment + the top section of /settings/security)
- **Whitelist** — admin and Keycloak admin IP allowlists, each with
  its own form and audit trail
- **Audit** — the four security toggles (audit log, upload rate
  limit, magic bytes, login anomaly) and the live audit log feed
- **Geo Block** — new feature, see below

The legacy `/settings/deployment` and `/settings/security` URLs
continue to work — they redirect to `/settings/deploy-security/mode`
to preserve operator bookmarks.

#### Geo Block — country-based access control

A new feature under `/settings/deploy-security/geo-block` lets the
operator block or allow visitors based on their country of origin.
The lookup is powered by the `CF-IPCountry` header injected by
Cloudflare on every proxied request (~99.9% accuracy). Cloudflare
free plan is sufficient. The policy is hot-reloadable from the UI
without restarting any container.

> **Cloudflare (free plan) is required** for Geo Block to work.
> See [docs/cloudflare-setup.md](docs/cloudflare-setup.md) for
> step-by-step instructions (3 scenarios: VPS+Caddy, behind WAF,
> WAF without Cloudflare via `X-Country-Code` header).
>
> The previous GeoLite2 MMDB approach was removed — the free MaxMind
> database misclassified too many European IPs (Luxembourg resolved
> as FR/DE/US), making the feature unreliable in production.

Two modes:
- **Denylist** — allow everyone except listed countries (e.g. block
  RU, KP, IR but accept the rest of the world)
- **Allowlist** — block everyone except listed countries (e.g.
  accept only FR, BE, CH, LU, MC for a French-speaking SaaS)

Self-lockout protection: when the operator enables Geo Block from
the UI, the server detects their own country from the request IP
and automatically adjusts the lists so they don't block themselves
on the next page load. The "Test" widget on the same page lets
them simulate access from any country before saving.

Always-exempt paths (cannot be geo-blocked):
- Health check endpoints
- OIDC callback URLs (/api/auth/*)
- Stripe webhooks (/api/stripe/webhook — Stripe IPs are global)
- Public CSAT surveys (/api/csat/public/* — customer feedback
  must remain reachable from anywhere)

Every blocked request emits an `AuditLog` event of type `GEO_BLOCK`,
with the country, IP, and path stored in the metadata for forensic
review. The Geo Block page surfaces a 24-hour stats widget with the
top blocked countries.

Tech notes for operators upgrading:
- Geo Block requires Cloudflare proxy (orange cloud) enabled on your
  DNS records. Without the `CF-IPCountry` header, the feature is
  disabled and the UI shows a red "Cloudflare requis" banner.
- Operators behind a WAF without Cloudflare can configure their WAF
  to inject `X-Country-Code` as an alternative (see cloudflare-setup.md).
- Schema migration adds `geoBlockEnabled`, `geoBlockMode`,
  `geoBlockCountries`, `geoBlockSetAt`, `geoBlockSetBy` to
  `SecuritySettings`. Default `geoBlockEnabled=false`, so the
  feature is opt-in and existing installs see no behaviour change
  until they activate it from the UI.

#### Honeypot routes + auto-blocklist (Phase 2 hardening)

Real TicketBrainy users never access `/wp-admin`, `/wp-login.php`,
`/.env`, `/.git/HEAD`, `/phpmyadmin`, `/administrator`, `/admin.php`,
or other common scanner paths — those are exclusively probed by
automated attack tools.

Each hit on one of these paths now:
1. Returns a generic 404 (so the attacker doesn't know they
   tripped a trap)
2. Records an `AuditLog` event of type `HONEYPOT_HIT` with the
   probed path, source IP, and User-Agent
3. Adds the source IP to a new `IpBlocklist` table with reason
   `honeypot`, expiring after `honeypotBlockDurationHours`
   (default 24h, configurable in `SecuritySettings`)

Subsequent requests from the same IP are then rejected by
`enforceAccess()` — the dashboard layout check that runs before
any other authorization. This means a single hit on `/wp-admin`
shuts the attacker out of the entire instance for 24 hours.

Schema migration adds the `IpBlocklist` table and the
`honeypotEnabled` + `honeypotBlockDurationHours` columns to
`SecuritySettings`. Honeypots are enabled by default — there's
no downside.

#### CSP nonce strict (Phase 2 hardening)

The previous Content-Security-Policy header included
`'unsafe-inline'` on `script-src`, which the v1.10.131 pentest
correctly flagged as a regression vector for any XSS that might
land in a future code change. v1.10.14 replaces it with a strict
nonce-based policy.

The middleware now:
1. Generates a fresh 16-byte random nonce for every HTML request
2. Sets it on a request header (`x-nonce`) so Server Components
   can read it via `headers().get('x-nonce')`
3. Emits a Content-Security-Policy header with
   `'nonce-XXXX' 'strict-dynamic'` on `script-src`

`'unsafe-inline'` is kept as a legacy fallback for browsers that
don't support `'strict-dynamic'` (Chrome ≤59, Firefox ≤58, Safari
≤15.4 — every modern browser ignores it when a valid nonce is
present, per the W3C CSP3 spec).

`style-src` keeps `'unsafe-inline'` because Tailwind and shadcn
inject style attributes at runtime that can't be nonced.

#### `/.well-known/security.txt` (RFC 9116)

A standard `security.txt` file is now served at
`https://your-instance.example/.well-known/security.txt` with the
TicketBrainy security contact email and disclosure policy URL.
This is a small but well-documented signal to security researchers
that you have a coordinated disclosure process — and it's expected
by most bug bounty platforms and audit checklists.

#### Plugins page — license fingerprint for support

The license display on the Plugins page now shows the first and
last 4 characters of both the license key and the hardware ID
(middle masked with `…`). Allows support to identify the active
license without leaking enough material to clone it. The full key
never leaves the server.

### Schema migration

```sql
-- New columns on SecuritySettings
ALTER TABLE "SecuritySettings"
  ADD COLUMN "geoBlockEnabled"            BOOLEAN  DEFAULT false NOT NULL,
  ADD COLUMN "geoBlockMode"               TEXT     DEFAULT 'denylist' NOT NULL,
  ADD COLUMN "geoBlockCountries"          TEXT[]   DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN "geoBlockSetAt"              TIMESTAMP(3),
  ADD COLUMN "geoBlockSetBy"              TEXT,
  ADD COLUMN "honeypotEnabled"            BOOLEAN  DEFAULT true NOT NULL,
  ADD COLUMN "honeypotBlockDurationHours" INTEGER  DEFAULT 24 NOT NULL,
  ADD COLUMN "rateLimitConfig"            JSONB;

-- New table
CREATE TABLE "IpBlocklist" (
  id        TEXT PRIMARY KEY,
  ip        TEXT NOT NULL UNIQUE,
  reason    TEXT NOT NULL,
  source    TEXT,
  "expiresAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) DEFAULT NOW() NOT NULL,
  metadata  JSONB
);
CREATE INDEX "IpBlocklist_expiresAt_idx" ON "IpBlocklist"("expiresAt");
CREATE INDEX "IpBlocklist_reason_createdAt_idx" ON "IpBlocklist"("reason", "createdAt");
```

The `migrate` container runs this automatically on first boot of
the new image — no manual migration needed.

### Upgrade

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

The `--force-recreate` flag is mandatory — without it, the `caddy`
and `keycloak-init` containers (whose images haven't changed in
this release) won't pick up the bind-mounted file updates from the
git pull. See `docs/deployment-modes.md` for the rationale.

After restart, visit Settings → Deploy & Security → Geo Block to
configure the new feature, and Settings → Deploy & Security →
Audit to verify all four security toggles are still active.

### Reported in v1.10.141 (next release)

- Security Dashboard widgets (24h events graph, top blocked IPs,
  top blocked countries, alert center)
- Configurable rate-limit thresholds via UI (the limits are
  hardcoded today; the `rateLimitConfig` JSON column on
  `SecuritySettings` is the storage backbone for the upcoming UI)

## [1.10.1312] — 2026-04-10

### Docs — upgrade gotcha + Keycloak admin posture guidance

Doc-only patch. Surfaces two learnings from the v1.10.131 rollout
on a production VPS that would have silently broken the hardening
otherwise.

#### Upgrade must use `--force-recreate`

The v1.10.131 fixes live in two bind-mounted files:
`proxy/Caddyfile` (Caddy reverse proxy config) and
`keycloak/apply-config.sh` (Keycloak realm hardener). When you
run `git pull && docker compose pull && docker compose up -d`,
Compose **only recreates services whose image changed**. The
`caddy:2` and `curlimages/curl` images used by `caddy` and
`keycloak-init` are stable, so **those two containers keep
running with their previous in-memory config**, silently
ignoring the updated bind-mounted files.

**Symptom:** your pentest shows the hardening isn't active
(admin console still reachable, CORS still wildcard, BFP still
off on the master realm), even though the files on disk are
up to date and the web container is running the new version.

**Fix:** always upgrade with:

```bash
docker compose up -d --force-recreate
```

Or restart the two bind-mount consumers explicitly:

```bash
docker compose restart caddy keycloak-init
```

`docs/deployment-modes.md` now opens with a prominent
"Upgrading from a previous version — READ FIRST" section that
calls this out explicitly.

#### Keycloak admin posture — by order of preference

The v1.10.131 hardening left the Keycloak admin console
reachable for allowlisted IPs so that self-hosted operators
without a VPN or bastion can still access `/admin/master/console/`
from their office network. This is a deliberate trade-off and
`docs/deployment-modes.md §Keycloak admin IP allowlist` now
documents the preferred order:

1. **VPN / bastion / LAN** — best. The admin console should
   ideally never be reachable from the public Internet.
2. **Allowlist IP** — pragmatic fallback. `/admin/*` and
   `/realms/master/*` return 404 for non-allowlisted IPs
   (masks the existence of the console from scanners).
3. **Neither** — acceptable only if paired with strong
   `KC_ADMIN_PASSWORD` + Brute Force Protection (which v1.10.131
   applies automatically on the master realm).

No code changes — pure documentation patch. Images rebuilt
through `release-lockstep.sh` for lockstep discipline.

## [1.10.131] — 2026-04-10

### Security — blackbox pentest hardening (6 fixes)

A black-box external pentest conducted on a v1.10.13 VPS install
surfaced 1 critical + 4 high-severity findings in the infrastructure
configuration (the application code itself — Next.js Server Actions,
NextAuth middleware, SQL access paths — was found clean: no SQLi,
XSS, SSRF, IDOR, SSTI, or path traversal). This release closes all
critical/high findings and two of the medium findings.

#### C-01 (CRITICAL) — Next.js port exposed in cleartext HTTP

The `web` service in `docker-compose.yml` published `${APP_PORT}:3000`
on all interfaces (`0.0.0.0`), making the Next.js HTTP port directly
reachable from the internet without TLS. Cookies (CSRF, callback,
session) were emitted over cleartext on this port, bypassing Caddy
entirely and exposing them to MitM interception.

**Fix**: the port mapping now defaults to `127.0.0.1:${APP_PORT}:3000`
(loopback only). Caddy reaches the container through the internal
Docker network (`web:3000`), which is unaffected. Operators who
genuinely run without a reverse proxy can opt back in by setting
`WEB_BIND=0.0.0.0` in their `.env`.

- Reproducer before fix: `curl http://vps.example:4000/api/auth/session` → 200 OK
- Reproducer after fix: `curl http://vps.example:4000/api/auth/session` → Connection refused

#### H-01 (HIGH) — NextAuth cookies missing `Secure` flag

`useSecureCookies` was hard-coded to `false` in `auth/index.ts`, so
all NextAuth cookies (`next-auth.session-token`,
`next-auth.callback-url`, `next-auth.csrf-token`) were emitted
without `Secure`, allowing them to travel over plain HTTP. The
rationale in the previous comment (`SSL is terminated at the reverse
proxy, so the app always receives HTTP`) was correct for the
internal socket but had the wrong conclusion: the cookies are
emitted into the browser, which speaks HTTPS to the reverse proxy,
so `Secure` is the correct flag.

**Fix**: `useSecureCookies` is now derived from `NEXTAUTH_URL`
(`true` if it starts with `https://`). In HTTPS mode, cookies are
renamed with the `__Secure-` prefix (session, callback) and `__Host-`
prefix (csrf) so browsers refuse them if ever served over HTTP. Dev
mode (local HTTP) is unaffected.

#### H-02 (HIGH) — Keycloak master admin console publicly exposed

The Keycloak admin console at `/admin/master/console/` was
reachable without any restriction, and the master realm
authentication endpoints had no rate-limit. A combination that
enabled credential stuffing and made the entire IAM one working
exploit away from a pre-auth Keycloak CVE.

**Fix**: the proxy `Caddyfile` now blocks `/admin/*`, `/admin`, and
`/realms/master/*` with a hard `404` in the default (no-allowlist)
case, masking the very existence of the admin console from
scanners. If the operator configures an admin IP allowlist via
Settings → Security, the web container re-renders the Caddyfile and
switches that block to `403` for non-allowlisted IPs (historical
behavior preserved for admin access use cases). The Keycloak user
login flow (`/realms/ticketbrainy/*`, `/resources/*`, `/js/*`)
remains fully open.

#### H-03 (HIGH) — Keycloak reflects arbitrary CORS `Origin` with credentials

All Keycloak OIDC endpoints (`/token`, `/userinfo`, `/logout`,
`/certs`, `.well-known/openid-configuration`) reflected any
`Origin` header back in `Access-Control-Allow-Origin` with
`Access-Control-Allow-Credentials: true`. Tested origins:
`https://evil.example`, `null`, `http://attacker.internal` — all
accepted. Root cause: a client with `Web Origins: *` or `+`
upstream.

**Fix**: two levels of defense. Level 1: the `ticketbrainy` realm
JSON is already clean (explicit `webOrigins` per client). Level 2
(defense-in-depth): Caddy now strips all `Access-Control-Allow-*`
headers emitted by Keycloak and re-emits them conditionally only
when the request `Origin` matches exactly `https://${KEYCLOAK_DOMAIN}`.
Any other origin — including `null` and future regressions in the
realm JSON — is silently blocked at the proxy layer.

#### M-01 (MEDIUM) — no rate-limit on master realm login

8 consecutive failed `grant_type=password` attempts against
`/realms/master/.../token` returned 8 × 401 with no 429, no
`Retry-After`, no slow-down. The master realm is the administrative
realm of Keycloak and had Brute Force Protection disabled by
default.

**Fix**: `apply-config.sh` now applies Brute Force Protection to the
`master` realm in addition to `ticketbrainy`: `failureFactor=5`,
`maxFailureWaitSeconds=900` (15-minute lockout),
`minimumQuickLoginWaitSeconds=60`, password policy upgraded to
`length(14)` (vs 12 on the user realm) because master is
admin-only.

#### M-02 (MEDIUM) — Direct Access Grants (ROPC) on `admin-cli`

The `admin-cli` public client in the master realm accepted
`grant_type=password`, and `team.actions.ts` (the Keycloak user
sync action) was the last applicative consumer of this
flow — using the global admin credentials kept in Node process
memory. Both facts made the flow vulnerable to credential stuffing
(mitigated by M-01 above) and violated the OAuth 2.1 / OAuth
Security BCP recommendation against ROPC.

**Fix**: `apply-config.sh` now provisions a dedicated confidential
client `ticketbrainy-admin-write` in the `ticketbrainy` realm
with `serviceAccountsEnabled: true`,
`directAccessGrantsEnabled: false`, and the minimal realm-management
roles `manage-users` + `view-users` + `query-users` (no
`manage-realm`, no `manage-clients`, no `view-events` — principle
of least privilege). The client secret is published through the
same `kc-secrets` volume pattern as `admin-read`, and
`team.actions.ts` now authenticates with `grant_type=client_credentials`
via a new helper at
`apps/web/src/lib/security/keycloak-admin-write.ts`. The global
admin credentials are no longer needed by the web process.

`admin-cli` remains enabled for the bootstrap-only consumers that
still need it: `apply-config.sh` itself (which runs before the new
client exists) and `scripts/keycloak-reset-admin.sh` (break-glass).
Both run in contexts where credential-stuffing is not a realistic
vector, and are now mitigated by the master realm's Brute Force
Protection.

### Hardening details — headers and TLS

- Strict-Transport-Security now includes `preload` on both vhosts
- New headers on the app vhost: `X-Frame-Options: DENY`,
  `Cross-Origin-Opener-Policy: same-origin`,
  `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()`
- Referrer-Policy now explicit on the Keycloak vhost
  (`strict-origin-when-cross-origin`)

### Upgrade instructions

Bind-mounted installs (most self-hosted users) **must** force
recreate the web container so the new `Caddyfile` takes effect:

```
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

After restart, check:

```
# C-01 verification — port 4000 should refuse connections
curl --connect-timeout 5 http://your-vps.example:4000/api/auth/session
# Expected: Connection refused

# H-02 verification — Keycloak admin should 404
curl -I https://vpskey.example/admin/master/console/
# Expected: HTTP/2 404

# H-03 verification — CORS from evil origin should not emit ACAO
curl -I -H "Origin: https://evil.example" \
  https://vpskey.example/realms/ticketbrainy/.well-known/openid-configuration \
  | grep -i access-control
# Expected: (empty output)

# M-01/M-02 verification — check keycloak-init logs
docker logs aidesk-keycloak-init-1 2>&1 | grep -E "(admin-write|master realm)"
# Expected: "ticketbrainy-admin-write" creation + "master realm hardened"
```

## [1.10.13] — 2026-04-10

### Fixed — KC_ADMIN_READ_CLIENT_SECRET auto-wired on fresh install

Reported on a clean v1.10.11 VPS install. Settings → Security →
Authentication panel showed:

> Unable to reach Keycloak — check ticketbrainy-admin-read
> client credentials. KC_ADMIN_READ_CLIENT_SECRET is not set

Before v1.10.13, the fresh-install flow for this panel required
a **3-step manual dance** no operator actually does:

1. `keycloak-init` creates the `ticketbrainy-admin-read` client
   on first boot and prints the client secret in its logs.
2. Operator reads the logs, finds the secret, copies it into
   `.env` as `KC_ADMIN_READ_CLIENT_SECRET=...`.
3. Operator restarts the web container to pick up the new env.

Step 2 never happened on real installs — the Security page just
stayed broken indefinitely.

#### Fix — shared volume bridge

`keycloak-init` now writes the secret atomically to a new docker
named volume (`kc-secrets`) that the web container mounts
read-only at `/data/keycloak-secrets`. `keycloak-admin.ts`
lazy-reads the secret from the file when the env var is empty,
so fresh installs work out of the box.

Touched files:

- **`keycloak/apply-config.sh`** — after fetching the secret
  from Keycloak, atomically writes it to
  `/opt/keycloak-init/secrets/admin-read-secret` (tmp file +
  rename, 644 perms so `uid 1001 (nextjs)` can read).
- **`docker-compose.yml`** — new `kc-secrets` volume.
  `keycloak-init` now runs as `user: "0:0"` (root) and mounts
  it `:rw`; `web` mounts it `:ro`.
- **`apps/web/src/lib/security/keycloak-admin.ts`** *(private
  repo)* — new `loadClientSecret()` helper that prefers the env
  var and falls back to the file, caches on first success.

#### Backward compatible

Operators who already set `KC_ADMIN_READ_CLIENT_SECRET` in their
`.env` keep their workflow — the env var takes precedence over
the file. The fallback only fires when the env var is
unset/empty.

### Upgrade from v1.10.12

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate keycloak-init web
```

`--force-recreate keycloak-init` is required so it picks up the
new `apply-config.sh` logic, the root user override, and the
`kc-secrets` mount. `web` recreate picks up the new volume
mount and the updated `keycloak-admin.ts`.

### Release mechanics

- All 5 service images re-tagged + pushed at `v1.10.13` AND
  `:latest` (lockstep release)
- 6 version source files bumped 1.10.12 → 1.10.13
- Public repo changes: `docker-compose.yml` +
  `keycloak/apply-config.sh`

---

## [1.10.12] — 2026-04-09

### Improved — Deployment banner UX (per-field drift + revert)

Follow-up polish to the v1.10.11 drift-detection fix. The banner
now tells the operator **which** fields diverge and offers a
one-click escape hatch.

#### Per-field drift diff

When the saved DB config differs from the running env vars, the
banner now lists each changed field with:

- the human-readable label (e.g. "LAN hosts", "App domain")
- the value saved in the DB (what *would* apply)
- the value currently running on the instance (what *is* live)

Before, the operator had to reverse-engineer the divergence by
comparing their `.env` against the form field-by-field.

#### "Revert to running config" button

A new one-click undo button inside the drift banner. Clicking it:

1. Resets the form to the values currently running in the
   container (env vars at page-load time).
2. Saves — the DB goes back in sync with live, `hasDrift` becomes
   `false`, and the banner disappears **without a docker restart**.

Useful when the operator tested a field change, saved it, then
wanted out of the half-committed state.

### Upgrade from v1.10.11

Web-only update — Caddy config and bootstrap Caddyfile unchanged:

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate web
```

### Release mechanics

- All 5 service images re-tagged + pushed at `v1.10.12` AND
  `:latest` (lockstep release)
- 6 version source files bumped 1.10.11 → 1.10.12
- No changes to `docker-compose.yml`, `proxy/Caddyfile`, or
  `proxy/caddy-entrypoint.sh`

---

## [1.10.11] — 2026-04-09

### Fixed — 4 fresh-install polish issues from VPS walkthrough

Four independent bugs reported on a clean v1.10.10 VPS install.
All shipped in a single lockstep release.

#### 1. Initial Setup checklist — "Add your first customer" was always complete

`db.customer.count()` in the checklist also counted the seeded
system customer (the catch-all for public-domain emails), so the
step was auto-completed before the operator had added anyone.
The query now excludes `isSystem: true` rows.

#### 2. Renamed the catch-all from "AutresClients" to "Other"

The catch-all for orphan tickets from public email domains
(gmail/hotmail/outlook/…) was named "AutresClients", a
French-only label that confused non-French operators. It's now
called "Other" — universally readable across the languages we
support.

The seed upsert force-renames existing rows on every `up -d`
(`update: { isSystem: true, name: "Other" }`), so upgrading
installs rename automatically. No manual SQL needed.

The ticket table previously decided the red system-badge avatar
via a brittle string comparison `customer.name === "AutresClients"`
— now switched to `customer.isSystem` which is rename-safe.

#### 3. Deployment pending banner stuck after save

Settings → Deployment → *Save* used to hard-code the client-side
drift to `true` after every save, so:

- Clicking Save with no actual changes raised a false
  "Modifications en attente d'application" banner.
- Even after the operator ran the suggested
  `docker compose down && up -d`, the banner never cleared
  without a page refresh.

`saveDeploymentConfig` now re-computes the real drift against
live env vars post-save and returns it. The form uses that value
directly — no-op saves no longer raise a false banner, and saves
that bring the DB back in sync with live env clear an existing
banner instantly.

#### 4. SSL certificates panel — "No Caddy certificates detected" despite a live cert

Settings → Security → SSL certificates displayed "No Caddy
certificates detected" even when Caddy was actively serving a
Let's Encrypt certificate. Root cause:

- Caddy writes every file it creates in 600 mode
  (`-rw-------` root:root).
- The web container mounts `caddy-data:/data/caddy:ro` and
  runs Node.js as `uid 1001 (nextjs)`.
- `listCaddyCerts()` hit `Permission denied` on every
  `readdir` under `/data/caddy/caddy/certificates/...` even
  though the files were right there.

Fix: wrap the caddy container with a small entrypoint shim
(`proxy/caddy-entrypoint.sh`) that runs a background loop every
60 seconds and widens perms on PUBLIC cert files only:

```sh
find /data/caddy/certificates -type d -exec chmod o+rx {} +
find /data/caddy/certificates -type f -name '*.crt' -exec chmod o+r {} +
```

Private keys (`*.key`) and ACME metadata (`*.json`) stay 600
and are never exposed outside the caddy container. The 60s loop
catches cert renewals too — Caddy re-writes renewed certs in
600, and the next sweep re-widens them.

### Upgrade from v1.10.10

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate caddy web
```

`--force-recreate caddy` is required because `caddy-entrypoint.sh`
is a new bind mount (the running caddy container must restart to
pick it up). The seed re-runs automatically via the `migrate`
service and force-renames "AutresClients" → "Other".

### Release mechanics

- All 5 service images re-tagged + pushed at `v1.10.11` AND
  `:latest` (lockstep release)
- 6 version source files bumped 1.10.10 → 1.10.11
- Public repo additions: `proxy/caddy-entrypoint.sh`,
  `docker-compose.yml` caddy service now mounts the entrypoint

---

## [1.10.10] — 2026-04-09

### Fixed — Keycloak allowlist hot-reload regression loop

The v1.10.09 fix for the Caddy admin API origin validation covered
two of the three code paths that need the `origins` allowlist, but
missed the third: the `renderCaddyfile()` function in the web
container that re-generates a Caddyfile from DB state on every
"Save & reload Caddy" click.

**Symptom on the VPS after v1.10.09**: after the very first
successful save the UI started showing

```
Saved to database, but Caddy reload failed:
{"error":"client is not allowed to access from origin 'http://caddy:2019'"}
```

on every subsequent save. The hot-reload silently died even though
the bootstrap `proxy/Caddyfile` and the web container both had the
v1.10.09 fixes.

**Cause**: `renderCaddyfile()` emitted `admin 0.0.0.0:2019`
*without* an `origins` block. The first successful save — which
passed the origin check against the bootstrap config still in
memory — replaced the running Caddy config with the rendered one,
wiping the origins allowlist in-process. Every later POST /load
was then rejected. Verified live on VPS 212.47.64.102:

```
$ docker exec caddy wget -qO- http://localhost:2019/config/admin
{"listen":"0.0.0.0:2019"}   ← no "origins" field
```

**Fix**: `apps/web/src/lib/security/caddy-reload.ts` —
`renderCaddyfile()` now emits the same admin block as the bootstrap
`proxy/Caddyfile`:

```
admin 0.0.0.0:2019 {
    origins caddy:2019 localhost:2019 127.0.0.1:2019
}
```

A comment on the block explicitly warns that this must stay in
lockstep with `proxy/Caddyfile` in this repo.

### Upgrade from v1.10.09

Standard rolling upgrade. `proxy/Caddyfile` is unchanged, so no
`--force-recreate caddy` is required this time — only the web
image needs to be refreshed:

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate web
```

If the operator already hit the bug on v1.10.09 and the running
Caddy config lost its origins, one additional restart of Caddy
will reload the bootstrap Caddyfile from disk and re-seed the
origins:

```bash
docker compose --profile with-proxy up -d --force-recreate caddy
```

### Release mechanics

- All 5 service images re-tagged + pushed at `v1.10.10` AND
  `:latest` (lockstep release per the release-lockstep.sh script)
- 6 version source files bumped 1.10.09 → 1.10.10
- `proxy/Caddyfile` unchanged (already correct since v1.10.09)

---

## [1.10.09] — 2026-04-09

### Fixed — Caddy admin API origin validation

The v1.10.08 Keycloak admin IP allowlist hot-reload was rejected
by Caddy with `client is not allowed to access from origin ''` on
every save. Two missing pieces:

**Cause**: when Caddy's admin API listens on a non-loopback
address (`admin 0.0.0.0:2019`), the default origin validation
refuses every request unless an explicit `origins` directive is
specified. The v1.10.08 Caddyfile had none, so the allowed list
was empty and every POST /load from the web container was
dropped. On top of that, server-to-server Node fetch sends an
empty `Origin` header by default, which also confuses Caddy's
origin parsing.

**Fix**:

- `proxy/Caddyfile` — the admin block now declares the allowed
  origins explicitly:

  ```
  admin 0.0.0.0:2019 {
      origins caddy:2019 localhost:2019 127.0.0.1:2019
  }
  ```

  `caddy:2019` matches the docker DNS hostname the web container
  uses to reach Caddy. The loopback variants are kept for local
  debugging via SSH port-forward.

- `apps/web/src/lib/security/caddy-reload.ts` — the fetch call
  now sets an explicit `Origin: http://caddy:2019` header. Caddy
  parses this as a URL, extracts the Host part, and matches it
  against the origins list.

### Upgrade from v1.10.08

Standard rolling upgrade, with `git pull` to refresh the
bind-mounted Caddyfile:

```bash
cd ticketbrainyApp
git pull
docker compose --profile with-proxy pull
docker compose --profile with-proxy up -d --force-recreate caddy web
```

The `--force-recreate caddy` is required because the Caddyfile
is a bind mount — the running container keeps the old config
until the process restarts.

### Release mechanics

- `web` image rebuilt (new digest sha256:44f605c56cae…)
- 4 other images re-tagged from the matching v1.10.08 builds
  for lockstep parity
- 6 version source files bumped 1.10.08 → 1.10.09

## [1.10.08] — 2026-04-09

### Added — Keycloak admin IP allowlist, managed from the UI

The `Settings → Security` page gets a new **"Keycloak admin IP
allowlist"** panel next to the existing TicketBrainy admin
allowlist. It restricts `/admin/*`, `/admin`, and
`/realms/master/*` on the Keycloak domain to specific CIDRs,
enforced by the Caddy reverse proxy **before** the request
reaches Keycloak.

This is a separate list from the TicketBrainy admin allowlist
because they protect different things:

| Allowlist | Enforced by | What it protects |
|---|---|---|
| TicketBrainy admin | Next.js server actions | Security mutation routes |
| Keycloak admin | Caddy reverse proxy | Keycloak admin console + master realm |

The two are complementary — the first protects app-level admin
actions, the second protects the identity provider admin console.
Both default to "no restriction" on fresh installs.

**Zero-downtime hot reload**: saving the list from the UI
triggers a server action that:

1. Validates CIDRs and self-lockout (your current IP must be in
   the list before it's saved)
2. Persists to `SecuritySettings.keycloakAdminIpAllowlist`
3. Re-renders the entire Caddyfile from a TypeScript template
4. POSTs the rendered config to `http://caddy:2019/load` (Caddy's
   admin API, exposed only on the internal docker network)
5. Caddy validates the new config, switches in-flight requests
   over, and drops the old config — no container restart, no
   dropped connections

**Survives container restarts**: because Caddy boots with a bare
Caddyfile (no matcher), a full `docker compose down/up` would
silently drop the restriction. The web container's Next.js
instrumentation hook re-pushes the current DB value to Caddy
two seconds after boot, so the restriction is re-applied
automatically. This also makes the restriction survive image
upgrades.

**What stays open** — the public SSO flow for regular ticket
users (`/realms/ticketbrainy/*`) and the shared Keycloak
`/resources/*` (CSS/JS for login pages) are not blocked. Only
the admin surface is restricted.

**Break-glass**: if you lock yourself out (e.g. ISP rotated your
IP), SSH to the server and clear the DB list, then restart
Caddy — see `docs/DEPLOYMENT-MODES.md` for the exact commands.

### Schema changes

New Prisma column on `SecuritySettings`:

    keycloakAdminIpAllowlist String[] @default([])

Applied automatically by the migrate container on the next boot
via `prisma db push`. No data migration needed; existing rows
get the default empty array, matching pre-v1.10.08 behaviour
(no restriction).

### Release mechanics

- `web` + `migrate` images rebuilt (schema change triggers
  the migrate rebuild)
- 3 other images re-tagged from the matching v1.10.07 builds
  for lockstep parity
- All 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.08` +
  `:latest`, digest parity verified
- 6 version source files bumped 1.10.07 → 1.10.08

## [1.10.07] — 2026-04-09

### Fixed — Bootstrap banner readable in light theme

The bootstrap-mode banner on the `/login` page used `text-amber-200`
with no `dark:` variant, which made the text almost invisible on
a light-theme background (pale yellow on near-white). Dark theme
was fine.

Now uses a proper light/dark colour pair:

- `bg-amber-100/70 text-amber-900` in light mode
- `dark:bg-amber-500/5 dark:text-amber-100` in dark mode

And the inline `<code>` elements get a matching split
(`bg-amber-500/20` / `dark:bg-amber-500/10`).

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.07` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from
  the matching v1.10.06 builds for lockstep parity
- 6 version source files bumped 1.10.06 → 1.10.07

## [1.10.06] — 2026-04-09

### Fixed — Initial Setup checklist polish

Two small fixes to the dashboard checklist introduced in v1.10.04,
caught during the first operator walkthrough.

**Keycloak users step lands on admin login, not a deep link**
— the step opened
`https://KEYCLOAK_DOMAIN/admin/ticketbrainy/console/#/ticketbrainy/users`
directly. That URL bypasses the master realm's admin login flow and
lands on a blank/broken state because Keycloak can't reconcile the
requested page with the missing admin session. Changed to just the
root `https://KEYCLOAK_DOMAIN/` so operators go through the normal
admin login flow, then navigate to the `ticketbrainy` realm from the
dropdown (which matches the walkthrough in the step description).

**Mailbox step copy explains multi-mailbox + default SMTP** — the
step description conflated "ticket reception" and "system
notifications" without explaining how multiple mailboxes are handled.
Rewrote to explicitly say:

- You can add several mailboxes
- The **first mailbox you add** becomes the default SMTP used by the
  ticketing system for outbound notifications (user invites, password
  resets, new-ticket alerts)

Both EN and FR copy updated.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.06` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from the
  matching v1.10.05 builds for lockstep parity
- 6 version source files bumped 1.10.05 → 1.10.06

## [1.10.05] — 2026-04-09

### Added

**DNS prerequisites spelled out + pre-check** — `install.sh` now
explicitly lists the two DNS A records required for Caddy mode
(one for the app, one for Keycloak) in the mode B description,
and runs a non-blocking DNS resolution check after both domains
are captured. If either domain doesn't resolve or points somewhere
else, you get a clear warning and a confirmation prompt — you can
continue the install and fix DNS afterwards (Caddy keeps trying
the ACME challenge in the background). `docs/DEPLOYMENT-MODES.md`
has a new prerequisites table explaining why two records are
needed (Keycloak's OIDC redirect URIs require its own origin).

**Activation wizard pre-fills from install.sh** — the license
email you typed at the terminal is now persisted to `.env`,
passed to the web container via docker-compose, and read by the
server component of `/activate` so step 1 renders with the email
pre-populated. You still confirm before clicking "Activate" —
we don't auto-submit, you stay in control — but there's no more
retyping the same address in the browser. Prevents the typo-driven
"two fresh-deploy devices" issue on VigilanceKey.

**Admin IP allowlist panel — inline help + current-IP quick-insert**
The Settings → Security → Admin IP allowlist panel has three new
UX improvements:

1. An inline help block at the top explaining the format (one
   IP/CIDR per line), concrete examples (`/32` for a single
   workstation, `/24` for an office subnet), and that an empty
   list is a valid first-run setting (auth still protects the
   pages).

2. The server component now reads `x-forwarded-for` from the
   current request and passes your current IP to the form. A
   blue banner displays the detected IP and a one-click "Add /32"
   button inserts it into the textarea. Prevents self-lockout.

3. A break-glass procedure block documents
   `SECURITY_ALLOWLIST_BYPASS=true` as the documented emergency
   recovery path, with the exact 2-command sequence to run on
   the server.

`docs/DEPLOYMENT-MODES.md` has a new "Admin IP allowlist — what
to put there" section with guidance for residential ISPs with
dynamic IPs (don't enable it; use WAF-level restrictions at your
upstream firewall instead).

### Upgrade notes

Standard rolling upgrade:

```bash
docker compose pull
docker compose up -d
```

If you're upgrading from v1.10.02 or earlier and want to take
advantage of the wizard pre-fill on an already-activated instance,
there's nothing to do — the feature only kicks in on fresh
installs, your existing `.env` is untouched.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.05` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from
  the matching v1.10.04 builds for lockstep parity
- 6 version source files bumped 1.10.04 → 1.10.05

## [1.10.04] — 2026-04-09

### Added — Initial Setup checklist on the dashboard

Fresh installs now get a dashboard widget that walks operators
through the 5 must-do steps before the instance is production-ready:

1. **Add your first mailbox** — IMAP + SMTP, used for both ticket
   reception AND system notifications (password reset, invites)
2. **Create your first Keycloak users** — opens the Keycloak admin
   console (URL auto-resolved from KEYCLOAK_DOMAIN in Caddy mode,
   or IP:8180 in LAN mode)
3. **Choose your interface language** → Settings → Language
4. **Add your first customers** → Settings → Customers
5. **Customise your personal theme** → Settings → Appearance

Each step shows a green check when done (auto-detected from real DB
state OR manually dismissed via click), a progress bar counts the
completed items, and the whole widget auto-hides when everything is
done or when the operator clicks the dismiss `X`. Preference-only
steps (language, theme) can be manually toggled; real-infra steps
(mailbox, Keycloak users, customers) are detected from Prisma counts
and cannot be faked.

Auto-detection queries run in parallel with the existing dashboard
queries — no added latency beyond ~5-10ms.

### Fixed — Analytics / Reports "Analytics Pro" lock screen

Both `/analytics` and `/analytics/reports` still referenced the
decommissioned `analytics_pro` plugin in their `<FeatureGate>`
lock screen. The feature flag check (`hasFeature("analytics_dashboard")`)
already resolved correctly against the current `enterprise_pack`
plugin, but the "Requires …" CTA text pointed users to a plugin
that no longer exists in the marketplace. Updated both pages to
`pluginName="Enterprise Pack"` with the correct slug, so clicking
the lock now takes operators to the right plugin detail page.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.04` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from
  v1.10.03 builds for lockstep parity
- 6 version source files bumped 1.10.03 → 1.10.04
- Rolling upgrade: `docker compose pull && docker compose up -d`

## [1.10.03] — 2026-04-09

### Fixed — Settings/Deployment sees Caddy + wizard auto-detects mode

Three related fixes that surfaced on the fresh VPS deploy path once
v1.10.02 unblocked the SSO bootstrap. The operator could successfully
log in but `Settings → Deployment` reported "Caddy disabled, no
domains, no Let's Encrypt certs" even while Caddy was running and
serving real certs from the front.

**Web container never received deployment env vars**

`docker-compose.yml` referenced `APP_DOMAIN`, `APP_URL`, `APP_PORT`,
`KEYCLOAK_DOMAIN`, `LETSENCRYPT_EMAIL` for Caddy variable substitution
and for deriving `NEXTAUTH_URL`, but NEVER passed them into the web
container's environment. `getLiveConfig()` in `deployment.actions.ts`
reads directly from `process.env`, so on the web side every one of
those values came back empty. The Settings → Deployment panel
correctly rendered the resulting config as "Caddy disabled".

Added all five vars to the web service environment block so the live
config reflects what's actually running.

**Caddy cert detection defeated by Caddy's 700 perms**

`deployment-detector.ts` used `fs.readdirSync("/data/caddy/caddy/
certificates")` which throws EACCES inside the web container. Caddy
creates `acme/`, `certificates/` and `locks/` as `root:root mode 700`,
while the web container runs as a non-root `nextjs` user. The
sticky-bit `1777` on the parent `/data/caddy/caddy/` dir lets us
STAT children but not READ them.

The detection code swallowed the EACCES in try/catch and returned
false → every Caddy deploy was reported as "Caddy inactive, no
certs" on the Security page, greying out the entire HTTPS/Caddy/
Let's Encrypt section.

New heuristic: check for `/data/caddy/caddy/last_clean.json` via
`existsSync`. Caddy writes this file on every cert maintenance cycle
(the first one runs at container startup). `existsSync` calls
`stat()` internally, which only needs execute on the parent dir
(`1777` grants that) and NOT read on the file contents (which we
don't need).

**Activation wizard step 2 always defaulted to LAN-only**

The `/activate` step 2 React component initialised state with
`useState<NetworkExposure>("none")`. On a VPS deploy where install.sh
just configured Caddy, the wizard showed "LAN-only" pre-selected and
operators who clicked through quickly ended up persisting
`networkExposure="none"` into `SecuritySettings`. From that point on
the Security page said "LAN-only, Caddy disabled" — matching the DB
but not reality.

The server component now auto-detects the mode from install.sh's
env vars and passes it as `initialMode` to the form:

- `APP_DOMAIN` set → **vps-caddy** (install.sh only writes `APP_DOMAIN`
  in Caddy mode)
- `APP_URL` starts with `https://` and no `APP_DOMAIN` → **behind-waf**
- otherwise → **none** (LAN)

Step 2 opens with the best-guess option selected and a green banner:

> Detected from your install.sh configuration: VPS with managed
> Caddy. Click any other option above to override.

The operator can still override before submitting.

### Upgrade notes from v1.10.0 – v1.10.02

Standard rolling upgrade:

```bash
docker compose pull
docker compose up -d
```

If your SecuritySettings row already has `networkExposure=none`
from an earlier broken activation, fix it in-place from the UI:
**Settings → Security → Deployment mode panel** → click the
correct mode. No reinstall needed.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.03` + `:latest`
- Only `web` has source changes; the other 4 are re-tagged from the
  matching v1.10.02 builds for lockstep parity
- 6 version source files bumped 1.10.02 → 1.10.03

## [1.10.02] — 2026-04-09

### Fixed — Bootstrap login flow + Keycloak public exposure

Two fixes that complete the fresh-install story started in 1.10.01.
That release fixed the SSO first-user auto-promotion server-side, but
on a real Caddy VPS deploy the operator could never actually REACH
the point where that code runs because of two chicken-and-egg issues.

**Bootstrap mode on the login page (critical)**

Until now, the `/login` page showed the local email+password form
only to client IPs that matched `LAN_HOSTS`. On a VPS deploy, every
operator is "public" from the server's perspective — no LAN exists —
so the local seed account `admin@ticketbrainy.local` was effectively
invisible from the outside, and the SSO button was the only option.
But SSO has no admin users yet on a fresh install, so there's no way
to log in at all.

New behaviour: the login page now checks the database for any
active Keycloak ADMIN user. If none exists, it enters "bootstrap
mode": the local form is shown regardless of client IP, with a small
amber banner explaining why. As soon as someone logs in via SSO and
gets auto-promoted (the "first SSO admin" rule from v1.10.01), the
bootstrap flag flips off and the local form is hidden from public
IPs again.

This cleanly solves the chicken-and-egg: bootstrap with the local
account, create the Keycloak user, SSO in, the bootstrap door closes
automatically.

**Keycloak host port bound to localhost in Caddy mode**

The `keycloak` service used `"${KC_PORT:-8180}:8080"` which binds
to 0.0.0.0 — exposing the admin console on `http://<public-ip>:8180`.
Keycloak 26 then rejects every non-localhost HTTP hit with
"HTTPS required", which is a dead end but still looks like the right
URL, confusing operators. Worse, Keycloak's admin console client has
relative `redirectUris` which get resolved against the request URL,
so a single HTTP hit on :8180 would sometimes poison the session
with an HTTP redirect_uri that then fails against the HTTPS endpoint.

Change:

```yaml
ports:
  - "${KC_BIND:-0.0.0.0}:${KC_PORT:-8180}:8080"
```

`install.sh` in Caddy mode now writes `KC_BIND=127.0.0.1` to `.env`,
so the port is only reachable from localhost on the server itself.
Caddy still reaches Keycloak via the internal docker network
(`keycloak:8080`), so `https://<kc-domain>/admin` remains the
working entry point. LAN deployments (non-Caddy mode) are untouched
— `KC_BIND` defaults to `0.0.0.0` so admins on the LAN can still
hit `http://<server-ip>:8180` as before.

**install.sh — final summary + bootstrap sequence**

Updated the "Access URLs" and "Next steps" sections to:

- Display the correct Keycloak admin URL per mode (Caddy: HTTPS
  domain, Direct: IP:8180)
- In Caddy mode, explicitly warn that `http://<ip>:8180` is bound to
  localhost only, with a tip to configure DNS if not ready
- Walk through the 5-step bootstrap sequence: activate license →
  log in with `admin@ticketbrainy.local` (bootstrap mode) → create
  user in Keycloak admin console → set password manually in the
  Credentials tab → log out and SSO in (auto-promoted to ADMIN) →
  change the seed admin password

### Upgrade notes from v1.10.0 or v1.10.01

The cleanest fix is to wipe and reinstall:

```bash
docker compose down -v
cd ..
rm -rf ticketbrainyApp
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
bash install.sh
```

If you cannot drop the database but are on v1.10.0/v1.10.01 and
stuck, add this to your `.env` in Caddy mode and recreate Keycloak:

```
KC_BIND=127.0.0.1
```

Then `docker compose up -d --force-recreate keycloak`.

### Release mechanics

- 5 images at `ghcr.io/kr1s57/ticketbrainy-*:v1.10.02` + `:latest`,
  digest parity verified (only `web` has source changes; the other
  four are re-tagged from the matching v1.10.01 builds)
- 6 version source files bumped 1.10.01 → 1.10.02

## [1.10.01] — 2026-04-09

### Fixed — Fresh install / SSO first-login UX

Four fixes that unblock the first-time deploy experience on a fresh
VPS. A real end-to-end test install on v1.10.0 hit every single one
of these in sequence — the hardest one left the app entirely unusable
after a successful Keycloak SSO login.

**SSO first-admin auto-promotion (critical)**

The jwt callback in `apps/web/src/lib/auth/index.ts` used
`userCount === 0 ? "ADMIN" : "AGENT"` to decide whether a fresh
Keycloak user should be auto-promoted. On every real install
`prisma/seed.ts` has already created the seed local account
`admin@ticketbrainy.local` *before* anyone logs in via SSO, so
userCount is always ≥ 1 and every SSO user landed as AGENT with
`isActive=false`.

Worse: the next branch (`if (!dbUser.isActive)`) returned the token
without setting `token.userId` or `token.role`. Every downstream
`db.user.findUnique({ where: { id: session.userId } })` then threw
`User not found` with a cryptic 500, and every admin endpoint
returned 403 because `session.user.role` was undefined. The user
was left with an apparently-working login that crashed on every
page.

New logic: the first user with `keycloakId IS NOT NULL AND
role='ADMIN' AND isActive=true` is the "first SSO admin" — the
seed local account does not block this check because it has no
keycloakId. Additionally, `token.userId` and `token.role` are
always set, even for inactive users, so downstream code can render
a proper "account pending approval" screen instead of crashing.
`token.error='inactive'` is now an *additional* marker, not a
replacement.

Security model: whoever holds access to the Keycloak realm is
trusted to be the first TicketBrainy admin. This is already the
trust boundary in practice — Keycloak realm access is what gates
who can reach the app at all.

**Telegram bot crash loop**

`process.exit(1)` on missing `TELEGRAM_BOT_TOKEN` combined with
Docker's `restart: unless-stopped` caused a crash-loop that flooded
logs on every fresh install that did not use Telegram notifications.
Replaced with a silent poll-wait loop that re-checks env + DB every
60s. When the operator eventually configures a token in Settings
→ Telegram, the bot picks it up on the next poll and starts
normally. No more log noise, no more manual `docker compose stop
telegram-bot` workaround.

**install.sh — Caddy-mode final summary**

In Caddy mode, `APP_URL` (and `NEXTAUTH_URL` inside the container)
is set to `https://<domain>`. The CSRF check in `/api/activate` and
every server action requires the browser's `Origin` header to match
that exact URL. Hitting `http://<server-ip>:4000` in Caddy mode
gets rejected with **403 Forbidden** because origins don't match.

The installer now:
- Displays ONLY the HTTPS domain URL in Caddy mode (never the LAN IP)
- Shows a prominent warning box explaining why `http://<ip>:4000`
  must NOT be used in Caddy mode
- Includes quick troubleshooting pointers (DNS resolution, Caddy
  logs, firewall ports 80/443)
- Updates the Next steps block to point at the right URL per mode
- Adds a "Keycloak SSO as admin" section documenting the auto-promotion
  rule from the fix above

**docs/DEPLOYMENT-MODES.md — Keycloak email + first SSO admin**

Added two new sections:

- **Keycloak email** — explains that "No sender address configured
  in the realm settings for emails" comes from a missing realm-level
  SMTP config in Keycloak. Documents both paths to unblock user
  provisioning (configure realm SMTP OR use `Credentials → Set
  password` instead of the email-based reset flow).
- **First SSO admin login** — documents the auto-promotion rule from
  v1.10.01 and the interaction with the seed local account.

### Upgrade notes from v1.10.0

**If you already installed v1.10.0 and your SSO user is stuck:**

The cleanest fix is to wipe and re-install — same outcome, zero
manual surgery:

```bash
docker compose down -v
cd ..
rm -rf ticketbrainyApp
git clone https://github.com/kr1s57/ticketbrainyApp.git
cd ticketbrainyApp
bash install.sh
```

For operators who cannot drop the database, the SQL fix is:

```sql
UPDATE "User"
SET "isActive" = true, "role" = 'ADMIN'
WHERE email = '<your-email>' AND "keycloakId" IS NOT NULL;
```

Followed by `docker compose pull && docker compose up -d --force-recreate web`.

### Release mechanics

- 5 images rebuilt and pushed to `ghcr.io/kr1s57/ticketbrainy-*`
  at BOTH `v1.10.01` AND `:latest`, digest parity verified
- 6 version source files bumped 1.10.0 → 1.10.01

## [1.10.0] — 2026-04-09

### New — Security Settings page

A new **Settings → Security** section gives operators a single place to
inspect and configure the platform's security posture. It covers nine
modules, grouped into read-only posture panels at the top and
togglable enforcement modules below.

**Read-only posture panels**

1. **Deployment mode** — current mode (LAN / behind-WAF / VPS+Caddy /
   VPS direct) plus live runtime signals that flag mismatches between
   the declared mode and the detected topology (Caddy presence,
   upstream proxy type via `CF-Ray` / `X-Forwarded-For`, etc.)
2. **Authentication (Keycloak)** — realm name, brute-force config,
   MFA policy, password policy, session timeouts, user count, and
   24-hour login-failure count. Data comes from the Keycloak Admin
   API via a dedicated read-only client `ticketbrainy-admin-read`
   created idempotently on every boot by `keycloak-init`.
3. **Rate limiting** — 6 known rules (`login:ip`, `login:user`,
   `activate:ip`, `csat:ip`, `ai:user`, `upload:user`) with live
   active-bucket counts read directly from Redis
4. **SSL certificates** — lists Let's Encrypt certificates persisted
   by Caddy with per-domain expiry (empty when Caddy is not used)

**Togglable enforcement modules**

5. **Audit logging** — records 17 security-sensitive event types
   (login success/failure, user created/deleted, role changed,
   mailbox OAuth, plugin enable/disable, license activation, upload
   rejected, rate-limit hit, etc.) to a new `AuditLog` table. Runtime
   toggle + configurable retention window (default 90 days) + daily
   background purge job. Comes with a paginated feed, event-type
   filter, and CSV export on the same Security page.
6. **Upload rate-limit** — throttles `/api/attachments/upload` to 20
   uploads per 5 minutes per user when enabled. Rejections are
   logged as `RATE_LIMIT_HIT` audit events.
7. **Magic-bytes validation** — rejects uploads whose content does
   not match the claimed extension (e.g. a `.exe` renamed to
   `.pdf`). Runs on the web upload path AND on incoming email
   attachments (advisory-only on the mail side — attachments are
   stored but flagged with a reason).
8. **Login anomaly detection** — when enabled, tracks a per-user
   failure counter in Redis with a 10-minute sliding window and
   emits `AUTH_LOGIN_SUSPICIOUS` audit events after 5 failures.
9. **Admin IP allowlist** — restricts `/settings/**` and
   `/api/admin/**` to specific CIDR blocks (IPv4 or IPv6). Includes
   triple self-lockout protection (client-side CIDR validation,
   server-side current-IP-in-list check, and a
   `SECURITY_ALLOWLIST_BYPASS=true` break-glass env var — see
   `docs/DEPLOYMENT-MODES.md §break-glass` for the recovery
   procedure).

### New — Activation wizard, step 2

`/activate` now has a second step where the operator chooses their
deployment mode from the four options above. The choice is persisted
in the database and drives the default toggle values for the Security
page (e.g. VPS modes enable rate-limit and anomaly detection by
default; LAN mode leaves them off). You can always change the mode
later at **Settings → Security**.

### New — `docs/DEPLOYMENT-MODES.md`

Full reference guide for the four modes, with pre-requisites,
recommended toggles per mode, the break-glass recovery procedure, and
how to retrieve the Keycloak `ticketbrainy-admin-read` client secret
from the init container logs.

### Database — schema changes

Two new tables and two new columns are added automatically by
`migrate` on the next `docker compose up -d`:

- `SecuritySettings` — singleton row holding every toggle state and
  the admin IP allowlist. Seeded with safe defaults so upgrades from
  v1.3.x–v1.9.x land in a known state.
- `AuditLog` — indexed on `eventType+createdAt`, `userId+createdAt`,
  `ip+createdAt`, and `createdAt` for fast filtering and pagination.
- `Attachment.flagged` (boolean) and `Attachment.flagReason` (text)
  — set by the magic-bytes validator on the upload path and by
  `mail-service` on incoming email attachments. Used to surface a
  flag badge in the UI (future release).

### Config — new environment variables

Add the following to your `.env` (see `.env.example` for the exact
format and the new section "Security Settings v1.10.0"):

```
KC_ADMIN_READ_CLIENT_ID=ticketbrainy-admin-read
KC_ADMIN_READ_CLIENT_SECRET=
SECURITY_ALLOWLIST_BYPASS=
```

After the first `docker compose up -d` retrieve the Keycloak secret
from the init container logs:

```bash
docker compose logs keycloak-init | grep KC_ADMIN_READ_CLIENT_SECRET
```

Paste it into `.env` as `KC_ADMIN_READ_CLIENT_SECRET=...` and then:

```bash
docker compose up -d --force-recreate web
```

The Security page will now show the full Keycloak posture panel
instead of an amber error card.

### Upgrade notes from v1.3.x

**Upgrading from a v1.3.x install is a straightforward
`docker compose pull && docker compose up -d`** — the `migrate`
service applies the new schema, and the `keycloak-init` service
creates the new admin-read client on first boot. After that, follow
the new-env-vars procedure above to wire the Keycloak secret into
`.env`.

Everything between v1.3.202 and v1.10.0 was an internal rolling
update — the `:latest` tag always reflected the current state. If
you want to pin to a specific version, use `:v1.10.0` in
`docker-compose.yml` instead of `:latest`.

### Deferred to future releases

- Antivirus scanning for attachments (ClamAV) — out of scope for
  v1.10.0 to keep the shipping surface small
- SPF / DKIM / DMARC validation on incoming email
- Spam scoring on incoming email
- Middleware-layer IP allowlist enforcement — currently implemented
  at the server-action layer because Next.js 16 node middleware is
  still experimental. The UI and enforcement are fully functional;
  this is an internal architectural note only.

---

## [1.3.202] — 2026-04-06

### Security — Image hardening

This patch strips build-time artifacts from the `web` Docker image so
the customer-facing container no longer carries raw TypeScript source,
build configuration, or source maps. Also scrubs a few leftover code
comments and one user-facing error message that named internal
infrastructure.

**What the image no longer ships**

- Raw `.ts` / `.tsx` source tree under `/app/apps/web/src/` — Next.js 16
  + Turbopack was over-inclusive in its standalone file tracing and was
  shipping the full application source into every image. This release
  deletes the source tree from the standalone output at build time.
- Server route source maps (`.next/server/**/*.map`)
- Build-time config files (Dockerfile, tsconfig.json, components.json,
  tailwind.config.ts, postcss.config.js, next.config.ts, prisma.config.ts)
- Internal dev scripts (`scripts/check-feature-gates.mjs`)
- Turbopack cache/log from the host build context

**Other scrubs**

- `allowedDevOrigins` is no longer in `next.config.ts` (it used to bake a
  LAN-only workstation IP into the production bundle).
- The activation screen hint and the fresh-deploy error message no
  longer name the internal license server hostname — they now reference
  the configured `VIGILANCE_KEY_URL` env var instead.

No functional change for end users. Upgrade is a plain image pull.

```bash
docker compose pull
docker compose up -d
```

Image size is unchanged (334 MB). The stripped files were < 1 % of the
total — the fix addresses the content of the image, not its weight.

---

## [1.3.201] — 2026-04-06

### Added — Mailbox inbound filter rules

Every mailbox now has a configurable set of **exclusion rules** that are
checked before any incoming IMAP message becomes a ticket. Use them to
silently drop noisy automated notifications (deploy summaries, cron
reports, monitoring heartbeats) or to block entire sender domains.

Each rule has three fields:

- **Field**: `Objet`, `Corps du message`, `Email expéditeur`, or
  `Domaine expéditeur`
- **Operator**: `contient`, `est égal à`, `commence par`, or
  `correspond à (regex)`
- **Value**: the text/pattern to match against

A message that matches **any active rule** is marked as read on IMAP but
**never creates a ticket and never touches the database** — the filter
runs before deduplication so noisy senders cost essentially zero.

Regex patterns are validated server-side at save time — invalid patterns
are rejected with a clear error message instead of crashing the poll
cycle later.

**Where to configure**: Settings → Mailboxes → Edit a mailbox → scroll to
the "Règles d'exclusion (filtre inbound)" section (only visible on
already-saved mailboxes).

### Added — Multi-select delete on ticket lists

The ticket list selection toolbar (previously showing only the "Merge"
button when 2+ tickets are selected) now also surfaces a destructive
**"Supprimer la sélection"** button as soon as at least one ticket is
checked. Confirmation prompt tells you how many tickets will be affected,
then they are moved to the "Supprimés" folder where they can be restored.

Under the hood it's a single transaction that soft-deletes every target
and writes one activity entry per ticket — fast and idempotent even for
large selections (capped at 500 per call).

### Database migration

This release adds a `MailboxExclusion` table with a foreign key cascade
from `Mailbox`. No manual action required — the schema is applied
automatically by the `migrate` init container on the first `up -d` after
pulling.

### Upgrade

```bash
docker compose pull
docker compose up -d
```

The new features are available immediately after the containers restart.

---

## [1.3.200] — 2026-04-06

### Dashboard & Statistics — full redesign with Recharts

Both the main **Dashboard** and the **Statistics** page have been rebuilt on
top of Recharts (wrapped by the shadcn `ChartContainer`). Hand-rolled div
bars and list-with-dots are gone; replaced by proper accessible charts that
follow the active theme automatically.

**What's new on the Statistics page**

- **Volumes & Résolutions** section with a grouped bar chart (opened vs
  resolved per day) and a radial resolution-rate gauge with target line.
- **Performances Équipe** section with a ranked agent leaderboard
  (progress-bar visualization) and a priority distribution with colored
  semantic bars.
- **Analyse de Tendance** section with a weekly 3-series line chart
  (opened / in progress / resolved) and a status distribution donut with
  legend.
- Modernized KPI row with accent-tinted icons and background accents.

**What's new on the Dashboard**

- Full 7-day activity bar chart (opened vs resolved) — right next to
  "My workload" — driven by a new data query.
- Modernized KPI cards with accent icons.
- Refined mailbox grid with hover-lift animation, connection dot, and
  agent badge overflow.
- Recent tickets list with French relative timestamps.

**Technical notes**

- All charts use semantic CSS tokens (`--chart-tb-*`) that cascade through
  the 4 existing themes (light default, light pro, dark default, dark pro),
  so no JS theme switch is needed.
- Dates are pre-formatted server-side in `fr-FR`, avoiding any hydration
  mismatch between SSR and client.
- Chart components live at `apps/web/src/components/charts/` in the source
  and are tree-shaken into the right pages at build time.

No migration is required — the new UI is bundled into the updated
`ghcr.io/kr1s57/ticketbrainy-web:v1.3.200` image and ships automatically
when you pull and restart.

### Security — Keycloak hardening sync + admin recovery toolkit

This release also ships an idempotent post-start configuration sync for
Keycloak and a self-contained admin recovery toolkit. After every
`docker compose up -d` the security defaults are re-enforced automatically,
so accidental UI changes or future Keycloak image upgrades cannot quietly
weaken the realm.

### Added

- **`keycloak-init` one-shot service** in `docker-compose.yml`. Runs after
  Keycloak is up, applies our hardened defaults via the admin REST API, then
  exits. Idempotent and safe to re-run.
- **`keycloak/apply-config.sh`** — single source of truth for the realm
  defaults. Edit it to change them.
- **`scripts/keycloak-reset-admin.sh`** — admin recovery toolkit with three
  modes:
  - `--mode unlock` — clear brute-force lockout for the admin user
  - `--mode api <NEW>` — rotate password while current credentials still work
  - `--mode recovery <NEW>` — full bootstrap recovery when the password is lost
  Auto-detects the keycloak container and Docker network — no configuration.
- **`docs/KEYCLOAK-ADMIN-RECOVERY.md`** — complete operational runbook
  covering hardening sync, login-theme reapplication after upgrade, all three
  recovery modes, end-user lockouts, brute-force settings, and the
  post-upgrade checklist.

### Changed

- **Realm template** (`keycloak/ticketbrainy-realm.json`) — strengthened for
  fresh installs:
  - `passwordPolicy`: `length(8) and notUsername`
    → `length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername and passwordHistory(5)`
  - `otpPolicyAlgorithm`: `HmacSHA1` → `HmacSHA256`
  - `ssoSessionMaxLifespan`: 36 000 s (10 h) → 28 800 s (8 h)
- These same hardened settings are also re-applied on every `up -d` to existing
  installs by the `keycloak-init` service — no manual migration needed.

### Brute-force protection — what's enforced

| Setting                  | Value | Meaning                          |
|--------------------------|-------|----------------------------------|
| `bruteForceProtected`    | true  | Master switch                    |
| `failureFactor`          | 5     | Failed attempts before lockout   |
| `maxFailureWaitSeconds`  | 900   | 15-minute lockout                |
| `permanentLockout`       | false | Auto-unlock after wait           |
| `passwordHistory`        | 5     | Block last 5 passwords on reuse  |

### What this means for you

After pulling the new images and `docker compose up -d`:

1. The new `keycloak-init` container runs once, applies the hardened settings
   to your existing realm, and exits with `OK — Keycloak realm 'ticketbrainy'
   is hardened`. Check with `docker compose logs keycloak-init`.
2. The custom branded login theme is **automatically re-applied after every
   Keycloak upgrade** — no more manual API patching.
3. If you ever lose the admin password, run
   `./scripts/keycloak-reset-admin.sh --mode recovery 'NewStrongPassword!'`
   from your install directory.

See [docs/KEYCLOAK-ADMIN-RECOVERY.md](docs/KEYCLOAK-ADMIN-RECOVERY.md) for
the full operational runbook.

---

## [1.3.002] — 2026-04-06

### Security — Critical license server hardening

Every response from the TicketBrainy license server is now cryptographically
signed with **Ed25519** and verified by the client on every permission check.
This closes an attack path where a modified `VIGILANCE_KEY_URL` could be
redirected to a local mock server to activate premium plugins without a
valid license.

### What changed under the hood
- The license server signs every `sync` / `fresh-deploy` response with an
  Ed25519 key. The public key is compiled into the TicketBrainy web image.
- The web app refuses any unsigned response or any response whose
  signature does not verify against the embedded public key.
- The `PluginLicense` table has four new nullable columns
  (`signedPayload`, `signature`, `signingKeyId`, `issuedAt`). The database
  migration runs automatically at startup.
- `hasFeature()` re-verifies the stored envelope on every call — a row
  hand-inserted into the database with no envelope no longer grants access.

### What this means for you
**Nothing to configure.** Pull the new images, restart, and click
**Sync** once in *Settings → Plugins* to re-fetch your licenses with
signed envelopes. During the ~10 seconds between the restart and your
first Sync click, premium plugin pages will temporarily show as locked.

See the [update instructions](#update-instructions) below.

---

## [1.3.001] — 2026-04-06

### Added
- **Interactive installer** (`install.sh`) — guided wizard for first-time deployment
- **Built-in Caddy reverse proxy** with automatic Let's Encrypt HTTPS (Mode B)
- **Settings > Deployment** UI — manage domain, HTTPS, and LAN access from the web UI
- **Enterprise Pack** plugin — unlimited users and unlimited mailboxes
- **CIDR support** in `LAN_HOSTS` — allow whole subnets (e.g., `192.168.1.0/24`)
- **Step-by-step Keycloak guide** for users new to SSO ([docs/KEYCLOAK-GUIDE.md](docs/KEYCLOAK-GUIDE.md))
- **Delete deployment** button on the license server admin (cleanup test installations)

### Changed
- **Default port changed from 3000 to 4000** to avoid conflicts with other apps
- **Activation flow simplified** — license check now happens server-side, no more cookie issues
- **Core plan limits enforced** — 3 active users max, 1 mailbox max (upgrade to Enterprise Pack for unlimited)
- **Login page** — local form visibility now based on real client IP (not just URL)
- **Settings menu** — Enterprise Pack moved to "Core" section, CSAT moved to "Productivity"
- All Docker images upgraded to **Node 22** (required for Prisma 7.6)

### Fixed
- Activation infinite loop on fresh installs
- `LAN_HOSTS` not detecting workstation IPs correctly
- Install script ANSI color codes not rendering on some terminals
- Webhook URL validation now blocks internal Docker hostnames
- Keycloak users created via auto-sync are now inactive by default (require admin approval)
- Email notifications now properly escape HTML in customer names and subjects
- File uploads use the validated MIME type to determine the file extension (no client trust)

### Security
- Comprehensive security audit applied
- Stricter role-based access control on admin actions
- Multiple privilege escalation paths fixed
- Content Security Policy (CSP) and Strict Transport Security (HSTS) headers added
- AI service refuses to start if its internal token is missing (fail-closed)

### Removed
- Old `Analytics Pro` plugin renamed to **Enterprise Pack** (now includes unlimited users + mailboxes)
- Legacy cookie-based activation gate

---

## [1.2.001] — 2026-04-05

- Keycloak theme customization
- Mailbox table redesign with status badges
- User invitation flow improvements
- CSAT single-use survey tokens
- Stripe plugin marketplace integration
- Email CC/BCC support

## [1.1.030] — 2026-04-04

- Auto-close inactive tickets workflow
- Email branding and signature customization
- 9 new premium plugins (MVP)
- Plugin feature gating system
- Customer logo upload

## [1.1.020] — 2026-04-04

- Full French i18n
- CSAT manual and automatic surveys
- Service monitor dashboard

---

## Update instructions

To update an existing TicketBrainy installation:

```bash
cd ticketbrainyApp
git pull
docker compose pull
docker compose --profile with-proxy up -d   # If using Caddy
# or
docker compose up -d                        # If behind your own proxy
```

Database migrations run automatically on startup.

### After updating to 1.3.200

The new `keycloak-init` service runs automatically after `up -d`. Verify it
succeeded:

```bash
docker compose logs keycloak-init
# Expected last line:
# [apply-config] OK — Keycloak realm 'ticketbrainy' is hardened
```

If you ever need to re-apply the hardening (e.g. after editing the script):

```bash
docker compose up -d --no-deps keycloak-init
```

### After updating to 1.3.002

Open `Settings → Plugins` in the admin UI and click **Sync** once.
This re-fetches all your licenses with cryptographic signatures so
premium features stay enabled. If you skip this step, premium pages
will show as locked until the next automatic sync.

### Verifying the update

```bash
# Check the installed version
docker compose exec web cat apps/web/package.json | grep '"version"'
# should show: "version": "1.3.200"

# Check that the keycloak hardening sync ran
docker compose logs keycloak-init | tail -5
```
