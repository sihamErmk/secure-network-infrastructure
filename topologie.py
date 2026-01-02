#!/usr/bin/python3
"""
Topologie Mininet - Infrastructure reseau securisee
Projet LSI3 2025/2026
"""

from mininet.net import Mininet
from mininet.node import Node, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info

class LinuxRouter(Node):
    """Routeur Linux avec capacites de pare-feu"""
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')
        self.cmd('sysctl -w net.ipv6.conf.all.disable_ipv6=1')
        self.cmd('sysctl -w net.ipv6.conf.default.disable_ipv6=1')

    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

def create_topology():
    """Creation de la topologie reseau"""
    net = Mininet(topo=None, build=False, controller=None)

    info('*** Creation du Pare-feu central\n')
    fw = net.addHost('fw', cls=LinuxRouter, ip='10.0.0.1/24')
    
    info('*** Creation des hotes par zone\n')
    h_wan = net.addHost('h_wan', ip='10.0.0.2/24', defaultRoute='via 10.0.0.1')
    h_dmz = net.addHost('h_dmz', ip='10.0.1.2/24', defaultRoute='via 10.0.1.1')
    h_lan = net.addHost('h_lan', ip='10.0.2.2/24', defaultRoute='via 10.0.2.1')
    h_vpn = net.addHost('h_vpn', ip='10.0.3.2/24', defaultRoute='via 10.0.3.1')
    h_admin = net.addHost('h_admin', ip='10.0.4.2/24', defaultRoute='via 10.0.4.1')

    info('*** Creation des switches\n')
    s_wan = net.addSwitch('s1', cls=OVSSwitch, failMode='standalone')
    s_dmz = net.addSwitch('s2', cls=OVSSwitch, failMode='standalone')
    s_lan = net.addSwitch('s3', cls=OVSSwitch, failMode='standalone')
    s_vpn = net.addSwitch('s4', cls=OVSSwitch, failMode='standalone')
    s_admin = net.addSwitch('s5', cls=OVSSwitch, failMode='standalone')

    info('*** Creation des liens\n')
    net.addLink(fw, s_wan, intfName1='fw-eth0')
    net.addLink(fw, s_dmz, intfName1='fw-eth1')
    net.addLink(fw, s_lan, intfName1='fw-eth2')
    net.addLink(fw, s_vpn, intfName1='fw-eth3')
    net.addLink(fw, s_admin, intfName1='fw-eth4')

    net.addLink(h_wan, s_wan)
    net.addLink(h_dmz, s_dmz)
    net.addLink(h_lan, s_lan)
    net.addLink(h_vpn, s_vpn)
    net.addLink(h_admin, s_admin)

    info('*** Demarrage du reseau\n')
    net.build()
    net.start()

    info('*** Configuration des IPs sur le Pare-feu\n')
    fw.cmd('ip addr add 10.0.1.1/24 dev fw-eth1')
    fw.cmd('ip addr add 10.0.2.1/24 dev fw-eth2')
    fw.cmd('ip addr add 10.0.3.1/24 dev fw-eth3')
    fw.cmd('ip addr add 10.0.4.1/24 dev fw-eth4')
    
    for i in range(5):
        fw.cmd(f'ip link set fw-eth{i} up')

    for host in net.hosts:
        host.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1 2>/dev/null")

    info('*** Topologie creee avec succes\n')
    return net

if __name__ == '__main__':
    setLogLevel('info')
    net = create_topology()
    CLI(net)
    net.stop()