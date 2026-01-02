Secure Network Infrastructure (Zero Trust Implementation)
Ce projet implémente une infrastructure réseau sécurisée basée sur le modèle Zero Trust au sein d'un environnement simulé Mininet.
📁 Structure du Projet
code
Text
.
├── topologie.py       # Définition du réseau (5 zones + Cluster HA)
├── firewall.sh        # Règles IPTables (Zone-Based Firewall)
├── generate_ssl.sh    # Génération des certificats pour la DMZ
├── sec.py             # Serveur Web Python (HTTPS + Redirection)
├── setup_dmz.sh       # Script d'installation du service Web
├── vpn_gencert.sh     # Génération de la PKI pour le VPN
├── vpn_server.sh      # Configuration & Lancement du serveur VPN (h_vpn)
└── vpn_client.sh      # Configuration & Lancement du client VPN (h_wan)
🛠️ Préparation de l'environnement
1. Cloner le projet
code
Bash
git clone https://github.com/sihamErmk/secure-network-infrastructure.git
cd secure-network-infrastructure
2. Permissions et Dépendances
code
Bash
chmod +x *.sh topologie.py
sudo apt-get update && sudo apt-get install -y mininet openvswitch-switch openssl openvpn curl iptables snort
🚀 Guide d'Utilisation & Tests de Validation
1. Lancer la Topologie
code
Bash
sudo python3 topologie.py
Test : mininet> nodes
Résultat attendu : Affichage de fw1, fw2, h_wan, h_dmz, h_lan, h_vpn, h_adm.
2. Configurer le Pare-feu (fw1)
code
Bash
mininet> fw1 bash firewall.sh
Test : mininet> h_wan ping -c 2 10.0.2.2 (WAN vers LAN)
Résultat attendu : 100% packet loss. (Preuve que le Zero Trust bloque tout accès non autorisé).
3. Déployer la DMZ Sécurisée (h_dmz)
code
Bash
mininet> h_dmz bash setup_dmz.sh
Test A (Redirection) : mininet> h_wan curl -I http://10.0.1.2
Résultat attendu : HTTP/1.0 301 Moved Permanently (Redirection vers HTTPS).
Test B (HTTPS) : mininet> h_wan curl -k https://10.0.1.2
Résultat attendu : Affichage du code HTML : <h1>Zone Demilitarisee (DMZ) Securisee</h1>.
4. Établir l'Accès Distant (VPN)
code
Bash
mininet> h_vpn bash vpn_gencert.sh
mininet> h_vpn bash vpn_server.sh
mininet> h_wan bash vpn_client.sh
Test A (Interface) : mininet> h_wan ip addr show tun0
Résultat attendu : Une interface tun0 apparaît avec l'IP 10.8.0.2.
Test B (Tunnel) : mininet> h_wan ping -c 2 10.8.0.1
Résultat attendu : 0% packet loss (Le tunnel est fonctionnel).
5. Administration SSH Sécurisée (h_lan)
code
Bash
# Générer la clé sur l'admin
mininet> h_adm ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
# Transférer la clé sur h_lan
mininet> h_adm cat /root/.ssh/id_rsa.pub | h_lan bash -c "mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys"
Test A (Sécurité) : mininet> h_dmz ssh 10.0.2.2 (Depuis une zone non autorisée)
Résultat attendu : Permission denied (publickey) ou timeout.
Test B (Connexion) : mininet> h_adm ssh 10.0.2.2
Résultat attendu : Accès direct au shell de h_lan sans demander de mot de passe.
6. Détection d'Intrusion (Snort)
code
Bash
mininet> fw1 snort -A console -q -c /etc/snort/snort.conf -i fw1-eth0
Test : Dans un autre terminal, faites mininet> h_wan curl -k https://10.0.1.2
Résultat attendu : Une alerte s'affiche sur la console de fw1 : [IDS] Flux HTTPS DMZ detecte.
📊 Résumé des Preuves pour le Rapport
Service	Commande de preuve	Validation
Zéro Trust	ping 10.0.2.2	Échec (Isolation confirmée)
HTTPS	curl -k https://10.0.1.2	Succès (Chiffrement validé)
VPN	ping 10.8.0.1	Succès (Tunnel opérationnel)
SSH	ssh 10.0.2.2	Succès (Clé publique validée)
IDS	Console fw1	Alertes visibles (Détection validée)
🧹 Nettoyage
code
Bash
mininet> exit
sudo mn -c