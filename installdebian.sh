!/bin/bash
 
# Script d'automatisation des installations sur Debian
# Exécuter en tant que root
 
set -e  # Arrêter sur erreur
 
echo "Mise à jour du système..."
apt update && apt upgrade -y
 
echo "Installation des paquets principaux..."
apt install -y ssh zip nmap locate ncdu curl git screen dnsutils net-tools sudo lynx
 
echo "Installation de la couche NetBIOS (pour postes locaux)..."
apt install -y winbind samba
 
echo "Mise à jour de la base locate..."
updatedb
 
echo "Modification de /etc/nsswitch.conf pour ajouter 'wins'..."
sed -i 's/hosts: files mdns4_minimal \[NOTFOUND=return\] dns/hosts: files mdns4_minimal \[NOTFOUND=return\] dns wins/' /etc/nsswitch.conf
 
echo "Personnalisation du .bashrc root..."
sed -i '9,13s/^#//' /root/.bashrc
 
echo "Installation terminée ! Redémarrez pour appliquer toutes les modifications."
echo "Vérifiez /etc/nsswitch.conf pour confirmer l'ajout de 'wins'."
