# Virtualisation des réseaux, SDN et OpenFlow · Travaux pratiques

Formation 1-041, deux jours. Neuf travaux pratiques et une mise en situation finale : on construit des réseaux virtuels sous Linux (namespaces, Open vSwitch, VLAN, VXLAN), on pilote une topologie Mininet avec le contrôleur ONOS, puis on programme un switch en OpenFlow, à la main et avec une application Python os-ken.

## Comment travailler

- **Lisez l'énoncé ici**, sur GitHub, dans le navigateur de lab-a. Chaque bloc de commandes a un bouton de copie en haut à droite.
- **Tapez ou collez les commandes dans la console de lab-a**, en « Bureau distant » ou en « Terminal SSH ».
- Commencez par [Avant de commencer](avant-de-commencer.md) : vos deux machines, les habitudes de travail et l'installation.

## Corrigés

Chaque TP a son corrigé dans un sous-dossier `corrige/` : `tp2b/corrige/` pour le TP2-B, par exemple. Il reprend les réponses aux questions et, pour le projet final, les scripts d'infrastructure et de politique de référence.

Cherchez d'abord par vous-même : le corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Récupérer les fichiers sur lab-a

Les machines arrivent vierges (Ubuntu 24.04, bureau et Firefox). L'installation des outils, au début du [TP1-A](tp1a/README.md) sur lab-a et du [TP2-B](tp2b/README.md) sur lab-b, clone d'abord ce dépôt dans `~/lab` :

```bash
sudo apt-get update -q && sudo apt-get install -y git
git clone https://github.com/tahero-madi/virtualisation-reseau-sdn.git ~/lab
ls ~/lab                     # un dossier par TP, plus infra/
```

Si le formateur modifie un fichier pendant la formation, `cd ~/lab && git pull` récupère la nouvelle version.

## Programme des TP

| Quand | TP | Durée |
| --- | --- | --- |
| **Jour 1 · Module 1 — Virtualiser le réseau** | | |
| Jour 1, 09:40 | [TP1-A — Un réseau virtuel en dix commandes](tp1a/README.md) | 45 min |
| Jour 1, 10:35 | [TP1-B — Un pare-feu virtualisé](tp1b/README.md) | 30 min |
| **Jour 1 · Module 2 — Architecture et normalisation** | | |
| Jour 1, 13:30 | [TP2-A — VLAN, routage et filtrage entre zones](tp2a/README.md) | 65 min |
| Jour 1, 14:45 | [TP2-B — Overlay VXLAN entre lab-a et lab-b](tp2b/README.md) | 65 min |
| **Jour 2 · Module 3 — Piloter le réseau par un contrôleur** | | |
| Jour 2, 09:57 | [TP3-A — Prendre en main ONOS](tp3a/README.md) | 45 min |
| Jour 2, 10:52 | [TP3-B — Intentions et résilience](tp3b/README.md) | 40 min |
| Jour 2, 11:32 | [TP3-C — La politique comme du code](tp3c/README.md) | 18 min |
| **Jour 2 · Module 4 — Programmer en OpenFlow** | | |
| Jour 2, 13:50 | [TP4-A — Programmer un switch à la main](tp4a/README.md) | 45 min |
| Jour 2, 14:50 | [TP4-B — Une application de contrôle en Python](tp4b/README.md) | 25 min |
| Jour 2, 15:15 | [Mise en situation finale](mise-en-situation/README.md) | 30 min |

En cas de problème : [En cas de blocage](en-cas-de-blocage.md).

## Contenu du dépôt

| Dossier ou fichier | Contenu |
| --- | --- |
| `tp1a/` … `tp4b/`, `mise-en-situation/` | L'énoncé du TP (`README.md`) et ses fichiers |
| `tp3a/ring.py` | Topologie Mininet en anneau, 4 switches et 4 hôtes (TP3) |
| `tp3c/apply_policy.py`, `tp3c/politique.yaml` | Politique de connectivité et son application par l'API REST d'ONOS (TP3-C) |
| `tp4b/switch_acl.py`, `tp4b/lancer_controleur.py` | Application os-ken (switch apprenant avec filtrage) et son lanceur (TP4-B) |
| `reset_lab.sh` | Remise à zéro : supprime tous les namespaces et bridges OVS, Mininet et ONOS |
| `infra/preparation_vm.sh` | Installation complète et contrôles des deux machines du lab |
| `infra/preparation_lab.sh` | Installation minimale sur une seule machine |

> **Attention :** `reset_lab.sh` supprime **tous** les namespaces et bridges Open vSwitch de la machine. À n'utiliser que sur une machine de laboratoire.

## Le lab : deux machines

Les TP se font sur **lab-a** ; **lab-b** ne sert qu'au TP2-B, comme second hyperviseur. Les deux sont sur le même réseau local, avec le port UDP 4789 ouvert entre elles.

| Machine | Rôle | Ressources | Système |
| --- | --- | --- | --- |
| lab-a | Tous les TP : Open vSwitch, Mininet, Docker et ONOS 2.7.0, os-ken (installés au TP1-A). Bureau et Firefox fournis par la machine | 4 vCPU, 8 Go de RAM, 40 Go | Ubuntu 24.04 LTS |
| lab-b | Second hyperviseur du TP2-B : Open vSwitch et outils réseau | 2 vCPU, 2 Go de RAM, 20 Go | Ubuntu 24.04 LTS Server |

Pour refaire le lab chez vous, sur deux VM KVM, VMware ou VirtualBox (pas de conteneurs LXC : les TP chargent des modules noyau) :

On se place dans `~/lab` puis on lance avec un chemin relatif : sous `sudo`, un `~` pointerait vers `/root`, pas vers votre dossier.

```bash
# Sur lab-a
git clone https://github.com/tahero-madi/virtualisation-reseau-sdn.git ~/lab
cd ~/lab
sudo bash infra/preparation_vm.sh --kit "$PWD"    # installe tout, rassemble les scripts dans ~/lab

# Sur lab-b
git clone https://github.com/tahero-madi/virtualisation-reseau-sdn.git ~/lab
cd ~/lab
sudo bash infra/preparation_vm.sh --secondaire    # installation légère

# Sur lab-a, une fois lab-b prête : ping et MTU 1 500 entre les deux machines
cd ~/lab && sudo bash infra/preparation_vm.sh --verifier-seulement --pair <adresse de lab-b>
```

`sudo bash infra/preparation_vm.sh --help` détaille les options (`--sans-bureau`, `--test-onos`, `--underlay`). Avec une seule machine, le TP2-B se fait en « variante seule », deux namespaces jouant les hyperviseurs. L'interface web d'ONOS s'ouvre dans le Firefox de lab-a : `http://localhost:8181/onos/ui` (onos / rocks).

## Versions testées

Ubuntu 24.04 LTS, Open vSwitch et Mininet des dépôts Ubuntu, ONOS 2.7.0 (image Docker `onosproject/onos:2.7.0`), os-ken 4.2.2 sous Python 3, OpenFlow 1.3.
