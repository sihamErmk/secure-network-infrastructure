#!/bin/bash
# Zones : eth0=WAN, eth1=DMZ, eth2=LAN, eth3=VPN, eth4=ADM

# Reset
iptables -F
iptables -P INPUT DROP
iptables -P FORWARD DROP

# Autoriser le trafic de retour (Crucial !)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 1. WAN -> DMZ (Autoriser HTTP et HTTPS)
iptables -A FORWARD -i fw-eth0 -o fw-eth1 -p tcp -d 10.0.1.2 --dport 80 -j ACCEPT
iptables -A FORWARD -i fw-eth0 -o fw-eth1 -p tcp -d 10.0.1.2 --dport 443 -j ACCEPT

# 2. VPN/ADM -> LAN & DMZ (Administration SSH)
iptables -A FORWARD -i fw-eth4 -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -i fw-eth3 -p tcp --dport 22 -j ACCEPT

# 3. Logs pour debug
iptables -A FORWARD -j LOG --log-prefix "FIREWALL_DROP: "

echo "[OK] Firewall Zero Trust appliqué."