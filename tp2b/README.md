# TP2-B — Overlay VXLAN entre deux hyperviseurs

**Jour 1, 14:45 · 65 min · sur lab-a et lab-b.** Objectif : étendre un segment de niveau 2 entre deux hyperviseurs par un overlay VXLAN. Support : chapitres 5 à 8.

Relier deux « VM » hébergées sur deux hyperviseurs dans un même segment de niveau 2, au-dessus d'un réseau IP. Ici, les deux hyperviseurs sont vos machines lab-a et lab-b, et le réseau IP est le LAN de votre environnement.

**Préparer lab-b.** lab-b est aussi un Ubuntu 24.04 vierge. Installez-y les outils réseau — rapide, sans image ONOS :

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tahero-madi/virtualisation-reseau-sdn.git ~/lab
cd ~/lab
sudo bash infra/preparation_vm.sh --secondaire
```

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
