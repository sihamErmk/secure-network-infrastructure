#!/usr/bin/python3
from mininet.net import Mininet
from mininet.node import Node, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info

class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')
    def terminate(self):
        self.cmd('sysctl -w net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

def run_topo():
    net = Mininet(topo=None, build=False, controller=None)

    info('*** Création du Pare-feu (fw)\n')
    fw = net.addHost('fw', cls=LinuxRouter, ip='10.0.0.1/24')

    info('*** Création des hôtes et zones\n')
    h_wan = net.addHost('h_wan', ip='10.0.0.2/24', defaultRoute='via 10.0.0.1')
    h_dmz = net.addHost('h_dmz', ip='10.0.1.2/24', defaultRoute='via 10.0.1.1')
    h_lan = net.addHost('h_lan', ip='10.0.2.2/24', defaultRoute='via 10.0.2.1')
    h_vpn = net.addHost('h_vpn', ip='10.0.3.2/24', defaultRoute='via 10.0.3.1')
    h_adm = net.addHost('h_adm', ip='10.0.4.2/24', defaultRoute='via 10.0.4.1')

    # Switches
    s_wan, s_dmz, s_lan, s_vpn, s_adm = [net.addSwitch(s, cls=OVSSwitch, failMode='standalone') for s in ['s1','s2','s3','s4','s5']]

    # Liens
    net.addLink(fw, s_wan, intfName1='fw-eth0')
    net.addLink(fw, s_dmz, intfName1='fw-eth1')
    net.addLink(fw, s_lan, intfName1='fw-eth2')
    net.addLink(fw, s_vpn, intfName1='fw-eth3')
    net.addLink(fw, s_adm, intfName1='fw-eth4')
    
    net.addLink(h_wan, s_wan)
    net.addLink(h_dmz, s_dmz)
    net.addLink(h_lan, s_lan)
    net.addLink(h_vpn, s_vpn)
    net.addLink(h_adm, s_adm)

    net.build()
    net.start()

    # IPs supplémentaires sur le routeur
    fw.cmd('ip addr add 10.0.1.1/24 dev fw-eth1')
    fw.cmd('ip addr add 10.0.2.1/24 dev fw-eth2')
    fw.cmd('ip addr add 10.0.3.1/24 dev fw-eth3')
    fw.cmd('ip addr add 10.0.4.1/24 dev fw-eth4')

    info('*** Réseau prêt. Utilisez "fw bash firewall.sh" et "h_dmz bash setup_dmz.sh" ***\n')
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    run_topo()