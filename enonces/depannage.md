# Dépannage

Les scripts fournis sont dans le dossier [`kit/`](../kit/). Les applications Python ont été testées avec os-ken 4.2.2 sous Python 3.13, face à un switch OpenFlow 1.3.

| Symptôme | Cause probable | Remède |
| --- | --- | --- |
| `RTNETLINK answers: File exists` | Objet déjà créé par un essai précédent | `reset_lab.sh`, puis rendre le script idempotent |
| Mininet refuse de démarrer | Restes d'une session interrompue | `sudo mn -c` |
| Switch absent de l'interface ONOS | ONOS pas encore prêt, ou application openflow inactive | Attendre la réponse de l'API, `app activate org.onosproject.openflow` |
| Le contrôleur os-ken ne voit aucun switch | Port 6653 occupé par ONOS | `sudo docker stop onos` |
| `ovs-ofctl` : « version negotiation failed » | Bridge limité à OpenFlow 1.3 | Ajouter `-O OpenFlow13` |
| Règle sans effet | Prérequis manquant (`ip`, `tcp`) ou priorité trop basse | `dump-flows` (compteurs), `ofproto/trace` |
| Pas de trafic VXLAN entre VM | UDP 4789 filtré, `local_ip` erronée | `tcpdump udp port 4789` des deux côtés |
| Le ping passe, le transfert bloque | MTU de l'overlay | MTU des interfaces à 1 450, ou underlay à 1 550 et plus |
| Meter sans effet | Datapath sans prise en charge des meters | `ovs-ofctl -O OpenFlow13 meter-features s1` |

---

[← TP4](tp4-openflow-et-mise-en-situation.md) · [Sommaire](../README.md)
