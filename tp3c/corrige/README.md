# Corrigé du TP3-C

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Résultat attendu

`politique.yaml` déclare trois autorisations, traduites en intentions hôte-à-hôte (bidirectionnelles) :

| Autorisation | Hôtes | Pingent après application |
| --- | --- | --- |
| dev-vers-recette | h1 ↔ h2 | oui |
| admin-vers-recette | h4 ↔ h2 | oui |
| admin-vers-prod | h4 ↔ h3 | oui |

`pingall` montre donc **trois paires qui répondent** (h1-h2, h2-h4, h3-h4) et toutes les autres en échec (h1-h3, h1-h4, h2-h3). C'est l'image fidèle du fichier : la connectivité est exactement ce qui est écrit, rien de plus.

Retrait des intentions du TP3-B, avant d'appliquer :

```bash
curl -s -u onos:rocks http://localhost:8181/onos/v1/intents \
  | jq -r '.intents[] | "\(.appId) \(.key)"'
# puis, pour chaque clé de org.onosproject.cli :
curl -s -u onos:rocks -X DELETE http://localhost:8181/onos/v1/intents/org.onosproject.cli/<clé>
```

## Pour aller plus loin

- **Rendre le script idempotent** : lister les intentions existantes, supprimer celles qui ne sont plus dans `politique.yaml`, ajouter celles qui manquent — pour que rejouer le script converge vers l'état décrit, sans doublon.
- **Pipeline GitLab CI** (chapitre 12) : `valider` (schéma du YAML) → `tester` (appliquer dans un lab jetable et vérifier `pingall`) → `appliquer` (sur la branche principale, par l'API REST). Les identifiants du contrôleur passent par des variables protégées et masquées, jamais dans le dépôt. Le dépôt devient la source de vérité : ce qui est fusionné est, par définition, ce qui tourne.

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
