# firewall.sh
# 1. Reset
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP

# 2. Stateful Inspection (Autoriser le retour de trafic)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 3. WAN -> DMZ (HTTPS uniquement)
iptables -A FORWARD -i fw1-eth0 -o fw1-eth1 -p tcp -d 10.0.1.2 --dport 80 -j ACCEPT
iptables -A FORWARD -i fw1-eth0 -o fw1-eth1 -p tcp -d 10.0.1.2 --dport 443 -j ACCEPT

# 4. VPN -> LAN/DMZ (Admin SSH)
iptables -A FORWARD -i fw1-eth3 -p tcp --dport 22 -j ACCEPT

# 5. LAN -> WAN (Navigation limitée)
iptables -A FORWARD -i fw1-eth2 -o fw1-eth0 -p tcp --dport 443 -j ACCEPT

# 6. Logging
iptables -A FORWARD -j LOG --log-prefix "ZPF-BLOCK: "



# Autoriser le trafic VPN (UDP 1194) du WAN vers le serveur VPN
iptables -A FORWARD -i fw1-eth0 -o fw1-eth3 -p udp --dport 1194 -j ACCEPT

# Autoriser le trafic venant du tunnel VPN (10.8.0.0/24) vers le LAN
iptables -A FORWARD -s 10.8.0.0/24 -d 10.0.2.0/24 -j ACCEPT