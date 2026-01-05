#!/bin/bash
# 05_setup_heartbeat.sh - Configuration Haute Disponibilité avec Heartbeat

echo "=========================================="
echo "Installation et Configuration Heartbeat"
echo "=========================================="

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then 
    echo "ERREUR: Ce script doit être exécuté avec sudo"
    exit 1
fi

# Installation de Heartbeat et cluster-glue
echo "[1/6] Installation des paquets nécessaires..."
apt update
apt install -y heartbeat cluster-glue resource-agents

# Création des répertoires de configuration
mkdir -p /etc/ha.d
mkdir -p /var/log/heartbeat

# Configuration du fichier ha.cf (principal)
echo "[2/6] Configuration de ha.cf..."
tee /etc/ha.d/ha.cf > /dev/null <<'EOF'
# ================================================
# Configuration Heartbeat - Projet LSI3
# Cluster Actif/Passif pour haute disponibilité
# ================================================

# ================================================
# Fichiers de log
# ================================================
logfile /var/log/heartbeat/ha-log
logfacility local0
debugfile /var/log/heartbeat/ha-debug

# ================================================
# Délais et timeouts (en secondes)
# ================================================
keepalive 2          # Intervalle d'envoi des heartbeats
deadtime 10          # Temps avant de considérer un nœud mort
warntime 5           # Temps avant l'alerte
initdead 30          # Temps d'attente au démarrage (premier heartbeat)

# ================================================
# Interface de communication
# ================================================
# Utilisation de l'interface de communication entre fw1 et fw2
# IMPORTANT: Adapter selon votre topologie
bcast fw1-eth0       # Interface broadcast pour heartbeat (zone WAN)
udpport 694          # Port UDP pour heartbeat

# Alternative avec multicast (si supporté):
# mcast eth0 225.0.0.1 694 1 0

# ================================================
# Comportement du cluster
# ================================================
auto_failback on     # Le nœud principal reprend le service après récupération
                     # off = le nœud qui a pris le relais garde la main

# ================================================
# Nœuds du cluster
# ================================================
node fw1             # Nœud actif (principal)
node fw2             # Nœud passif (backup)

# ================================================
# Compression et optimisation
# ================================================
compression bz2
compression_threshold 2

# ================================================
# Authentification
# ================================================
# IMPORTANT: Utiliser l'authentification en production
auth sha1
/etc/ha.d/authkeys

# Alternative sans authentification (NON RECOMMANDÉ):
# auth crc

# ================================================
# Processus de surveillance (optionnel)
# ================================================
# respawn hacluster /usr/lib/heartbeat/ipfail

# ================================================
# Options avancées
# ================================================
# Ping node (pour vérifier connectivité réseau)
# ping 8.8.8.8
# ping_group group1

# Nice level pour les processus heartbeat
nice_failback 10

# API compatibility
apiauth ipfail gid=haclient uid=hacluster
EOF

# Configuration des authkeys (authentification)
echo "[3/6] Configuration de l'authentification..."
tee /etc/ha.d/authkeys > /dev/null <<'EOF'
# ================================================
# Fichier d'authentification Heartbeat
# ================================================
# Format: auth <num>
#         <num> <method> <key>

auth 1
1 sha1 HASHkey_LSI3_SecureCluster_2025_ProjetZeroTrust
EOF

chmod 600 /etc/ha.d/authkeys

# Configuration des ressources (haresources)
echo "[4/6] Configuration des ressources (IP virtuelle)..."
tee /etc/ha.d/haresources > /dev/null <<'EOF'
# ================================================
# Configuration des ressources Heartbeat
# ================================================
# Format: noeud_principal ressource [ressource...]
#
# fw1 = nœud principal qui possède les ressources par défaut
# IPaddr::IP/masque/interface = IP virtuelle partagée (VIP)
# 10.0.0.100 = IP virtuelle pour l'accès aux services

fw1 IPaddr::10.0.0.100/24/fw1-eth0
EOF

# Script de vérification du statut du cluster
echo "[5/6] Création du script de monitoring..."
tee /usr/local/bin/check_ha_status.sh > /dev/null <<'EOF'
#!/bin/bash
# Script de vérification du statut du cluster Heartbeat

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================="
echo "Statut du Cluster Haute Disponibilité"
echo -e "==========================================${NC}"

# Statut du service Heartbeat
echo -e "\n${YELLOW}[1] Statut du service Heartbeat:${NC}"
if systemctl is-active --quiet heartbeat; then
    echo -e "  ${GREEN}✓ Service actif${NC}"
    systemctl status heartbeat --no-pager | grep -E "Active|Main PID" | sed 's/^/  /'
else
    echo -e "  ${RED}✗ Service inactif${NC}"
fi

# Vérification des processus Heartbeat
echo -e "\n${YELLOW}[2] Processus Heartbeat:${NC}"
if pgrep -x heartbeat > /dev/null; then
    ps aux | grep -E "[h]eartbeat" | awk '{print "  PID: "$2" | CMD: "$11}' | head -5
else
    echo -e "  ${RED}Aucun processus heartbeat trouvé${NC}"
fi

# Affichage des logs récents
echo -e "\n${YELLOW}[3] Dernières entrées du log (15 lignes):${NC}"
if [ -f /var/log/heartbeat/ha-log ]; then
    tail -n 15 /var/log/heartbeat/ha-log | sed 's/^/  /'
else
    echo -e "  ${RED}Fichier de log non trouvé${NC}"
fi

# Vérification de l'IP virtuelle
echo -e "\n${YELLOW}[4] IP Virtuelle (VIP: 10.0.0.100):${NC}"
if ip addr show | grep -q "10.0.0.100"; then
    interface=$(ip addr show | grep "10.0.0.100" | awk '{print $NF}')
    echo -e "  ${GREEN}✓ IP Virtuelle ACTIVE sur ce nœud${NC}"
    echo -e "  Interface: $interface"
    ip addr show | grep "10.0.0.100" | sed 's/^/  /'
else
    echo -e "  ${YELLOW}⚠ IP Virtuelle NON présente${NC}"
    echo -e "  Ce nœud est probablement PASSIF"
fi

# Rôle du nœud
echo -e "\n${YELLOW}[5] Rôle du nœud:${NC}"
if ip addr show | grep -q "10.0.0.100"; then
    echo -e "  ${GREEN}✓ NŒUD ACTIF (PRIMARY)${NC}"
else
    echo -e "  ${CYAN}⚠ NŒUD PASSIF (STANDBY)${NC}"
fi

# Configuration actuelle
echo -e "\n${YELLOW}[6] Configuration:${NC}"
if [ -f /etc/ha.d/ha.cf ]; then
    echo "  Nœuds configurés:"
    grep "^node" /etc/ha.d/ha.cf | sed 's/^/    /'
    echo "  Auto-failback:"
    grep "^auto_failback" /etc/ha.d/ha.cf | sed 's/^/    /'
fi

# Ressources
echo -e "\n${YELLOW}[7] Ressources gérées:${NC}"
if [ -f /etc/ha.d/haresources ]; then
    grep -v "^#" /etc/ha.d/haresources | grep -v "^$" | sed 's/^/  /'
fi

echo -e "\n${CYAN}==========================================${NC}"
EOF

chmod +x /usr/local/bin/check_ha_status.sh

# Script de test de basculement
echo "[6/6] Création du script de test de basculement..."
tee /usr/local/bin/test_ha_failover.sh > /dev/null <<'EOF'
#!/bin/bash
# Script de test de basculement (failover)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================="
echo "Test de Basculement (Failover)"
echo -e "==========================================${NC}"
echo ""

# Vérifier si on est sur le nœud actif
if ! ip addr show | grep -q "10.0.0.100"; then
    echo -e "${RED}Ce nœud est PASSIF. Exécutez ce script sur le nœud ACTIF (fw1)${NC}"
    exit 1
fi

echo -e "${YELLOW}Ce test va :${NC}"
echo "  1. Afficher l'état actuel"
echo "  2. Arrêter Heartbeat sur ce nœud"
echo "  3. Surveiller le basculement"
echo ""
read -p "Continuer? (o/N): " confirm

if [ "$confirm" != "o" ]; then
    echo "Test annulé"
    exit 0
fi

echo ""
echo -e "${CYAN}[1] État AVANT le basculement:${NC}"
ip addr show | grep "10.0.0.100" && echo "  ✓ IP virtuelle présente sur ce nœud"

echo ""
echo -e "${YELLOW}[2] Arrêt de Heartbeat...${NC}"
systemctl stop heartbeat

echo ""
echo -e "${YELLOW}[3] Attente du basculement (15 secondes)...${NC}"
for i in {15..1}; do
    echo -n "  $i..."
    sleep 1
done
echo ""

echo ""
echo -e "${CYAN}[4] État APRÈS le basculement:${NC}"
if ip addr show | grep -q "10.0.0.100"; then
    echo -e "  ${RED}✗ IP virtuelle toujours présente (problème!)${NC}"
else
    echo -e "  ${GREEN}✓ IP virtuelle basculée vers fw2${NC}"
    echo -e "  ${GREEN}✓ Basculement réussi!${NC}"
fi

echo ""
echo -e "${YELLOW}Pour vérifier sur fw2:${NC}"
echo "  ip addr show | grep 10.0.0.100"
echo ""
echo -e "${YELLOW}Pour restaurer ce nœud:${NC}"
echo "  systemctl start heartbeat"
EOF

chmod +x /usr/local/bin/test_ha_failover.sh

# Instructions finales
echo ""
echo "=========================================="
echo "[OK] Configuration Heartbeat terminée!"
echo "=========================================="
echo ""
echo -e "\033[1;33mIMPORTANT:\033[0m"
echo "  1. Cette configuration doit être copiée sur TOUS les nœuds (fw1 ET fw2)"
echo "  2. Les nœuds doivent pouvoir communiquer sur l'interface spécifiée"
echo "  3. Les noms de nœuds (fw1, fw2) doivent correspondre aux hostnames"
echo ""
echo -e "\033[1;36mCONFIGURATION:\033[0m"
echo "  Fichier principal: /etc/ha.d/ha.cf"
echo "  Authentification:  /etc/ha.d/authkeys"
echo "  Ressources:        /etc/ha.d/haresources"
echo "  Logs:              /var/log/heartbeat/ha-log"
echo ""
echo -e "\033[1;32mCOMMANDES UTILES:\033[0m"
echo "  Démarrer:        sudo systemctl start heartbeat"
echo "  Arrêter:         sudo systemctl stop heartbeat"
echo "  Activer auto:    sudo systemctl enable heartbeat"
echo "  Statut:          sudo /usr/local/bin/check_ha_status.sh"
echo "  Test failover:   sudo /usr/local/bin/test_ha_failover.sh"
echo "  Logs en direct:  sudo tail -f /var/log/heartbeat/ha-log"
echo ""
echo -e "\033[1;33mTEST DE BASCULEMENT:\033[0m"
echo "  1. Sur fw1: sudo systemctl stop heartbeat"
echo "  2. Attendre 10-15 secondes"
echo "  3. Sur fw2: ip addr show | grep 10.0.0.100"
echo "  4. Tester: curl -k https://10.0.0.100 (devrait fonctionner)"
echo ""
echo -e "\033[1;33mÀ ADAPTER:\033[0m"
echo "  - Interface réseau: Modifier 'bcast fw1-eth0' dans ha.cf"
echo "  - IP virtuelle: Modifier '10.0.0.100' dans haresources"
echo "  - Hostnames: Vérifier que 'fw1' et 'fw2' correspondent"
echo ""
echo "=========================================="