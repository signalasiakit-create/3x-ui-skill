# WARP Outbound Setup

Route Google/YouTube traffic through Cloudflare WARP to hide datacenter IP and fix geo-detection.

**When to use:** After basic VPN is working (Step 21 complete). Optional enhancement.

**What this gives:**
- Google/YouTube see Cloudflare IP instead of Hetzner/Vultr/etc.
- Eliminates Google CAPTCHAs and geo-blocks
- DNS queries for Google go through Cloudflare (1.1.1.1)

---

## Step 1: Install wgcf on Server

Download and install wgcf (Cloudflare WARP CLI tool):

```bash
ssh {nickname} "wget -q -O /usr/local/bin/wgcf https://github.com/ViRb3/wgcf/releases/latest/download/wgcf_linux_amd64 && chmod +x /usr/local/bin/wgcf && wgcf --version"
```

Expected: `wgcf version ...`

## Step 2: Register and Generate WARP Config

```bash
ssh {nickname} "cd /tmp && wgcf register --accept-tos && wgcf generate"
```

Extract credentials from generated config:

```bash
ssh {nickname} "python3 -c \"
import re
with open('/tmp/wgcf-profile.conf') as f:
    cfg = f.read()
priv = re.search(r'PrivateKey\s*=\s*(\S+)', cfg).group(1)
ipv4 = re.search(r'Address\s*=\s*([0-9./]+)', cfg).group(1)
pub  = re.search(r'PublicKey\s*=\s*(\S+)', cfg).group(1)
ep   = re.search(r'Endpoint\s*=\s*(\S+)', cfg).group(1)
print('PRIVATE_KEY:', priv)
print('IPV4_ADDR:  ', ipv4)
print('PUBLIC_KEY: ', pub)
print('ENDPOINT:   ', ep)
\""
```

**Save all 4 values** — needed for the next step.

## Step 3: Add WARP Outbound in 3x-ui Panel

Login to panel API:

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -c /tmp/3x-cookie -b /tmp/3x-cookie -X POST "https://127.0.0.1:${PANEL_PORT}/{web_base_path}/login" -H "Content-Type: application/x-www-form-urlencoded" -d "username={panel_username}&password={panel_password}"'
```

Add WireGuard (WARP) outbound. Replace `{PRIVATE_KEY}`, `{IPV4_ADDR}`, `{PUBLIC_KEY}`, `{ENDPOINT}` with values from Step 2:

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -c /tmp/3x-cookie -b /tmp/3x-cookie -X POST "https://127.0.0.1:${PANEL_PORT}/{web_base_path}/panel/api/outbounds/add" -H "Content-Type: application/json" -d '"'"'{
  "tag": "warp",
  "protocol": "wireguard",
  "settings": "{\"secretKey\":\"{PRIVATE_KEY}\",\"address\":[\"{IPV4_ADDR}\"],\"peers\":[{\"publicKey\":\"{PUBLIC_KEY}\",\"endpoint\":\"{ENDPOINT}\",\"allowedIPs\":[\"0.0.0.0/0\",\"::/0\"]}],\"domainStrategy\":\"ForceIPv4\"}"
}'"'"''
```

**Check response:** should return `{"success":true,...}`

**If API returns 404 (older 3x-ui)** — add via panel UI instead:
1. Open panel in browser
2. Go to **Settings → Xray Config** (or "Advanced Config")
3. Find the `"outbounds"` array in the JSON
4. Add this object to the array:
```json
{
  "tag": "warp",
  "protocol": "wireguard",
  "settings": {
    "secretKey": "{PRIVATE_KEY}",
    "address": ["{IPV4_ADDR}"],
    "peers": [
      {
        "publicKey": "{PUBLIC_KEY}",
        "endpoint": "{ENDPOINT}",
        "allowedIPs": ["0.0.0.0/0", "::/0"]
      }
    ],
    "domainStrategy": "ForceIPv4"
  }
}
```
5. Save and restart Xray

## Step 4: Add Routing Rules

Route Google and related domains through WARP outbound.

In panel → **Settings → Routing Rules** → Add rule:

| Field | Value |
|-------|-------|
| Domain | `geosite:google,domain:youtube.com,domain:googleapis.com,domain:gstatic.com,domain:googleusercontent.com,domain:gmail.com,domain:googlevideo.com,domain:gemini.google.com,domain:aistudio.google.com,domain:generativelanguage.googleapis.com` |
| Outbound | `warp` |

**If panel doesn't have a routing UI** — add via Xray Config JSON editor (same place as step above), find `"routing"` → `"rules"` array and add:

```json
{
  "type": "field",
  "domain": [
    "geosite:google",
    "domain:youtube.com",
    "domain:googleapis.com",
    "domain:gstatic.com",
    "domain:googleusercontent.com",
    "domain:gmail.com",
    "domain:googlevideo.com",
    "domain:gemini.google.com",
    "domain:aistudio.google.com",
    "domain:generativelanguage.googleapis.com"
  ],
  "outboundTag": "warp"
}
```

Place this rule **before** the default proxy rule.

After saving routing — restart Xray in panel (or via SSH):

```bash
ssh {nickname} "sudo x-ui restart"
```

## Step 5: Verify WARP Is Working

Check what IP Google sees:

```bash
ssh {nickname} "curl -sk --interface warp https://www.cloudflare.com/cdn-cgi/trace | grep ip"
```

Expected: IP in Cloudflare range (not your server's Hetzner/Vultr IP).

Alternatively check from a device connected to VPN:
- Open [https://1.1.1.1/cdn-cgi/trace](https://1.1.1.1/cdn-cgi/trace) in browser
- The `ip=` line should show a Cloudflare IP
- Open [https://myip.wtf/json](https://myip.wtf/json) — org field should say "Cloudflare"

## Cleanup

```bash
ssh {nickname} "rm -f /tmp/wgcf-profile.conf /tmp/wgcf-account.toml /tmp/3x-cookie"
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| wgcf download fails | Check GitHub releases URL: https://github.com/ViRb3/wgcf/releases — copy link for latest `wgcf_linux_amd64` |
| API 404 on outbounds/add | Use panel UI fallback (Step 3 alternate) |
| WARP outbound shows in panel but Google still sees datacenter IP | Check routing rules — domain rule must be above the default proxy rule |
| `curl --interface warp` fails | WARP outbound not started — restart Xray: `sudo x-ui restart` |
| Slow speeds through WARP | Expected — WARP adds one hop. Route only Google/YouTube, not all traffic |
| YouTube still slow | Add `domain:googlevideo.com` to the routing rule domains |

---

## Notes

- **Only Google/YouTube go through WARP** — other traffic goes directly through your server. This keeps speed for non-Google traffic.
- **WARP is free** — no Cloudflare account needed. wgcf registers anonymously.
- **WARP+** (faster, paid) — activate by adding a license key from the Cloudflare mobile app to `/tmp/wgcf-account.toml` before running `wgcf generate`.
- **Google account country** — if Google Gemini or other geo-restricted Google services still don't work after WARP, the Google account itself may have Russia set as country. Check and change at: https://policies.google.com/country-association-form — this is a one-time account setting, unrelated to VPN.
- **IPv6 leak** — even with WARP, if your device has an IPv6 address that routes outside the VPN, Google may still detect location. Disable IPv6 in Hiddify settings if in doubt.
