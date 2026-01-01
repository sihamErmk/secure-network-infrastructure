#!/bin/bash
# Nettoyage
iptables -F
iptables -X
iptables -t nat -F

# 1. POLITIQUE PAR DÉFAUT : ZERO TRUST
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 2. ETAT DE CONNEXION (Stateful)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 3. WAN -> DMZ (Autoriser HTTPS uniquement)
iptables -A FORWARD -i fw-eth0 -o fw-eth1 -p tcp --dport 443 -d 10.0.1.2 -j ACCEPT

# 4. VPN -> LAN (Accès admin après tunnel)
iptables -A FORWARD -i fw-eth3 -o fw-eth2 -j ACCEPT

# 5. LOGGING (Exigence 5.1)
iptables -A FORWARD -j LOG --log-prefix "ZPF-DROP: "
EOF

chmod +x /root/firewall.sh
/root/firewall.sh