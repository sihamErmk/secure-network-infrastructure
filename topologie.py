# topo.py
from mininet.net import Mininet
from mininet.node import Node, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info

class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

def run_topo():
    net = Mininet(topo=None, build=False, controller=None)

    info('*** Création des Routeurs (Cluster HA)\n')
    fw1 = net.addHost('fw1', cls=LinuxRouter, ip='10.0.0.1/24')
    fw2 = net.addHost('fw2', cls=LinuxRouter, ip='10.0.0.254/24') # Backup

    info('*** Création des Hôtes par zone\n')
    h_wan = net.addHost('h_wan', ip='10.0.0.2/24', defaultRoute='via 10.0.0.1')
    h_dmz = net.addHost('h_dmz', ip='10.0.1.2/24', defaultRoute='via 10.0.1.1')
    h_lan = net.addHost('h_lan', ip='10.0.2.2/24', defaultRoute='via 10.0.2.1')
    h_vpn = net.addHost('h_vpn', ip='10.0.3.2/24', defaultRoute='via 10.0.3.1')
    h_adm = net.addHost('h_adm', ip='10.0.4.2/24', defaultRoute='via 10.0.4.1')

    # Switches pour chaque zone
    switches = [net.addSwitch(f's{i}', cls=OVSSwitch, failMode='standalone') for i in range(1, 6)]

    # Connexions FW1 aux 5 switches
    for i, s in enumerate(switches):
        net.addLink(fw1, s, intfName1=f'fw1-eth{i}')
        net.addLink(fw2, s, intfName1=f'fw2-eth{i}')

    # Connexions Hôtes
    net.addLink(h_wan, switches[0])
    net.addLink(h_dmz, switches[1])
    net.addLink(h_lan, switches[2])
    net.addLink(h_vpn, switches[3])
    net.addLink(h_adm, switches[4])

    net.build()
    net.start()
    
    # Adresses IP des passerelles sur FW1
    for i in range(1, 5):
        fw1.cmd(f'ip addr add 10.0.{i}.1/24 dev fw1-eth{i}')
    
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    run_topo()