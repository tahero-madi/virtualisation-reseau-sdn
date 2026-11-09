#!/usr/bin/env bash
# verif_prevol.sh — vérifie qu'une paire lab-a / lab-b supporte le projet final distribué.
# À lancer SUR lab-b, avec ONOS DÉJÀ démarré sur lab-a.
# Usage : sudo bash verif_prevol.sh <IP_LAB_A>
A="${1:?Usage: sudo bash verif_prevol.sh <IP_LAB_A>}"
ok=0; ko=0
res() { if [ "$1" = ok ]; then echo "  [ OK ] $2"; ok=$((ok + 1)); else echo "  [ECHEC] $2"; ko=$((ko + 1)); fi; }

ping -c1 -W2 "$A" >/dev/null 2>&1 && res ok "ping lab-a ($A)" || res ko "ping lab-a ($A)"
timeout 3 bash -c "echo > /dev/tcp/$A/6653" 2>/dev/null \
  && res ok "TCP 6653 vers lab-a (session OpenFlow possible)" \
  || res ko "TCP 6653 vers lab-a — ONOS doit tourner sur lab-a, et le port être ouvert"
ovs-vsctl --version >/dev/null 2>&1 && res ok "Open vSwitch installé" || res ko "Open vSwitch installé (lancer preparation_vm.sh --secondaire)"
if modprobe vxlan 2>/dev/null && ip link add tmpvx type vxlan id 1 dstport 4789 2>/dev/null; then
  ip link del tmpvx 2>/dev/null || true; res ok "support VXLAN du noyau (UDP 4789)"
else
  res ko "support VXLAN du noyau"
fi

IF=$(ip -o route get "$A" 2>/dev/null | grep -oP '(?<=dev )\S+' | head -1)
[ -n "$IF" ] && echo "  [info] interface du LAN : $IF, MTU $(cat "/sys/class/net/$IF/mtu" 2>/dev/null) — prévoir 1450 côté overlay"
echo "  [info] l'isolement UDP 4789 bidirectionnel est déjà éprouvé au TP2-B ; rejouez-le en cas de doute."

echo "$ok OK, $ko en echec"
[ "$ko" -eq 0 ]
