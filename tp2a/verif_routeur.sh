#!/usr/bin/env bash
# verif_routeur.sh — vérifie le routeur sur un bâton du TP2-A.
# À lancer avec : sudo bash verif_routeur.sh

ok=0; ko=0

if [ "$(ip netns exec rtr sysctl -n net.ipv4.ip_forward 2>/dev/null)" = "1" ]; then
  echo "  [ OK ] routage (ip_forward) actif dans rtr"; ok=$((ok + 1))
else
  echo "  [ECHEC] ip_forward inactif dans rtr"; ko=$((ko + 1))
fi

if ovs-vsctl get Port rtr-port trunks 2>/dev/null | grep -q 10; then
  echo "  [ OK ] rtr-port raccordé en trunk"; ok=$((ok + 1))
else
  echo "  [ECHEC] rtr-port pas en trunk 10,20,30"; ko=$((ko + 1))
fi

for v in 10 20 30; do
  if ip -n rtr addr show dev "rtr-eth0.$v" 2>/dev/null | grep -q "10.10.$v.254"; then
    echo "  [ OK ] rtr-eth0.$v porte 10.10.$v.254"; ok=$((ok + 1))
  else
    echo "  [ECHEC] rtr-eth0.$v / 10.10.$v.254 manquante"; ko=$((ko + 1))
  fi
done

echo "$ok OK, $ko en echec"
[ "$ko" -eq 0 ]
