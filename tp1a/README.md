# TP1-A — Un réseau virtuel en dix commandes

**Jour 1, 09:40 · 45 min.** Objectif : construire un réseau virtuel isolé sur un hôte Linux, en une dizaine de commandes. Support : chapitres 3 et 4.

## Installation des outils (une seule fois, pour les deux jours)

Votre machine lab-a est un Ubuntu 24.04 vierge : le bureau et Firefox, mais aucun outil réseau. On les installe maintenant. Dans un **premier terminal** :

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/tahero-madi/virtualisation-reseau-sdn.git ~/lab
sudo bash ~/lab/infra/preparation_vm.sh --kit ~/lab --sans-bureau
```

Le script installe d'abord Open vSwitch (quelques minutes), puis continue à télécharger l'image ONOS et os-ken, dont vous aurez besoin au jour 2. **Dès que s'affiche `[ OK ] Open vSwitch répond`, ouvrez un second terminal et commencez le TP ci-dessous** ; laissez le premier terminal finir le téléchargement. À la fin, quand le script affiche son bilan, prenez un **instantané « outils installés »** : en cas de problème, vous y reviendrez plutôt qu'à la machine vierge.

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
