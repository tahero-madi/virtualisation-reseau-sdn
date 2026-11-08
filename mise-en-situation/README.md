# Mise en situation finale

**Jour 2, 15:15 · 3 min de présentation, puis 30 min de travail individuel.** Objectif : traduire seul une demande de changement en règles OpenFlow prouvées. C'est un exercice de synthèse, **non noté** : l'occasion de rejouer en autonomie les gestes des TP4.

Le chef de projet ouvre une demande de changement sur le switch s1 :

```bash
sudo mn --topo single,4 --mac --switch ovs,protocols=OpenFlow13 --controller none
```

- `--topo single,4` : un switch, **quatre** hôtes ; `--controller none` : sans contrôleur, à vous de poser les règles en OpenFlow.

h1 est le serveur prod, h2 le poste dev, h3 le poste recette, h4 une sonde de détection d'intrusion.

La demande de changement :

1. La recette (h3) n'accède au serveur prod (h1) qu'en TCP 443.
2. Tout le trafic destiné au serveur prod est copié vers la sonde (h4).
3. Le flux de sauvegarde dev vers prod (h2 vers h1) est limité à 10 Mbit/s.
4. La configuration est livrée sous forme de fichier rejouable par `replace-flows` et commitée.
5. Chaque point est prouvé : test, compteurs ou `ofproto/trace`.

Pour vous repérer, ce qu'il faut avoir produit à la fin :

- [ ] Filtrage recette → prod : TCP 443 passe, le reste est refusé — prouvé par un test.
- [ ] Copie vers la sonde : un groupe `all` qui livre à h1 et copie vers h4 — prouvé par les compteurs du port de la sonde.
- [ ] Limitation de débit : un meter à 10 Mbit/s sur h2 → h1 — prouvé par `iperf`.
- [ ] Configuration rejouable : un fichier de règles appliqué par `replace-flows`, commité.
- [ ] Explication : le parcours d'un paquet commenté avec `ofproto/trace`.

`ovs-ofctl` seul suffit ; une application os-ken est un plus. Rappel des trois pièges du jour : les prérequis des champs (`ip`, `tcp`), l'option `-O OpenFlow13`, et la table-miss (une règle de priorité 0 qui détruit).

> L'évaluation des acquis fera l'objet d'un QCM, ajouté ultérieurement. Cette mise en situation sert uniquement à s'entraîner.
