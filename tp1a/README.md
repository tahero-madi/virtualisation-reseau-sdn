# TP1-A — Un réseau virtuel en dix commandes

**Jour 1, 09:40 · 45 min.** Objectif : construire un réseau virtuel isolé sur un hôte Linux, en une dizaine de commandes. Support : chapitres 3 et 4.

## Installation des outils (une seule fois, pour les deux jours)

Votre machine lab-a est un Ubuntu 24.04 vierge : le bureau et Firefox, mais aucun outil réseau. On les installe maintenant :

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tahero-madi/virtualisation-reseau-sdn.git ~/lab
cd ~/lab
sudo bash infra/preparation_vm.sh --kit "$PWD" --sans-bureau
```

On se place dans `~/lab` puis on lance avec un chemin relatif : sous `sudo`, un `~` pointerait vers `/root`, pas vers votre dossier. Le script installe tout le lab, en quelques minutes :

- **Open vSwitch** et **Mininet** — les commutateurs virtuels et les topologies ;
- **Docker** et l'image du contrôleur **ONOS 2.7.0**, utilisée au jour 2 ;
- un environnement Python **os-ken** dans `~/osken`, pour le jour 2 ;
- les outils d'observation : **nftables**, **tcpdump**, **tshark**, **iperf**, **jq**, **git**.

À la fin, le script affiche `Installation terminée : tout est prêt`, après une série de contrôles. Prenez alors un **instantané « outils installés »** : en cas de pépin pendant un TP, vous y reviendrez plutôt qu'à la machine vierge.

## L'exercice

Relier deux machines isolées, h1 et h2 (zone dev), par un commutateur Open vSwitch, puis observer ce que fait le commutateur.

```bash
# 1. Deux machines isolées et un commutateur virtuel
sudo ip netns add h1
sudo ip netns add h2
sudo ovs-vsctl add-br br-lab

# 2. Un câble virtuel par machine
for h in h1 h2; do
  sudo ip link add ${h}-eth0 type veth peer name ${h}-port
  sudo ip link set ${h}-eth0 netns $h
  sudo ovs-vsctl add-port br-lab ${h}-port
  sudo ip link set ${h}-port up
  sudo ip -n $h link set lo up
  sudo ip -n $h link set ${h}-eth0 up
done

# 3. Adressage et test
sudo ip -n h1 addr add 10.10.10.1/24 dev h1-eth0
sudo ip -n h2 addr add 10.10.10.2/24 dev h2-eth0
sudo ip netns exec h1 ping -c 3 10.10.10.2
```

Observer :

```bash
sudo ovs-vsctl show
sudo ovs-ofctl dump-flows br-lab
sudo ovs-appctl fdb/show br-lab
sudo ip netns exec h1 ip neigh
```

Questions :

1. Pourquoi `ip a` exécuté dans h1 ne montre-t-il pas les interfaces de l'hôte ?
2. Que signifie l'action `NORMAL` affichée par `dump-flows` ?
3. Retirez `h2-port` du bridge (`ovs-vsctl del-port`), relancez le ping, puis rebranchez. Que montre `fdb/show` avant et après ?

**Bonus : un conteneur est un namespace comme les autres.**

```bash
sudo docker run -d --name web alpine:3.20 sleep 3600
PID=$(sudo docker inspect -f '{{.State.Pid}}' web)
sudo nsenter -t "$PID" -n ip addr
bridge link | grep docker0
sudo docker rm -f web
```

Livrable : `tp1a.sh` rejouable, commité.
