# TP4-A — Programmer un switch à la main

**Jour 2, 13:50 · 45 min.** Objectif : programmer la politique d'un switch règle par règle, en OpenFlow, sans contrôleur. Support : chapitres 14 à 17.

Correspondance : h1 serveur prod (10.0.0.1), h2 poste dev (10.0.0.2), h3 poste recette (10.0.0.3).

```bash
sudo docker stop onos; sudo mn -c
sudo mn --topo single,3 --mac --switch ovs,protocols=OpenFlow13 --controller none
mininet> pingall
```

Dans un second terminal :

```bash
OF="sudo ovs-ofctl -O OpenFlow13"
sudo ovs-vsctl get-fail-mode s1

# 1. Connectivité de base : ARP diffusé, IPv4 livré selon la destination
$OF add-flow s1 "priority=100,arp,actions=flood"
$OF add-flow s1 "priority=100,ip,nw_dst=10.0.0.1,actions=output:1"
$OF add-flow s1 "priority=100,ip,nw_dst=10.0.0.2,actions=output:2"
$OF add-flow s1 "priority=100,ip,nw_dst=10.0.0.3,actions=output:3"
$OF dump-flows s1
```

```bash
# 2. Politique : la recette ne pingue pas la prod ; le dev n'accède à la recette qu'en HTTP
$OF add-flow s1 "priority=200,icmp,nw_src=10.0.0.3,nw_dst=10.0.0.1,actions=drop"
$OF add-flow s1 "priority=300,tcp,nw_src=10.0.0.2,nw_dst=10.0.0.3,tp_dst=80,actions=output:3"
$OF add-flow s1 "priority=250,ip,nw_src=10.0.0.2,nw_dst=10.0.0.3,actions=drop"
```

```text
mininet> h3 ping -c 2 h1
mininet> h2 ping -c 2 h1
mininet> h3 python3 -m http.server 80 &
mininet> h2 curl -s -m 3 -o /dev/null -w "%{http_code}\n" http://10.0.0.3/
mininet> h2 ping -c 2 h3
mininet> h1 ping -c 2 h3
```

```bash
# 3. Expliquer un comportement
sudo ovs-appctl ofproto/trace s1 in_port=3,icmp,nw_src=10.0.0.3,nw_dst=10.0.0.1

# 4. Limiter un débit : 5 Mbit/s de h1 vers h2
$OF add-meter s1 meter=1,kbps,band=type=drop,rate=5000
$OF add-flow s1 "priority=150,ip,nw_src=10.0.0.1,nw_dst=10.0.0.2,actions=meter:1,output:2"
$OF dump-meters s1
```

```text
mininet> iperf h1 h2
```

```bash
# 5. Bonus : copier le trafic destiné à h1 vers h3 avec un groupe « all »
$OF add-group s1 group_id=1,type=all,bucket=output:1,bucket=output:3
$OF --strict mod-flows s1 "priority=100,ip,nw_dst=10.0.0.1,actions=group:1"
$OF dump-ports s1 3
```

Questions :

1. Pourquoi `pingall` échoue-t-il au départ ? Que répond `get-fail-mode` ?
2. Notez le résultat de chaque test de l'étape 2. Pourquoi h1 ne peut-il plus pinguer h3, alors que seule la recette vers la prod est interdite ? Corrigez avec `icmp_type=8`.
3. Que lit-on dans la sortie de `ofproto/trace` ?
4. Quel débit mesure `iperf` avant et après le meter ?
5. Comment rejouer toute la configuration d'un coup ? (indice : `add-flows` et `replace-flows` lisent un fichier)

Livrable : `regles_tp4a.txt` rejouable par `replace-flows`, commité.
