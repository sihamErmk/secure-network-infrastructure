#!/bin/bash

# ==========================================================
# 1. DÉFINITION DES INTERFACES (Selon votre topologie)
# ==========================================================
WAN_IF="fw-eth0"    # Zone Internet (Hôte h_wan)
DMZ_IF="fw-eth1"    # Zone Publique (Hôte h_dmz)
LAN_IF="fw-eth2"    # Zone Interne (Hôte h_lan)
VPN_IF="fw-eth3"    # Zone Accès Distant (Hôte h_vpn)
ADM_IF="fw-eth4"    # Zone Administration (Hôte h_adm)

# IPs des serveurs critiques
SERVER_DMZ="10.0.1.2"

# ==========================================================
# 2. RÉINITIALISATION ET POLITIQUES PAR DÉFAUT
# ==========================================================
echo "[*] Initialisation du Pare-feu Zero Trust..."
iptables -F
iptables -X
iptables -t nat -F

# Politique par défaut : DROP (On jette tout)
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ==========================================================
# 3. RÈGLES DE BASE ET SÉCURITÉ RÉSEAU
# ==========================================================
# Autoriser la boucle locale (localhost)
iptables -A INPUT -i lo -j ACCEPT

# STATEFUL INSPECTION : Autoriser le trafic de retour (réponses)
# C'est ce qui permet au Zero Trust d'être fonctionnel
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ==========================================================
# 4. RÈGLES ICMP (PING) - RESTRICTION STRICTE
# ==========================================================
# Autoriser le ping SEULEMENT depuis l'intérieur vers l'extérieur
iptables -A FORWARD -i $LAN_IF -p icmp -j ACCEPT
iptables -A FORWARD -i $ADM_IF -p icmp -j ACCEPT
iptables -A FORWARD -i $VPN_IF -p icmp -j ACCEPT

# Le WAN ne peut pinger PERSONNE (Protection contre le scan)
# (Pas de règle ici = Blocage automatique par la politique DROP)

# ==========================================================
# 5. RÈGLES DE FLUX (SEGMENTATION)
# ==========================================================

# --- A. ACCÈS WAN -> DMZ (Services Web) ---
# Seul le HTTPS (443) est autorisé vers le serveur DMZ
echo "[*] Autorisation WAN -> DMZ (HTTPS uniquement)"
iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp -d $SERVER_DMZ --dport 443 -j ACCEPT
# Redirection HTTP vers HTTPS (Port 80 autorisé pour redirection)
iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp -d $SERVER_DMZ --dport 80 -j ACCEPT

# --- B. ACCÈS LAN -> WAN (Sortie Internet) ---
echo "[*] Autorisation LAN -> WAN (DNS et Web)"
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -p tcp --dport 443 -j ACCEPT

# --- C. ADMINISTRATION SÉCURISÉE (SSH par clé) ---
# SSH autorisé uniquement depuis la zone ADM ou VPN vers les serveurs
echo "[*] Autorisation Administration SSH"
iptables -A FORWARD -i $ADM_IF -o $LAN_IF -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -i $ADM_IF -o $DMZ_IF -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -i $VPN_IF -o $LAN_IF -p tcp --dport 22 -j ACCEPT

# ==========================================================
# 6. JOURNALISATION (LOGS) ET PROTECTION FINALE
# ==========================================================
# On enregistre tout ce qui va être bloqué (Exigence 5.1)
echo "[*] Activation de la journalisation des paquets bloqués"
iptables -A FORWARD -j LOG --log-prefix "ZPF-DROP: " --log-level 4
iptables -A INPUT -j LOG --log-prefix "ZPF-INPUT-DROP: " --log-level 4

echo "[OK] Pare-feu configuré en mode Zero Trust."