# TP4-A — Programmer un switch à la main

**Jour 2, 13:50 · 45 min.** Objectif : programmer la politique d'un switch règle par règle, en OpenFlow, sans contrôleur. Support : chapitres 14 à 17.

Correspondance : h1 serveur prod (10.0.0.1), h2 poste dev (10.0.0.2), h3 poste recette (10.0.0.3).

```bash
sudo docker stop onos; sudo mn -c                                                   # arrête ONOS (libère le port) et nettoie Mininet
sudo mn --topo single,3 --mac --switch ovs,protocols=OpenFlow13 --controller none   # 1 switch, 3 hôtes, SANS contrôleur
mininet> pingall                                                                    # échoue : sans contrôleur ni règles, le switch ne livre rien
```

Dans un second terminal :

```bash
OF="sudo ovs-ofctl -O OpenFlow13"            # raccourci pour parler au switch en OpenFlow 1.3
sudo ovs-vsctl get-fail-mode s1              # mode du switch privé de contrôleur : « secure » = il ne fait rien

# 1. Connectivité de base : ARP diffusé, IPv4 livré selon la destination
$OF add-flow s1 "priority=100,arp,actions=flood"                   # l'ARP est diffusé sur tous les ports
$OF add-flow s1 "priority=100,ip,nw_dst=10.0.0.1,actions=output:1" # ce qui va vers h1 sort au port 1
$OF add-flow s1 "priority=100,ip,nw_dst=10.0.0.2,actions=output:2" # vers h2 -> port 2
$OF add-flow s1 "priority=100,ip,nw_dst=10.0.0.3,actions=output:3" # vers h3 -> port 3
$OF dump-flows s1                                                  # affiche les règles posées et leurs compteurs
```

```bash
# 2. Politique : la recette ne pingue pas la prod ; le dev n'accède à la recette qu'en HTTP
$OF add-flow s1 "priority=200,icmp,nw_src=10.0.0.3,nw_dst=10.0.0.1,actions=drop"               # jette le ping recette -> prod
$OF add-flow s1 "priority=300,tcp,nw_src=10.0.0.2,nw_dst=10.0.0.3,tp_dst=80,actions=output:3"  # dev -> recette en HTTP : autorisé (priorité la plus haute)
$OF add-flow s1 "priority=250,ip,nw_src=10.0.0.2,nw_dst=10.0.0.3,actions=drop"                 # dev -> recette, tout le reste : jeté
```

```text
mininet> h3 ping -c 2 h1                                                      # recette -> prod : bloqué
mininet> h2 ping -c 2 h1                                                      # dev -> prod : aucune règle ne le bloque, passe
mininet> h3 python3 -m http.server 80 &                                      # serveur web sur h3 (recette)
mininet> h2 curl -s -m 3 -o /dev/null -w "%{http_code}\n" http://10.0.0.3/   # dev -> recette en HTTP : 200
mininet> h2 ping -c 2 h3                                                      # dev -> recette hors HTTP : bloqué
mininet> h1 ping -c 2 h3                                                      # prod -> recette : voir question 2 (la réponse est jetée)
```

```bash
# 3. Expliquer un comportement
sudo ovs-appctl ofproto/trace s1 in_port=3,icmp,nw_src=10.0.0.3,nw_dst=10.0.0.1   # simule un paquet et montre la règle qui s'applique

# 4. Limiter un débit : 5 Mbit/s de h1 vers h2
$OF add-meter s1 meter=1,kbps,band=type=drop,rate=5000                                       # crée un compteur qui jette au-delà de 5000 kbps
$OF add-flow s1 "priority=150,ip,nw_src=10.0.0.1,nw_dst=10.0.0.2,actions=meter:1,output:2"   # applique ce meter au flux h1 -> h2
$OF dump-meters s1                                                                           # affiche les meters et leurs compteurs
```

```text
mininet> iperf h1 h2    # mesure le débit h1 <-> h2 : plafonné à ~5 Mbit/s par le meter
```

```bash
# 5. Bonus : copier le trafic destiné à h1 vers h3 avec un groupe « all »
$OF add-group s1 group_id=1,type=all,bucket=output:1,bucket=output:3          # groupe « all » : duplique vers le port 1 ET le port 3
$OF --strict mod-flows s1 "priority=100,ip,nw_dst=10.0.0.1,actions=group:1"   # ce qui va vers h1 passe désormais par ce groupe
$OF dump-ports s1 3                                                           # compteurs du port 3 : ils montent (il reçoit la copie)
```

Questions :

1. Pourquoi `pingall` échoue-t-il au départ ? Que répond `get-fail-mode` ?
2. Notez le résultat de chaque test de l'étape 2. Pourquoi h1 ne peut-il plus pinguer h3, alors que seule la recette vers la prod est interdite ? Corrigez avec `icmp_type=8`.
3. Que lit-on dans la sortie de `ofproto/trace` ?
4. Quel débit mesure `iperf` avant et après le meter ?
5. Comment rejouer toute la configuration d'un coup ? (indice : `add-flows` et `replace-flows` lisent un fichier)

Livrable : `regles_tp4a.txt` rejouable par `replace-flows`, commité.
