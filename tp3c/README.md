# TP3-C — La politique comme du code

**Jour 2, 11:32 · 18 min.** Objectif : décrire la politique des zones dans un fichier YAML versionné et l'appliquer par script. Support : chapitres 9 à 12.

Décrire la connectivité des zones dans un fichier versionné, puis l'appliquer par un script qui appelle l'API REST d'ONOS. Correspondance : h1 dev, h2 recette, h3 prod, h4 admin.

### Étape 1 — Faire le ménage : supprimer les intentions du TP3-B

Avant de partir d'une politique propre, on **retire les intentions** posées à la main au TP précédent, sinon elles se cumuleraient avec celles qu'on va appliquer.

```bash
curl -s -u onos:rocks http://localhost:8181/onos/v1/intents \
  | jq -r '.intents[] | "\(.appId) \(.key) \(.state)"'
curl -s -u onos:rocks -X DELETE http://localhost:8181/onos/v1/intents/org.onosproject.cli/<clé>
```

**Ligne par ligne.**

- premier `curl … | jq` : liste les intentions existantes avec leur application (`appId`), leur **clé** (`key`) et leur état.
- second `curl -X DELETE …/intents/org.onosproject.cli/<clé>` : supprime une intention par sa clé. Reprenez chaque clé affichée par la commande précédente.

### Étape 2 — Le fichier de politique

```yaml
autorisations:
  - nom: dev-vers-recette
    de: "00:00:00:00:00:01"
    vers: "00:00:00:00:00:02"
  - nom: admin-vers-recette
    de: "00:00:00:00:00:04"
    vers: "00:00:00:00:00:02"
  - nom: admin-vers-prod
    de: "00:00:00:00:00:04"
    vers: "00:00:00:00:00:03"
```

**Ce que décrit `politique.yaml`.** C'est la politique de connectivité exprimée en texte, lisible et versionnable. Sous `autorisations`, chaque entrée est **une connexion autorisée**, décrite par identités (adresses MAC) plutôt que par des règles d'équipement :

- `dev-vers-recette` : h1 (dev, `…:01`) peut joindre h2 (recette, `…:02`).
- `admin-vers-recette` : h4 (admin, `…:04`) peut joindre h2 (recette).
- `admin-vers-prod` : h4 (admin) peut joindre h3 (prod, `…:03`).

Tout ce qui n'est pas listé n'est pas autorisé. Ce fichier est la **source de vérité** : pour changer la politique, on modifie le fichier, pas les équipements.

### Étape 3 — Appliquer la politique par script

```bash
python3 apply_policy.py politique.yaml
```

**Ce que fait `apply_policy.py`.** Le script lit le fichier YAML et, pour **chaque** autorisation, crée une `HostToHostIntent` via l'API REST nord d'ONOS (un `POST` sur `/onos/v1/intents`). Autrement dit, il transforme chaque ligne de politique en une intention, et affiche le code HTTP renvoyé par ONOS — vous devez obtenir **HTTP 201** (créé) pour chaque règle.

### Étape 4 — Vérifier

```bash
mininet> pingall
```

Comparez les paires qui répondent à ce que décrit le fichier : seules `h1↔h2`, `h2↔h4` et `h3↔h4` doivent passer. Vous venez de réaliser à la main les étapes « décrire » et « appliquer » d'un pipeline GitOps réseau.

> Le fichier `politique.yaml` et le script sont déjà dans ce dépôt : rien à committer, ils font partie du kit du TP.

Pour aller plus loin : rendez le script **idempotent** en supprimant les intentions absentes du fichier (le principe de réconciliation d'ArgoCD ou de Flux, appliqué au réseau), puis esquissez le pipeline GitLab CI qui enchaînerait validation, test et application (chapitre 12).
