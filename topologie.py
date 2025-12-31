#!/usr/bin/python3

from mininet.net import Mininet
from mininet.node import Host, Node
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.topo import Topo

class LinuxRouter(Node):
    """Un nœud configuré comme un routeur IPv4"""
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        # Activer le transfert de paquets (Forwarding)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

def setup_network():
    net = Mininet(topo=None, build=False, waitConnected=True)

    info('*** Création des nœuds\n')
    
    # Ajout des routeurs (Futur cluster Haute Disponibilité)
    r1 = net.addHost('r1', cls=LinuxRouter, ip='10.0.1.1/24')
    r2 = net.addHost('r2', cls=LinuxRouter, ip='10.0.1.2/24')

    # Zone WAN (Internet)
    h_wan = net.addHost('h_wan', ip='10.0.1.10/24', defaultRoute='via 10.0.1.1')

    # Zone DMZ (Serveurs Web)
    h_web = net.addHost('h_web', ip='10.0.2.10/24', defaultRoute='via 10.0.2.1')

    # Zone LAN (Interne)
    h_lan = net.addHost('h_lan', ip='10.0.3.10/24', defaultRoute='via 10.0.3.1')
    
    # Zone Administration
    h_admin = net.addHost('h_admin', ip='10.0.4.10/24', defaultRoute='via 10.0.4.1')

    info('*** Création des commutateurs (switches)\n')
    s_wan = net.addSwitch('s1')
    s_dmz = net.addSwitch('s2')
    s_lan = net.addSwitch('s3')
    s_adm = net.addSwitch('s4')

    info('*** Création des liens\n')
    # Liens WAN
    net.addLink(h_wan, s_wan)
    net.addLink(r1, s_wan) # eth0 de r1
    net.addLink(r2, s_wan) # eth0 de r2

    # Liens DMZ
    net.addLink(s_dmz, r1) # eth1 de r1
    net.addLink(s_dmz, r2) # eth1 de r2
    net.addLink(h_web, s_dmz)

    # Liens LAN
    net.addLink(s_lan, r1) # eth2 de r1
    net.addLink(s_lan, r2) # eth2 de r2
    net.addLink(h_lan, s_lan)

    # Liens Admin
    net.addLink(s_adm, r1) # eth3 de r1
    net.addLink(s_adm, r2) # eth3 de r2
    net.addLink(h_admin, s_adm)

    info('*** Démarrage du réseau\n')
    net.build()
    
    # Configuration des interfaces IP sur les routeurs
    # r1
    r1.setIP('10.0.2.1/24', intf='r1-eth1')
    r1.setIP('10.0.3.1/24', intf='r1-eth2')
    r1.setIP('10.0.4.1/24', intf='r1-eth3')
    
    # r2
    r2.setIP('10.0.2.2/24', intf='r2-eth1')
    r2.setIP('10.0.3.2/24', intf='r2-eth2')
    r2.setIP('10.0.4.2/24', intf='r2-eth3')

    info('*** Réseau prêt. Test de connectivité de base...\n')
    # Note: h_wan ping r1 sur son interface WAN
    net.ping([h_wan, r1])

    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    setup_network()