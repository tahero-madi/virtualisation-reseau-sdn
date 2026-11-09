# Corrigé — Projet final SDN multi-sites

> Solution de référence et commandes de preuve. Les étudiants montent tout eux-mêmes ; ces scripts sont la référence du formateur.

## Pré-vol (formateur)

Avant la session, sur une vraie paire lab-a/lab-b : lancer ONOS sur lab-a, puis sur lab-b `sudo bash verif_prevol.sh <IP_LAB_A>` — ping, TCP 6653, Open vSwitch et support VXLAN doivent être tous `[ OK ]`.

## 1. Monter l'infrastructure

Scripts de référence fournis dans ce dossier (ce sont eux que les étudiants doivent reconstituer) :

```bash
# sur lab-a
sudo bash infra_lab_a.sh <IP_LAB_A> <IP_LAB_B>    # ONOS + s1 + h1 (dev) + h2 (prod) + tunnel
# sur lab-b
sudo bash infra_lab_b.sh <IP_LAB_A> <IP_LAB_B>    # s2 + h3 (recette) + h4 (admin) + tunnel
```

Points clés attendus dans leur montage : switches en OpenFlow 1.3 + fail-mode `secure` + dpid fixés ; tunnel VXLAN VNI 4000 entre `br-a` et `br-b` ; machines en `/24` commun, MTU 1450 ; `ofport_request` pour des numéros de ports déterministes.

Vérifier qu'ONOS voit les deux sites :

```bash
curl -s -u onos:rocks http://localhost:8181/onos/v1/devices | jq -r '.devices[].id'   # ...0001 et ...0002
curl -s -u onos:rocks http://localhost:8181/onos/v1/links   | jq '.links | length'     # >= 2
```

## 2. Passer en défaut-refus

```text
onos> app deactivate org.onosproject.fwd
```

ou en REST : `curl -s -u onos:rocks -X DELETE http://localhost:8181/onos/v1/applications/org.onosproject.fwd/active`. On **garde `proxyarp`** actif, sinon l'ARP ne traverse pas et les hôtes ne se découvrent pas entre sites.

## 3. Déclarer la politique par intentions

Voir [`politique_multisite.sh`](politique_multisite.sh) : cinq `HostToHostIntent` posées par l'API REST — dev↔prod, recette↔prod, admin↔dev, admin↔prod, admin↔recette. La paire **dev↔recette n'est pas déclarée**, donc interdite par le défaut-refus. Chaque appel renvoie **201** ; `onos> intents` doit montrer 5 intentions **INSTALLED**.

## 4. Prouver

**La matrice.** Depuis lab-a pour h1/h2, depuis lab-b pour h3/h4 :

```bash
# sur lab-a
for d in 10.0.0.1 10.0.0.2 10.0.0.3 10.0.0.4; do
  sudo ip netns exec h1 ping -c1 -W1 $d >/dev/null 2>&1 && echo "dev -> $d OK" || echo "dev -> $d ---"
done
# attendu : dev -> prod (.2) OK, admin (.4) OK ; dev -> recette (.3) ---
```

**Le trafic est inter-sites et encapsulé.** Sur lab-a, pendant un ping dev → admin (h4, sur lab-b) :

```bash
IF=$(ip -o route get <IP_LAB_B> | grep -oP '(?<=dev )\S+' | head -1)
sudo tcpdump -n -i "$IF" -c 4 udp port 4789 &
sudo ip netns exec h1 ping -c 3 10.0.0.4
```

On voit les paquets VXLAN (UDP 4789) : le trafic passe bien par le tunnel entre les deux hyperviseurs.

**La topologie vue par ONOS** : 2 devices (`...0001`, `...0002`), le lien s1↔s2, 4 hôtes localisés chacun sur son switch.

## Notes de mise au point

- Lien s1↔s2 absent d'ONOS : vérifier que `vxlan0` est `up` des deux côtés, que `local_ip`/`remote_ip` ne sont pas inversés, et que les deux switches sont bien connectés au contrôleur (le lien n'apparaît qu'ensuite, via LLDP encapsulé dans le tunnel).
- Hôtes absents : ils se révèlent au premier paquet ; `proxyarp` doit rester actif.
- `fwd` réactivé par erreur rouvrirait tout : vérifier `onos> apps -a -s` après avoir posé la politique.
- Repartir propre entre deux essais : `sudo bash ../reset.sh` sur chaque machine.
