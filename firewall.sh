#!/bin/bash
# Nettoyage
iptables -F
iptables -X
iptables -P FORWARD DROP  # Politique ZERO TRUST

# Autoriser le trafic établi (Stateful)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Règle DMZ : WAN -> DMZ (Port 443 seulement)
iptables -A FORWARD -i fw1-eth0 -o fw1-eth1 -p tcp --dport 443 -d 10.0.1.10 -j ACCEPT

# Règle ADMIN : VPN -> LAN/DMZ (SSH seulement)
iptables -A FORWARD -i fw1-eth3 -o fw1-eth2 -p tcp --dport 22 -j ACCEPT

# Journalisation (Exigence 5.1)
iptables -A FORWARD -j LOG --log-prefix "FIREWALL-DROP: "