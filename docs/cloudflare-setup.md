# TicketBrainy — Cloudflare Setup Guide

> Cloudflare (plan gratuit) est **requis** pour activer la
> fonctionnalité **Geo Block** (blocage par pays). Sans Cloudflare,
> le Geo Block est désactivé et la page Settings → Deploy & Security
> → Geo Block affiche un bandeau "Cloudflare requis".

## Pourquoi Cloudflare ?

TicketBrainy utilise le header `CF-IPCountry` que Cloudflare injecte
automatiquement dans chaque requête passant par son réseau. Ce header
contient le code pays ISO du visiteur (ex: `FR`, `LU`, `DE`) avec
une fiabilité de ~99.9%, alimenté par le plus grand réseau CDN mondial.

La base GeoLite2 gratuite de MaxMind (précédemment utilisée) a été
retirée car elle classifiait incorrectement trop d'IPs européennes.

## Prérequis

- Un compte Cloudflare (plan **Free** suffit)
- Accès à votre registrar DNS pour changer les nameservers

## Scénario 1 — VPS avec Caddy (pas de WAF)

C'est le cas le plus courant pour les clients self-hosted sur un VPS
(Contabo, Hetzner, OVH, DigitalOcean, etc.).

### Étape 1 : Créer un compte Cloudflare

1. Rendez-vous sur https://dash.cloudflare.com/sign-up
2. Créez votre compte avec votre email
3. Choisissez le plan **Free**

### Étape 2 : Ajouter votre domaine

1. Dashboard → **Add a site** → tapez votre domaine (ex: `example.com`)
2. Cloudflare scanne vos DNS actuels et importe les records existants
3. Vérifiez que vos records A sont corrects :

| Type | Name | Content | Proxy |
|---|---|---|---|
| A | `support` (ou votre sous-domaine app) | `IP_DE_VOTRE_VPS` | ☁️ **Proxied** |
| A | `auth` (ou votre sous-domaine Keycloak) | `IP_DE_VOTRE_VPS` | ☁️ **Proxied** |

4. **Important** : les deux sous-domaines (app + Keycloak) doivent
   être en mode **Proxied** (nuage orange ☁️), pas DNS Only (gris).

### Étape 3 : Changer les nameservers

Cloudflare vous donne 2 nameservers (ex: `ada.ns.cloudflare.com`
et `bob.ns.cloudflare.com`).

1. Connectez-vous chez votre registrar DNS
2. Remplacez les NS actuels par ceux de Cloudflare
3. Sauvegardez

La propagation prend entre 5 minutes et 24 heures.

### Étape 4 : Configurer SSL/TLS

1. Cloudflare → **SSL/TLS → Overview** → sélectionnez **Full (strict)**
2. Cloudflare termine le TLS côté visiteur, puis se connecte en HTTPS
   à votre Caddy (qui a son propre certificat Let's Encrypt)

### Étape 5 : Vérifier

Attendez que le status passe à "Active" dans l'Overview Cloudflare,
puis :

```bash
curl -sI https://votre-domaine.example/login | grep "server:"
# Attendu: server: cloudflare
```

### Étape 6 : Activer Geo Block

1. Dans TicketBrainy → Settings → Deploy & Security → Geo Block
2. Le bandeau doit être **vert** : "Source de détection : Cloudflare
   (CF-IPCountry)"
3. Choisissez votre mode (Denylist ou Allowlist) et les pays
4. Sauvegardez

## Scénario 2 — Derrière un WAF + Cloudflare

Si vous avez déjà un WAF (Sophos XGS, F5, Traefik) devant
TicketBrainy, vous pouvez ajouter Cloudflare en amont. Le trafic
passe par :

```
Visiteur → Cloudflare → Votre WAF → Caddy/App
```

### Configuration

Suivez les mêmes étapes 1 à 5 du Scénario 1. Cloudflare injecte
`CF-IPCountry` dans la requête, votre WAF la forwarde à l'app.

### Whitelisting IPs Cloudflare sur le WAF (optionnel)

Pour empêcher un attaquant de contourner Cloudflare en se connectant
directement à l'IP de votre WAF, vous pouvez restreindre le trafic
HTTPS entrant aux seules IPs Cloudflare :

- IPv4 : https://www.cloudflare.com/ips-v4
- IPv6 : https://www.cloudflare.com/ips-v6
- API : `curl -s https://api.cloudflare.com/client/v4/ips`

**Cette étape est optionnelle.** Sans elle, le Geo Block fonctionne
à 100% pour le trafic passant par le domaine (= la quasi-totalité
des visiteurs). Le seul "bypass" serait un attaquant connaissant
l'IP directe de votre WAF ET s'y connectant explicitement.

## Scénario 3 — WAF seul (sans Cloudflare)

Si vous ne souhaitez pas utiliser Cloudflare, votre WAF peut
potentiellement injecter un header de pays lui-même :

- **Sophos XGS** : créez une règle HTTP Header → ajoutez
  `X-Country-Code: %GEOIP_COUNTRY_CODE%`
- **F5 BIG-IP** : iRule avec `set country [IP::country]` →
  `HTTP::header insert "X-Country-Code" $country`
- **Traefik** : plugin GeoIP middleware

TicketBrainy lit le header `X-Country-Code` en priorité 3 (après
`CF-IPCountry` et `X-Vercel-IP-Country`). Si votre WAF l'injecte,
le Geo Block fonctionnera sans Cloudflare.

**Limitation** : la précision dépend de la base GeoIP de votre WAF.
Les WAF commerciaux (Sophos, F5) utilisent généralement des bases
MaxMind payantes (~99.8% de précision).

## Mise à jour de TicketBrainy

Commande standard pour mettre à jour une instance TicketBrainy :

```bash
cd /opt/ticketbrainyApp
git pull
docker compose pull
docker compose up -d --force-recreate
```

Le `--force-recreate` est **obligatoire** — sans lui, les containers
dont l'image n'a pas changé (Caddy, keycloak-init) gardent leur
ancienne configuration bind-montée en mémoire, même si les fichiers
sur le disque ont été mis à jour par `git pull`.

## FAQ

**Q: Cloudflare gratuit est-il suffisant ?**
R: Oui. Le header `CF-IPCountry` est inclus dans tous les plans,
y compris Free.

**Q: Le Geo Block fonctionne-t-il sans Cloudflare ?**
R: Non (sauf si votre WAF injecte `X-Country-Code`). Sans header
de pays, le Geo Block fail-open (autorise tout le monde) et la page
Settings affiche un bandeau rouge "Cloudflare requis".

**Q: Les certificats Let's Encrypt de Caddy vont-ils continuer
à fonctionner ?**
R: Oui. Caddy renouvelle son cert normalement. Cloudflare utilise
son propre certificat côté visiteur (edge) et se connecte au cert
Caddy côté origine (mode "Full strict").

**Q: Que se passe-t-il si Cloudflare tombe en panne ?**
R: Le trafic ne passe plus par Cloudflare, donc `CF-IPCountry` est
absent. Le Geo Block fail-open (autorise tout). Le site reste
accessible.

**Q: Puis-je bloquer par pays directement dans Cloudflare ?**
R: Oui, via Cloudflare WAF Rules. Mais la fonctionnalité Geo Block
de TicketBrainy vous permet de le configurer depuis l'interface
TicketBrainy sans toucher au dashboard Cloudflare, et les blocages
sont tracés dans le journal d'audit.
