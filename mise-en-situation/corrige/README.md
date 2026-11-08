# Corrigé de la mise en situation finale

> Corrigé formateur. Il existe plusieurs solutions correctes : l'essentiel est que chaque exigence soit **prouvée**.

Une solution complète est dans [`regles_solution.txt`](regles_solution.txt). Elle s'appuie sur un groupe (la copie vers la sonde) et un meter (la limite de débit), à créer avant de charger les règles :

```bash
OF="sudo ovs-ofctl -O OpenFlow13"
$OF add-group s1 group_id=1,type=all,bucket=output:1,bucket=output:4   # vers h1 (prod) ET h4 (sonde)
$OF add-meter s1 meter=1,kbps,band=type=drop,rate=10000                # 10 Mbit/s
$OF replace-flows s1 regles_solution.txt
```

## Comment chaque exigence est tenue

| Exigence | Règle | Preuve attendue |
| --- | --- | --- |
| Recette (h3) → prod (h1) en TCP 443 seulement | `priority=300` accepte le TCP 443 vers `group:1` ; `priority=250` jette le reste de h3 vers h1 | `h3 curl https://h1` (443) passe ; `h3 ping h1` et un autre port échouent |
| Tout le trafic vers la prod copié vers la sonde (h4) | les paquets `nw_dst=10.0.0.1` partent vers `group:1`, qui diffuse sur les ports 1 **et** 4 | compteurs du port 4 (`dump-ports s1 4`) qui montent avec le trafic vers h1 |
| Dev (h2) → prod (h1) limité à 10 Mbit/s | `priority=200` envoie ce flux vers `meter:1` puis `group:1` | `iperf h2 h1` plafonne à ~10 Mbit/s |
| Configuration rejouable et commitée | tout est dans `regles_solution.txt`, rechargé par `replace-flows` | le fichier est versionné ; le relancer redonne le même état |
| Parcours d'un paquet expliqué | — | `ofproto/trace s1 ...` sur un paquet h3 → h1:443 montre `group:1`, sur un autre port montre `drop` |

## Points d'attention de correction

- **Le groupe `all`** est la façon propre de copier vers la sonde sans casser la livraison normale : un simple `output` en double ne suffit pas si une autre règle s'applique déjà.
- **L'ordre des priorités** compte : la règle TCP 443 (300) doit primer sur le drop de h3 → h1 (250).
- **Exercice non noté** : l'évaluation des acquis se fera par un QCM ajouté ultérieurement. Ici, l'essentiel est que chacune des cinq exigences soit réalisée **et prouvée** (test, compteurs ou `ofproto/trace`).

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
