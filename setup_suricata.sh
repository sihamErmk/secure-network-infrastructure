#!/bin/bash
# setup_suricata.sh - IDS Suricata pour Mininet (fw1)

echo "[*] Nettoyage des anciennes instances..."
pkill suricata 2>/dev/null

echo "[*] Creation du dossier de logs..."
mkdir -p /var/log/suricata

echo "[*] Creation du fichier de regles dans /root/local.rules..."
# Utilisation du chemin /root/ pour eviter les problemes de permissions
cat <<EOF > /root/local.rules
# Regle 1 : Detection du Ping (ICMP)
alert icmp any any -> any any (msg:"[IDS] Ping detecte (ICMP)"; sid:1000001; rev:1;)

# Regle 2 : Detection de scan de ports (Flags SYN)
alert tcp any any -> 10.0.1.2 443 (msg:"[IDS] Scan HTTPS detecte"; flags:S; sid:1000002; rev:1;)

# Regle 3 : Detection de tentative SSH
alert tcp any any -> any 22 (msg:"[IDS] Flux SSH detecte"; sid:1000003; rev:1;)
EOF

chmod 644 /root/local.rules

echo "[OK] Configuration terminee."
echo "[!] Lancez maintenant Suricata avec la commande suivante sur fw1 :"
echo "suricata -c /etc/suricata/suricata.yaml -i fw1-eth0 -S /root/local.rules --runmode single"