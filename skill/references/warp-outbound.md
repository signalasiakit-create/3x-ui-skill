# WARP Outbound Setup (via warp-cli proxy)

Route Google/YouTube traffic through Cloudflare WARP to hide datacenter IP and fix geo-detection.

**When to use:** After basic VPN is working (Step 21 complete). Optional enhancement.

**What this gives:**
- Google/YouTube see Cloudflare IP instead of Hetzner/Vultr/etc.
- Eliminates Google CAPTCHAs and geo-blocks
- Works via local SOCKS5 proxy — no changes to xray WireGuard config

> **Note:** The old wgcf + WireGuard outbound approach is no longer used.
> The `/panel/xray/update` API in current 3x-ui versions does not reliably accept config changes.
> All outbound and routing changes must be done through the panel UI.

---

## Step 1: Add Cloudflare WARP Repository and Install

```bash
ssh {nickname} "curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg"
```

```bash
ssh {nickname} 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list'
```

```bash
ssh {nickname} "sudo apt update && sudo apt install -y cloudflare-warp"
```

Verify installed:

```bash
ssh {nickname} "warp-cli --version"
```

Expected: `warp-cli 2024.x.x` or similar.

## Step 2: Register and Configure WARP

Register a new WARP account:

```bash
ssh {nickname} "warp-cli --accept-tos registration new"
```

Set mode to proxy (SOCKS5 on localhost:40000):

```bash
ssh {nickname} "warp-cli --accept-tos mode proxy"
```

Connect:

```bash
ssh {nickname} "warp-cli --accept-tos connect"
```

## Step 3: Verify WARP Is Running

Check connection status:

```bash
ssh {nickname} "warp-cli --accept-tos status"
```

Expected: `Status update: Connected`

Check SOCKS5 port is listening:

```bash
ssh {nickname} "ss -tlnp | grep 40000"
```

Expected output: something like `LISTEN 0 ... 127.0.0.1:40000`

Test WARP IP directly:

```bash
ssh {nickname} "curl -sx socks5://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace | grep -E 'ip=|warp='"
```

Expected:
```
ip=104.x.x.x       ← Cloudflare IP (not your server IP)
warp=on             ← WARP is active
```

If `warp=off` — WARP connected but not routing. Check mode: `warp-cli mode` should show `Proxy`.

## Step 4: Add WARP Outbound in Panel UI

Open the panel in browser (via SSH tunnel or domain if configured):

```bash
ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}
# Then open: https://127.0.0.1:{panel_port}/{web_base_path}
```

In the panel:

1. Go to **Xray Configs → Outbounds**
2. Click **Add Outbound**
3. Fill in:

| Field | Value |
|-------|-------|
| Protocol | `socks` |
| Tag | `warp-cli` |
| Address | `127.0.0.1` |
| Port | `40000` |

4. Save

## Step 5: Add Routing Rule in Panel UI

In the panel:

1. Go to **Xray Configs → Routing**
2. Click **Add Rule**
3. Fill in:

| Field | Value |
|-------|-------|
| Inbound Tag | `inbound-443` |
| Outbound Tag | `warp-cli` |
| Domains | `geosite:google-gemini,geosite:youtube,geosite:google,domain:notebooklm.google.com,domain:notebooklm.google` |

4. Place this rule **above** any default proxy rules
5. Save

## Step 6: Restart Xray and Verify

In the panel — click **Restart Xray** (or via SSH):

```bash
ssh {nickname} "sudo x-ui restart"
```

Verify from a device connected to VPN:
- Open [https://www.cloudflare.com/cdn-cgi/trace](https://www.cloudflare.com/cdn-cgi/trace) — `warp=on`, IP is Cloudflare
- Open [https://myip.wtf/json](https://myip.wtf/json) — `org` field should say "Cloudflare"
- Try opening [https://gemini.google.com](https://gemini.google.com) — should load without geo-block

---

## Enable WARP on Server Restart (autostart)

WARP does not autostart by default. Enable systemd service:

```bash
ssh {nickname} "sudo systemctl enable --now warp-taskd"
```

Verify it will start on boot:

```bash
ssh {nickname} "sudo systemctl status warp-taskd"
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `warp-cli` not found after install | `sudo apt update && sudo apt install -y cloudflare-warp` — check repo was added correctly |
| `status` shows `Disconnected` | Run `warp-cli --accept-tos connect` again |
| Port 40000 not listening | WARP not in proxy mode — run `warp-cli --accept-tos mode proxy && warp-cli --accept-tos connect` |
| `warp=off` in trace | Mode is not `proxy` — check: `warp-cli mode`; switch with `warp-cli --accept-tos mode proxy` |
| Google still shows datacenter IP | Routing rule not saved or Xray not restarted — check panel Routing, restart x-ui |
| `inbound-443` tag not found | Check panel → Inbounds — the inbound tag might differ (e.g., `inbound-443-0`). Use the actual tag shown |
| Slow speeds | Expected — WARP adds one hop. Only Google/YouTube routed, not all traffic |
| WARP disconnects after reboot | Enable autostart: `sudo systemctl enable --now warp-taskd` |

---

## Notes

- **Only Google/YouTube go through WARP** — other traffic goes directly through your server. This keeps speed for non-Google traffic.
- **WARP is free** — no Cloudflare account needed. wgcf registers anonymously.
- **WARP+ (paid)** — faster speeds, better IPs. Activate via Cloudflare mobile app license key: `warp-cli registration license <key>`
- **Google account country** — if Google Gemini or other geo-restricted Google services still don't work after WARP, the Google account itself may have Russia set as country. Check and change at: https://policies.google.com/country-association-form — one-time account setting, unrelated to VPN.
- **IPv6 leak** — even with WARP, if your device has an IPv6 address that routes outside the VPN, Google may still detect location. Disable IPv6 in Hiddify settings if in doubt.
- **Panel API limitation** — the `/panel/xray/update` API in current 3x-ui versions does not reliably accept outbound/routing changes. Always configure outbounds and routing through the panel UI.
