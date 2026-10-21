# Dependabot

Dependabot surveille les dépendances et ouvre automatiquement des Pull Requests de mise à jour. Il ne tourne **pas** dans Jenkins : c'est une fonctionnalité de GitHub.

## Fonctionnement

- Configuration : `.github/dependabot.yml` (npm à la racine, Dockerfile de l'app, Dockerfile Jenkins).
- Fréquence : hebdomadaire, 5 PR npm ouvertes au maximum.
- Cooldown : 7 jours avant de proposer une version fraîchement publiée (protection contre les paquets compromis ou instables). Les mises à jour de **sécurité** ne sont pas retardées.
- Complémentarité avec Dependency-Check : Dependency-Check **détecte et bloque** dans le pipeline, Dependabot **propose le correctif** sous forme de PR, et le pipeline vérifie cette PR avant le merge.

## Configuration

```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    cooldown:
      default-days: 7
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    cooldown:
      default-days: 7
    ignore:
      - dependency-name: "node"
        update-types: ["version-update:semver-major"]
  - package-ecosystem: "docker"
    directory: "/jenkins"
    schedule:
      interval: "weekly"
    cooldown:
      default-days: 7
```

- La règle `ignore` empêche Dependabot de proposer de nouvelles versions **majeures** de l'image Node. Le changement de version majeure se fait à la main, sur une version LTS, en même temps dans `Dockerfile` et `jenkins/Dockerfile`.
- Le `cooldown` est exigé par Semgrep (règle `dependabot-missing-cooldown`), qui analyse aussi ce fichier.

## Activation (une seule fois, par un admin du dépôt)

GitHub > *Settings > Code security* :
- activer **Dependabot alerts**
- activer **Dependabot security updates**

> Dependabot lit sa configuration sur la branche par défaut. Il ne démarre donc qu'**après le merge** de cette configuration dans `main`.

## Exemple de Pull Requests générées

![Pull Requests Dependabot](screenshots/dependabot-prs.png)

Dependabot a ouvert 7 PR dès l'activation. Toutes ne sont pas à merger telles quelles :

| PR | Mise à jour | Décision |
|---|---|---|
| #1 | `postcss` et `next` | Remplacée par #5 |
| #2 | `next` 14.2.15 vers 15.5.27 | Fermée (même dépendance que #5) |
| #5 | `next` 14.2.15 vers 16.4.2 | **Mergée** |
| #6 et #7 | `react-dom` et `react` 18.3.1 vers 19.3.1 | **Mergées** (les deux doivent avoir la même version majeure) |
| #8 | `better-sqlite3` 11.10.0 vers 13.0.3 | **Mergée** (impose Node >= 22) |
| #4 | image `node` 20 vers 25 | **Refusée** : Node 25 n'est pas une version LTS. Passage manuel à Node 22. |

## Bonnes pratiques

- **Toujours exécuter le pipeline sur la PR avant de merger.** Un build rouge signale une mise à jour qui casse le projet : c'était le cas de `better-sqlite3` 13, qui exige Node 22 et se compile à l'installation.
- **Plusieurs PR sur la même dépendance** (ici `next`) : en merger une, fermer l'autre.
- **Dépendances liées** (`react` et `react-dom`) : les merger ensemble, car une version majeure différente casse l'application.
- **En cas de conflit sur une PR**, commenter `@dependabot rebase` plutôt que de résoudre le `package-lock.json` à la main.
- **Refuser une version majeure non voulue** : commenter `@dependabot ignore this major version`, puis ajouter une règle `ignore` dans la configuration.

## Intégration avec Jenkins (facultatif)

Pour que chaque PR Dependabot déclenche le pipeline :

1. Utiliser un job **Multibranch Pipeline** (sources de branches GitHub).
2. Configurer un webhook GitHub vers `http://<jenkins>/github-webhook/`. Jenkins étant en local, exposer le port 8080 avec un tunnel (ngrok, cloudflared). Sans webhook, utiliser le scan périodique des branches.

> Dependabot nécessite un dépôt GitHub. Avec GitLab ou Gitea, utiliser Renovate.