#!/usr/bin/env bash
# Capstone — infrastructure côté lab-b : switch s2 (contrôlé par l'ONOS de lab-a) + machines recette/admin + un bout du tunnel.
# À lancer SUR lab-b :  sudo bash infra_lab_b.sh <IP_LAB_A> <IP_LAB_B>
set -euo pipefail
A="${1:?Usage: sudo bash infra_lab_b.sh <IP_LAB_A> <IP_LAB_B>}"
B="${2:?Usage: sudo bash infra_lab_b.sh <IP_LAB_A> <IP_LAB_B>}"

echo ">> Nettoyage d'un essai précédent"
for ns in h3 h4; do ip netns del "$ns" 2>/dev/null || true; done
ovs-vsctl --if-exists del-br br-b

echo ">> Switch s2 (br-b, dpid ...0002), piloté par l'ONOS de lab-a ($A:6653)"
ovs-vsctl add-br br-b
ovs-vsctl set bridge br-b other-config:datapath-id=0000000000000002
ovs-vsctl set bridge br-b protocols=OpenFlow13
ovs-vsctl set-fail-mode br-b secure
ovs-vsctl set-controller br-b tcp:"$A":6653

ajoute_machine() {   # <nom> <ip> <mac> <ofport>
  local n="$1" ip="$2" mac="$3" of="$4"
  ip netns add "$n"
  ip link add "$n-eth0" type veth peer name "$n-port"
  ip link set "$n-eth0" netns "$n"
  ovs-vsctl add-port br-b "$n-port" -- set interface "$n-port" ofport_request="$of"
  ip link set "$n-port" up
  ip -n "$n" link set lo up
  ip -n "$n" link set "$n-eth0" address "$mac"
  ip -n "$n" link set "$n-eth0" mtu 1450     # marge pour l'encapsulation VXLAN (50 octets)
  ip -n "$n" addr add "$ip/24" dev "$n-eth0"
  ip -n "$n" link set "$n-eth0" up
}
echo ">> Machines de lab-b : h3 (recette, 10.0.0.3) et h4 (admin, 10.0.0.4)"
ajoute_machine h3 10.0.0.3 00:00:00:00:00:03 3
ajoute_machine h4 10.0.0.4 00:00:00:00:00:04 4

echo ">> Tunnel VXLAN vers lab-a (VNI 4000, ofport 10)"
ovs-vsctl add-port br-b vxlan0 \
  -- set interface vxlan0 type=vxlan options:local_ip="$B" options:remote_ip="$A" options:key=4000 ofport_request=10

echo "OK. lab-b prêt : s2 + h3/h4 + tunnel vers $A, contrôleur = $A:6653."
