# Network: ethernet vs Wi-Fi on `alien` — 2026-06-23

Investigation + benchmark of wired vs wireless on the `alien` node (Ubuntu
26.04, NetworkManager + netplan). Goal: make ethernet the primary link and
have a repeatable way to measure link speed / signal / latency across mediums.

The repeatable tool that came out of this is **`netbench`** (`.local/bin/netbench`,
installed to `~/.local/bin`). All numbers below are reproducible with it.

## TL;DR

- Ethernet is now the primary route (metric **100**), Wi-Fi the fallback (metric
  **600**); both persist across reboots via netplan.
- To the gateway, ethernet is **~4× lower latency and ~4.5× steadier** than Wi-Fi.
- `osx` (192.168.1.9) is a poor latency target — it's a power-saving Wi-Fi Mac
  and self-adds ~450 ms regardless of *our* medium. Use the gateway as the
  reference for medium comparisons.

## Hardware / link state

| Interface | Type  | Negotiated speed | Signal            |
|-----------|-------|------------------|-------------------|
| `enp70s0` | wired | 1000 Mb/s, full duplex | n/a          |
| `wlp71s0` | Wi-Fi | ~780–866 MBit/s (VHT, 80 MHz, NSS 2) | -34 dBm (~100%) |

## Latency (per-medium, probe bound to the NIC, gateway 192.168.1.1)

Measured with `sudo netbench` (binds each probe to its interface). Loss 0% both.

| Medium   | avg RTT | jitter (stddev) | vs ethernet |
|----------|---------|-----------------|-------------|
| ethernet | ~1.1 ms | ~0.4 ms         | —           |
| Wi-Fi    | ~4.5 ms | ~1.9 ms         | ~4× slower, ~4.5× more jitter |

Against `osx` (192.168.1.9), both mediums report avg ~450–465 ms / max ~900 ms —
identical within noise, because the bottleneck is osx's own Wi-Fi power-save,
not the local link. (Reference hosts `.1`/`.12` answer in 1–3 ms over ethernet.)

> Measurement caveat: with both NICs on the same `192.168.1.0/24` subnet,
> naive source-routed pings suffer ARP / reverse-path contention and produce
> garbage (100% loss on one NIC, wild RTTs on the other). For a *clean*
> per-medium read, either bind the probe (what `sudo netbench` does) or test one
> medium in isolation by downing the other connection.

## Root cause found along the way

Ethernet originally never got a DHCP lease — it sat on a link-local
`169.254.x.x` address despite a healthy gigabit carrier. Cause: the connection's
`ipv4.method` was **`link-local`**, not `auto`, so NetworkManager never sent a
DHCP request (no `dhcp4` transaction in the logs; it jumped to the IPv4LL
fallback in ~0.16 s). It was *not* a cable, port, or router problem. Fix:

```sh
sudo nmcli connection modify netplan-enp70s0 ipv4.method auto ipv6.method auto
```

This persisted into netplan as `dhcp4: true` / `dhcp6: true`.

## Priority configuration (persists across reboots)

Lower route metric wins. Set explicitly in the netplan source so it survives
`netplan generate`/regeneration (relying on NM's implicit wired default of 100
worked but was fragile):

```sh
sudo nmcli connection modify netplan-enp70s0 ipv4.route-metric 100 ipv6.route-metric 100
sudo nmcli connection modify IZZI-EE87-5G    ipv4.route-metric 600 ipv6.route-metric 600
```

Resulting netplan (`/etc/netplan/90-NM-*.yaml`):

| Interface | netplan file (`90-NM-…`) | `dhcp4-overrides.route-metric` |
|-----------|--------------------------|-------------------------------|
| `enp70s0` (ethernet) | `449b80c8-…` | 100 (primary) |
| `wlp71s0` (Wi-Fi)    | `04375a49-…` | 600 (fallback) |

Verify after a change without rebooting:

```sh
sudo netplan generate          # boot-equivalent regeneration of the NM backend
ip route show default          # ethernet (metric 100) should sit above Wi-Fi (600)
```

## Reproduce / re-measure

```sh
netbench                 # all interfaces, ping the gateway
sudo netbench -c 50      # clean per-NIC latency binding, 50 packets
netbench -i enp70s0      # single interface
netbench 1.1.1.1         # ping a specific target
```

See `.local/bin/netbench` for the full option list (`netbench -h`).
