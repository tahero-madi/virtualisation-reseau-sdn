# TP1-B — Un pare-feu virtualisé

**Jour 1, 10:35 · 30 min.** Objectif : insérer un pare-feu logiciel — une VNF — qu'on détruit et recrée par script. Support : chapitres 3 et 4.

Insérer un pare-feu, la « VNF » `fw`, entre la zone dev (h1, h2) et un serveur de la zone prod (`srv`, 10.10.30.10).

```bash
# Instanciation de la VNF (le pare-feu) et du serveur de prod
sudo ip netns add fw                                   # « fw » : le pare-feu, une machine isolée
sudo ip netns add srv                                  # « srv » : le serveur de production
sudo ip link add fw-dev type veth peer name fw-port    # câble entre le pare-feu et le commutateur (côté dev)
sudo ip link set fw-dev netns fw                       # bout fw-dev dans le pare-feu
sudo ovs-vsctl add-port br-lab fw-port && sudo ip link set fw-port up   # autre bout branché sur br-lab, activé
sudo ip link add fw-prod type veth peer name srv-eth0  # câble direct entre le pare-feu et le serveur (côté prod)
sudo ip link set fw-prod netns fw                      # bout fw-prod dans le pare-feu
sudo ip link set srv-eth0 netns srv                    # bout srv-eth0 dans le serveur

sudo ip -n fw addr add 10.10.10.254/24 dev fw-dev      # patte du pare-feu côté dev = passerelle de la zone dev
sudo ip -n fw addr add 10.10.30.254/24 dev fw-prod     # patte du pare-feu côté prod = passerelle de la zone prod
sudo ip -n srv addr add 10.10.30.10/24 dev srv-eth0    # adresse du serveur
for i in lo fw-dev fw-prod; do sudo ip -n fw link set $i up; done   # active les interfaces du pare-feu
for i in lo srv-eth0; do sudo ip -n srv link set $i up; done        # active les interfaces du serveur
sudo ip netns exec fw sysctl -w net.ipv4.ip_forward=1  # autorise le pare-feu à router entre ses deux pattes
sudo ip -n h1 route add default via 10.10.10.254       # h1 sort par le pare-feu
sudo ip -n h2 route add default via 10.10.10.254       # h2 sort par le pare-feu
sudo ip -n srv route add default via 10.10.30.254      # le serveur répond en repassant par le pare-feu

# Politique : h1 a droit à HTTP vers le serveur, toute la zone dev au ping. Le reste est jeté.
sudo ip netns exec fw nft -f - <<'EOF'
table inet vnf {
  chain forward {
    type filter hook forward priority 0; policy drop;                         # par défaut, jeter ce qui traverse
    ct state established,related accept                                        # laisser revenir les réponses des connexions acceptées
    ip saddr 10.10.10.1 ip daddr 10.10.30.10 tcp dport 80 accept              # h1 -> serveur en HTTP (port 80)
    ip saddr 10.10.10.0/24 ip daddr 10.10.30.10 icmp type echo-request accept  # toute la zone dev -> serveur en ping
  }
}
EOF
```

Tester :

```bash
sudo ip netns exec srv python3 -m http.server 80 &                                       # serveur web de test dans srv
sudo ip netns exec h1 curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://10.10.30.10/   # h1 -> serveur : doit répondre 200
sudo ip netns exec h2 curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://10.10.30.10/   # h2 -> serveur : bloqué, code 000
sudo ip netns exec h2 ping -c 2 10.10.30.10                                              # h2 -> serveur en ping : autorisé
sudo ip netns exec fw nft list ruleset > vnf-fw.nft                                      # sauvegarde la config du pare-feu (livrable)
```

| Test | Résultat attendu |
| --- | --- |
| h1 vers le serveur en HTTP | Code 200 |
| h2 vers le serveur en HTTP | Code 000 (bloqué) |
| h2 vers le serveur en ping | Réponses reçues |

**Le geste NFV : détruire et recréer.** Rassemblez les commandes ci-dessus dans `tp1b.sh`, en commençant par supprimer `fw` et `srv` s'ils existent, puis :

```bash
sudo ip netns del fw                                 # détruit le pare-feu ; ses câbles disparaissent avec lui
sudo ovs-vsctl --if-exists del-port br-lab fw-port   # retire le port resté côté commutateur
time sudo bash tp1b.sh                                # recrée toute la VNF par script, et chronomètre l'opération
```

Questions :

1. Pourquoi la règle `ct state established,related accept` est-elle indispensable ?
2. Où se trouve « physiquement » ce pare-feu ? Qu'est-ce que cela change pour la sauvegarde, le plan de reprise et la montée en charge ?
3. Qu'apporterait un orchestrateur (MANO, Kubernetes) à ce que vous venez de faire à la main ?
4. Quelles fonctions de votre périmètre pourraient devenir des VNF ou des CNF ?

Livrables : `tp1b.sh` et `vnf-fw.nft`, commités.
