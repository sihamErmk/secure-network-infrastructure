from mininet.net import Mininet
from mininet.node import Node, OVSSwitch
from mininet.link import Intf
from mininet.cli import CLI
from mininet.log import setLogLevel, info

class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        self.cmd('sysctl -w net.ipv4.ip_forward=1')

def setup_network():
    net = Mininet(topo=None, build=False, controller=None)

    # Pare-feux (Cluster HA)
    fw1 = net.addHost('fw1', cls=LinuxRouter, ip='10.0.0.1/24')
    fw2 = net.addHost('fw2', cls=LinuxRouter, ip='10.0.0.3/24')

    # Hôtes par zone
    h_wan = net.addHost('h_wan', ip='10.0.0.2/24', defaultRoute='via 10.0.0.1')
    h_dmz = net.addHost('h_dmz', ip='10.0.1.2/24', defaultRoute='via 10.0.1.1')
    h_lan = net.addHost('h_lan', ip='10.0.2.2/24', defaultRoute='via 10.0.2.1')
    h_vpn = net.addHost('h_vpn', ip='10.0.3.2/24', defaultRoute='via 10.0.3.1')
    h_adm = net.addHost('h_admin', ip='10.0.4.2/24', defaultRoute='via 10.0.4.1')

    # Switches (Segmentation par zone)
    s1, s2, s3, s4, s5 = [net.addSwitch(s, cls=OVSSwitch, failMode='standalone') for s in ('s1', 's2', 's3', 's4', 's5')]

    # Internet Bridge (Optionnel pour mises à jour)
    Intf('enp0s3', node=s1)

    # Liens FW1 & FW2 vers tous les switches
    for fw in [fw1, fw2]:
        for i, s in enumerate([s1, s2, s3, s4, s5]):
            net.addLink(fw, s, intfName1=f'{fw.name}-eth{i}')

    # Liens Hôtes vers switches
    net.addLink(h_wan, s1); net.addLink(h_dmz, s2); net.addLink(h_lan, s3)
    net.addLink(h_vpn, s4); net.addLink(h_adm, s5)

    net.build()
    net.start()

    # Config IPs additionnelles sur les interfaces FW
    for f in [fw1, fw2]:
        suffix = "1" if f.name == "fw1" else "3"
        for i in range(1, 5):
            f.cmd(f'ip addr add 10.0.{i}.{suffix}/24 dev {f.name}-eth{i}')
            f.cmd(f'ip link set {f.name}-eth{i} up')

    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    setup_network()