# Corrigé du TP2-B

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Questions

**1. Quel est le résultat de chacun des deux pings ? Expliquez par le calcul.**

- `-s 1422` : le paquet IP fait 1422 + 28 = 1450 octets ; enveloppé par VXLAN (+ 50 octets), 1500, ce qui tient sur l'underlay à 1500 → **il passe**.
- `-s 1472` : le paquet fait 1500 ; enveloppé, 1550, trop grand pour l'underlay à 1500, et le bit *Don't Fragment* interdit de fragmenter → **il échoue** (message d'erreur ou perte selon la variante).

Si l'underlay est déjà à 1450 (overlay sous Proxmox), les deux seuils se décalent de 50 octets : 1372 passe, 1422 échoue.

**2. Combien de segments VXLAN distincts peut-on créer ? Comparez au VLAN.**

Environ 16,7 millions (VNI sur 24 bits), contre 4094 VLAN (12 bits). C'est la réponse de VXLAN au cloud multi-locataire.

**3. Qui « sait » où se trouve la machine distante ? Que ferait EVPN ou un contrôleur ?**

Personne ne l'a appris dynamiquement : le pont apprend l'adresse MAC de vmB en voyant arriver le trafic par le tunnel, et l'adresse du VTEP d'en face a été écrite à la main (`remote_ip`). EVPN l'annoncerait par une route de type 2 (MAC/IP) ; un contrôleur SDN programmerait directement chaque VTEP.

**4. Pourquoi les plugins Kubernetes en mode VXLAN fixent-ils le MTU des pods à 1 450 ?**

Pour absorber les 50 octets de l'en-tête VXLAN sur un underlay à 1500, et éviter la fragmentation — exactement l'expérience que vous venez de faire.

**5. Un second segment (VNI 5020) : que modifier, qu'est-ce qui garantit l'isolement ?**

Ajouter un port VXLAN avec `options:key=5020`, **sur un second pont**. C'est le VNI (la clé) qui garantit l'isolement : deux VNI différents = deux segments de niveau 2 séparés. Si le port 5020 était ajouté au même `br-ovl` que le port 5010, le pont relierait les deux tunnels et les deux segments n'en feraient plus qu'un.

## Erreurs fréquentes

- **Rien ne passe entre vmA et vmB** : le port UDP 4789 est filtré entre lab-a et lab-b (règle de la plateforme, pare-feu local). Diagnostic : `tcpdump udp port 4789` sur les deux machines.
- **`local_ip` et `remote_ip` recopiés tels quels de lab-a sur lab-b**, donc inversés : chaque machine s'envoie à elle-même.
- **Variable `IF` vide** (nom d'interface non détecté) : la capture reste muette alors que le ping fonctionne.

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
