# TP1 — Un réseau virtuel et une fonction réseau virtualisée

Objectif : construire un réseau isolé sur un hôte Linux, puis y insérer un pare-feu logiciel qu'on détruit et recrée par script. Chapitres 3 et 4. Durée indicative : 1 h 15.

## TP1-A — Un réseau virtuel en dix commandes

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

## TP1-B — Un pare-feu virtualisé

Insérer un pare-feu, la « VNF » `fw`, entre la zone dev (h1, h2) et un serveur de la zone prod (`srv`, 10.10.30.10).

```bash
# Instanciation de la VNF et du serveur
sudo ip netns add fw
sudo ip netns add srv
sudo ip link add fw-dev type veth peer name fw-port
sudo ip link set fw-dev netns fw
sudo ovs-vsctl add-port br-lab fw-port && sudo ip link set fw-port up
sudo ip link add fw-prod type veth peer name srv-eth0
sudo ip link set fw-prod netns fw
sudo ip link set srv-eth0 netns srv

sudo ip -n fw addr add 10.10.10.254/24 dev fw-dev
sudo ip -n fw addr add 10.10.30.254/24 dev fw-prod
sudo ip -n srv addr add 10.10.30.10/24 dev srv-eth0
for i in lo fw-dev fw-prod; do sudo ip -n fw link set $i up; done
for i in lo srv-eth0; do sudo ip -n srv link set $i up; done
sudo ip netns exec fw sysctl -w net.ipv4.ip_forward=1
sudo ip -n h1 route add default via 10.10.10.254
sudo ip -n h2 route add default via 10.10.10.254
sudo ip -n srv route add default via 10.10.30.254

# Politique : h1 a droit à HTTP vers le serveur, toute la zone dev au ping
sudo ip netns exec fw nft -f - <<'EOF'
table inet vnf {
  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    ip saddr 10.10.10.1 ip daddr 10.10.30.10 tcp dport 80 accept
    ip saddr 10.10.10.0/24 ip daddr 10.10.30.10 icmp type echo-request accept
  }
}
EOF
```

Tester :

```bash
sudo ip netns exec srv python3 -m http.server 80 &
sudo ip netns exec h1 curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://10.10.30.10/
sudo ip netns exec h2 curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://10.10.30.10/
sudo ip netns exec h2 ping -c 2 10.10.30.10
sudo ip netns exec fw nft list ruleset > vnf-fw.nft
```

| Test | Résultat attendu |
| --- | --- |
| h1 vers le serveur en HTTP | Code 200 |
| h2 vers le serveur en HTTP | Code 000 (bloqué) |
| h2 vers le serveur en ping | Réponses reçues |

**Le geste NFV : détruire et recréer.** Rassemblez les commandes ci-dessus dans `tp1b.sh`, en commençant par supprimer `fw` et `srv` s'ils existent, puis :

```bash
sudo ip netns del fw
sudo ovs-vsctl --if-exists del-port br-lab fw-port
time sudo bash tp1b.sh
```

Questions :

1. Pourquoi la règle `ct state established,related accept` est-elle indispensable ?
2. Où se trouve « physiquement » ce pare-feu ? Qu'est-ce que cela change pour la sauvegarde, le plan de reprise et la montée en charge ?
3. Qu'apporterait un orchestrateur (MANO, Kubernetes) à ce que vous venez de faire à la main ?
4. Quelles fonctions de votre périmètre pourraient devenir des VNF ou des CNF ?

Livrables : `tp1b.sh` et `vnf-fw.nft`, commités.

---

[← Préparer son poste](00-preparer-son-poste.md) · [Sommaire](../README.md) · [TP2 →](tp2-vlan-et-vxlan.md)
