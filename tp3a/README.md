# TP3-A — Prendre en main ONOS

**Jour 2, 09:57 · 45 min.** Objectif : raccorder une topologie Mininet au contrôleur ONOS et l'explorer par l'interface web, la CLI et l'API REST. Support : chapitres 9 à 12. Commencez par `sudo bash reset_lab.sh`.

```bash
sudo bash reset_lab.sh
sudo docker run -d --name onos -p 8181:8181 -p 8101:8101 -p 6653:6653 \
  -e ONOS_APPS=drivers,openflow,proxyarp,fwd,gui2 onosproject/onos:2.7.0
until curl -sf -u onos:rocks http://localhost:8181/onos/v1/applications > /dev/null; do sleep 5; done
echo "ONOS prêt"

sudo mn --custom ring.py --topo ring --mac \
        --switch ovs,protocols=OpenFlow13 \
        --controller remote,ip=127.0.0.1,port=6653
mininet> pingall        # relancer une fois si des pertes au premier passage
```

La topologie `ring.py` relie 4 switches en anneau, avec un hôte par switch.

Explorer :

- Interface web, dans le Firefox de lab-a : `http://localhost:8181/onos/ui` (onos / rocks), touche H pour afficher les hôtes.
- Ligne de commande : `ssh -p 8101 onos@localhost` (mot de passe rocks), puis `apps -a -s`, `devices`, `links`, `hosts`, `flows -s`.
- API :

```bash
API=http://localhost:8181/onos/v1; AUTH=onos:rocks
curl -s -u $AUTH $API/devices | jq -r '.devices[].id'
curl -s -u $AUTH $API/links   | jq '.links | length'
curl -s -u $AUTH $API/hosts   | jq -c '.hosts[] | {mac, ipAddresses}'
```

Questions :

1. ONOS compte 8 liens pour 4 câbles entre switches : pourquoi ?
2. Comment ONOS découvre-t-il les liens ? (indice : LLDP, PACKET\_OUT, PACKET\_IN)
3. Comparez la table de flux de s1 avant et après `pingall` : quelle application a posé les règles ?
