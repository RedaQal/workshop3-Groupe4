# SCA : OWASP Dependency-Check

Le SAST analyse notre code. Dependency-Check analyse les **dépendances** (npm) et signale celles qui ont des vulnérabilités connues (CVE).

## Fonctionnement

- Stage `SCA` placé après `SAST` et avant `Docker Build`.
- Outil : Dependency-Check CLI, installé dans l'image Jenkins.
- Base de vulnérabilités : NVD (NIST), téléchargée au premier build puis conservée dans le volume `jenkins_home`.
- Seuil : le build échoue si une dépendance a une CVE de score CVSS >= 7 (High / Critical).
- Rapports : `dependency-check-report/` (HTML et JSON), archivés comme artefacts du build.
- Périmètre : tout le dépôt sauf `node_modules`, `.next` et les dossiers de rapports (trop lent sinon). L'analyseur Sonatype OSS Index est désactivé (`--disableOssIndex`) car il échoue sans authentification.

## Prérequis (une seule fois, par l'administrateur Jenkins)

1. Demander une clé API gratuite : https://nvd.nist.gov/developers/request-an-api-key (reçue par e-mail).
2. Jenkins > *Manage Jenkins > Credentials > Global > Add Credentials*
   - Kind : **Secret text**
   - Secret : la clé NVD
   - ID : **`nvd-api-key`**
3. Reconstruire l'image Jenkins :
```bash
   docker compose build jenkins
   docker compose up -d jenkins
   docker exec jenkins dependency-check.sh --version
```

> Sans clé NVD, le téléchargement est très limité et le premier build peut échouer ou durer des heures. Avec une clé, prévoir 10 à 20 minutes au premier build. Les suivants sont rapides.

## Avant / après

Le projet utilise volontairement `next@14.2.15`, qui contient des vulnérabilités connues.

- **Avant** : le stage `SCA` échoue (CVE High / Critical sur `next`).
- **Correction** : `npm install next@14`, puis commit de `package.json` et `package-lock.json`.
- **Après** : le stage `SCA` passe et le build continue jusqu'au staging.

Captures : `docs/screenshots/sca-before.png` et `docs/screenshots/sca-after.png`.

![SCA avant](screenshots/sca-before.png)
![SCA après](screenshots/sca-after.png)