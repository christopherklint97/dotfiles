#!/usr/bin/env bash
# Pin Tailscale control-plane + DERP traffic to en0, bypassing OpenVPN full-tunnel.
# Run AFTER OpenVPN connects (or before — routes survive).
# Undo: tailscale-pin-en0.sh down
#
# DERP list embedded — no DNS lookup needed at runtime (OpenVPN may hijack DNS).
# Refresh embedded list with: tailscale-pin-en0.sh refresh

set -euo pipefail

CONTROL_CIDR="192.200.0.0/24"

# DERP IPv4 list (regenerate with `tailscale-pin-en0.sh refresh` when OpenVPN OFF)
DERP_IPS=(
    199.38.181.104 209.177.145.120 199.38.181.93 199.38.181.103
    192.73.240.161 192.73.240.121 192.73.240.132
    172.237.61.194 172.237.61.197 172.237.61.190
    209.177.158.246 209.177.158.15 199.38.182.118
    192.73.242.187 192.73.242.28 192.73.242.204
    176.58.93.248 176.58.93.147 176.58.93.154
    102.67.165.90 102.67.165.185 102.67.165.36
    192.73.243.135 192.73.243.229 192.73.243.141
    192.73.244.245 208.111.40.12 208.111.40.216
    176.58.90.147 176.58.90.207 176.58.90.104
    45.159.97.144 45.159.97.61 45.159.97.233
    192.73.252.65 192.73.252.134 208.111.34.178
    103.6.84.152 205.147.105.30 205.147.105.78
    162.248.221.199 162.248.221.215 162.248.221.248
    45.159.98.196 45.159.98.253 45.159.98.145
    185.34.3.232 185.34.3.207 185.34.3.75
    208.83.234.151
    65.109.143.62 95.217.2.165 157.180.28.32
    178.156.152.91 167.235.72.200
    68.183.90.120
    172.105.179.230
    172.238.6.34
    102.67.167.245 102.67.167.37
    208.83.233.233
    172.237.72.8 172.237.72.43
    176.58.92.144 176.58.90.147
    172.237.28.183
    5.161.218.233
    208.111.40.12
    172.105.166.103
    192.73.248.83
    192.73.243.229
)

get_gw() {
    netstat -rn -f inet | awk '$1=="default" && $NF=="en0" {print $2; exit}'
}

case "${1:-up}" in
    up)
        GW="$(get_gw)"
        [[ -z "${GW:-}" ]] && { echo "No en0 default route. Connect Wi-Fi first." >&2; exit 1; }
        echo "en0 gateway: $GW"

        echo "Pinning $CONTROL_CIDR"
        sudo route -n add -net "$CONTROL_CIDR" "$GW" 2>/dev/null \
            || sudo route -n change -net "$CONTROL_CIDR" "$GW"

        echo "Pinning ${#DERP_IPS[@]} DERP IPs"
        for ip in "${DERP_IPS[@]}"; do
            sudo route -n add -host "$ip" "$GW" 2>/dev/null \
                || sudo route -n change -host "$ip" "$GW" >/dev/null
        done

        echo "Done. Verify:"
        sleep 2
        tailscale netcheck 2>&1 | grep -E 'DERP|IPv4'
        ;;
    down)
        echo "Removing pins."
        sudo route -n delete -net "$CONTROL_CIDR" 2>/dev/null || true
        for ip in "${DERP_IPS[@]}"; do
            sudo route -n delete -host "$ip" 2>/dev/null || true
        done
        ;;
    refresh)
        echo "Refreshing embedded DERP list (needs working DNS — OpenVPN should be OFF)."
        curl -fsS https://login.tailscale.com/derpmap/default \
            | python3 -c '
import json,sys
d=json.load(sys.stdin)
ips=[]
for r in d["Regions"].values():
    for n in r["Nodes"]:
        ip=n.get("IPv4","")
        if ip and "." in ip and not ip.startswith("("):
            ips.append(ip)
print("DERP_IPS=(")
for ip in ips:
    print(f"    {ip}")
print(")")
'
        echo "Paste into script."
        ;;
    *)
        echo "Usage: $0 [up|down|refresh]" >&2
        exit 1
        ;;
esac
