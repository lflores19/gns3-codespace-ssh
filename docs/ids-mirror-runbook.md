# fw1 IDS software mirror runbook

This captures fw1 `eth0` ingress traffic in a second Suricata instance on `mirror0`. It is a same-guest software mirror—not a physical SPAN port—and cannot see same-VLAN traffic that does not traverse the router. The original Suricata capture on `eth0`, nftables rules, and guest routes are out of scope.

## Install on fw1

1. Copy `config/ids/mirror.yaml` to `/etc/suricata/mirror.yaml`.
2. Copy `scripts/fw1-ids-mirror.start` to `/etc/local.d/ids-mirror.start`.
3. Run `chmod +x /etc/local.d/ids-mirror.start`.
4. Start it with `/etc/local.d/ids-mirror.start` or reboot fw1. Alpine's `local` service is already enabled by default.

## Verify

Run these checks inside fw1:

```sh
sh -n /etc/local.d/ids-mirror.start
suricata -T -c /etc/suricata/mirror.yaml
/etc/local.d/ids-mirror.start
tc -s filter show dev eth0 ingress
```

Generate an authorized routed test flow, then correlate `/var/log/suricata/mirror/eve.json` with `/var/log/suricata/mirror/mirror.pcap*`: both should describe the same source, destination, port, and VLAN where present. `tc -s` should show packets sent to `mirror0` without drops.

## Rollback

Stop only the mirror Suricata process and remove `mirror0` if retiring this feature. Remove the `clsact` qdisc only when this installation added it and no unrelated ingress filters now use it. Do not blindly delete `clsact` or any existing filter.

Do not promote IDS01 until this configuration has passed a real fw1 reboot validation.
