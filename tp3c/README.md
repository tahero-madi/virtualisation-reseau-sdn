# TP3-C — La politique comme du code

**Jour 2, 11:32 · 18 min.** Objectif : décrire la politique des zones dans un fichier YAML versionné et l'appliquer par script. Support : chapitres 9 à 12.

Décrire la connectivité des zones dans un fichier YAML versionné et l'appliquer par script. Correspondance : h1 dev, h2 recette, h3 prod, h4 admin.

`politique.yaml` :

```yaml
autorisations:                    # chaque entrée = une connexion autorisée (traduite en intention hôte-à-hôte)
  - nom: dev-vers-recette
    de: "00:00:00:00:00:01"       # MAC de h1 (dev)
    vers: "00:00:00:00:00:02"     # MAC de h2 (recette)
  - nom: admin-vers-recette
    de: "00:00:00:00:00:04"       # h4 (admin)
    vers: "00:00:00:00:00:02"     # h2 (recette)
  - nom: admin-vers-prod
    de: "00:00:00:00:00:04"       # h4 (admin)
    vers: "00:00:00:00:00:03"     # h3 (prod)
```

1. Retirez les intentions du TP3-B : listez-les, puis supprimez-les par clé.

```bash
curl -s -u onos:rocks http://localhost:8181/onos/v1/intents \                 # liste les intentions existantes...
  | jq -r '.intents[] | "\(.appId) \(.key) \(.state)"'                        # ...avec leur application, leur clé et leur état
curl -s -u onos:rocks -X DELETE http://localhost:8181/onos/v1/intents/org.onosproject.cli/<clé>   # en supprime une par sa clé
```

2. Appliquez la politique : `python3 apply_policy.py politique.yaml`.
3. Vérifiez avec `pingall` quelles paires répondent, et comparez au fichier.
4. Commitez `politique.yaml` et le script.

Pour aller plus loin : rendez le script idempotent en supprimant les intentions absentes du fichier, puis esquissez le pipeline GitLab CI qui enchaînerait validation, test et application (chapitre 12).
