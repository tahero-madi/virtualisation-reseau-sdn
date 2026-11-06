# TP2-A — VLAN, routage et filtrage entre zones

**Jour 1, 13:30 · 65 min.** Objectif : isoler les zones par VLAN et les relier par un routeur qui filtre. Support : chapitres 5 à 8. Commencez par `sudo bash reset_lab.sh`.

```bash
#!/usr/bin/env bash
# tp2a.sh — segmentation dev / recette / prod sur Open vSwitch
set -euo pipefail
BR=br-vlan
sudo ovs-vsctl --may-exist add-br $BR           # crée le commutateur br-vlan (sans erreur s'il existe déjà)

# host <nom> <vlan> <ip/masque> <passerelle> : crée une machine rattachée à un VLAN
host() {
  sudo ip netns add $1                          # la machine (namespace)
  sudo ip link add $1-eth0 type veth peer name $1-p   # son câble
  sudo ip link set $1-eth0 netns $1             # un bout dans la machine
  sudo ovs-vsctl add-port $BR $1-p tag=$2       # l'autre bout sur le switch, en accès VLAN $2 (étiquette)
  sudo ip link set $1-p up
  sudo ip -n $1 addr add $3 dev $1-eth0         # son adresse IP
  sudo ip -n $1 link set $1-eth0 up
  sudo ip -n $1 link set lo up
  sudo ip -n $1 route add default via $4        # sa passerelle = le routeur (ajouté plus bas)
}
host dev1 10 10.10.10.11/24 10.10.10.254        # zone dev     (VLAN 10)
host dev2 10 10.10.10.12/24 10.10.10.254        # zone dev     (VLAN 10)
host rec1 20 10.10.20.11/24 10.10.20.254        # zone recette (VLAN 20)
host prd1 30 10.10.30.11/24 10.10.30.254        # zone prod    (VLAN 30)
```

Vérifier l'isolement : `sudo ip netns exec dev1 ping -c 2 10.10.10.12` doit réussir, `sudo ip netns exec dev1 ping -c 2 10.10.20.11` doit échouer.

Ajouter un routeur raccordé en trunk :

```bash
sudo ip netns add rtr                                  # le routeur, à cheval sur les trois VLAN
sudo ip link add rtr-eth0 type veth peer name rtr-p    # son câble
sudo ip link set rtr-eth0 netns rtr
sudo ovs-vsctl add-port br-vlan rtr-p trunks=10,20,30  # port TRUNK : transporte les VLAN 10, 20 et 30 étiquetés
sudo ip link set rtr-p up
sudo ip -n rtr link set rtr-eth0 up
for v in 10 20 30; do
  sudo ip -n rtr link add link rtr-eth0 name rtr-eth0.$v type vlan id $v   # une sous-interface par VLAN
  sudo ip -n rtr addr add 10.10.$v.254/24 dev rtr-eth0.$v                  # la passerelle de ce VLAN
  sudo ip -n rtr link set rtr-eth0.$v up
done
sudo ip netns exec rtr sysctl -w net.ipv4.ip_forward=1  # active le routage entre les VLAN
```

Lire la norme dans le paquet :

```bash
sudo ip netns exec dev1 ping -c 20 10.10.30.11 > /dev/null &   # génère du trafic dev -> prod en fond
sudo tcpdump -e -n -i rtr-p -c 4 icmp                          # capture sur le trunk ; -e affiche l'étiquette VLAN 802.1Q
```

Appliquer une politique entre zones :

```bash
sudo ip netns exec rtr nft -f - <<'EOF'
table inet zones {
  chain forward {
    type filter hook forward priority 0; policy drop;                 # par défaut, aucune zone ne parle à une autre
    ct state established,related accept                               # laisser revenir les réponses des connexions acceptées
    iifname "rtr-eth0.10" oifname "rtr-eth0.20" accept                # dev -> recette : tout autorisé
    iifname "rtr-eth0.20" oifname "rtr-eth0.30" tcp dport 443 accept  # recette -> prod : seulement HTTPS (443)
    iifname "rtr-eth0.20" oifname "rtr-eth0.30" icmp type echo-request accept  # recette -> prod : ping autorisé
  }
}
EOF
```

| Test | Résultat attendu |
| --- | --- |
| dev1 → rec1 (ping) | Autorisé |
| dev1 → prd1 (ping) | Bloqué |
| rec1 → prd1 (ping) | Autorisé |
| prd1 → dev1 (ping) | Bloqué |

Où vit la configuration :

```bash
sudo ovsdb-client list-tables                             # les tables de la base de configuration d'OVS
sudo ovsdb-client dump Open_vSwitch Port name tag trunks  # tous les ports, leur VLAN d'accès (tag) ou de trunk
sudo ovsdb-client monitor Open_vSwitch Port name tag   # s'abonne aux changements en direct ; dans un 2e terminal, ajoutez un port
```

Questions :

1. Combien de VLAN au maximum ? Pourquoi est-ce insuffisant pour un cloud multi-locataire ?
2. Que voit-on dans `ovsdb-client monitor` quand on ajoute un port ? Qui, en production, s'abonne à ces événements ?
3. Aucune règle n'autorise prod vers recette : pourquoi prd1 répond-il pourtant aux pings de rec1 ?
4. Dans la capture, quelle valeur d'EtherType signale l'étiquette, et quels numéros de VLAN voyez-vous ?

Livrables : `tp2a.sh` et `zones.nft`, commités.
