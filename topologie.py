#!/usr/bin/python3

from mininet.net import Mininet
from mininet.node import Node, OVSSwitch, Controller
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.nodelib import NAT

class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

def setup_network():
    net = Mininet(topo=None, build=False, controller=None)

    info('*** Création des Pare-feux (fw1 et fw2 pour la HA)\n')
    fw1 = net.addHost('fw1', cls=LinuxRouter, ip='10.0.0.1/24')
    fw2 = net.addHost('fw2', cls=LinuxRouter, ip='10.0.0.3/24')
    
    info('*** Création des Hôtes par zone\n')
    h_wan = net.addHost('h_wan', ip='10.0.0.2/24', defaultRoute='via 10.0.0.1')
    h_dmz = net.addHost('h_dmz', ip='10.0.1.2/24', defaultRoute='via 10.0.1.1')
    h_lan = net.addHost('h_lan', ip='10.0.2.2/24', defaultRoute='via 10.0.2.1')
    h_vpn = net.addHost('h_vpn', ip='10.0.3.2/24', defaultRoute='via 10.0.3.1')
    h_adm = net.addHost('h_admin', ip='10.0.4.2/24', defaultRoute='via 10.0.4.1')

    info('*** Création des switches (Zones)\n')
    s_wan = net.addSwitch('s1', cls=OVSSwitch, failMode='standalone')
    s_dmz = net.addSwitch('s2', cls=OVSSwitch, failMode='standalone')
    s_lan = net.addSwitch('s3', cls=OVSSwitch, failMode='standalone')
    s_vpn = net.addSwitch('s4', cls=OVSSwitch, failMode='standalone')
    s_adm = net.addSwitch('s5', cls=OVSSwitch, failMode='standalone')

    info('*** Ajout du NAT pour l\'accès Internet\n')
    # On connecte le NAT au switch WAN pour que tout le monde puisse sortir
    nat0 = net.addNAT(name='nat0', connect=s_wan).configDefault()

    info('*** Création des liens physiques\n')
    # Liens FW1
    net.addLink(fw1, s_wan, intfName1='fw1-eth0')
    net.addLink(fw1, s_dmz, intfName1='fw1-eth1')
    net.addLink(fw1, s_lan, intfName1='fw1-eth2')
    net.addLink(fw1, s_vpn, intfName1='fw1-eth3')
    net.addLink(fw1, s_adm, intfName1='fw1-eth4')

    # Liens FW2 (Haute Disponibilité)
    net.addLink(fw2, s_wan, intfName1='fw2-eth0')
    net.addLink(fw2, s_dmz, intfName1='fw2-eth1')
    net.addLink(fw2, s_lan, intfName1='fw2-eth2')
    net.addLink(fw2, s_vpn, intfName1='fw2-eth3')
    net.addLink(fw2, s_adm, intfName1='fw2-eth4')

    # Liens Hôtes
    net.addLink(h_wan, s_wan)
    net.addLink(h_dmz, s_dmz)
    net.addLink(h_lan, s_lan)
    net.addLink(h_vpn, s_vpn)
    net.addLink(h_adm, s_adm)

    info('*** Démarrage du réseau\n')
    net.build()
    net.start()

    info('*** Configuration des IPs sur les Pare-feux\n')
    for f in [fw1, fw2]:
        name = f.name
        # On ne touche pas eth0 (déjà configuré par Mininet)
        f.cmd(f'ip addr add 10.0.1.{ "1" if name=="fw1" else "3" }/24 dev {name}-eth1')
        f.cmd(f'ip addr add 10.0.2.{ "1" if name=="fw1" else "3" }/24 dev {name}-eth2')
        f.cmd(f'ip addr add 10.0.3.{ "1" if name=="fw1" else "3" }/24 dev {name}-eth3')
        f.cmd(f'ip addr add 10.0.4.{ "1" if name=="fw1" else "3" }/24 dev {name}-eth4')
        for i in range(5):
            f.cmd(f'ip link set {name}-eth{i} up')

    # Désactivation IPv6
    for host in net.hosts:
        host.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")

    info('*** Configuration DNS sur les hôtes ***\n')
    for host in [h_dmz, h_lan, h_adm, h_wan, fw1, fw2]:
        host.cmd('echo "nameserver 8.8.8.8" > /etc/resolv.conf')

    info('*** Lancement de la console Mininet ***\n')
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    setup_network()