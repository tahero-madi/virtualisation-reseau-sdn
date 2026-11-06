# TP4-B — Une application de contrôle en Python

**Jour 2, 14:50 · 25 min.** Objectif : confier la même politique à une application de contrôle écrite en Python (os-ken). Support : chapitres 14 à 17.

Remplacer les règles manuelles par l'application `switch_acl.py` : elle apprend les adresses MAC (mode réactif) et pose la politique au branchement du switch (mode proactif).

```bash
# Terminal 1 : le contrôleur (port 6653 libre : ONOS arrêté — sinon sudo docker stop onos)
~/osken/bin/python lancer_controleur.py switch_acl.py    # lance votre application os-ken ; elle attend les switches

# Terminal 2 : capture du dialogue OpenFlow, puis topologie
sudo tcpdump -i lo -w of.pcap tcp port 6653 &            # enregistre les échanges switch <-> contrôleur (port 6653)
sudo mn -c                                               # nettoie Mininet
sudo mn --topo single,3 --mac --switch ovs,protocols=OpenFlow13 \
        --controller remote,ip=127.0.0.1,port=6653       # 1 switch, 3 hôtes, pilotés par VOTRE contrôleur
mininet> pingall                                         # déclenche les échanges : PacketIn, FlowMod, etc.

# Après la sortie de Mininet (commande « exit »)
sudo pkill tcpdump                                                              # arrête la capture
tshark -r of.pcap -Y openflow_v4 -T fields -e openflow_v4.type | sort | uniq -c # compte chaque type de message OpenFlow
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
