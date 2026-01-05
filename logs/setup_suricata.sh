#!/bin/bash
# setup_suricata.sh - Configuration de l'IDS Suricata sur fw1

echo "[*] Configuration de Suricata sur fw1..."

# 1. Création d'un fichier de règles locales
mkdir -p /etc/suricata/rules
cat <<EOF > /etc/suricata/rules/local.rules
# Détection du Ping (ICMP)
alert icmp any any -> any any (msg:"[IDS] Ping detecte (ICMP)"; sid:1000001; rev:1;)

# Détection de scan de ports (Tentatives TCP SYN)
alert tcp any any -> 10.0.1.2 443 (msg:"[IDS] Tentative de scan HTTPS sur DMZ"; flags:S; sid:1000002; rev:1;)

# Détection de flux SSH non autorisés
alert tcp any any -> any 22 (msg:"[IDS] Flux SSH detecte (Port 22)"; sid:1000003; rev:1;)
EOF

# 2. Ajout de la règle locale dans la configuration principale
# On s'assure que Suricata lit notre fichier local.rules
if ! grep -q "local.rules" /etc/suricata/suricata.yaml; then
    echo "  - local.rules" >> /etc/suricata/suricata.yaml
fi

echo "[OK] Suricata est prêt sur fw1."