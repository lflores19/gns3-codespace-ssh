# Política SDN02: bloqueo reversible de HTTPS desde VLAN 10 (Ventas)
# La regla se aplica con cookie 0x5151 para revertirla por cookie.
from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import MAIN_DISPATCHER, CONFIG_DISPATCHER, set_ev_cls

COOKIE_BLOCK = 0x5151
VLAN_VENTAS = 10

class VlanPolicy(app_manager.RyuApp):
    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        dp = ev.msg.datapath
        ofp = dp.ofproto
        parser = dp.ofproto_parser
        match = parser.OFPMatch(vlan_vid=VLAN_VENTAS, eth_type=0x0800, ip_proto=6, tcp_dst=443)
        actions = []  # drop
        inst = [parser.OFPInstructionActions(ofp.OFPIT_APPLY_ACTIONS, actions)]
        mod = parser.OFPFlowMod(datapath=dp, cookie=COOKIE_BLOCK, priority=200,
                                command=ofp.OFPFC_ADD, match=match, instructions=inst)
        dp.send_msg(mod)
