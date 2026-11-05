#!/usr/bin/env bash
# reset_lab.sh — supprime TOUS les namespaces et bridges OVS : VM de lab uniquement
sudo mn -c > /dev/null 2>&1 || true
for ns in $(ip netns list | awk '{print $1}'); do sudo ip netns del "$ns"; done
for br in $(sudo ovs-vsctl list-br); do sudo ovs-vsctl del-br "$br"; done
sudo pkill -f 'http.server' || true
sudo docker rm -f onos > /dev/null 2>&1 || true
