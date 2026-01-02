#!/usr/bin/python3
from mininet.net import Mininet
from mininet.node import Node, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.link import Intf

class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

def setup_network():
    net = Mininet(topo=None, build=False, controller=None)

    info('*** Création des Pare-feux (Cluster HA)\n')
    fw1 = net.addHost('fw1', cls=LinuxRouter, ip='10.0.0.1/24')
    fw2 = net.addHost('fw2', cls=LinuxRouter, ip='10.0.0.2/24')
    
    info('*** Création des Hôtes par zone\n')
    h_wan = net.addHost('h_wan', ip='10.0.0.10/24', defaultRoute='via 10.0.0.1')
    h_dmz = net.addHost('h_dmz', ip='10.0.1.10/24', defaultRoute='via 10.0.1.1')
    h_lan = net.addHost('h_lan', ip='10.0.2.10/24', defaultRoute='via 10.0.2.254') # IP Virtuelle
    h_vpn = net.addHost('h_vpn', ip='10.0.3.10/24', defaultRoute='via 10.0.3.1')
    h_adm = net.addHost('h_admin', ip='10.0.4.10/24', defaultRoute='via 10.0.4.1')

    info('*** Création des switches (Segmentation)\n')
    s1, s2, s3, s4, s5 = [net.addSwitch(f's{i}', cls=OVSSwitch, failMode='standalone') for i in range(1, 6)]

    info('*** Liens Physiques\n')
    for fw in [fw1, fw2]:
        net.addLink(fw, s1, intfName1=f'{fw.name}-eth0') # WAN
        net.addLink(fw, s2, intfName1=f'{fw.name}-eth1') # DMZ
        net.addLink(fw, s3, intfName1=f'{fw.name}-eth2') # LAN
        net.addLink(fw, s4, intfName1=f'{fw.name}-eth3') # VPN
        net.addLink(fw, s5, intfName1=f'{fw.name}-eth4') # ADMIN

    net.addLink(h_wan, s1); net.addLink(h_dmz, s2); net.addLink(h_lan, s3)
    net.addLink(h_vpn, s4); net.addLink(h_adm, s5)

    info('*** Connexion Internet (Bridge)\n')
    Intf('enp0s3', node=s1)

    net.build()
    net.start()
    
    # Config IPs additionnelles sur les interfaces des FW
    for i, fw in enumerate([fw1, fw2]):
        suffix = i + 1
        fw.cmd(f'ip addr add 10.0.1.{suffix}/24 dev {fw.name}-eth1')
        fw.cmd(f'ip addr add 10.0.2.{suffix}/24 dev {fw.name}-eth2')
        fw.cmd(f'ip addr add 10.0.3.{suffix}/24 dev {fw.name}-eth3')
        fw.cmd(f'ip addr add 10.0.4.{suffix}/24 dev {fw.name}-eth4')

    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    setup_network()