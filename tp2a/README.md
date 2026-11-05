# TP2-A — VLAN, routage et filtrage entre zones

**Jour 1, 13:30 · 65 min.** Objectif : isoler les zones par VLAN et les relier par un routeur qui filtre. Support : chapitres 5 à 8. Commencez par `sudo bash reset_lab.sh`.

```bash
#!/usr/bin/env bash
# tp2a.sh — segmentation dev / recette / prod sur Open vSwitch
set -euo pipefail
BR=br-vlan
sudo ovs-vsctl --may-exist add-br $BR

# host <nom> <vlan> <ip/masque> <passerelle>
host() {
  sudo ip netns add $1
  sudo ip link add $1-eth0 type veth peer name $1-p
  sudo ip link set $1-eth0 netns $1
  sudo ovs-vsctl add-port $BR $1-p tag=$2
  sudo ip link set $1-p up
  sudo ip -n $1 addr add $3 dev $1-eth0
  sudo ip -n $1 link set $1-eth0 up
  sudo ip -n $1 link set lo up
  sudo ip -n $1 route add default via $4
}
host dev1 10 10.10.10.11/24 10.10.10.254
host dev2 10 10.10.10.12/24 10.10.10.254
host rec1 20 10.10.20.11/24 10.10.20.254
host prd1 30 10.10.30.11/24 10.10.30.254
```

Vérifier l'isolement : `sudo ip netns exec dev1 ping -c 2 10.10.10.12` doit réussir, `sudo ip netns exec dev1 ping -c 2 10.10.20.11` doit échouer.

Ajouter un routeur raccordé en trunk :

```bash
sudo ip netns add rtr
sudo ip link add rtr-eth0 type veth peer name rtr-p
sudo ip link set rtr-eth0 netns rtr
sudo ovs-vsctl add-port br-vlan rtr-p trunks=10,20,30
sudo ip link set rtr-p up
sudo ip -n rtr link set rtr-eth0 up
for v in 10 20 30; do
  sudo ip -n rtr link add link rtr-eth0 name rtr-eth0.$v type vlan id $v
  sudo ip -n rtr addr add 10.10.$v.254/24 dev rtr-eth0.$v
  sudo ip -n rtr link set rtr-eth0.$v up
done
sudo ip netns exec rtr sysctl -w net.ipv4.ip_forward=1
```

Lire la norme dans le paquet :

```bash
sudo ip netns exec dev1 ping -c 20 10.10.30.11 > /dev/null &
sudo tcpdump -e -n -i rtr-p -c 4 icmp
```

Appliquer une politique entre zones :

```bash
sudo ip netns exec rtr nft -f - <<'EOF'
table inet zones {
  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    iifname "rtr-eth0.10" oifname "rtr-eth0.20" accept
    iifname "rtr-eth0.20" oifname "rtr-eth0.30" tcp dport 443 accept
    iifname "rtr-eth0.20" oifname "rtr-eth0.30" icmp type echo-request accept
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
sudo ovsdb-client list-tables
sudo ovsdb-client dump Open_vSwitch Port name tag trunks
sudo ovsdb-client monitor Open_vSwitch Port name tag   # dans un 2e terminal, puis ajoutez un port
```

Questions :

1. Combien de VLAN au maximum ? Pourquoi est-ce insuffisant pour un cloud multi-locataire ?
2. Que voit-on dans `ovsdb-client monitor` quand on ajoute un port ? Qui, en production, s'abonne à ces événements ?
3. Aucune règle n'autorise prod vers recette : pourquoi prd1 répond-il pourtant aux pings de rec1 ?
4. Dans la capture, quelle valeur d'EtherType signale l'étiquette, et quels numéros de VLAN voyez-vous ?

Livrables : `tp2a.sh` et `zones.nft`, commités.
