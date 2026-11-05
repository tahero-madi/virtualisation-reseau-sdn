# TP4 — Programmer en OpenFlow

Objectif : construire la politique d'un switch règle par règle, puis la confier à une application Python, avant une mise en situation notée. Chapitres 14 à 17. Durée indicative : 1 h 10, puis 30 minutes de mise en situation.

## TP4-A — Programmer un switch à la main

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

## TP4-B — Une application de contrôle en Python

Remplacer les règles manuelles par l'application [`switch_acl.py`](../kit/switch_acl.py) : elle apprend les adresses MAC (mode réactif) et pose la politique au branchement du switch (mode proactif).

```bash
# Terminal 1 : le contrôleur (port 6653 libre : ONOS arrêté)
~/osken/bin/python lancer_controleur.py switch_acl.py

# Terminal 2 : capture du dialogue OpenFlow, puis topologie
sudo tcpdump -i lo -w of.pcap tcp port 6653 &
sudo mn -c
sudo mn --topo single,3 --mac --switch ovs,protocols=OpenFlow13 \
        --controller remote,ip=127.0.0.1,port=6653
mininet> pingall

# Après la sortie de Mininet
sudo pkill tcpdump
tshark -r of.pcap -Y openflow_v4 -T fields -e openflow_v4.type | sort | uniq -c
```

Questions :

1. Quelles paires échouent au `pingall`, et pourquoi ?
2. Quels types de messages compte tshark ? Faites le lien avec le chapitre 16.
3. Combien de règles `dump-flows` montre-t-il après `pingall`, et avec quelles priorités ?

Exercices, au choix :

1. N'interdire que les requêtes ICMP de h3 vers h1 : `OFPMatch(eth_type=0x0800, ip_proto=1, icmpv4_type=8, ipv4_src=..., ipv4_dst=...)`.
2. Charger la liste `DENY` depuis un fichier YAML versionné.
3. Journaliser chaque nouvelle adresse MAC apprise avec son port.
4. Ajouter le module de statistiques du chapitre 17 et lancer les deux applications ensemble.

Avec Ryu au lieu d'os-ken : remplacer `os_ken` par `ryu`, `OSKenApp` par `RyuApp`, et lancer avec `ryu-manager`.

## Mise en situation finale (30 min, individuelle)

Le chef de projet ouvre une demande de changement sur le switch s1 :

```bash
sudo mn --topo single,4 --mac --switch ovs,protocols=OpenFlow13 --controller none
```

h1 est le serveur prod, h2 le poste dev, h3 le poste recette, h4 une sonde de détection d'intrusion.

1. La recette (h3) n'accède au serveur prod (h1) qu'en TCP 443.
2. Tout le trafic destiné au serveur prod est copié vers la sonde (h4).
3. Le flux de sauvegarde dev vers prod (h2 vers h1) est limité à 10 Mbit/s.
4. La configuration est livrée sous forme de fichier rejouable par `replace-flows` et commitée.
5. Chaque point est prouvé : test, compteurs ou `ofproto/trace`.

| Critère d'évaluation | Points |
| --- | --- |
| Filtrage recette vers prod, prouvé par test | 5 |
| Copie vers la sonde, prouvée par compteurs | 4 |
| Limitation de débit, prouvée par `iperf` | 4 |
| Configuration rejouable et commitée | 4 |
| Parcours d'un paquet expliqué avec `ofproto/trace` | 3 |

Acquis à partir de 12/20, avec les critères 1 et 4 atteints. `ovs-ofctl` seul suffit ; une application os-ken est un plus.

---

[← TP3](tp3-controleur-onos.md) · [Sommaire](../README.md) · [Dépannage →](depannage.md)
