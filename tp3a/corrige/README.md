# Corrigé du TP3-A

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Questions

**1. ONOS compte 8 liens pour 4 câbles entre switches : pourquoi ?**

ONOS compte les liens de façon orientée : chaque câble entre deux switches donne deux liens, un dans chaque sens. Quatre câbles de l'anneau → huit liens.

**2. Comment ONOS découvre-t-il les liens ?**

Par LLDP. ONOS émet une trame LLDP en `PACKET_OUT` sur chaque port de switch ; le switch voisin la reçoit et, n'ayant pas de règle pour elle, la remonte au contrôleur en `PACKET_IN`. ONOS en déduit : « le port X de ce switch est relié au port Y de ce voisin ». Il répète la mesure en continu pour détecter les pannes.

**3. Quelle application a posé les règles vues après `pingall` ?**

L'application de routage réactif `org.onosproject.fwd` : au premier paquet d'un hôte vers un autre, elle calcule le chemin et installe les flux correspondants sur les switches. Avant `pingall`, la table de s1 ne contient que les flux par défaut (LLDP, remontée au contrôleur).

---

[Énoncé](../README.md) · [Sommaire](../../README.md)
