# Virtualisation des réseaux, SDN et OpenFlow — travaux pratiques

Énoncés et scripts des travaux pratiques de la formation **1-041 « Virtualisation des réseaux, SDN, OpenFlow »** (2 jours). On y construit des réseaux virtuels sous Linux (namespaces, Open vSwitch, VLAN, VXLAN), on pilote une topologie Mininet avec le contrôleur ONOS, puis on programme un switch en OpenFlow, à la main et avec une application Python os-ken.

## Les TP

| TP | Sujet | Durée | Énoncé |
| --- | --- | --- | --- |
| — | Préparer son poste, habitudes de travail | — | [00-preparer-son-poste.md](enonces/00-preparer-son-poste.md) |
| TP1 | Un réseau virtuel (TP1-A) et un pare-feu virtualisé, une VNF (TP1-B) | 1 h 15 | [tp1-reseau-virtuel-et-vnf.md](enonces/tp1-reseau-virtuel-et-vnf.md) |
| TP2 | VLAN et routage entre zones (TP2-A), overlay VXLAN entre deux hyperviseurs (TP2-B) | 2 h 10 | [tp2-vlan-et-vxlan.md](enonces/tp2-vlan-et-vxlan.md) |
| TP3 | Contrôleur ONOS (TP3-A), intentions et résilience (TP3-B), politique en YAML (TP3-C) | 1 h 45 | [tp3-controleur-onos.md](enonces/tp3-controleur-onos.md) |
| TP4 | Règles OpenFlow à la main (TP4-A), application de contrôle Python (TP4-B), mise en situation finale | 1 h 10 + 30 min | [tp4-openflow-et-mise-en-situation.md](enonces/tp4-openflow-et-mise-en-situation.md) |
| — | Pannes fréquentes et remèdes | — | [depannage.md](enonces/depannage.md) |

Chaque TP se termine par un script rejouable, versionné dans Git : c'est le livrable.

## Contenu du dépôt

```text
enonces/   les énoncés, un fichier par TP
kit/       les fichiers fournis aux stagiaires
infra/     le script de préparation des machines
```

| Fichier | Rôle |
| --- | --- |
| [`kit/ring.py`](kit/ring.py) | Topologie Mininet en anneau, 4 switches et 4 hôtes (TP3) |
| [`kit/politique.yaml`](kit/politique.yaml) | Politique de connectivité entre zones (TP3-C) |
| [`kit/apply_policy.py`](kit/apply_policy.py) | Applique la politique YAML par l'API REST d'ONOS (TP3-C) |
| [`kit/switch_acl.py`](kit/switch_acl.py) | Application os-ken : switch apprenant avec filtrage (TP4-B) |
| [`kit/lancer_controleur.py`](kit/lancer_controleur.py) | Lanceur d'applications os-ken, à la place d'`osken-manager` (TP4-B) |
| [`kit/reset_lab.sh`](kit/reset_lab.sh) | Remise à zéro : supprime tous les namespaces et bridges OVS, Mininet et ONOS |
| [`kit/preparation_lab.sh`](kit/preparation_lab.sh) | Installation minimale sur une seule machine |
| [`infra/preparation_vm.sh`](infra/preparation_vm.sh) | Installation complète et contrôles des deux machines du lab |

> **Attention :** `reset_lab.sh` supprime **tous** les namespaces et bridges Open vSwitch de la machine. À n'utiliser que sur une machine de laboratoire.

## Le lab : deux machines

Les TP se font sur **lab-a** ; **lab-b** ne sert qu'au TP2-B, comme second hyperviseur. Les deux sont sur le même réseau local, avec le port UDP 4789 ouvert entre elles.

| Machine | Rôle | Ressources | Système |
| --- | --- | --- | --- |
| lab-a | Tous les TP : Open vSwitch, Mininet, Docker et ONOS 2.7.0, os-ken, bureau XFCE et Firefox | 4 vCPU, 8 Go de RAM, 40 Go | Ubuntu 24.04 LTS |
| lab-b | Second hyperviseur du TP2-B : Open vSwitch et outils réseau | 2 vCPU, 2 Go de RAM, 20 Go | Ubuntu 24.04 LTS Server |

Sur les machines de la formation, tout est déjà installé et le kit est dans `~/lab`. Pour refaire le lab chez vous, sur deux VM KVM, VMware ou VirtualBox (pas de conteneurs LXC : les TP chargent des modules noyau) :

```bash
# Sur lab-a
git clone https://github.com/tahero-madi/virtualisation-reseau-sdn.git
cd virtualisation-reseau-sdn
sudo bash infra/preparation_vm.sh --kit kit     # installe tout, copie kit/ dans ~/lab (dépôt Git local)
sudo reboot

# Sur lab-b
git clone https://github.com/tahero-madi/virtualisation-reseau-sdn.git
sudo bash virtualisation-reseau-sdn/infra/preparation_vm.sh --secondaire   # installation légère

# Sur lab-a, une fois lab-b prête : ping et MTU 1 500 entre les deux machines
sudo bash infra/preparation_vm.sh --verifier-seulement --pair <adresse de lab-b>
```

Options utiles de `preparation_vm.sh` : `--sans-bureau` (lab-a sans interface graphique), `--test-onos` (démarre ONOS une fois pour vérifier son API), `--underlay IFACE IP/MASQUE` (seconde carte réseau dédiée au TP2-B). `sudo bash infra/preparation_vm.sh --help` les détaille. Avec une seule machine, le TP2-B se fait en « variante seule », deux namespaces jouant les hyperviseurs.

L'interface web d'ONOS s'ouvre dans le navigateur de lab-a : `http://localhost:8181/onos/ui` (onos / rocks).

## Versions testées

Ubuntu 24.04 LTS, Open vSwitch et Mininet des dépôts Ubuntu, ONOS 2.7.0 (image Docker `onosproject/onos:2.7.0`), os-ken 4.2.2 sous Python 3, OpenFlow 1.3.

## Corrigés

Les corrigés des TP et de la mise en situation sont réservés au formateur et ne sont pas publiés dans ce dépôt.
