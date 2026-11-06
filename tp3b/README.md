# TP3-B — Intentions et résilience

**Jour 2, 10:52 · 40 min.** Objectif : exprimer la connectivité par des intentions et observer leur maintien pendant une panne. Support : chapitres 9 à 12.

Remplacer l'acheminement automatique par une politique explicite, puis constater que le contrôleur la maintient pendant une panne.

```text
onos> app deactivate org.onosproject.fwd                              # coupe le routage automatique : plus rien n'est acheminé
mininet> pingall                                                     # tout échoue désormais (aucune règle posée)
onos> add-host-intent 00:00:00:00:00:01/None 00:00:00:00:00:03/None  # déclare l'intention « h1 doit joindre h3 »
onos> intents                                                        # liste les intentions et leur état (INSTALLED)
mininet> h1 ping -c 3 h3                                             # h1 -> h3 : passe grâce à l'intention
mininet> h1 ping -c 3 h2                                             # h1 -> h2 : échoue, aucune intention pour cette paire
onos> paths of:0000000000000001 of:0000000000000003                 # chemins calculés par ONOS entre s1 et s3
```

Provoquer des pannes :

```text
mininet> link s1 s2 down     # coupe un lien de l'anneau
mininet> h1 ping -c 3 h3     # passe encore : ONOS a recalculé par l'autre côté
mininet> link s1 s4 down     # coupe le second chemin : s1 est isolé
onos> intents                # l'intention passe à FAILED (plus aucun chemin possible)
mininet> link s1 s4 up       # on rétablit un lien
mininet> h1 ping -c 3 h3     # repasse : l'intention est réinstallée toute seule
```

La même intention par l'API nord :

```bash
curl -s -u onos:rocks -X POST -H 'Content-Type: application/json' \   # même intention, mais par l'API REST : h2 <-> h4
  http://localhost:8181/onos/v1/intents -d '{
    "type": "HostToHostIntent", "appId": "org.onosproject.cli", "priority": 100,
    "one": "00:00:00:00:00:02/None", "two": "00:00:00:00:00:04/None"}'
```

Questions :

1. Notez le résultat de chaque commande. Quel est l'état de l'intention après la seconde panne ? Après le rétablissement ?
2. Quelle différence y a-t-il entre installer un flux et déclarer une intention ?
3. Que se passerait-il, sur la même panne, avec des règles posées à la main ?
4. Sur l'anneau, ARP fonctionne sans l'application `fwd` : quelle application répond à sa place ?
