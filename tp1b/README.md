# TP1-B — Un pare-feu virtualisé

**Jour 1, 10:35 · 30 min.** Objectif : insérer un pare-feu logiciel — une VNF — qu'on détruit et recrée par script. Support : chapitres 3 et 4.

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
