#!/bin/bash
#
# Script d'installation automatique Debian - Baseline CLI
# Basé sur les instructions thomascherrier/TSSR baseline_debian.md
#

set -e

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Vérification root
if [[ $EUID -ne 0 ]]; then
   log_error "Ce script doit être exécuté en tant que root"
   exit 1
fi

log_section "Début de la configuration Baseline Debian CLI"

# ============================================
# 1. Mise à jour du système
# ============================================
log_section "1/7 - Mise à jour du système"
log_info "Mise à jour des paquets..."
apt update && apt upgrade -y

# ============================================
# 2. Installation des BinUtils
# ============================================
log_section "2/7 - Installation des BinUtils"
log_info "Installation de : ssh, zip, nmap, locate, ncdu, curl, git, screen, dnsutils, net-tools, sudo, lynx"

apt install -y \
    ssh \
    zip \
    nmap \
    locate \
    ncdu \
    curl \
    git \
    screen \
    dnsutils \
    net-tools \
    sudo \
    lynx

log_info "Indexation de la base de données locate..."
updatedb

# ============================================
# 3. Installation NetBIOS (optionnel)
# ============================================
log_section "3/7 - Installation couche NetBIOS"
read -p "Voulez-vous installer la couche NetBIOS (winbind/samba) ? Uniquement pour postes locaux non exposés sur Internet (o/n) : " INSTALL_NETBIOS

if [[ $INSTALL_NETBIOS == "o" || $INSTALL_NETBIOS == "O" ]]; then
    log_info "Installation de winbind et samba..."
    apt install -y winbind samba

    log_info "Configuration de /etc/nsswitch.conf..."
    # Backup du fichier original
    cp /etc/nsswitch.conf /etc/nsswitch.conf.backup

    # Ajout de wins à la ligne hosts si pas déjà présent
    if grep -q "^hosts:.*wins" /etc/nsswitch.conf; then
        log_info "wins déjà présent dans nsswitch.conf"
    else
        sed -i '/^hosts:/ s/$/ wins/' /etc/nsswitch.conf
        log_info "wins ajouté à la ligne hosts dans nsswitch.conf"
    fi
else
    log_warn "Installation NetBIOS ignorée"
fi

# ============================================
# 4. Personnalisation du BASH
# ============================================
log_section "4/7 - Personnalisation du BASH"
log_info "Décommentage des lignes 9-13 dans /root/.bashrc..."

cp /root/.bashrc /root/.bashrc.backup

# Décommenter les lignes de force_color_prompt et ls aliases (généralement lignes 9-13)
sed -i '47,59s/^#//' /root/.bashrc 2>/dev/null || true
sed -i '/force_color_prompt=yes/s/^# //' /root/.bashrc
sed -i '/alias ll=/s/^# //' /root/.bashrc
sed -i '/alias la=/s/^# //' /root/.bashrc
sed -i '/alias l=/s/^# //' /root/.bashrc

log_info "BASH personnalisé (source /root/.bashrc pour appliquer les changements)"

# ============================================
# 5. Configuration du Réseau
# ============================================
log_section "5/7 - Configuration du Réseau"

read -p "Voulez-vous configurer une IP fixe ? (o/n) : " CONFIG_IP
if [[ $CONFIG_IP == "o" || $CONFIG_IP == "O" ]]; then
    # Détection de l'interface principale
    DEFAULT_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
    read -p "Interface réseau à configurer [$DEFAULT_IF] : " INTERFACE
    INTERFACE=${INTERFACE:-$DEFAULT_IF}

    read -p "Adresse IP (ex: 192.168.1.100) : " IP_ADDRESS
    read -p "Masque CIDR [24] : " NETMASK
    NETMASK=${NETMASK:-24}
    read -p "Passerelle (ex: 192.168.1.1) : " GATEWAY
    read -p "DNS primaire [8.8.8.8] : " DNS1
    DNS1=${DNS1:-8.8.8.8}
    read -p "DNS secondaire [8.8.4.4] : " DNS2
    DNS2=${DNS2:-8.8.4.4}
    read -p "Search domain [local] : " SEARCH_DOMAIN
    SEARCH_DOMAIN=${SEARCH_DOMAIN:-local}

    # Backup de la config réseau
    cp /etc/network/interfaces /etc/network/interfaces.backup

    # Configuration de l'interface
    log_info "Configuration de l'interface $INTERFACE..."
    cat > /etc/network/interfaces <<EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# Loopback interface
auto lo
iface lo inet loopback

# Interface principale
auto $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS/$NETMASK
    gateway $GATEWAY
EOF

    # Configuration DNS
    log_info "Configuration DNS..."
    cat > /etc/resolv.conf <<EOF
search $SEARCH_DOMAIN
nameserver $DNS1
nameserver $DNS2
EOF

    log_warn "Configuration réseau appliquée. Redémarrage réseau requis."
    read -p "Voulez-vous redémarrer le réseau maintenant ? (o/n) : " RESTART_NET
    if [[ $RESTART_NET == "o" || $RESTART_NET == "O" ]]; then
        systemctl restart networking
        log_info "Réseau redémarré"
    fi
else
    log_warn "Configuration IP fixe ignorée"
fi

# Configuration du hostname
read -p "Voulez-vous changer le hostname ? (o/n) : " CHANGE_HOSTNAME
if [[ $CHANGE_HOSTNAME == "o" || $CHANGE_HOSTNAME == "O" ]]; then
    read -p "Nouveau hostname : " NEW_HOSTNAME
    echo "$NEW_HOSTNAME" > /etc/hostname
    hostnamectl set-hostname "$NEW_HOSTNAME"
    log_info "Hostname changé en : $NEW_HOSTNAME"
fi

log_info "Affichage de la configuration IP actuelle :"
ip a

# ============================================
# 6. Installation de WebMin
# ============================================
log_section "6/7 - Installation de WebMin"
read -p "Voulez-vous installer WebMin ? (o/n) : " INSTALL_WEBMIN

if [[ $INSTALL_WEBMIN == "o" || $INSTALL_WEBMIN == "O" ]]; then
    log_info "Téléchargement du script d'installation WebMin..."
    curl -o /tmp/webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh

    log_info "Exécution du script de configuration du repo..."
    sh /tmp/webmin-setup-repo.sh

    log_info "Installation de WebMin..."
    apt install -y webmin --install-recommends

    # Récupération de l'IP pour afficher l'URL
    CURRENT_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)

    log_info "WebMin installé avec succès !"
    echo ""
    echo -e "${GREEN}Accédez à WebMin via :${NC}"
    echo -e "  https://$CURRENT_IP:10000"
    echo -e "  ou"
    echo -e "  https://$(hostname):10000"
    echo ""
else
    log_warn "Installation WebMin ignorée"
fi

# ============================================
# 7. Bonus Fun - BSDGames
# ============================================
log_section "7/7 - Bonus Fun : BSDGames"
read -p "Voulez-vous installer les jeux BSD ? (o/n) : " INSTALL_GAMES

if [[ $INSTALL_GAMES == "o" || $INSTALL_GAMES == "O" ]]; then
    log_info "Installation de bsdgames..."
    apt install -y bsdgames

    log_info "BSDGames installés !"
    echo ""
    echo -e "${GREEN}Pour jouer :${NC}"
    echo -e "  cd /usr/games"
    echo -e "  ./nomdujeu"
    echo ""
    echo -e "Exemples de jeux disponibles : adventure, tetris-bsd, snake, worm, etc."
else
    log_warn "Installation BSDGames ignorée"
fi

# ============================================
# Résumé final
# ============================================
log_section "Configuration terminée !"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Configuration Baseline Debian terminée !  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Résumé des installations :"
echo "  ✓ Système mis à jour"
echo "  ✓ BinUtils installés (ssh, zip, nmap, curl, git, etc.)"
[[ $INSTALL_NETBIOS == "o" || $INSTALL_NETBIOS == "O" ]] && echo "  ✓ NetBIOS/Samba installé et configuré"
echo "  ✓ BASH personnalisé"
[[ $CONFIG_IP == "o" || $CONFIG_IP == "O" ]] && echo "  ✓ Réseau configuré en IP fixe"
[[ $CHANGE_HOSTNAME == "o" || $CHANGE_HOSTNAME == "O" ]] && echo "  ✓ Hostname modifié"
[[ $INSTALL_WEBMIN == "o" || $INSTALL_WEBMIN == "O" ]] && echo "  ✓ WebMin installé"
[[ $INSTALL_GAMES == "o" || $INSTALL_GAMES == "O" ]] && echo "  ✓ BSDGames installé"
echo ""
log_info "Pensez à redémarrer le système pour appliquer tous les changements !"
log_info "Script terminé avec succès."
