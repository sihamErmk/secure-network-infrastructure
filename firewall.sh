#!/bin/bash
# Reset
iptables -F
iptables -X
iptables -t nat -F

# Politique par défaut : DROP TOTAL
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Autoriser le trafic établi (Stateful)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 1. WAN -> DMZ (HTTPS uniquement)
iptables -A FORWARD -i fw1-eth0 -o fw1-eth1 -p tcp --dport 443 -d 10.0.1.2 -j ACCEPT

# 2. VPN -> ADMIN (Accès distant sécurisé)
iptables -A FORWARD -i fw1-eth3 -o fw1-eth4 -p tcp --dport 22 -j ACCEPT

# 3. Journalisation
iptables -A FORWARD -j LOG --log-prefix "ZERO-TRUST-DROP: "