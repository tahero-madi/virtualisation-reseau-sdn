"""Topologie en anneau pour le TP3 : 4 switches, 1 hote par switch."""
from mininet.topo import Topo


class RingTopo(Topo):
    def build(self, n=4):
        switches = [self.addSwitch(f"s{i}") for i in range(1, n + 1)]
        for i, sw in enumerate(switches, start=1):
            self.addLink(self.addHost(f"h{i}"), sw)
        for i in range(n):
            self.addLink(switches[i], switches[(i + 1) % n])


topos = {"ring": RingTopo}
