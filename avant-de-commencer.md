# Avant de commencer

Ce dépôt réunit les énoncés des travaux pratiques de la formation **1-041 « Virtualisation des réseaux, SDN, OpenFlow »**. Lisez chaque énoncé ici, sur GitHub, dans le navigateur de lab-a : chaque bloc de commandes a un bouton de copie. Les notions sont développées dans le support de cours.

Chaque stagiaire dispose de deux machines Ubuntu 24.04 LTS, sur un LAN qui n'appartient qu'à lui : lab-a (4 vCPU, 8 Go de RAM, bureau graphique et Firefox), où se font tous les TP, et lab-b, un second hyperviseur léger qui ne sert qu'au TP2-B. On y accède par son lien personnel, depuis le navigateur du poste : lab-a en « Bureau distant » ou en « Terminal SSH », lab-b en « Terminal SSH ». Aucun port des machines n'est joignable directement.

## Votre accès personnel

Chaque apprenant ouvre **son propre lien**, qui donne accès à ses deux machines (lab-a et lab-b) :

| Participant | Apprenant | Accès à lab-a et lab-b |
| --- | --- | --- |
| 01 | Rémi CURET | https://hra-ng.hexceos.cloud/p/ef7403c0-dade-4254-966e-f7ceb82afb32uufe4x8n |
| 02 | Ismael KHAYI | https://hra-ng.hexceos.cloud/p/ef7403c0-dade-4254-966e-f7ceb82afb32nnfm7d2e |
| 03 | Quentin LEJARD | https://hra-ng.hexceos.cloud/p/ef7403c0-dade-4254-966e-f7ceb82afb32pdnnwgwq |
| 04 | Clément PILON | https://hra-ng.hexceos.cloud/p/ef7403c0-dade-4254-966e-f7ceb82afb32n5xuv8rw |

> Ces liens sont personnels et donnent un accès direct à vos machines : ne les partagez pas en dehors de la session.

| Besoin | Détail |
| --- | --- |
| Système | Ubuntu 24.04 LTS, avec un bureau graphique léger et Firefox sur lab-a, ou Debian 12 et 13 |
| Droits | `sudo` |
| Réseau | Accès par la plateforme Hexceos (bureau distant, terminal SSH, console de secours) ; pour le TP2-B, lab-a et lab-b sur le même LAN, UDP 4789 autorisé entre les deux |
| Navigateur | Firefox, sur lab-a elle-même : l'interface web d'ONOS s'ouvre à l'adresse `http://localhost:8181/onos/ui` |

**Les machines arrivent vierges.** lab-a et lab-b sont des Ubuntu 24.04 avec seulement le bureau et Firefox ; aucun outil réseau n'est préinstallé. Vous installez les outils vous-même, une fois pour les deux jours : sur lab-a au début du [TP1-A](tp1a/README.md), sur lab-b au début du [TP2-B](tp2b/README.md). Le script [`infra/preparation_vm.sh`](infra/preparation_vm.sh) s'en charge, et un instantané pris juste après vous évite de tout réinstaller en cas de pépin. Pour refaire le lab chez vous, c'est la même installation : voir le [README](README.md).

**Habitudes à prendre.**

- Travailler avec deux terminaux : l'un pour Mininet ou le contrôleur, l'autre pour observer (`ovs-ofctl`, `tcpdump`). Deux fenêtres de terminal sur le bureau de lab-a, ou `tmux` dans un terminal SSH.
- Copier-coller entre le poste et les machines : le presse-papiers fonctionne dans les deux sens, et le bouton « Coller » de la barre d'outils envoie le vôtre dans la machine si un collage échoue. Pour un fichier entier, dans un sens ou dans l'autre : le bouton « Fichiers ».
- Écrire chaque TP dans un script rejouable, le versionner dans le dépôt Git de lab-a (`~/lab`), et télécharger ce dossier sur son poste chaque soir avec le bouton « Fichiers » : les machines sont détruites après la formation.
- Prendre un instantané de la machine avant chaque TP, ou le demander au formateur : on y revient en quelques secondes. « Réinitialiser » recrée tout l'environnement depuis le modèle, mais efface tout, scripts compris.
- Repartir d'un état propre entre deux TP avec `reset_lab.sh`.
- Avant de chercher longtemps : `sudo mn -c`, puis relancer.
