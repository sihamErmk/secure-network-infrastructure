#!/bin/bash
# setup_suricata.sh - IDS Suricata pour Mininet (fw1)

echo "[*] Nettoyage des anciennes instances..."
pkill suricata 2>/dev/null

echo "[*] Creation du dossier de logs..."
mkdir -p /var/log/suricata

echo "[*] Generation du fichier de regles dans /root/local.rules..."
# On utilise le chemin que vous avez valide pour eviter les problemes de pattern
cat <<EOF > /root/local.rules
alert icmp any any -> any any (msg:"[IDS] Ping detecte (ICMP)"; sid:1000001; rev:1;)
alert tcp any any -> 10.0.1.2 443 (msg:"[IDS] Scan HTTPS detecte"; flags:S; sid:1000002; rev:1;)
alert tcp any any -> any 22 (msg:"[IDS] Flux SSH detecte"; sid:1000003; rev:1;)
EOF

chmod 644 /root/local.rules

echo "[OK] Configuration terminee. Le fichier /root/local.rules a ete cree."
echo "[!] LANCEZ SURICATA AVEC CETTE COMMANDE :"
echo "suricata -c /etc/suricata/suricata.yaml -i fw1-eth0 -S /root/local.rules --runmode single"