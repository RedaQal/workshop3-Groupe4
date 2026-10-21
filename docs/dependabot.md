\# Dependabot



Dependabot surveille les dépendances et ouvre automatiquement des Pull Requests de mise à jour. Il ne tourne \*\*pas\*\* dans Jenkins : c'est une fonctionnalité de GitHub.



\## Fonctionnement



\- Configuration : `.github/dependabot.yml` (npm à la racine, Dockerfile de l'app, Dockerfile Jenkins).

\- Fréquence : hebdomadaire, 5 PR npm ouvertes au maximum.

\- Complémentarité avec Dependency-Check : Dependency-Check \*\*détecte et bloque\*\* dans le pipeline, Dependabot \*\*propose le correctif\*\* sous forme de PR.



\## Activation (une seule fois, par un admin du dépôt)



GitHub > \*Settings > Code security\* :

\- activer \*\*Dependabot alerts\*\*

\- activer \*\*Dependabot security updates\*\*



> Dependabot lit sa configuration sur la branche par défaut. Il ne démarre donc qu'\*\*après le merge\*\* de cette configuration dans `main`.



\## Intégration avec Jenkins (facultatif)



Pour que chaque PR Dependabot déclenche le pipeline :

1\. Utiliser un job \*\*Multibranch Pipeline\*\* (sources de branches GitHub).

2\. Configurer un webhook GitHub vers `http://<jenkins>/github-webhook/`. Jenkins étant en local, exposer le port 8080 avec un tunnel (ngrok, cloudflared). Sans webhook, utiliser le scan périodique des branches.



> Dependabot nécessite un dépôt GitHub. Avec GitLab ou Gitea, utiliser Renovate.

