# TP2 — Segmenter, router, relier par un overlay

Objectif : isoler les zones par VLAN, les relier par un routeur qui filtre, puis étendre un segment entre deux hyperviseurs par VXLAN. Chapitres 5 à 8. Durée indicative : 2 h 10. Commencez par `sudo bash reset_lab.sh`.

## TP2-A — VLAN, routage et filtrage entre zones

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

## TP2-B — Overlay VXLAN entre deux hyperviseurs

Relier deux « VM » hébergées sur deux hyperviseurs dans un même segment de niveau 2, au-dessus d'un réseau IP. Ici, les deux hyperviseurs sont vos machines lab-a et lab-b, et le réseau IP est le LAN de votre environnement.

**Sur vos deux machines (Open vSwitch).** Relevez d'abord l'adresse LAN de chacune avec `ip -br a`. Prenez un instantané de lab-a et de lab-b. Lancez le bloc sur lab-a, puis sur lab-b en inversant `LOCAL` et `REMOTE` et en changeant la ligne `MOI` (`vmB`, 172.16.10.2) :

```bash
LOCAL=10.10.0.11; REMOTE=10.10.0.12      # adresse LAN de cette machine, puis de l'autre (ip -br a)
IF=$(ip -o route get $REMOTE | grep -oP '(?<=dev )\S+'); echo "interface du LAN : $IF"
MOI=vmA; IP=172.16.10.1; AUTRE=172.16.10.2   # sur lab-b : MOI=vmB; IP=172.16.10.2; AUTRE=172.16.10.1

sudo ovs-vsctl add-br br-ovl
sudo ovs-vsctl add-port br-ovl vx5010 -- set interface vx5010 type=vxlan \
     options:local_ip=$LOCAL options:remote_ip=$REMOTE options:key=5010
sudo ip netns add $MOI
sudo ip link add $MOI-eth0 type veth peer name $MOI-p
sudo ip link set $MOI-eth0 netns $MOI
sudo ovs-vsctl add-port br-ovl $MOI-p && sudo ip link set $MOI-p up
sudo ip -n $MOI addr add $IP/24 dev $MOI-eth0
sudo ip -n $MOI link set $MOI-eth0 up

sudo ip netns exec $MOI ping -c 3 $AUTRE
sudo tcpdump -n -i $IF -c 4 udp port 4789
sudo tshark -i $IF -f 'udp port 4789' -c 2 -V | grep -A 4 'Virtual eXtensible'
```

**Variante seule (VXLAN natif Linux), si lab-b n'est pas disponible.** Sur lab-a, deux namespaces jouent les hyperviseurs :

```bash
sudo ip netns add hv1; sudo ip netns add hv2
sudo ip link add u1 type veth peer name u2
sudo ip link set u1 netns hv1; sudo ip link set u2 netns hv2
sudo ip -n hv1 addr add 192.168.100.1/24 dev u1; sudo ip -n hv1 link set u1 up
sudo ip -n hv2 addr add 192.168.100.2/24 dev u2; sudo ip -n hv2 link set u2 up

for i in 1 2; do
  peer=$((3 - i))
  sudo ip -n hv$i link add vx5010 type vxlan id 5010 dstport 4789 \
       local 192.168.100.$i remote 192.168.100.$peer dev u$i
  sudo ip -n hv$i link add br0 type bridge
  sudo ip -n hv$i link set vx5010 master br0
  sudo ip netns add vm$i
  sudo ip link add vm$i-eth0 type veth peer name tap$i
  sudo ip link set vm$i-eth0 netns vm$i
  sudo ip link set tap$i netns hv$i
  sudo ip -n hv$i link set tap$i master br0
  for d in vx5010 br0 tap$i; do sudo ip -n hv$i link set $d up; done
  sudo ip -n vm$i addr add 172.16.10.$i/24 dev vm$i-eth0
  sudo ip -n vm$i link set vm$i-eth0 up
done

sudo ip netns exec vm1 ping -c 3 172.16.10.2
sudo ip netns exec hv1 tcpdump -n -i u1 -c 4 udp port 4789
```

**L'expérience MTU**, sur lab-a (variante seule : `vm1` au lieu de `vmA`) :

```bash
sudo ip netns exec vmA ping -c 2 -M do -s 1422 172.16.10.2
sudo ip netns exec vmA ping -c 2 -M do -s 1472 172.16.10.2
```

Questions :

1. Quel est le résultat de chacun des deux pings ? Expliquez par le calcul.
2. Combien de segments VXLAN distincts peut-on créer ? Comparez au VLAN.
3. Ici, qui « sait » où se trouve la machine distante ? Que ferait EVPN ou un contrôleur à la place ?
4. Pourquoi les plugins Kubernetes en mode VXLAN fixent-ils le MTU des pods à 1 450 ?
5. Ajoutez un second segment (VNI 5020) : que faut-il modifier, et qu'est-ce qui garantit l'isolement entre 5010 et 5020 ?

Livrables : `tp2b.sh` et la capture `vxlan.pcap` annotée (VNI, port UDP, en-têtes externe et interne).

---

[← TP1](tp1-reseau-virtuel-et-vnf.md) · [Sommaire](../README.md) · [TP3 →](tp3-controleur-onos.md)
