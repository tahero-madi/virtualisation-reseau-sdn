# Corrigé du TP2-A

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Questions

**1. Combien de VLAN au maximum ? Pourquoi est-ce insuffisant pour un cloud multi-locataire ?**

4094 (l'identifiant VLAN tient sur 12 bits, 0 et 4095 réservés). Un cloud public compte bien plus de 4094 locataires et de segments isolés : c'est la limite que lève VXLAN, dont le VNI sur 24 bits offre environ 16,7 millions de segments.

**2. Que voit-on dans `ovsdb-client monitor` quand on ajoute un port ? Qui s'y abonne en production ?**

L'insertion de la ligne `Port` (son `name`, son `tag`) s'affiche en temps réel. En production, c'est le contrôleur SDN ou le gestionnaire de cloud (Neutron d'OpenStack, OVN) qui s'abonne à OVSDB pour réagir aux changements de topologie.

**3. Aucune règle n'autorise prod vers recette : pourquoi prd1 répond-il aux pings de rec1 ?**

Parce que la règle autorise **rec1 → prd1** (`iifname rtr-eth0.20 oifname rtr-eth0.30 ... icmp echo-request accept`). La réponse de prd1 vers rec1 n'est pas une nouvelle connexion : elle appartient à la connexion déjà établie, et passe par `ct state established,related accept`. Ce n'est donc pas « prod vers recette » qui est ouvert, mais le retour d'un échange lancé par la recette.

**4. Quel EtherType signale l'étiquette, et quels numéros de VLAN voyez-vous ?**

L'EtherType `0x8100` (802.1Q) signale la présence d'une étiquette. Sur le lien trunk `rtr-port`, la capture montre les VLAN **10, 20 et 30**, selon la zone d'où vient le paquet.

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
