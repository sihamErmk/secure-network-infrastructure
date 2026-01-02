# 🛡️ Secure Network Infrastructure (Zero Trust Implementation)

Ce projet consiste à concevoir, simuler et analyser une infrastructure réseau critique sécurisée en suivant le modèle **Zero Trust**. L'architecture est émulée sous **Mininet** et intègre des mécanismes avancés de segmentation, chiffrement et détection d'intrusion.

---

## 📂 Structure du Projet

```text
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
Ouvrez votre terminal et récupérez le dépôt :
code
Bash
git clone https://github.com/sihamErmk/secure-network-infrastructure.git
cd secure-network-infrastructure
2. Permissions et Dépendances
Rendez les scripts exécutables et installez les outils nécessaires :
code
Bash
chmod +x *.sh topologie.py
sudo apt-get update && sudo apt-get install -y mininet openvswitch-switch openssl openvpn curl iptables snort
🚀 Guide d'Utilisation & Validation
Suivez les étapes dans l'ordre pour configurer l'infrastructure.
Étape 1 : Lancer la Topologie
Démarrez le réseau virtuel Mininet :
code
Bash
sudo python3 topologie.py
Résultat attendu : La console mininet> s'affiche. Tapez nodes pour voir : fw1, fw2, h_wan, h_dmz, h_lan, h_vpn, h_adm.
Étape 2 : Configurer le Pare-feu (Zero Trust)
Appliquez les politiques de filtrage sur le routeur central :
code
Bash
mininet> fw1 bash firewall.sh
Test : mininet> h_wan ping -c 2 10.0.2.2
Résultat attendu : 100% packet loss. L'isolation est active.
Étape 3 : Déployer la DMZ Sécurisée
Lancez le serveur Web HTTPS sur l'hôte DMZ :
code
Bash
mininet> h_dmz bash setup_dmz.sh
Test Redirection : mininet> h_wan curl -I http://10.0.1.2 ➡️ 301 Moved Permanently
Test HTTPS : mininet> h_wan curl -k https://10.0.1.2 ➡️ Affiche le contenu HTML
Étape 4 : Établir l'Accès distant (VPN)
Configurez le tunnel chiffré entre le WAN et le réseau interne :
code
Bash
mininet> h_vpn bash vpn_gencert.sh
mininet> h_vpn bash vpn_server.sh
mininet> h_wan bash vpn_client.sh
Test Tunnel : mininet> h_wan ping -c 2 10.8.0.1 ➡️ 0% packet loss.
Étape 5 : Administration SSH sécurisée
Configuration de l'accès SSH par clé publique sur l'hôte LAN :
code
Bash
# Générer la clé sur h_adm
mininet> h_adm ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
# Déployer la clé sur h_lan
mininet> h_adm cat /root/.ssh/id_rsa.pub | h_lan bash -c "mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys"
Test : mininet> h_adm ssh 10.0.2.2 ➡️ Accès autorisé sans mot de passe.
Étape 6 : Détection d'Intrusion (Snort)
Surveillez le trafic en temps réel sur l'interface WAN du pare-feu :
code
Bash
mininet> fw1 snort -A console -q -c /etc/snort/snort.conf -i fw1-eth0
Test : Faites un curl ou un ping depuis h_wan.
Résultat attendu : Des alertes s'affichent sur la console de fw1.
📊 Tableau Récapitulatif des Tests
Fonctionnalité	Commande de validation	État	Résultat Attendu
Segmentation	h_wan ping 10.0.2.2	🔒	Bloqué (Policy DROP)
Chiffrement	h_wan curl -k https://10.0.1.2	🔑	Succès (TLS 1.3)
Redirection	h_wan curl -I http://10.0.1.2	🔄	Redirect 301
Accès distant	h_wan ping 10.8.0.1	🛡️	Succès (Via tun0)
Auth. SSH	h_adm ssh 10.0.2.2	🎟️	Succès (Key only)
Détection	Console Snort	👁️	Alertes en temps réel
🧹 Nettoyage
Pour quitter Mininet et réinitialiser les réglages réseau :
code
Bash
mininet> exit
sudo mn -c
👨‍💻 Projet LSI3 - 2025/2026