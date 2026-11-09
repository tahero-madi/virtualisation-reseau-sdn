# Corrigé — Capstone SDN multi-sites

> Cherchez d'abord par vous-même : ce corrigé donne la solution de référence et les commandes de preuve.

## 1. Passer en défaut-refus

On coupe l'acheminement automatique. Plus rien ne passe tant qu'aucune intention n'est posée.

```text
onos> app deactivate org.onosproject.fwd
```

Équivalent par l'API REST :

```bash
curl -s -u onos:rocks -X DELETE http://localhost:8181/onos/v1/applications/org.onosproject.fwd/active
```

On **garde `proxyarp`** actif : sans lui, l'ARP ne traverserait pas et les hôtes ne se découvriraient pas entre sites.

## 2. Déclarer la politique par intentions — `politique_multisite.sh`

```bash
#!/usr/bin/env bash
# politique_multisite.sh — déclare la connectivité autorisée par l'API REST d'ONOS.
# À lancer sur lab-a : sudo bash politique_multisite.sh
set -euo pipefail
API=http://localhost:8181/onos/v1; AUTH=onos:rocks
DEV=00:00:00:00:00:01; PROD=00:00:00:00:00:02; REC=00:00:00:00:00:03; ADM=00:00:00:00:00:04

autoriser() {   # <mac1> <mac2>
  curl -s -u "$AUTH" -X POST -H 'Content-Type: application/json' "$API/intents" \
    -d "{\"type\":\"HostToHostIntent\",\"appId\":\"org.onosproject.cli\",\"priority\":100,
         \"one\":\"$1/None\",\"two\":\"$2/None\"}" \
    -o /dev/null -w "intent %{http_code} : $1 <-> $2\n"
}

autoriser "$DEV"  "$PROD"    # dev  <-> prod
autoriser "$REC"  "$PROD"    # recette <-> prod
autoriser "$ADM"  "$DEV"     # admin <-> dev
autoriser "$ADM"  "$PROD"    # admin <-> prod
autoriser "$ADM"  "$REC"     # admin <-> recette
# dev <-> recette : AUCUNE intention déclarée -> interdit par le défaut-refus
```

Chaque appel doit renvoyer **201**. Vérifier l'état :

```text
onos> intents          # 5 intentions, toutes INSTALLED
```

## 3. Prouver

**La matrice de connectivité.** Depuis lab-a pour h1/h2, depuis lab-b pour h3/h4 :

```bash
# sur lab-a
for d in 10.0.0.1 10.0.0.2 10.0.0.3 10.0.0.4; do
  sudo ip netns exec h1 ping -c1 -W1 $d >/dev/null 2>&1 && echo "dev -> $d OK" || echo "dev -> $d ---"
done
# attendu : dev -> .2 (prod) OK, .4 (admin) OK ; dev -> .3 (recette) --- ; 

# sur lab-b
for d in 10.0.0.1 10.0.0.2 10.0.0.3 10.0.0.4; do
  sudo ip netns exec h3 ping -c1 -W1 $d >/dev/null 2>&1 && echo "recette -> $d OK" || echo "recette -> $d ---"
done
# attendu : recette -> .2 (prod) OK, .4 (admin) OK ; recette -> .1 (dev) --- ;
```

Résultat attendu : dev↔recette bloqué, tout le reste des paires déclarées passe.

**Le trafic est bien inter-sites et encapsulé.** Sur lab-a, pendant un ping dev → recette… non, dev→recette est bloqué ; prenez une paire autorisée entre sites, dev → admin (h4, sur lab-b) :

```bash
IF=$(ip -o route get <IP_LAB_B> | grep -oP '(?<=dev )\S+' | head -1)
sudo tcpdump -n -i "$IF" -c 4 udp port 4789 &
sudo ip netns exec h1 ping -c 3 10.0.0.4       # dev (lab-a) -> admin (lab-b)
```

On voit les paquets VXLAN (UDP 4789) : la preuve que le trafic passe par le tunnel entre les deux hyperviseurs.

**La topologie vue par ONOS** (interface web ou API) : 2 devices (`...0001`, `...0002`), le lien s1↔s2, 4 hôtes localisés chacun sur son switch.

## 4. Pour aller plus loin

- **recette → prod seulement en 443.** Remplacer l'intention host-to-host recette↔prod par une `PointToPointIntent` orientée avec un sélecteur L4 (`ethType=IPV4, ipProto=TCP, tcpDst=443`), dans les deux sens, entre les points de connexion de h3 et h2. C'est l'étape qui dépasse la granularité « machine à machine » des host intents.
- **Miroir vers la sonde.** Un switch piloté par ONOS ne se programme pas à la main avec `ovs-ofctl` sans entrer en conflit avec le contrôleur ; la copie se pose via une règle de flux POSTée à l'API (`/flows`) avec deux actions de sortie, ou via une application dédiée.
- **Résilience.** Avec un lien unique, couper le tunnel isole les sites (rien à recalculer). Pour montrer la résilience, ajouter un **second tunnel** sur un autre chemin d'underlay : ONOS disposerait de deux liens et rebasculerait seul, comme au TP3-B.

## Notes de mise au point (formateur)

- Si ONOS ne montre pas le lien s1↔s2 : vérifier que le port `vxlan0` est bien `up` des deux côtés, que `local_ip`/`remote_ip` ne sont pas inversés, et que la découverte LLDP est active (apps `openflow`). Le lien n'apparaît qu'une fois les deux switches connectés au contrôleur.
- Si les hôtes n'apparaissent pas : ils sont découverts au premier paquet ; un ping (même échoué) les révèle. `proxyarp` doit rester actif.
- `fwd` réactivé par erreur rouvrirait tout : vérifier `onos> apps -a -s` après avoir posé la politique.
