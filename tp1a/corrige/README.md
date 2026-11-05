# Corrigé du TP1-A

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Questions

**1. Pourquoi `ip a` exécuté dans h1 ne montre-t-il pas les interfaces de l'hôte ?**

Parce que h1 est un *network namespace* : il a sa propre pile réseau, isolée de celle de l'hôte. `ip a` dans h1 ne voit que `lo` et `h1-eth0`. C'est exactement ce qui isole deux locataires sur une même machine.

**2. Que signifie l'action `NORMAL` affichée par `dump-flows` ?**

Que le commutateur se comporte comme un switch Ethernet classique : apprentissage des adresses MAC et diffusion des trames inconnues. C'est le comportement par défaut d'Open vSwitch tant qu'aucun contrôleur ni aucune règle OpenFlow ne lui dit quoi faire — on s'en servira à l'inverse au TP4, où l'on remplace `NORMAL` par nos propres règles.

**3. Que montre `fdb/show` avant et après ?**

- **Avant de retirer le port :** une entrée associe l'adresse MAC de h2 à son port, apprise au premier ping.
- **Après `del-port` :** l'entrée disparaît, le port n'existe plus.
- **Après rebranchement et nouveau ping :** l'adresse de h2 est réapprise, sur le port. C'est l'apprentissage dynamique MAC → port, le cœur d'un switch de niveau 2.

## Bonus — un conteneur est un namespace comme les autres

`nsenter -t "$PID" -n ip addr` montre les interfaces du conteneur `web` exactement comme pour h1 : un conteneur n'est qu'un ensemble de namespaces. `bridge link | grep docker0` montre que Docker a raccordé le conteneur à son propre pont `docker0`, de la même façon que `br-lab` raccorde h1 et h2.

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
