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

Relier deux machines isolées, h1 et h2 (zone dev), par un commutateur Open vSwitch, puis observer ce que fait le commutateur. Voici l'infrastructure qu'on va construire :

```mermaid
graph LR
  h1["h1 — namespace<br/>10.10.10.1/24"] ---|veth| br["br-lab<br/>Open vSwitch"]
  h2["h2 — namespace<br/>10.10.10.2/24"] ---|veth| br
```

### Étape 1 — Deux machines isolées et un commutateur virtuel

```bash
sudo ip netns add h1
sudo ip netns add h2
sudo ovs-vsctl add-br br-lab
```

**Ligne par ligne.**

- `ip netns add h1` : crée « h1 », une machine isolée. Un *network namespace* est une pile réseau complète et séparée (ses interfaces, ses routes, son cache ARP) dans le même noyau.
- `ip netns add h2` : idem pour « h2 ».
- `ovs-vsctl add-br br-lab` : crée le commutateur virtuel Open vSwitch « br-lab », vide pour l'instant.

**Voir ce qu'on vient de créer :**

```bash
sudo ip netns list      # les machines isolées : h1, h2
sudo ovs-vsctl show     # le commutateur br-lab et ses ports (aucun pour l'instant)
```

- `ip netns list` : liste les namespaces existants ; vous devez y voir `h1` et `h2`.
- `ovs-vsctl show` : affiche la configuration du commutateur lue dans la base OVSDB — son pont `br-lab`, et ses ports (encore vide).

### Étape 2 — Un câble virtuel (paire veth) par machine, branché sur le commutateur

```bash
for h in h1 h2; do
  sudo ip link add ${h}-eth0 type veth peer name ${h}-port
  sudo ip link set ${h}-eth0 netns $h
  sudo ovs-vsctl add-port br-lab ${h}-port
  sudo ip link set ${h}-port up
  sudo ip -n $h link set lo up
  sudo ip -n $h link set ${h}-eth0 up
done
```

**Ligne par ligne** (la boucle répète les mêmes gestes pour h1 puis h2) :

- `ip link add ${h}-eth0 type veth peer name ${h}-port` : crée un câble virtuel à deux bouts — `-eth0` (côté machine) et `-port` (côté commutateur).
- `ip link set ${h}-eth0 netns $h` : pousse le bout `-eth0` dans la machine ; c'est sa carte réseau.
- `ovs-vsctl add-port br-lab ${h}-port` : branche l'autre bout sur le commutateur.
- `ip link set ${h}-port up` : active le port côté commutateur.
- `ip -n $h link set lo up` : active la boucle locale (`lo`) dans la machine — souvent oubliée.
- `ip -n $h link set ${h}-eth0 up` : active la carte réseau dans la machine.

**Voir ce qu'on vient de brancher :**

```bash
ip -br link show h1-port    # le port de h1, côté commutateur (hôte)
ip -br link show h2-port    # le port de h2, côté commutateur (hôte)
sudo ip netns list          # les machines isolées
sudo ip -n h1 -br link      # les interfaces vues depuis h1 : lo et h1-eth0
sudo ip -n h2 -br link      # les interfaces vues depuis h2 : lo et h2-eth0
```

- `ip -br link show h1-port` / `h2-port` : affichent, en format bref (`-br`), l'état des ports côté hôte ; ils doivent être `UP`.
- `ip -n h1 -br link` / `ip -n h2 -br link` : `-n h1` exécute la commande *dans* le namespace h1 ; vous n'y voyez que ses propres interfaces (`lo`, `h1-eth0`), preuve de l'isolement.

### Étape 3 — Adressage et test

```bash
sudo ip -n h1 addr add 10.10.10.1/24 dev h1-eth0
sudo ip -n h2 addr add 10.10.10.2/24 dev h2-eth0
sudo ip netns exec h1 ping -c 3 10.10.10.2   # depuis h1, 3 paquets vers h2 : 0% packet loss
```

**Ligne par ligne.**

- `ip -n h1 addr add 10.10.10.1/24 dev h1-eth0` : attribue une adresse IP à h1 (zone dev).
- `ip -n h2 addr add 10.10.10.2/24 dev h2-eth0` : adresse de h2.
- `ip netns exec h1 ping -c 3 10.10.10.2` : depuis h1, envoie 3 paquets vers h2 ; valide le lien à travers le commutateur.

### Observer ce que fait le commutateur

```bash
sudo ovs-vsctl show                 # ses ponts et ses ports (h1-port, h2-port)
sudo ovs-ofctl dump-flows br-lab    # ses règles OpenFlow : ici une seule, NORMAL
sudo ovs-appctl fdb/show br-lab     # sa table d'apprentissage : quelle MAC sur quel port
sudo ip netns exec h1 ip neigh      # la table ARP de h1 : les voisins (IP ↔ MAC) vus
```

- `ovs-vsctl show` : la configuration du commutateur ; vous y voyez maintenant `h1-port` et `h2-port`.
- `ovs-ofctl dump-flows br-lab` : les règles OpenFlow du commutateur ; par défaut une seule, `actions=NORMAL`, qui le fait commuter comme un switch classique.
- `ovs-appctl fdb/show br-lab` : la table d'apprentissage des adresses MAC (quelle MAC derrière quel port).
- `ip netns exec h1 ip neigh` : le cache ARP de h1 (les correspondances IP ↔ MAC qu'il a apprises).

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

**Ligne par ligne.**

- `docker run -d --name web alpine:3.20 sleep 3600` : lance un conteneur qui tourne en fond.
- `PID=$(sudo docker inspect -f '{{.State.Pid}}' web)` : récupère le PID du conteneur sur l'hôte.
- `nsenter -t "$PID" -n ip addr` : entre dans le namespace réseau du conteneur et liste ses interfaces — c'est exactement un namespace comme h1.
- `bridge link | grep docker0` : montre le câble veth du conteneur, branché sur le pont `docker0`.
- `docker rm -f web` : supprime le conteneur.

Livrable : `tp1a.sh` rejouable, commité.
