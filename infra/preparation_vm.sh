#!/usr/bin/env bash
# preparation_vm.sh — prépare les machines des TP de la formation 1-041
# Cible : Ubuntu 24.04 LTS (Server, installation minimale + OpenSSH), VM KVM (Proxmox), VMware ou VirtualBox.
#
# Deux machines par stagiaire, sur le même LAN. Lancez-le toujours depuis le dépôt, en chemin
# relatif — jamais « sudo bash ~/lab/... » : sous sudo, ~ pointe vers /root, pas vers votre dossier.
#   lab-a  machine de TP complète : cd ~/lab && sudo bash infra/preparation_vm.sh --kit "$PWD"
#   lab-b  second hyperviseur du TP2-B (VXLAN), légère : cd ~/lab && sudo bash infra/preparation_vm.sh --secondaire
#
# Options :
#   --secondaire                 lab-b : Open vSwitch et outils réseau seulement (ni bureau, ni Docker, ni ONOS, ni os-ken)
#   --kit CHEMIN                 copie les scripts des TP à plat dans ~/lab : le dépôt cloné ou l'archive kit_tp_1-041.zip
#   --sans-bureau                lab-a sans bureau XFCE, ni xrdp, ni Firefox (accès terminal seul)
#   --pair IP                    contrôle aussi le lien vers l'autre machine : ping et MTU de 1 500 sans fragmentation
#   --underlay IFACE IP/MASQUE   infra perso avec une 2e carte dédiée au TP2-B, ex. --underlay ens19 192.168.50.11/24
#                                (inutile sur Hexceos : le TP2-B passe par le LAN de l'environnement)
#   --test-onos                  démarre ONOS une fois pour vérifier son API (2 à 3 minutes de plus)
#   --verifier-seulement         ne rien installer : relancer les contrôles (avec --secondaire sur lab-b)
#
# Le script est rejouable : relancé, il complète l'installation sans casser l'existant.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ---------- arguments ----------
UNDERLAY_IF="" UNDERLAY_IP="" KIT="" PAIR="" BUREAU=1 SECONDAIRE=0 TEST_ONOS=0 VERIF_SEULE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --secondaire) SECONDAIRE=1; BUREAU=0; shift ;;
    --kit) KIT="${2:?chemin du zip manquant}"; shift 2 ;;
    --sans-bureau) BUREAU=0; shift ;;
    --pair) PAIR="${2:?adresse IP manquante (autre machine du LAN)}"; shift 2 ;;
    --underlay) UNDERLAY_IF="${2:?interface manquante}"; UNDERLAY_IP="${3:?adresse IP/masque manquante}"; shift 3 ;;
    --test-onos) TEST_ONOS=1; shift ;;
    --verifier-seulement) VERIF_SEULE=1; shift ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

if [[ $SECONDAIRE -eq 1 && $TEST_ONOS -eq 1 ]]; then
  echo "--test-onos ne s'applique pas à lab-b (--secondaire) : ONOS tourne sur lab-a." >&2; exit 2
fi

[[ $EUID -eq 0 ]] || { echo "À lancer avec sudo : sudo bash $0 ..." >&2; exit 1; }
CIBLE="${SUDO_USER:-root}"
HOME_CIBLE="$(getent passwd "$CIBLE" | cut -d: -f6)"
en_cible() { sudo -u "$CIBLE" -H "$@"; }

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "Attention : testé pour Ubuntu 24.04, système détecté : ${PRETTY_NAME:-inconnu}. On continue." >&2
fi

etape() { printf '\n=== %s ===\n' "$*"; }
if [[ $SECONDAIRE -eq 1 ]]; then ROLE="lab-b (secondaire)"; else ROLE="lab-a (machine de TP)"; fi
etape "Préparation de $ROLE pour le compte $CIBLE"

# ---------- 1. paquets du lab ----------
installer_base() {
  etape "Paquets du lab"
  # tshark : ne pas poser de question sur la capture par les non-root
  echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections
  local paquets
  if [[ $SECONDAIRE -eq 1 ]]; then
    paquets=(openvswitch-switch iproute2 nftables tcpdump tshark iperf3
             curl jq git unzip tmux ethtool)
  else
    paquets=(openvswitch-switch mininet iproute2 nftables tcpdump tshark iperf iperf3
             curl jq git unzip tmux ethtool
             python3-venv python3-pip python3-yaml python3-requests)
    # Docker déjà présent (docker-ce de docker.com par exemple) : on le garde, docker.io entrerait en conflit
    command -v docker > /dev/null || paquets+=(docker.io)
  fi
  apt-get update
  apt-get install -y "${paquets[@]}"
  systemctl enable --now openvswitch-switch
  if [[ $SECONDAIRE -eq 0 ]]; then
    systemctl enable --now docker
    usermod -aG docker "$CIBLE"
  fi

  # modules noyau utilisés par les TP (OVS, VXLAN), chargés aussi au démarrage
  printf 'openvswitch\nvxlan\n' > /etc/modules-load.d/lab-1-041.conf
  modprobe openvswitch
  modprobe vxlan
}

# ---------- 2. images Docker et environnement os-ken (lab-a) ----------
installer_images_osken() {
  etape "Images Docker (ONOS 2.7.0, alpine) — plusieurs centaines de Mo"
  docker pull onosproject/onos:2.7.0
  docker pull alpine:3.20

  etape "Environnement Python os-ken (~/osken)"
  [[ -x "$HOME_CIBLE/osken/bin/python" ]] || en_cible python3 -m venv "$HOME_CIBLE/osken"
  en_cible "$HOME_CIBLE/osken/bin/pip" install --upgrade pip
  # version testée pendant la conception des TP, sinon la dernière 4.x
  en_cible "$HOME_CIBLE/osken/bin/pip" install "os-ken==4.2.2" pyyaml requests \
    || en_cible "$HOME_CIBLE/osken/bin/pip" install "os-ken>=4,<5" pyyaml requests
}

# ---------- 3. bureau graphique + accès RDP + Firefox (lab-a) ----------
installer_bureau() {
  etape "Bureau XFCE, xrdp et Firefox"
  apt-get install -y xfce4 xfce4-terminal dbus-x11 xrdp xorgxrdp
  adduser xrdp ssl-cert > /dev/null
  echo "startxfce4" > "$HOME_CIBLE/.xsession"
  chown "$CIBLE:" "$HOME_CIBLE/.xsession"
  systemctl enable --now xrdp

  # Firefox en paquet .deb du dépôt Mozilla : le snap d'Ubuntu se comporte mal dans les sessions xrdp
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/packages.mozilla.org.asc
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    > /etc/apt/sources.list.d/mozilla.list
  printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla
  apt-get update
  apt-get install -y firefox
}

# ---------- 4. infra perso : 2e carte réseau dédiée au TP2-B ----------
configurer_underlay() {
  etape "Interface underlay $UNDERLAY_IF = $UNDERLAY_IP"
  ip link show "$UNDERLAY_IF" > /dev/null 2>&1 || { echo "Interface $UNDERLAY_IF introuvable (voir : ip -br link)" >&2; exit 1; }
  if ip route show default | grep -qw "dev $UNDERLAY_IF"; then
    echo "Refus : $UNDERLAY_IF porte la route par défaut (c'est la carte d'administration)." >&2
    exit 1
  fi
  cat > /etc/netplan/60-lab-underlay.yaml <<EOF
network:
  version: 2
  ethernets:
    $UNDERLAY_IF:
      dhcp4: false
      addresses: [$UNDERLAY_IP]
      mtu: 1500
EOF
  chmod 600 /etc/netplan/60-lab-underlay.yaml
  netplan apply
}

# ---------- 5. kit des TP ----------
installer_kit() {
  etape "Kit des TP dans $HOME_CIBLE/lab"
  [[ -e "$KIT" ]] || { echo "Kit introuvable : $KIT" >&2; exit 1; }
  tmp="$(mktemp -d)"
  if [[ -d "$KIT" ]]; then
    cp -r "$KIT"/. "$tmp"/          # dépôt cloné, ou dossier de scripts
  else
    unzip -q -o "$KIT" -d "$tmp"    # archive kit_tp_1-041.zip
  fi
  [[ -n "$(find "$tmp" -name ring.py -print -quit)" ]] || { echo "ring.py introuvable : est-ce bien le dépôt 1-041 ?" >&2; exit 1; }
  # le dépôt range les scripts par sous-TP (tp3a/ring.py, …) ; on les rassemble à plat dans ~/lab
  en_cible mkdir -p "$HOME_CIBLE/lab"
  find "$tmp" -type f \( -name '*.py' -o -name '*.sh' -o -name '*.yaml' -o -name '*.txt' \) \
       -not -path '*/.git/*' -exec cp -t "$HOME_CIBLE/lab/" {} +
  chown -R "$CIBLE:" "$HOME_CIBLE/lab"
  chmod +x "$HOME_CIBLE/lab"/*.sh "$HOME_CIBLE/lab"/*.py 2> /dev/null || true
  # dépôt Git local : chaque stagiaire y versionne ses scripts (environnements isolés, pas de dépôt partagé)
  [[ -d "$HOME_CIBLE/lab/.git" ]] || en_cible git -C "$HOME_CIBLE/lab" init -q
  rm -rf "$tmp"
}

# ---------- 6. contrôles ----------
OK=0 KO=0
controle() {  # controle "libellé" commande...
  local lib="$1"; shift
  if "$@" > /tmp/lab-controle.log 2>&1; then
    printf '  [ OK ] %s\n' "$lib"; OK=$((OK + 1))
  else
    printf '  [ÉCHEC] %s\n' "$lib"; sed 's/^/         /' /tmp/lab-controle.log | tail -5; KO=$((KO + 1))
  fi
}

# Les fonctions de test sont appelées dans un « if » : set -e n'y joue plus, d'où les && explicites.
test_vxlan_namespaces() {
  local rc
  ip netns del t1041 2> /dev/null || true
  ip netns add t1041 &&
    ip -n t1041 link add vxt type vxlan id 42 dstport 4789 local 127.0.0.1 remote 127.0.0.2 &&
    ip -n t1041 -d link show vxt | grep -q "dstport 4789"
  rc=$?
  ip netns del t1041 2> /dev/null || true
  return $rc
}

test_mininet() {
  local rc
  mn -c > /dev/null 2>&1 || true
  timeout 120 mn --switch ovsbr --controller none --test pingall 2>&1 | grep -q " 0% dropped"
  rc=$?
  mn -c > /dev/null 2>&1 || true
  return $rc
}

test_firefox() {  # le .deb de Mozilla, pas le paquet de transition vers le snap
  local v
  v="$(dpkg-query -W -f='${Version}' firefox)" && echo "firefox $v" && [[ "$v" != *snap* ]]
}

test_onos() {
  docker rm -f onos-test > /dev/null 2>&1 || true
  docker run -d --name onos-test -p 18181:8181 \
    -e ONOS_APPS=drivers,openflow,proxyarp,fwd,gui2 onosproject/onos:2.7.0 > /dev/null
  for _ in $(seq 1 60); do
    if curl -sf -u onos:rocks http://localhost:18181/onos/v1/applications > /dev/null; then
      docker rm -f onos-test > /dev/null; return 0
    fi
    sleep 5
  done
  docker logs --tail 20 onos-test
  docker rm -f onos-test > /dev/null
  return 1
}

# MTU du chemin vers l'autre machine : 1472 octets de données ICMP + 28 d'en-têtes = 1 500, sans fragmentation.
# En échec, le TP2-B marche quand même, mais le passage « Attention MTU » se démontre différemment (voir le guide).
test_mtu_pair() {
  local mtu
  mtu="$(ip -o route get "$PAIR" | grep -oP '(?<=dev )\S+' | xargs -I{} cat /sys/class/net/{}/mtu)"
  echo "MTU de l'interface vers $PAIR : $mtu"
  ping -c 2 -W 2 -M "do" -s 1472 "$PAIR"
}

controler() {
  etape "Contrôles ($ROLE)"
  controle "Open vSwitch répond ($(ovs-vsctl --version | head -1))" ovs-vsctl show
  controle "Modules noyau openvswitch et vxlan" bash -c "lsmod | grep -qw openvswitch && lsmod | grep -qw vxlan"
  controle "Namespaces et interface VXLAN (dstport 4789)" test_vxlan_namespaces
  controle "nftables présent" nft --version
  controle "tcpdump et tshark présents" bash -c "tcpdump --version && tshark -v | head -1"
  controle "jq et iperf3 présents" bash -c "jq --version && iperf3 --version | head -1"
  if [[ $SECONDAIRE -eq 0 ]]; then
    controle "Mininet : pingall sur un switch OVS sans contrôleur" test_mininet
    controle "Docker : conteneur alpine" docker run --rm alpine:3.20 true
    controle "Image ONOS 2.7.0 présente" bash -c "docker image inspect onosproject/onos:2.7.0 > /dev/null"
    controle "os-ken importable dans ~/osken" en_cible "$HOME_CIBLE/osken/bin/python" -c "import os_ken"
    controle "Modules Python du TP3-C (requests, yaml)" python3 -c "import requests, yaml"
    controle "iperf (v2) présent" bash -c "iperf --version 2>&1 | head -1"
  fi
  if [[ -f "$HOME_CIBLE/.xsession" ]]; then
    controle "xrdp actif (bureau accessible en RDP, port 3389)" systemctl is-active --quiet xrdp
    controle "Firefox installé (paquet .deb de Mozilla)" test_firefox
  fi
  [[ -f /etc/netplan/60-lab-underlay.yaml ]] && \
    controle "Interface underlay configurée" bash -c "ip -br addr | grep -q \"$(grep -oP '(?<=addresses: \[)[^]/]+' /etc/netplan/60-lab-underlay.yaml)\""
  [[ -d "$HOME_CIBLE/lab" ]] && controle "Kit présent dans ~/lab" test -f "$HOME_CIBLE/lab/ring.py"
  if [[ -n "$PAIR" ]]; then
    controle "L'autre machine ($PAIR) répond au ping" ping -c 2 -W 2 "$PAIR"
    controle "Chemin vers $PAIR : MTU 1 500 sans fragmentation" test_mtu_pair
  fi
  [[ $TEST_ONOS -eq 1 ]] && controle "ONOS démarre et son API répond (jusqu'à 5 min)" test_onos
  printf '\nBilan : %d contrôle(s) OK, %d en échec.\n' "$OK" "$KO"
}

# ---------- déroulé ----------
if [[ $VERIF_SEULE -eq 0 ]]; then
  installer_base
  if [[ $SECONDAIRE -eq 0 ]]; then installer_images_osken; fi
  if [[ $BUREAU -eq 1 ]]; then installer_bureau; fi
  if [[ -n "$KIT" ]]; then installer_kit; fi
fi
# même en --verifier-seulement : sur un clone (infra perso), on change l'adresse underlay
if [[ -n "$UNDERLAY_IF" ]]; then configurer_underlay; fi
controler

if [[ $SECONDAIRE -eq 1 ]]; then
  cat <<EOF

Étapes suivantes (lab-b) :
  1. Notez l'adresse LAN de cette machine : ip -br a
  2. Sur lab-a : cd ~/lab && sudo bash infra/preparation_vm.sh --verifier-seulement --pair <adresse de lab-b>
  3. Prenez un instantané « etat-initial ».
EOF
else
  cat <<EOF

Étapes suivantes (lab-a) :
  1. Les TP utilisent « sudo docker », pas besoin de redémarrer.
  2. Pour l'interface d'ONOS, ouvrez le Firefox de la machine sur http://localhost:8181/onos/ui (onos / rocks).
  3. Préparez lab-b (même LAN) : cd ~/lab && sudo bash infra/preparation_vm.sh --secondaire
  4. Vérifiez le lien et la MTU : cd ~/lab && sudo bash infra/preparation_vm.sh --verifier-seulement --pair <adresse de lab-b>
  5. Prenez un instantané « outils installés » des deux machines avant de dérouler les TP.
EOF
fi
[[ $KO -eq 0 ]]
