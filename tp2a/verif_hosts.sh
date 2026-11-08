#!/usr/bin/env bash
# verif_hosts.sh — vérifie les 4 machines du TP2-A (namespace, adresse, VLAN d'accès).
# À lancer avec : sudo bash verif_hosts.sh
#
# Convention de nommage attendue : pour une machine « X »
#   - namespace : X
#   - interface côté machine : X-eth0
#   - port côté commutateur : X-port (en accès sur son VLAN)

# machine vlan ip
LIGNES="dev1 10 10.10.10.11
dev2 10 10.10.10.12
rec1 20 10.10.20.11
prd1 30 10.10.30.11"

ok=0; ko=0
while read -r nom vlan ip; do
  err=""
  ip netns list | grep -qw "$nom" || err="namespace $nom absent"
  if [ -z "$err" ] && ! ip -n "$nom" addr show dev "$nom-eth0" 2>/dev/null | grep -q "$ip"; then
    err="adresse $ip absente sur $nom-eth0"
  fi
  if [ -z "$err" ] && [ "$(ovs-vsctl get Port "$nom-port" tag 2>/dev/null)" != "$vlan" ]; then
    err="port $nom-port pas en accès VLAN $vlan"
  fi
  if [ -z "$err" ]; then echo "  [ OK ] $nom"; ok=$((ok + 1)); else echo "  [ECHEC] $nom : $err"; ko=$((ko + 1)); fi
done <<< "$LIGNES"

echo "$ok OK, $ko en echec"
[ "$ko" -eq 0 ]
