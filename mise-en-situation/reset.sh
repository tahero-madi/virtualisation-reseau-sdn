#!/usr/bin/env bash
# reset.sh — remet une machine (lab-a OU lab-b) à zéro pour le projet final.
# Nettoie ce qui existe sur la machine où on le lance.
# À lancer avec : sudo bash reset.sh
set -u

# Les machines (namespaces) : les supprimer retire aussi leurs câbles veth.
for ns in h1 h2 h3 h4; do
  ip netns del "$ns" 2>/dev/null || true
done

# Les switches : les supprimer retire aussi leurs ports (dont le tunnel VXLAN).
for br in br-a br-b; do
  ovs-vsctl --if-exists del-br "$br"
done

# Le contrôleur (présent seulement sur lab-a).
docker rm -f onos 2>/dev/null || true

# Filet de sécurité : interfaces éventuellement restées après un essai interrompu.
for i in h1-port h2-port h3-port h4-port vxlan0; do
  ip link show dev "$i" >/dev/null 2>&1 && ip link del dev "$i" 2>/dev/null || true
done

echo "Machine remise à zéro pour le projet final."
