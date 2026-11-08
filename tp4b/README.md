# TP4-B — Une application de contrôle en Python

**Jour 2, 14:50 · 25 min.** Objectif : confier la même politique à une application de contrôle écrite en Python (os-ken). Support : chapitres 14 à 17.

Au TP4-A, vous posiez les règles à la main. Ici, c'est **votre propre contrôleur** qui les pose : l'application `switch_acl.py` apprend les adresses MAC (mode réactif) et installe la politique au branchement du switch (mode proactif).

## Les deux fichiers du kit

**`lancer_controleur.py`** — le lanceur. os-ken 4.x ne fournit plus la commande `osken-manager`, alors on fournit ce petit lanceur équivalent. Il initialise la bibliothèque et démarre l'application qu'on lui passe en argument :

```python
from os_ken.lib import hub
hub.patch(thread=False)                 # bascule os-ken en mode coroutines (pas de threads)
...
from os_ken.base.app_manager import AppManager
cfg.CONF(args=[], project="os_ken")     # configuration par défaut
AppManager.run_apps(sys.argv[1:])       # lance l'application passée en argument (switch_acl.py)
```

- `hub.patch(thread=False)` : os-ken fonctionne par coroutines coopératives ; c'est pourquoi il ne faut jamais bloquer dans un gestionnaire.
- `AppManager.run_apps(sys.argv[1:])` : charge et exécute `switch_acl.py` ; c'est l'équivalent de `ryu-manager switch_acl.py`.

**`switch_acl.py`** — votre contrôleur. Une classe qui hérite d'`OSKenApp`, déclare OpenFlow 1.3, et réagit à deux événements :

```python
DENY = [("10.0.0.3", "10.0.0.1")]       # couples (source, destination) interdits : recette -> prod

@set_ev_cls(EventOFPSwitchFeatures, CONFIG_DISPATCHER)   # au branchement du switch
def on_switch_connect(self, ev):
    # 1) table-miss : tout paquet inconnu remonte au contrôleur (priorité 0)
    self.add_flow(dp, 0, parser.OFPMatch(), [OFPActionOutput(OFPP_CONTROLLER, ...)])
    # 2) politique PROACTIVE : règles de blocage (liste d'actions vide = drop)
    for src, dst in DENY:
        self.add_flow(dp, 100, OFPMatch(eth_type=IP, ipv4_src=src, ipv4_dst=dst), [])

@set_ev_cls(EventOFPPacketIn, MAIN_DISPATCHER)           # à chaque paquet remonté
def on_packet_in(self, ev):
    table[eth.src] = in_port                             # apprend la MAC source et son port
    out_port = table.get(eth.dst, OFPP_FLOOD)            # port de la destination, sinon on inonde
    if out_port != OFPP_FLOOD:                           # installation RÉACTIVE d'un flux
        self.add_flow(dp, 10, OFPMatch(in_port=in_port, eth_dst=eth.dst), actions, idle=30)
    dp.send_msg(OFPPacketOut(...))                       # renvoie le paquet
```

Points à retenir :

- `DENY` : la politique, une liste de couples (source, destination) IPv4 interdits — ici recette (10.0.0.3) vers prod (10.0.0.1).
- `on_switch_connect` (phase **CONFIG_DISPATCHER**, juste après FEATURES) : pose d'abord la **table-miss** (priorité 0, tout l'inconnu remonte au contrôleur), puis les **règles de blocage** de `DENY` en **proactif** (priorité 100, actions vides = drop).
- `add_flow` : méthode utilitaire qui construit et envoie un message `FLOW_MOD`.
- `on_packet_in` (phase **MAIN_DISPATCHER**) : le cœur **réactif** — apprend la MAC source et son port, cherche le port de la destination (sinon inonde), installe une règle apprise (30 s d'inactivité), et renvoie le paquet par un `PACKET_OUT`. Les trames LLDP sont ignorées.

### Étape 1 — Lancer le contrôleur et la topologie

```bash
# Terminal 1 : le contrôleur (port 6653 libre : ONOS arrêté — sinon sudo docker stop onos)
~/osken/bin/python lancer_controleur.py switch_acl.py

# Terminal 2 : capture du dialogue OpenFlow, puis topologie
sudo tcpdump -i lo -w of.pcap tcp port 6653 &
sudo mn -c
sudo mn --topo single,3 --mac --switch ovs,protocols=OpenFlow13 \
        --controller remote,ip=127.0.0.1,port=6653
mininet> pingall
```

**Ligne par ligne.**

- `~/osken/bin/python lancer_controleur.py switch_acl.py` : démarre votre application ; elle écoute sur le port 6653 et attend les switches.
- `tcpdump -i lo -w of.pcap tcp port 6653 &` : enregistre, en fond, les échanges switch ↔ contrôleur (sur la boucle locale).
- `mn -c` : nettoie Mininet.
- `mn --topo single,3 … --controller remote,…:6653` : un switch, trois hôtes, pilotés par **votre** contrôleur.
- `pingall` : déclenche les échanges (PACKET_IN, FLOW_MOD, PACKET_OUT…).

### Étape 2 — Lire le dialogue OpenFlow

```bash
# Après la sortie de Mininet (commande « exit »)
sudo pkill tcpdump
tshark -r of.pcap -Y openflow_v4 -T fields -e openflow_v4.type | sort | uniq -c
```

**Ligne par ligne.**

- `pkill tcpdump` : arrête la capture.
- `tshark -r of.pcap -Y openflow_v4 … | sort | uniq -c` : compte chaque **type de message OpenFlow** capturé — vous devez y retrouver HELLO, FEATURES, MULTIPART, puis les FLOW_MOD (table-miss et règle de blocage) et les PACKET_IN/PACKET_OUT du `pingall`.

**Point de contrôle** : au `pingall`, tout passe **sauf** h3 vers h1, et `dump-flows s1` montre la table-miss en priorité 0 et des règles apprises avec 30 s d'inactivité.

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
