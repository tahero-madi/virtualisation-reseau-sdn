#!/usr/bin/env bash
# preparation_lab.sh — Ubuntu 24.04, exécuté une fois par VM
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y openvswitch-switch mininet iproute2 nftables tcpdump tshark \
  iperf iperf3 curl jq git python3-venv python3-yaml python3-requests docker.io
sudo usermod -aG docker "$USER"

# Images et bibliothèques des modules 1, 3 et 4
sudo docker pull onosproject/onos:2.7.0
sudo docker pull alpine:3.20
python3 -m venv ~/osken && ~/osken/bin/pip install os-ken pyyaml requests

# Contrôles
sudo ovs-vsctl --version | head -1
sudo mn --switch ovsbr --controller none --test pingall
~/osken/bin/python -c "import os_ken; print('os-ken OK')"
