# TP3-B — Intentions et résilience

**Jour 2, 10:52 · 40 min.** Objectif : exprimer la connectivité par des intentions et observer leur maintien pendant une panne. Support : chapitres 9 à 12.

On reprend le lab du TP3-A (ONOS + l'anneau de 4 switches sous Mininet). On va remplacer l'acheminement automatique par une politique explicite, puis constater que le contrôleur la maintient pendant une panne.

## Accéder à la ligne de commande d'ONOS

Les commandes `onos>` se tapent dans la **CLI d'ONOS**, qu'on ouvre de deux façons :

- **En SSH** (recommandé), depuis un terminal de lab-a :

  ```bash
  ssh -p 8101 onos@localhost      # mot de passe : rocks
  ```

- **Par l'interface web** : `http://localhost:8181/onos/ui`, menu, section *« Application / CLI »* — la même console, dans le navigateur.

Les commandes `mininet>`, elles, se tapent dans la console Mininet (le terminal où tourne `sudo mn …`). Gardez donc **deux terminaux** ouverts : l'un sur la CLI ONOS, l'autre sur Mininet.

## Ce qu'est une intention

Un **flux** dit *comment* faire : « pose telle règle sur s1, s4, s3 ». Si un lien de ce chemin tombe, la règle reste en place… et devient fausse. Une **intention** dit seulement *quoi* obtenir : « h1 doit pouvoir joindre h3 ». ONOS la traduit en règles, les installe, et surtout les **recalcule et réinstalle** tout seul quand la topologie change. C'est l'idée clé du module 3 appliquée.

### Étape 1 — Remplacer l'acheminement automatique par une intention

```text
onos> app deactivate org.onosproject.fwd
mininet> pingall
onos> add-host-intent 00:00:00:00:00:01/None 00:00:00:00:00:03/None
onos> intents
mininet> h1 ping -c 3 h3
mininet> h1 ping -c 3 h2
onos> paths of:0000000000000001 of:0000000000000003
```

**Ligne par ligne.**

- `app deactivate org.onosproject.fwd` : coupe l'acheminement automatique réactif. Plus aucune application ne décide pour les hôtes.
- `pingall` : tout échoue désormais, car aucune règle n'est posée.
- `add-host-intent 00:…:01/None 00:…:03/None` : déclare l'intention « h1 (MAC …:01) doit joindre h3 (MAC …:03) ». Le `/None` signifie « sans VLAN ». ONOS calcule un chemin et pose les règles sur les switches traversés.
- `intents` : liste les intentions et leur état ; l'intention doit être **INSTALLED**.
- `h1 ping -c 3 h3` : passe, grâce à l'intention.
- `h1 ping -c 3 h2` : échoue — aucune intention ne couvre cette paire.
- `paths of:0000000000000001 of:0000000000000003` : affiche les chemins que ONOS a calculés entre s1 (dpid `…0001`) et s3 (dpid `…0003`). Sur l'anneau, il en existe **deux** de même coût (par s2 ou par s4) ; la sortie montre la liste des liens de chaque chemin et son coût. C'est cette connaissance des chemins de secours qui rend l'intention résiliente.

### Étape 2 — Provoquer des pannes

```text
mininet> link s1 s2 down
mininet> h1 ping -c 3 h3
mininet> link s1 s4 down
onos> intents
mininet> link s1 s4 up
mininet> h1 ping -c 3 h3
```

**Ligne par ligne.**

- `link s1 s2 down` : coupe un lien de l'anneau.
- `h1 ping -c 3 h3` : passe encore — ONOS a recalculé par l'autre côté de l'anneau.
- `link s1 s4 down` : coupe le second chemin ; s1 est maintenant isolé.
- `intents` : l'intention passe à l'état **FAILED** (plus aucun chemin possible).
- `link s1 s4 up` : on rétablit un lien.
- `h1 ping -c 3 h3` : repasse — l'intention est **réinstallée toute seule**, sans aucune intervention.

### Étape 3 — La même intention par l'API nord

```bash
curl -s -u onos:rocks -X POST -H 'Content-Type: application/json' \
  http://localhost:8181/onos/v1/intents -d '{
    "type": "HostToHostIntent", "appId": "org.onosproject.cli", "priority": 100,
    "one": "00:00:00:00:00:02/None", "two": "00:00:00:00:00:04/None"}'
```

**Ligne par ligne.**

- un `POST` sur `/onos/v1/intents` crée la même sorte d'intention, mais **par programme** : ici une `HostToHostIntent` entre h2 (`one`) et h4 (`two`).
- tout ce que fait la CLI se fait donc aussi par l'API REST — c'est ce qui rendra possible la politique « comme du code » du TP3-C.

Questions :

1. Notez le résultat de chaque commande. Quel est l'état de l'intention après la seconde panne ? Après le rétablissement ?
2. Quelle différence y a-t-il entre installer un flux et déclarer une intention ?
3. Que se passerait-il, sur la même panne, avec des règles posées à la main ?
4. Sur l'anneau, ARP fonctionne sans l'application `fwd` : quelle application répond à sa place ?
