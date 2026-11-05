# Corrigé du TP4-A

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Questions

**1. Pourquoi `pingall` échoue-t-il au départ ? Que répond `get-fail-mode` ?**

Le switch est lancé `--controller none` et sa table est vide. `get-fail-mode` répond **`secure`** : privé de contrôleur, un switch en mode sécurisé ne fait rien de lui-même (il ne bascule pas en switch classique). Aucune règle, donc aucun paquet transmis.

**2. Pourquoi h1 ne peut-il plus pinguer h3, alors que seule la recette vers la prod est interdite ? Corrigez avec `icmp_type=8`.**

La règle `priority=200,icmp,nw_src=10.0.0.3,nw_dst=10.0.0.1,actions=drop` est **sans état** et ne regarde que source et destination. Le ping de h1 vers h3 part bien (h1 → h3), mais la **réponse** de h3 vers h1 (`nw_src=10.0.0.3,nw_dst=10.0.0.1`) tombe sous cette règle de blocage : l'écho revient, il est jeté. h1 ne reçoit donc jamais de réponse.

Correctif : ne bloquer que les *requêtes* de la recette, pas les réponses, en ajoutant `icmp_type=8` (echo-request) à la règle de drop. Les réponses (`icmp_type=0`) ne correspondent plus et reviennent.

**3. Que lit-on dans la sortie de `ofproto/trace` ?**

Le parcours du paquet dans le pipeline : la règle qui correspond, sa priorité, et l'action qui en résulte (`output:N` ou `drop`). On voit noir sur blanc pourquoi un paquet est transmis ou jeté.

**4. Quel débit mesure `iperf` avant et après le meter ?**

Avant : proche du débit maximal du lien (centaines de Mbit/s dans Mininet). Après le meter réglé à 5000 kbps : environ **5 Mbit/s**, l'excédent étant jeté par la bande `drop`.

**5. Comment rejouer toute la configuration d'un coup ?**

Écrire les règles dans un fichier et le charger avec `ovs-ofctl -O OpenFlow13 replace-flows s1 regles.txt` : `replace-flows` remplace toute la table d'un coup (atomique), `add-flows` ajoute sans effacer. C'est la configuration réseau traitée comme un fichier versionné.

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
