#!/usr/bin/env bash
# Capstone — infrastructure côté lab-a : ONOS + switch s1 + machines dev/prod + un bout du tunnel.
# À lancer SUR lab-a :  sudo bash infra_lab_a.sh <IP_LAB_A> <IP_LAB_B>
set -euo pipefail
A="${1:?Usage: sudo bash infra_lab_a.sh <IP_LAB_A> <IP_LAB_B>}"
B="${2:?Usage: sudo bash infra_lab_a.sh <IP_LAB_A> <IP_LAB_B>}"

echo ">> Nettoyage d'un essai précédent"
for ns in h1 h2; do ip netns del "$ns" 2>/dev/null || true; done
ovs-vsctl --if-exists del-br br-a
docker rm -f onos 2>/dev/null || true

echo ">> Lancement d'ONOS (1 à 2 min de démarrage)"
docker run -d --name onos -p 8181:8181 -p 8101:8101 -p 6653:6653 \
  -e ONOS_APPS=drivers,openflow,fwd,proxyarp,gui2 onosproject/onos:2.7.0 >/dev/null
until curl -sf -u onos:rocks http://localhost:8181/onos/v1/applications >/dev/null; do sleep 5; done
echo "   ONOS prêt."

echo ">> Switch s1 (br-a, dpid ...0001), piloté par l'ONOS local"
ovs-vsctl add-br br-a
ovs-vsctl set bridge br-a other-config:datapath-id=0000000000000001
ovs-vsctl set bridge br-a protocols=OpenFlow13
ovs-vsctl set-fail-mode br-a secure
ovs-vsctl set-controller br-a tcp:127.0.0.1:6653

ajoute_machine() {   # <nom> <ip> <mac> <ofport>
  local n="$1" ip="$2" mac="$3" of="$4"
  ip netns add "$n"
  ip link add "$n-eth0" type veth peer name "$n-port"
  ip link set "$n-eth0" netns "$n"
  ovs-vsctl add-port br-a "$n-port" -- set interface "$n-port" ofport_request="$of"
  ip link set "$n-port" up
  ip -n "$n" link set lo up
  ip -n "$n" link set "$n-eth0" address "$mac"
  ip -n "$n" link set "$n-eth0" mtu 1450     # marge pour l'encapsulation VXLAN (50 octets)
  ip -n "$n" addr add "$ip/24" dev "$n-eth0"
  ip -n "$n" link set "$n-eth0" up
}
echo ">> Machines de lab-a : h1 (dev, 10.0.0.1) et h2 (prod, 10.0.0.2)"
ajoute_machine h1 10.0.0.1 00:00:00:00:00:01 1
ajoute_machine h2 10.0.0.2 00:00:00:00:00:02 2

echo ">> Tunnel VXLAN vers lab-b (VNI 4000, ofport 10)"
ovs-vsctl add-port br-a vxlan0 \
  -- set interface vxlan0 type=vxlan options:local_ip="$A" options:remote_ip="$B" options:key=4000 ofport_request=10

echo "OK. lab-a prêt : ONOS + s1 + h1/h2 + tunnel vers $B."
