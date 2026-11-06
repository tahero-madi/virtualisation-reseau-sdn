# Mise en situation finale

**Jour 2, 15:15 · 3 min de présentation, puis 30 min de travail individuel.** Évaluation notée : traduire une demande de changement en règles OpenFlow prouvées.

Le chef de projet ouvre une demande de changement sur le switch s1 :

```bash
sudo mn --topo single,4 --mac --switch ovs,protocols=OpenFlow13 --controller none   # 1 switch, 4 hôtes, sans contrôleur : à vous de poser les règles
```

h1 est le serveur prod, h2 le poste dev, h3 le poste recette, h4 une sonde de détection d'intrusion.

1. La recette (h3) n'accède au serveur prod (h1) qu'en TCP 443.
2. Tout le trafic destiné au serveur prod est copié vers la sonde (h4).
3. Le flux de sauvegarde dev vers prod (h2 vers h1) est limité à 10 Mbit/s.
4. La configuration est livrée sous forme de fichier rejouable par `replace-flows` et commitée.
5. Chaque point est prouvé : test, compteurs ou `ofproto/trace`.

| Critère d'évaluation | Points |
| --- | --- |
| Filtrage recette vers prod, prouvé par test | 5 |
| Copie vers la sonde, prouvée par compteurs | 4 |
| Limitation de débit, prouvée par `iperf` | 4 |
| Configuration rejouable et commitée | 4 |
| Parcours d'un paquet expliqué avec `ofproto/trace` | 3 |

Acquis à partir de 12/20, avec les critères 1 et 4 atteints. `ovs-ofctl` seul suffit ; une application os-ken est un plus.
