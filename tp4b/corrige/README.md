# Corrigé du TP4-B

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Questions

**1. Quelles paires échouent au `pingall`, et pourquoi ?**

La paire **h1–h3** : la liste `DENY = [("10.0.0.3", "10.0.0.1")]` installe un flux de blocage de h3 vers h1 dès la connexion du switch (mode proactif). Le reste passe, une fois les adresses MAC apprises (mode réactif).

**2. Quels types de messages compte tshark ? Lien avec le chapitre 16.**

Les types du protocole OpenFlow : `Hello`, `Features Request`/`Reply`, `Packet-In`, `Packet-Out`, `Flow-Mod`, etc. On retrouve le dialogue décrit au chapitre 16 : la poignée de main, puis les remontées `Packet-In` et les poses de règles `Flow-Mod`.

**3. Combien de règles `dump-flows` montre-t-il après `pingall`, et avec quelles priorités ?**

Trois familles : le *table-miss* (priorité 0, action « remonter au contrôleur »), les règles de blocage `DENY` (priorité 100, action vide = drop), et les flux installés réactivement pour chaque couple d'adresses appris (priorité 10, `idle_timeout` 30 s, qui disparaissent donc après 30 s sans trafic).

## Exercices, au choix

1. **ICMP seul** : `OFPMatch(eth_type=0x0800, ip_proto=1, icmpv4_type=8, ipv4_src="10.0.0.3", ipv4_dst="10.0.0.1")` — ne bloque que les echo-requests de h3 vers h1, les réponses reviennent (même piège qu'au TP4-A).
2. **`DENY` depuis un YAML** : lire un fichier versionné au démarrage (`yaml.safe_load`) et construire la liste, pour changer la politique sans toucher au code.
3. **Journaliser les MAC** : dans `on_packet_in`, à chaque nouvelle entrée de `mac_to_port`, un `self.logger.info("appris %s sur le port %s", eth.src, in_port)`.
4. **Statistiques (chapitre 17)** : ajouter une seconde application qui interroge périodiquement les compteurs de flux, et lancer les deux ensemble : `lancer_controleur.py switch_acl.py stats.py`.

Avec Ryu au lieu d'os-ken : remplacer `os_ken` par `ryu`, `OSKenApp` par `RyuApp`, et lancer avec `ryu-manager`.

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
