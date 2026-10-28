# DAST : OWASP ZAP

**Objectif** : découvrir et utiliser OWASP ZAP pour identifier les failles de sécurité d'une application web **en cours d'exécution**.

## SAST, SCA, DAST : trois angles différents

| | SAST | SCA | DAST |
|---|---|---|---|
| Analyse | le code source | les dépendances | l'application **déployée**, de l'extérieur |
| Outils du workshop | SonarQube, Semgrep | Dependency-Check, Dependabot | OWASP ZAP |
| Trouve | injections, secrets, mauvaises pratiques | CVE dans les paquets | en-têtes manquants, cookies faibles, erreurs de configuration, injections exploitables |
| Limite | ne voit pas la configuration au runtime | ne voit pas notre code | ne voit que ce qu'il atteint en explorant l'application |

## Fonctionnement dans le pipeline

Pipeline : `Checkout` > `Install & Build` > `SAST` > `SCA` > `Docker Build` > `Deploy Staging` > `DAST`

- **Cible** : `http://devsecops-staging:3000`. Le staging et ZAP sont sur le réseau Docker `devsecops`, donc ZAP atteint l'application par le nom de conteneur.
- **Outil** : image `ghcr.io/zaproxy/zaproxy:stable`, lancée par Jenkins via le socket Docker. Le premier build télécharge l'image (environ 1 Go).
- **Scan par défaut : baseline (passif)**. ZAP explore l'application pendant environ 1 minute (spider) et analyse les réponses. Il n'envoie aucune attaque.
- **Scan actif (facultatif)** : build avec le paramètre `ZAP_ACTIVE_SCAN` coché. ZAP envoie de vraies charges d'attaque (XSS, injections). À réserver au **staging**, jamais à la production.
- **Rapports** : `zap-report/zap-report.html` et `zap-report.json`, archivés comme artefacts du build.
- **Mode observation** : l'option `-I` empêche les warnings de faire échouer le build. Seule une erreur de ZAP (code 3, par exemple cible injoignable) fait échouer le stage.

| Code de sortie ZAP | Signification | Effet sur le build |
|---|---|---|
| 0 | Aucune alerte | OK |
| 1 | Alerte de niveau FAIL | OK en mode observation |
| 2 | Warnings | OK en mode observation |
| 3 | Erreur ZAP | Échec |

## Lancer ZAP à la main (atelier)

Staging démarré par le pipeline (conteneur `devsecops-staging`), depuis un terminal bash ou WSL à la racine du projet :

```bash
mkdir -p zap-wrk && chmod 777 zap-wrk

docker run --rm --network devsecops --user root \
  -v "$(pwd)/zap-wrk:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t http://devsecops-staging:3000 -r zap-report.html -I
```

Sous PowerShell, remplacer `$(pwd)` par `${PWD}`. Ouvrir ensuite `zap-wrk/zap-report.html` dans un navigateur.

## Lire le rapport

Le rapport classe les alertes par niveau de risque (High, Medium, Low, Informational). Pour chaque alerte, il indique les URL concernées, une description et une solution. Alertes typiques sur cette application :

| Alerte ZAP | Risque | Correctif |
|---|---|---|
| Content Security Policy (CSP) Header Not Set | une XSS est plus facile à exploiter | en-tête `Content-Security-Policy` |
| Missing Anti-clickjacking Header | l'application peut être affichée dans une iframe piégée | `X-Frame-Options` ou `frame-ancestors` |
| X-Content-Type-Options Header Missing | interprétation incorrecte du type de contenu par le navigateur | `X-Content-Type-Options: nosniff` |
| Server Leaks Information via "X-Powered-By" | le serveur révèle sa technologie, ce qui aide un attaquant | désactiver l'en-tête (`poweredByHeader: false`) |
| Permissions Policy Header Not Set | accès non restreint aux API du navigateur (caméra, micro...) | en-tête `Permissions-Policy` |
| Cookie No HttpOnly Flag / Cookie without Secure Flag | vol du cookie par XSS, ou interception en clair | `httpOnly: true`, `secure: true` |

Les alertes exactes dépendent de la version de ZAP et de celle de Next.js : se fier au rapport généré.

### À propos des cookies

Le scan baseline ne soumet pas de formulaire et ne s'authentifie pas. Le cookie `session` n'est posé que par `POST /api/login` (appel JSON déclenché par du JavaScript), donc ZAP ne le voit pas en mode passif. Pour vérifier les attributs du cookie, deux possibilités :

- à la main : `curl -i -X POST http://localhost:3001/api/login -H "Content-Type: application/json" -d '{"username":"admin","password":"x"}'` et lire l'en-tête `Set-Cookie` ;
- avec ZAP en mode manuel (proxy ou HUD) en se connectant depuis le navigateur, ou avec un scan authentifié.

## Scan actif

Le scan actif (`zap-full-scan.py`) ajoute des attaques aux requêtes découvertes. Pour le lancer depuis Jenkins : *Build with Parameters* et cocher `ZAP_ACTIVE_SCAN`. Il est plus long (plusieurs minutes).

ZAP ne trouve que ce que son spider atteint. Les liens `/api/ping?host=...` et `/api/file?name=...` de la page d'accueil sont explorés, mais les appels faits uniquement en JavaScript (login, recherche) ne le sont pas.

Pour voir ZAP détecter de vraies injections, il faut le lancer sur l'état **vulnérable** du code. Comme le pipeline s'arrête au SAST sur cette version, le faire à la main (branche `vulnerable`) :

```bash
git checkout vulnerable
docker build -t devsecops-app:vuln .
docker run -d --name vuln-app --network devsecops devsecops-app:vuln

mkdir -p zap-wrk && chmod 777 zap-wrk
docker run --rm --network devsecops --user root \
  -v "$(pwd)/zap-wrk:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-full-scan.py -t http://vuln-app:3000 -r zap-full.html -I

docker rm -f vuln-app
```

## Corrections appliquées

Ajout des en-têtes de sécurité et suppression de `X-Powered-By` dans `next.config.js` :

```js
const nextConfig = {
  // ... options existantes (serverExternalPackages, etc.)
  poweredByHeader: false,
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
          {
            key: 'Content-Security-Policy',
            value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'none'",
          },
        ],
      },
    ];
  },
};
```

`'unsafe-inline'` reste nécessaire pour les scripts de Next.js sans configuration de nonces : ZAP signale donc encore une alerte de niveau moyen sur la CSP. C'est un bon point de discussion.

## Avant / après

**Avant** : alertes sur les en-têtes manquants.

![ZAP avant](screenshots/zap-before.png)

**Après** : en-têtes ajoutés, alertes correspondantes disparues.

![ZAP après](screenshots/zap-after.png)

## Passer en mode bloquant

En mode observation, un warning ne casse pas le build. Pour faire échouer le build sur certaines règles, ZAP lit un fichier de configuration (`-c`) où chaque règle est classée `IGNORE`, `WARN` ou `FAIL`. Le générer avec l'option `-g`, passer les règles voulues en `FAIL` (par exemple les cookies et la CSP), puis le fournir à ZAP avec `-c` en retirant `-I`.

## Discussion : le DAST dans un pipeline CI/CD

- **Complémentarité** : le DAST trouve ce que le SAST ne voit pas (configuration, en-têtes, comportement réel) et inversement. Aucun outil ne suffit seul.
- **Où le placer** : après le déploiement sur un environnement de test, jamais avant (il faut une application qui tourne).
- **Baseline à chaque build, scan actif à la demande ou la nuit** : le passif est rapide et sans risque ; l'actif est lent et envoie de vraies attaques.
- **Jamais en production** : un scan actif peut créer des données, déclencher des alertes ou dégrader le service. Utiliser un environnement jetable ou de pré-production.
- **Couverture limitée** : ZAP ne teste que ce qu'il découvre. Les parcours derrière une authentification ou accessibles seulement en JavaScript demandent une configuration (contexte, utilisateur, import OpenAPI).
- **Faux positifs** : trier les résultats, puis classer en `IGNORE` les alertes justifiées plutôt que de laisser un rapport bruyant que personne ne lit.
- **Durcir progressivement** : observation d'abord, puis blocage sur les alertes critiques, comme pour le SAST. Un seuil trop strict dès le départ fait désactiver l'outil.
- **Rapport comme preuve** : archiver le rapport HTML pour chaque build permet de suivre l'évolution et de justifier les décisions.