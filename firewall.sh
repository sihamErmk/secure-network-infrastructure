#!/bin/bash
# firewall.sh - Pare-feu central (fw1)
# Zones : eth0=WAN, eth1=DMZ, eth2=LAN, eth3=VPN, eth4=ADM

# 1. Nettoyage et Politiques par défaut (Zero Trust)
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 2. Stateful Inspection (Indispensable pour autoriser les réponses)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 3. ACCÈS WAN -> DMZ (Exposition des services)
# Autoriser HTTP (80) pour redirection et HTTPS (443) vers le serveur DMZ
echo "[*] Autorisation WAN -> DMZ (Web)"
iptables -A FORWARD -i fw1-eth0 -o fw1-eth1 -p tcp -d 10.0.1.2 --dport 80 -j ACCEPT
iptables -A FORWARD -i fw1-eth0 -o fw1-eth1 -p tcp -d 10.0.1.2 --dport 443 -j ACCEPT

# 4. ACCÈS VPN (Tunneling)
# Autoriser la création du tunnel OpenVPN (UDP 1194) du WAN vers le serveur VPN
echo "[*] Autorisation du tunnel VPN (UDP 1194)"
iptables -A FORWARD -i fw1-eth0 -o fw1-eth3 -p udp -d 10.0.3.2 --dport 1194 -j ACCEPT

# 5. FLUX À L'INTÉRIEUR DU TUNNEL (Admin distant)
# Une fois le tunnel monté, le trafic vient de 10.8.0.0/24 via l'interface eth3
echo "[*] Autorisation Admin VPN -> LAN (SSH)"
iptables -A FORWARD -i fw1-eth3 -s 10.8.0.0/24 -d 10.0.2.2 -p tcp --dport 22 -j ACCEPT

# 6. ADMINISTRATION LOCALE (Zone ADM)
# Autoriser SSH direct de l'administrateur local vers le LAN et la DMZ
echo "[*] Autorisation Admin Local -> LAN/DMZ (SSH)"
iptables -A FORWARD -i fw1-eth4 -o fw1-eth2 -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -i fw1-eth4 -o fw1-eth1 -p tcp --dport 22 -j ACCEPT

# 7. SORTIE LAN -> WAN (Navigation limitée)
echo "[*] Autorisation LAN -> WAN (HTTPS)"
iptables -A FORWARD -i fw1-eth2 -o fw1-eth0 -p tcp --dport 443 -j ACCEPT

# 8. LOGGING (Pour le rapport technique)
# On enregistre tout ce qui est refusé pour prouver le fonctionnement du ZPF
iptables -A FORWARD -j LOG --log-prefix "ZPF-BLOCK: " --log-level 4

echo "[OK] Pare-feu Zero Trust configuré avec succès."