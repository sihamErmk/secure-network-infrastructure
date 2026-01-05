#!/bin/bash

# run_all_tests.sh - Audit de Sécurité Automatisé
# Projet : Zero Trust Network LSI3

RESULTS_FILE="test_results.json"
LOG_FILE="audit.log"

# Couleurs pour le terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}[*] Lancement de l'audit de sécurité...${NC}"

# 1. Nettoyage initial
sudo mn -c > /dev/null 2>&1

# 2. Lancement de la topologie en arrière-plan (sans CLI)
# On modifie temporairement topo.py pour ne pas lancer le CLI lors de l'audit
sed -i 's/CLI(net)/#CLI(net)/' topo.py
sudo python3 topo.py > $LOG_FILE 2>&1 &
TOP_PID=$!
sleep 5 # Attente de l'initialisation

# Fonctions utilitaires
check_ping() {
    # $1=Source, $2=Dest
    sudo ip netns exec mn.$1 ping -c 1 -W 1 $2 > /dev/null 2>&1
    return $?
}

check_port() {
    # $1=Source, $2=IP_Dest, $3=Port
    sudo ip netns exec mn.$1 nc -zv -w 2 $2 $3 > /dev/null 2>&1
    return $?
}

# Initialisation JSON
echo "{" > $RESULTS_FILE

# --- TEST 1 : Connectivité de base ---
echo -n "[Test 1] Routage FW1... "
if check_ping h_lan 10.0.1.2; then
    STATUS="PASS"; echo -e "${GREEN}OK${NC}"
else
    STATUS="FAIL"; echo -e "${RED}KO${NC}"
fi
echo "  \"T1_ROUTING\": {\"status\": \"$STATUS\", \"desc\": \"Ping LAN vers DMZ\"}," >> $RESULTS_FILE

# --- TEST 2 : Application du Pare-feu ---
echo -n "[Test 2] Configuration Firewall... "
sudo ip netns exec mn.fw1 bash firewall.sh >> $LOG_FILE 2>&1
if [ $? -eq 0 ]; then
    STATUS="PASS"; echo -e "${GREEN}OK${NC}"
else
    STATUS="FAIL"; echo -e "${RED}KO${NC}"
fi
echo "  \"T2_FIREWALL_LOAD\": {\"status\": \"$STATUS\", \"desc\": \"Chargement IPTables\"}," >> $RESULTS_FILE

# --- TEST 3 : Sécurité (Filtrage) ---
echo -n "[Test 3] Isolation WAN -> LAN (Zero Trust)... "
check_ping h_wan 10.0.2.2
if [ $? -ne 0 ]; then # Doit échouer
    STATUS="PASS"; echo -e "${GREEN}OK (Bloqué)${NC}"
else
    STATUS="FAIL"; echo -e "${RED}ECHEC (Ouvert)${NC}"
fi
echo "  \"T3_ISOLATION\": {\"status\": \"$STATUS\", \"desc\": \"WAN ne peut pas ping LAN\"}," >> $RESULTS_FILE

# --- TEST 4 : DMZ (HTTPS) ---
echo -n "[Test 4] Service DMZ HTTPS... "
# On prépare le serveur sur h_dmz
sudo ip netns exec mn.h_dmz bash setup_dmz_python.sh >> $LOG_FILE 2>&1
sleep 2
check_port h_wan 10.0.1.2 443
if [ $? -eq 0 ]; then
    STATUS="PASS"; echo -e "${GREEN}OUVERT${NC}"
else
    STATUS="FAIL"; echo -e "${RED}FERME${NC}"
fi
echo "  \"T4_DMZ_HTTPS\": {\"status\": \"$STATUS\", \"desc\": \"Acces Port 443 DMZ\"}," >> $RESULTS_FILE

# --- TEST 5 : VPN Tunneling ---
echo -n "[Test 5] Tunnel VPN... "
sudo ip netns exec mn.h_vpn bash vpn_server.sh >> $LOG_FILE 2>&1
sudo ip netns exec mn.h_wan bash vpn_client.sh >> $LOG_FILE 2>&1
sleep 7
# Vérifier si l'interface tun0 existe sur h_wan
sudo ip netns exec mn.h_wan ip addr show tun0 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    STATUS="PASS"; echo -e "${GREEN}TUNNEL UP${NC}"
else
    STATUS="FAIL"; echo -e "${RED}NO TUNNEL${NC}"
fi
echo "  \"T5_VPN_TUNNEL\": {\"status\": \"$STATUS\", \"desc\": \"Interface tun0 active\"}" >> $RESULTS_FILE

# Clôture JSON
echo "}" >> $RESULTS_FILE

# Nettoyage final
echo -e "${GREEN}[*] Audit terminé. Résultats dans $RESULTS_FILE${NC}"
sudo pkill -f "python3 topo.py"
sudo mn -c > /dev/null 2>&1
# Rétablir topo.py
sed -i 's/#CLI(net)/CLI(net)/' topo.py