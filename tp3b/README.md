# TP3-B — Intentions et résilience

**Jour 2, 10:52 · 40 min.** Objectif : exprimer la connectivité par des intentions et observer leur maintien pendant une panne. Support : chapitres 9 à 12.

Remplacer l'acheminement automatique par une politique explicite, puis constater que le contrôleur la maintient pendant une panne.

```text
onos> app deactivate org.onosproject.fwd
mininet> pingall
onos> add-host-intent 00:00:00:00:00:01/None 00:00:00:00:00:03/None
onos> intents
mininet> h1 ping -c 3 h3
mininet> h1 ping -c 3 h2
onos> paths of:0000000000000001 of:0000000000000003
```

Provoquer des pannes :

```text
mininet> link s1 s2 down
mininet> h1 ping -c 3 h3
mininet> link s1 s4 down
onos> intents
mininet> link s1 s4 up
mininet> h1 ping -c 3 h3
```

La même intention par l'API nord :

```bash
curl -s -u onos:rocks -X POST -H 'Content-Type: application/json' \
  http://localhost:8181/onos/v1/intents -d '{
    "type": "HostToHostIntent", "appId": "org.onosproject.cli", "priority": 100,
    "one": "00:00:00:00:00:02/None", "two": "00:00:00:00:00:04/None"}'
```

Questions :

1. Notez le résultat de chaque commande. Quel est l'état de l'intention après la seconde panne ? Après le rétablissement ?
2. Quelle différence y a-t-il entre installer un flux et déclarer une intention ?
3. Que se passerait-il, sur la même panne, avec des règles posées à la main ?
4. Sur l'anneau, ARP fonctionne sans l'application `fwd` : quelle application répond à sa place ?
