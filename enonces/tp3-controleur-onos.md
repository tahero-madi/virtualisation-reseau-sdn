# TP3 — Piloter le réseau par un contrôleur

Objectif : raccorder une topologie à ONOS, exprimer la connectivité par intentions, observer la résilience, puis appliquer une politique depuis un fichier versionné. Chapitres 9 à 12. Durée indicative : 1 h 45.

## TP3-A — Prendre en main ONOS

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

La topologie [`ring.py`](../kit/ring.py) relie 4 switches en anneau, avec un hôte par switch.

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

## TP3-B — Intentions et résilience

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

## TP3-C — La politique comme du code

Décrire la connectivité des zones dans un fichier YAML versionné et l'appliquer par script. Correspondance : h1 dev, h2 recette, h3 prod, h4 admin.

`politique.yaml` :

```yaml
autorisations:
  - nom: dev-vers-recette
    de: "00:00:00:00:00:01"
    vers: "00:00:00:00:00:02"
  - nom: admin-vers-recette
    de: "00:00:00:00:00:04"
    vers: "00:00:00:00:00:02"
  - nom: admin-vers-prod
    de: "00:00:00:00:00:04"
    vers: "00:00:00:00:00:03"
```

1. Retirez les intentions du TP3-B : listez-les, puis supprimez-les par clé.

```bash
curl -s -u onos:rocks http://localhost:8181/onos/v1/intents \
  | jq -r '.intents[] | "\(.appId) \(.key) \(.state)"'
curl -s -u onos:rocks -X DELETE http://localhost:8181/onos/v1/intents/org.onosproject.cli/<clé>
```

2. Appliquez la politique : `python3 apply_policy.py politique.yaml` (script : [`kit/apply_policy.py`](../kit/apply_policy.py)).
3. Vérifiez avec `pingall` quelles paires répondent, et comparez au fichier.
4. Commitez `politique.yaml` et le script.

Pour aller plus loin : rendez le script idempotent en supprimant les intentions absentes du fichier, puis esquissez le pipeline GitLab CI qui enchaînerait validation, test et application (chapitre 12).

---

[← TP2](tp2-vlan-et-vxlan.md) · [Sommaire](../README.md) · [TP4 →](tp4-openflow-et-mise-en-situation.md)
