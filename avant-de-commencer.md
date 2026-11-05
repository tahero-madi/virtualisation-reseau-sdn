# Avant de commencer

Ce dépôt réunit les énoncés des travaux pratiques de la formation **1-041 « Virtualisation des réseaux, SDN, OpenFlow »**. Lisez chaque énoncé ici, sur GitHub, dans le navigateur de lab-a : chaque bloc de commandes a un bouton de copie. Les notions sont développées dans le support de cours.

Chaque stagiaire dispose de deux machines Ubuntu 24.04 LTS, sur un LAN qui n'appartient qu'à lui : lab-a (4 vCPU, 8 Go de RAM, bureau graphique et Firefox), où se font tous les TP, et lab-b, un second hyperviseur léger qui ne sert qu'au TP2-B. On y accède par son lien personnel, depuis le navigateur du poste : lab-a en « Bureau distant » ou en « Terminal SSH », lab-b en « Terminal SSH ». Aucun port des machines n'est joignable directement.

| Besoin | Détail |
| --- | --- |
| Système | Ubuntu 24.04 LTS, avec un bureau graphique léger et Firefox sur lab-a, ou Debian 12 et 13 |
| Droits | `sudo` |
| Réseau | Accès par la plateforme Hexceos (bureau distant, terminal SSH, console de secours) ; pour le TP2-B, lab-a et lab-b sur le même LAN, UDP 4789 autorisé entre les deux |
| Navigateur | Firefox, sur lab-a elle-même : l'interface web d'ONOS s'ouvre à l'adresse `http://localhost:8181/onos/ui` |

**Installation des logiciels**, déjà faite sur les machines de la formation. Pour refaire le lab chez vous, le script complet [`infra/preparation_vm.sh`](infra/preparation_vm.sh) installe et contrôle les deux machines (voir le [README](README.md)). La version minimale ci-dessous, [`infra/preparation_lab.sh`](infra/preparation_lab.sh), suffit sur une seule machine :

```bash
#!/usr/bin/env bash
# preparation_lab.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y openvswitch-switch mininet iproute2 nftables tcpdump tshark \
  iperf iperf3 curl jq git python3-venv python3-yaml python3-requests docker.io
sudo usermod -aG docker "$USER"
sudo docker pull onosproject/onos:2.7.0
sudo docker pull alpine:3.20
python3 -m venv ~/osken && ~/osken/bin/pip install os-ken pyyaml requests

# Contrôles
sudo ovs-vsctl --version | head -1
sudo mn --switch ovsbr --controller none --test pingall
~/osken/bin/python -c "import os_ken; print('os-ken OK')"
```

**Habitudes à prendre.**

- Travailler avec deux terminaux : l'un pour Mininet ou le contrôleur, l'autre pour observer (`ovs-ofctl`, `tcpdump`). Deux fenêtres de terminal sur le bureau de lab-a, ou `tmux` dans un terminal SSH.
- Copier-coller entre le poste et les machines : le presse-papiers fonctionne dans les deux sens, et le bouton « Coller » de la barre d'outils envoie le vôtre dans la machine si un collage échoue. Pour un fichier entier, dans un sens ou dans l'autre : le bouton « Fichiers ».
- Écrire chaque TP dans un script rejouable, le versionner dans le dépôt Git de lab-a (`~/lab`), et télécharger ce dossier sur son poste chaque soir avec le bouton « Fichiers » : les machines sont détruites après la formation.
- Prendre un instantané de la machine avant chaque TP, ou le demander au formateur : on y revient en quelques secondes. « Réinitialiser » recrée tout l'environnement depuis le modèle, mais efface tout, scripts compris.
- Repartir d'un état propre entre deux TP avec `reset_lab.sh`.
- Avant de chercher longtemps : `sudo mn -c`, puis relancer.
