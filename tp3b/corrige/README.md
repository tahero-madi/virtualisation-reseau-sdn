# Corrigé du TP3-B

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Questions

**1. Quel est l'état de l'intention après la seconde panne ? Après le rétablissement ?**

- Première panne (`link s1 s2 down`) : ONOS recalcule, l'intention reste **INSTALLED** par l'autre côté de l'anneau ; h1 pingue toujours h3.
- Seconde panne (`link s1 s4 down`) : l'anneau est coupé des deux côtés, plus aucun chemin → l'intention passe à **FAILED**, le ping échoue.
- Rétablissement (`link s1 s4 up`) : ONOS recompile l'intention, elle repasse **INSTALLED**, la connectivité revient, sans aucune action de votre part.

**2. Quelle différence entre installer un flux et déclarer une intention ?**

Un flux est une règle unique, sur un switch donné. Une intention est une volonté de haut niveau (« relier A et B ») qu'ONOS compile en autant de flux que nécessaire le long du chemin, et **recompile tout seul** à chaque changement de topologie. Le flux est impératif et local ; l'intention est déclarative et à l'échelle du réseau.

**3. Que se passerait-il, sur la même panne, avec des règles posées à la main ?**

Rien ne se réparerait : le chemin resterait cassé jusqu'à ce que quelqu'un reprogramme les switches. Sans contrôleur pour recalculer, pas de reroutage automatique.

**4. Sur l'anneau, ARP fonctionne sans l'application `fwd` : quelle application répond à sa place ?**

L'application proxy ARP, `org.onosproject.proxyarp` : elle répond aux requêtes ARP à partir de ce qu'ONOS sait déjà des hôtes, sans inonder le réseau.

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
