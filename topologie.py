#!/usr/bin/python3

from mininet.net import Mininet
from mininet.node import Host, Node, OVSSwitch, Controller
from mininet.cli import CLI
from mininet.log import setLogLevel, info

class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

def setup_network():
    # Utilisation d'un contrôleur par défaut pour que les switches apprennent les adresses MAC
    net = Mininet(topo=None, build=False, controller=Controller)
    
    info('*** Ajout du contrôleur\n')
    net.addController('c0')

    info('*** Création des nœuds (Routeurs et Hôtes)\n')
    # Routeur R1 (Principal)
    r1 = net.addHost('r1', cls=LinuxRouter, ip='10.0.1.1/24')
    
    # Hôtes par zone
    h_wan = net.addHost('h_wan', ip='10.0.1.10/24', defaultRoute='via 10.0.1.1')
    h_web = net.addHost('h_web', ip='10.0.2.10/24', defaultRoute='via 10.0.2.1')
    h_lan = net.addHost('h_lan', ip='10.0.3.10/24', defaultRoute='via 10.0.3.1')
    h_admin = net.addHost('h_admin', ip='10.0.4.10/24', defaultRoute='via 10.0.4.1')

    info('*** Création des switches (OVS en mode standalone)\n')
    s1 = net.addSwitch('s1', cls=OVSSwitch, failMode='standalone') # WAN
    s2 = net.addSwitch('s2', cls=OVSSwitch, failMode='standalone') # DMZ
    s3 = net.addSwitch('s3', cls=OVSSwitch, failMode='standalone') # LAN
    s4 = net.addSwitch('s4', cls=OVSSwitch, failMode='standalone') # ADMIN

    info('*** Création des liens\n')
    # Connexions de R1 aux switches
    net.addLink(r1, s1, intfName1='r1-eth0') # Interface WAN
    net.addLink(r1, s2, intfName1='r1-eth1') # Interface DMZ
    net.addLink(r1, s3, intfName1='r1-eth2') # Interface LAN
    net.addLink(r1, s4, intfName1='r1-eth3') # Interface ADMIN

    # Connexions des hôtes aux switches
    net.addLink(h_wan, s1)
    net.addLink(h_web, s2)
    net.addLink(h_lan, s3)
    net.addLink(h_admin, s4)

    info('*** Démarrage du réseau\n')
    net.build()
    net.start()

    info('*** Configuration manuelle des IP sur le routeur R1\n')
    r1.cmd('ip addr add 10.0.2.1/24 dev r1-eth1')
    r1.cmd('ip addr add 10.0.3.1/24 dev r1-eth2')
    r1.cmd('ip addr add 10.0.4.1/24 dev r1-eth3')
    
    # On force l'activation de toutes les interfaces de r1
    for i in range(4):
        r1.cmd(f'ip link set r1-eth{i} up')

    info('*** Vérification de la connectivité LAN -> Routeur\n')
    # Test : h_lan (10.0.3.10) ping sa passerelle (10.0.3.1)
    print(net.get('h_lan').cmd('ping -c 3 10.0.3.1'))

    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    setup_network()