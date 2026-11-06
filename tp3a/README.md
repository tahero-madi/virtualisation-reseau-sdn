# TP3-A — Prendre en main ONOS

**Jour 2, 09:57 · 45 min.** Objectif : raccorder une topologie Mininet au contrôleur ONOS et l'explorer par l'interface web, la CLI et l'API REST. Support : chapitres 9 à 12. Commencez par `sudo bash reset_lab.sh`.

```bash
sudo bash reset_lab.sh                                 # repart d'une machine propre (namespaces, bridges, Mininet, ONOS)
sudo docker run -d --name onos -p 8181:8181 -p 8101:8101 -p 6653:6653 \
  -e ONOS_APPS=drivers,openflow,proxyarp,fwd,gui2 onosproject/onos:2.7.0   # lance ONOS : 8181 web, 8101 CLI SSH, 6653 OpenFlow
until curl -sf -u onos:rocks http://localhost:8181/onos/v1/applications > /dev/null; do sleep 5; done   # attend qu'ONOS réponde
echo "ONOS prêt"

sudo mn --custom ring.py --topo ring --mac \          # topologie « ring » définie dans ring.py, adresses MAC lisibles
        --switch ovs,protocols=OpenFlow13 \           # switches Open vSwitch en OpenFlow 1.3
        --controller remote,ip=127.0.0.1,port=6653    # pilotés par ONOS (contrôleur distant, port 6653)
mininet> pingall        # test de connectivité entre tous les hôtes ; relancer une fois si pertes au premier passage
```

La topologie `ring.py` relie 4 switches en anneau, avec un hôte par switch.

Explorer :

- Interface web, dans le Firefox de lab-a : `http://localhost:8181/onos/ui` (onos / rocks), touche H pour afficher les hôtes.
- Ligne de commande : `ssh -p 8101 onos@localhost` (mot de passe rocks), puis `apps -a -s`, `devices`, `links`, `hosts`, `flows -s`.
- API :

```bash
API=http://localhost:8181/onos/v1; AUTH=onos:rocks            # interface nord (REST) d'ONOS et identifiants
curl -s -u $AUTH $API/devices | jq -r '.devices[].id'         # liste les switches vus par ONOS
curl -s -u $AUTH $API/links   | jq '.links | length'          # nombre de liens découverts
curl -s -u $AUTH $API/hosts   | jq -c '.hosts[] | {mac, ipAddresses}'   # les hôtes appris (MAC et IP)
```

Questions :

1. ONOS compte 8 liens pour 4 câbles entre switches : pourquoi ?
2. Comment ONOS découvre-t-il les liens ? (indice : LLDP, PACKET\_OUT, PACKET\_IN)
3. Comparez la table de flux de s1 avant et après `pingall` : quelle application a posé les règles ?
