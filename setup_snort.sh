#!/bin/bash
# 04_setup_snort.sh - Configuration complète de Snort sur Ubuntu 22.04

echo "=========================================="
echo "Configuration de Snort IDS"
echo "=========================================="

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then 
    echo "ERREUR: Ce script doit être exécuté avec sudo"
    exit 1
fi

# Création des répertoires nécessaires
echo "[1/7] Création de la structure de répertoires..."
mkdir -p /etc/snort/rules
mkdir -p /etc/snort/so_rules
mkdir -p /etc/snort/preproc_rules
mkdir -p /var/log/snort
mkdir -p /usr/local/lib/snort_dynamicrules

# Permissions
chmod -R 755 /etc/snort
chmod -R 755 /var/log/snort

# Sauvegarde de la config existante si elle existe
if [ -f /etc/snort/snort.conf ]; then
    echo "[*] Sauvegarde de la configuration existante..."
    cp /etc/snort/snort.conf /etc/snort/snort.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# Configuration de base de Snort
echo "[2/7] Configuration du fichier snort.conf..."
tee /etc/snort/snort.conf > /dev/null <<'EOF'
# Configuration Snort pour le projet LSI3
# Ubuntu 22.04

# ================================================
# Configuration Réseau
# ================================================
var HOME_NET 10.0.0.0/8
var EXTERNAL_NET !$HOME_NET

var DNS_SERVERS $HOME_NET
var SMTP_SERVERS $HOME_NET
var HTTP_SERVERS $HOME_NET
var SQL_SERVERS $HOME_NET
var TELNET_SERVERS $HOME_NET

# Chemins
var RULE_PATH /etc/snort/rules
var SO_RULE_PATH /etc/snort/so_rules
var PREPROC_RULE_PATH /etc/snort/preproc_rules

# ================================================
# Configuration des Ports
# ================================================
portvar HTTP_PORTS [80,8080,8180]
portvar HTTPS_PORTS [443,8443]
portvar SHELLCODE_PORTS !80
portvar ORACLE_PORTS 1521
portvar SSH_PORTS 22
portvar FTP_PORTS [21,2100,3535]
portvar SIP_PORTS [5060,5061,5600]
portvar FILE_DATA_PORTS [$HTTP_PORTS,110,143]
portvar GTP_PORTS [2123,2152,3386]

# ================================================
# Préprocesseurs de Base
# ================================================
preprocessor frag3_global: max_frags 65536
preprocessor frag3_engine: policy windows detect_anomalies overlap_limit 10 min_fragment_length 100 timeout 180

preprocessor stream5_global: track_tcp yes, track_udp yes, track_icmp no, max_tcp 262144, max_udp 131072
preprocessor stream5_tcp: policy windows, detect_anomalies, require_3whs 180, overlap_limit 10, small_segments 3 bytes 150, timeout 180

preprocessor stream5_udp: timeout 180

# ================================================
# HTTP Inspect
# ================================================
preprocessor http_inspect: global iis_unicode_map unicode.map 1252 compress_depth 65535 decompress_depth 65535

preprocessor http_inspect_server: server default \
    profile all \
    ports { 80 8080 8180 } \
    server_flow_depth 0 \
    client_flow_depth 0 \
    post_depth 65495 \
    oversize_dir_length 500 \
    max_header_length 750 \
    max_headers 100 \
    max_spaces 200 \
    small_chunk_length { 10 5 } \
    enable_cookie \
    extended_response_inspection \
    inspect_gzip \
    normalize_utf \
    unlimited_decompress

# ================================================
# Autres Préprocesseurs
# ================================================
preprocessor rpc_decode: 111 32770 32771 32772 32773 32774 32775 32776 32777 32778 32779
preprocessor bo
preprocessor ftp_telnet: global inspection_type stateful encrypted_traffic no
preprocessor ftp_telnet_protocol: telnet normalize ports { 23 } ayt_attack_thresh 20
preprocessor ftp_telnet_protocol: ftp server default def_max_param_len 100

preprocessor smtp: ports { 25 465 587 691 } \
    inspection_type stateful \
    normalize cmds \
    normalize_cmds { MAIL RCPT HELP HELO ETRN EHLO EXPN VRFY ATRN SIZE BDAT DEBUG EMAL ESAM ESND ESOM EVFY IDENT NOOP RSET SEND SAML SOML AUTH TURN ETRN DATA QUIT ONEX QUEU STARTTLS TICK TIME TURNME VERB X-EXPS X-LINK2STATE XADR XAUTH XCIR XEXCH50 XGEN XLICENSE XQUE XSTA XTRN XUSR } \
    max_command_line_len 512 \
    max_header_line_len 1000 \
    max_response_line_len 512 \
    alt_max_command_line_len 260 { MAIL } \
    alt_max_command_line_len 300 { RCPT } \
    alt_max_command_line_len 500 { HELP HELO ETRN EHLO }

preprocessor ssh: server_ports { 22 } \
                  autodetect \
                  max_client_bytes 19600 \
                  max_encrypted_packets 20 \
                  max_server_version_len 100

preprocessor ssl: ports { 443 465 563 636 989 992 993 994 995 7801 7802 7900 7901 7902 7903 7904 7905 7906 7907 7908 7909 7910 7911 7912 7913 7914 7915 7916 7917 7918 7919 7920 }, trustservers, noinspect_encrypted

# ================================================
# Inclusion des Règles
# ================================================
include $RULE_PATH/local.rules
include $RULE_PATH/custom.rules

# ================================================
# Configuration de la Sortie
# ================================================
output alert_fast: /var/log/snort/alert
output log_tcpdump: /var/log/snort/snort.log
EOF

# Création des règles personnalisées - Scans réseau
echo "[3/7] Création des règles IDS pour scans réseau..."
tee /etc/snort/rules/local.rules > /dev/null <<'EOF'
# ================================================
# Règles de détection de scan réseau
# ================================================

# ICMP Ping Detection
alert icmp any any -> $HOME_NET any (msg:"ICMP Ping Detected"; itype:8; sid:1000001; rev:1;)

# Nmap SYN Scan
alert tcp any any -> $HOME_NET any (msg:"Nmap SYN Scan Detected"; flags:S; threshold:type threshold, track by_src, count 20, seconds 60; sid:1000002; rev:1;)

# Nmap NULL Scan
alert tcp any any -> $HOME_NET any (msg:"Nmap NULL Scan Detected"; flags:0; threshold:type threshold, track by_src, count 20, seconds 60; sid:1000003; rev:1;)

# Nmap FIN Scan
alert tcp any any -> $HOME_NET any (msg:"Nmap FIN Scan Detected"; flags:F; threshold:type threshold, track by_src, count 20, seconds 60; sid:1000004; rev:1;)

# Nmap XMAS Scan
alert tcp any any -> $HOME_NET any (msg:"Nmap XMAS Scan Detected"; flags:FPU; threshold:type threshold, track by_src, count 20, seconds 60; sid:1000005; rev:1;)

# Port Scan - Multiple Ports
alert tcp any any -> $HOME_NET any (msg:"Port Scan Detected - Multiple Ports"; threshold:type threshold, track by_src, count 30, seconds 60; sid:1000006; rev:1;)

# Aggressive Scan Detected
alert tcp any any -> $HOME_NET any (msg:"Aggressive Network Scan"; flags:S; threshold:type both, track by_src, count 50, seconds 30; sid:1000007; rev:1;)
EOF

# Règles pour SSH et attaques web
echo "[4/7] Création des règles IDS personnalisées..."
tee /etc/snort/rules/custom.rules > /dev/null <<'EOF'
# ================================================
# Détection brute-force SSH
# ================================================
alert tcp any any -> $HOME_NET 22 (msg:"SSH Brute Force Attack Detected"; flow:to_server,established; threshold:type threshold, track by_src, count 5, seconds 60; sid:1000010; rev:1;)

alert tcp any any -> $HOME_NET 22 (msg:"Multiple SSH Connection Attempts"; flags:S; threshold:type threshold, track by_src, count 10, seconds 30; sid:1000011; rev:1;)

alert tcp any any -> $HOME_NET 22 (msg:"SSH Failed Login Attempt"; flow:to_server,established; content:"Failed"; nocase; sid:1000012; rev:1;)

# ================================================
# Détection d'attaques web
# ================================================
alert tcp any any -> $HOME_NET $HTTP_PORTS (msg:"SQL Injection Attempt - UNION SELECT"; flow:to_server,established; content:"union"; nocase; content:"select"; nocase; sid:1000020; rev:1;)

alert tcp any any -> $HOME_NET $HTTP_PORTS (msg:"SQL Injection Attempt - OR 1=1"; flow:to_server,established; content:"or"; nocase; content:"1=1"; nocase; sid:1000021; rev:1;)

alert tcp any any -> $HOME_NET $HTTP_PORTS (msg:"XSS Attack Attempt - Script Tag"; flow:to_server,established; content:"<script"; nocase; sid:1000022; rev:1;)

alert tcp any any -> $HOME_NET $HTTP_PORTS (msg:"Directory Traversal Attempt"; flow:to_server,established; content:"../"; sid:1000023; rev:1;)

alert tcp any any -> $HOME_NET $HTTP_PORTS (msg:"Suspicious HTTP Request - admin"; flow:to_server,established; content:"/admin"; nocase; sid:1000024; rev:1;)

alert tcp any any -> $HOME_NET $HTTP_PORTS (msg:"Command Injection Attempt"; flow:to_server,established; pcre:"/;.*\s*(cat|ls|nc|wget|curl)/i"; sid:1000025; rev:1;)

alert tcp any any -> $HOME_NET $HTTP_PORTS (msg:"PHP Code Injection Attempt"; flow:to_server,established; content:"<?php"; nocase; sid:1000026; rev:1;)

# ================================================
# Détection VPN et autres services
# ================================================
alert udp any any -> $HOME_NET 1194 (msg:"OpenVPN Connection Attempt"; sid:1000030; rev:1;)

alert tcp any any -> $HOME_NET $HTTPS_PORTS (msg:"HTTPS Connection to Sensitive Service"; flags:S; sid:1000040; rev:1;)

# ================================================
# Détection d'anomalies réseau
# ================================================
alert tcp any any -> $HOME_NET any (msg:"Suspicious TCP Flags - All Flags Set"; flags:UAPRSF; sid:1000050; rev:1;)

alert ip any any -> $HOME_NET any (msg:"IP Fragmentation Detected"; fragbits:M; sid:1000051; rev:1;)
EOF

# Test de configuration
echo "[5/7] Test de la configuration Snort..."
snort -T -c /etc/snort/snort.conf 2>&1 | tee /tmp/snort_test.log

if grep -q "Snort successfully validated the configuration" /tmp/snort_test.log; then
    echo "[OK] Configuration Snort validée avec succès"
else
    echo "[ERREUR] La configuration Snort contient des erreurs"
    echo "Consultez /tmp/snort_test.log pour plus de détails"
fi

# Création du script de démarrage
echo "[6/7] Création du script de démarrage..."
tee /usr/local/bin/start_snort.sh > /dev/null <<'EOF'
#!/bin/bash
# Script de démarrage Snort

INTERFACE=${1:-eth0}
LOG_DIR="/var/log/snort"

echo "[*] Démarrage de Snort sur l'interface $INTERFACE..."

# Arrêt de Snort s'il est déjà en cours d'exécution
pkill -9 snort 2>/dev/null

# Démarrage en mode daemon
snort -A fast -b -d -D -i $INTERFACE -u snort -g snort -c /etc/snort/snort.conf -l $LOG_DIR

if [ $? -eq 0 ]; then
    echo "[OK] Snort démarré en mode daemon"
    echo "[i] PID: $(pgrep snort)"
    echo "[i] Logs disponibles dans: $LOG_DIR"
    echo "[i] Pour voir les alertes: sudo tail -f $LOG_DIR/alert"
else
    echo "[ERREUR] Échec du démarrage de Snort"
    exit 1
fi
EOF

chmod +x /usr/local/bin/start_snort.sh

# Configuration de l'utilisateur snort
echo "[7/7] Configuration de l'utilisateur snort..."
groupadd -f snort 2>/dev/null
useradd snort -r -s /sbin/nologin -c "Snort IDS" -g snort 2>/dev/null || true
chown -R snort:snort /var/log/snort
chown -R snort:snort /etc/snort

echo ""
echo "=========================================="
echo "[OK] Configuration de Snort terminée!"
echo "=========================================="
echo ""
echo "COMMANDES UTILES:"
echo "  Démarrer Snort:  sudo /usr/local/bin/start_snort.sh <interface>"
echo "  Exemple:         sudo /usr/local/bin/start_snort.sh fw1-eth0"
echo ""
echo "  Arrêter Snort:   sudo pkill snort"
echo "  Voir alertes:    sudo tail -f /var/log/snort/alert"
echo "  Voir logs:       sudo tail -f /var/log/snort/snort.log.*"
echo "  Test config:     sudo snort -T -c /etc/snort/snort.conf"
echo ""
echo "Règles créées:"
echo "  - /etc/snort/rules/local.rules (scans réseau)"
echo "  - /etc/snort/rules/custom.rules (attaques SSH/Web)"
echo ""