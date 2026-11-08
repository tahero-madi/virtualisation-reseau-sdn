#!/usr/bin/env bash
set -euo pipefail

# Retirer l'ancien port de la configuration OVS
ovs-vsctl --if-exists del-port br-lab fw-port

# Arrêter les processus du TP et supprimer les deux namespaces
for ns in fw srv; do
    if ip -n "$ns" link show >/dev/null 2>&1; then
        ip netns pids "$ns" | xargs -r kill
        ip netns del "$ns"
    fi
done

# Nettoyer d'éventuelles interfaces restées sur l'hôte
# après une création interrompue
for iface in fw-port fw-dev fw-prod srv-eth0; do
    if ip link show dev "$iface" >/dev/null 2>&1; then
        ip link del dev "$iface"
    fi
done

ip -n h1 -4 route flush exact default
ip -n h2 -4 route flush exact default
