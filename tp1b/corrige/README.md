# Corrigé du TP1-B

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Questions

**1. Pourquoi la règle `ct state established,related accept` est-elle indispensable ?**

La politique de la chaîne `forward` est `drop`. Sans cette règle, seul le paquet *aller* qui correspond à une règle explicite passe ; le paquet *retour* (la réponse du serveur) ne correspond à aucune règle et serait jeté. Même le HTTP autorisé ne marcherait pas : la requête de h1 arriverait au serveur, mais sa réponse serait bloquée. Le suivi de connexion (`ct`) reconnaît les paquets qui appartiennent à une connexion déjà acceptée et les laisse revenir.

**2. Où se trouve « physiquement » ce pare-feu ? Qu'est-ce que cela change ?**

Nulle part en matériel : c'est le namespace `fw`, un logiciel sur l'hôte Linux. Conséquences :

- **Sauvegarde** : pas de boîtier à sauvegarder, seulement sa configuration (`vnf-fw.nft`) et le script qui le recrée.
- **Plan de reprise** : on le reconstruit en quelques secondes, par script, sur n'importe quel hôte.
- **Montée en charge** : on en lance plusieurs instances, on les déplace, on les redimensionne à la demande.

Le réseau devient du code, pas une armoire à câbler.

**3. Qu'apporterait un orchestrateur (MANO, Kubernetes) ?**

Il instancie, place, surveille, redémarre et redimensionne la VNF automatiquement, gère son cycle de vie et son chaînage (service function chaining), à partir d'un état désiré déclaratif — au lieu des commandes `ip netns` et `nft` tapées à la main.

**4. Quelles fonctions de votre périmètre pourraient devenir des VNF ou des CNF ?**

Réponse ouverte : pare-feu, répartiteur de charge, reverse proxy, passerelle VPN, IDS/IPS, DNS, DHCP — toute fonction réseau de niveau 4 à 7 aujourd'hui rendue par un boîtier dédié.

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
