# VLESS XHTTP + Reality Setup

Use this when user wants XHTTP transport with Reality security instead of TCP+Reality.

**Why XHTTP+Reality:** XHTTP (SplitHTTP) splits traffic into many small HTTP requests, making it look like regular browser activity. Combined with Reality (which mimics a real TLS handshake), this is one of the hardest configurations to detect and block.

**Panel access:** If the user has a domain and SKILL.md Step 14c was completed, the panel is already accessible at `https://{domain}:{panel_port}/{web_base_path}` — no SSH tunnel needed for panel management. This is independent of the XHTTP+Reality VPN protocol.

**Key differences from TCP+Reality:**
- Transport is `xhttp` instead of `tcp`
- Requires a custom path (e.g. `/updates`)
- **No flow** — `xtls-rprx-vision` is TCP-only; XHTTP does not use flow
- **No fallback to Nginx** — XHTTP does not support Xray fallback (TCP only does)
- Sniffing with `routeOnly: true` recommended (see Step 4)
- Requires Xray core v1.8.16+ (auto-updated by 3x-ui)

## Prerequisites

- Server hardened (Part 1 complete)
- 3x-ui installed and running (Step 14)
- BBR enabled (Step 14b)
- ICMP disabled (Step 15)
- Reality scanner results available — SNI selected (same scanner as TCP+Reality, Step 17A)

If scanner hasn't been run yet, run it first:

```bash
ssh {nickname} 'ARCH=$(dpkg --print-architecture); case "$ARCH" in amd64) SA="64";; arm64|aarch64) SA="arm64-v8a";; *) SA="$ARCH";; esac && curl -sL "https://github.com/XTLS/RealiTLScanner/releases/latest/download/RealiTLScanner-linux-${SA}" -o /tmp/scanner && chmod +x /tmp/scanner; MY_IP=$(curl -4 -s ifconfig.me); SUBNET=$(echo $MY_IP | sed "s/\.[0-9]*$/.0\/24/"); echo "Scanning: $SUBNET"; timeout 120 /tmp/scanner --addr "$SUBNET" 2>&1 | head -80'
```

## Step 0: Choose XHTTP Path

**XHTTP path** is a URL segment that clients use when connecting. Examples: `/updates`, `/api/v1`, `/cdn`, or a random string like `/a3f7b1`.

**Decision:** Ask the user:

> Do you want a **random XHTTP path** (harder to guess, recommended) or a **custom path**?
>
> - **Random (recommended):** I'll generate a random path like `/a3f7b1`
> - **Custom:** You specify what the path should be (e.g., `/cdn`, `/updates`)

**If random → proceed to Step 1** (path will be generated in Step 2)

**If custom → ask for the path:**
> What should the custom path be? Examples: `/updates`, `/cdn`, `/api/v1`
>
> (Don't include the leading slash — I'll add it automatically)

**Save the chosen path as `{xhttp_path}`** — this will go into the final guide.

---

## Step 1: Verify Port 443 Is Free

```bash
ssh {nickname} "ss -tlnp | grep ':443 '"
```

If something is listening (apache2, nginx), stop and disable it:

```bash
ssh {nickname} "sudo systemctl stop apache2 && sudo systemctl disable apache2"
```

## Step 2: Generate Keys and IDs

Get session cookie:

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -c /tmp/3x-cookie -b /tmp/3x-cookie -X POST "https://127.0.0.1:${PANEL_PORT}/{web_base_path}/login" -H "Content-Type: application/x-www-form-urlencoded" -d "username={panel_username}&password={panel_password}"'
```

Generate Reality keys (private + public):

```bash
ssh {nickname} "sudo /usr/local/x-ui/bin/xray-linux-* x25519"
```

Output example:
```
PrivateKey: ABC123...   ← save as {PRIVATE_KEY}
PublicKey:  XYZ789...   ← save as {PUBLIC_KEY}
```

Generate UUID for the client:

```bash
ssh {nickname} "sudo /usr/local/x-ui/bin/xray-linux-* uuid"
```

Generate Short ID:

```bash
ssh {nickname} "openssl rand -hex 8"
```

Generate a random XHTTP path (short, URL-safe):

```bash
ssh {nickname} "openssl rand -hex 6"
```

Use this as `{XHTTP_PATH}`, e.g. `a3f7b1` → path will be `/a3f7b1`.

## Step 3: Create VLESS XHTTP+Reality Inbound

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -c /tmp/3x-cookie -b /tmp/3x-cookie -X POST "https://127.0.0.1:${PANEL_PORT}/{web_base_path}/panel/api/inbounds/add" -H "Content-Type: application/json" -d '"'"'{
  "up": 0,
  "down": 0,
  "total": 0,
  "remark": "vless-xhttp-reality",
  "enable": true,
  "expiryTime": 0,
  "listen": "",
  "port": 443,
  "protocol": "vless",
  "settings": "{\"clients\":[{\"id\":\"{CLIENT_UUID}\",\"flow\":\"\",\"email\":\"user1\",\"limitIp\":0,\"totalGB\":0,\"expiryTime\":0,\"enable\":true}],\"decryption\":\"none\",\"fallbacks\":[]}",
  "streamSettings": "{\"network\":\"xhttp\",\"security\":\"reality\",\"externalProxy\":[],\"realitySettings\":{\"show\":false,\"xver\":0,\"dest\":\"{BEST_SNI}:443\",\"serverNames\":[\"{BEST_SNI}\"],\"privateKey\":\"{PRIVATE_KEY}\",\"minClient\":\"\",\"maxClient\":\"\",\"maxTimediff\":0,\"shortIds\":[\"{SHORT_ID}\"],\"settings\":{\"publicKey\":\"{PUBLIC_KEY}\",\"fingerprint\":\"chrome\",\"serverName\":\"\",\"spiderX\":\"/\"}},\"xhttpSettings\":{\"path\":\"/{XHTTP_PATH}\",\"host\":\"\",\"headers\":{}}}",
  "sniffing": "{\"enabled\":true,\"destOverride\":[\"http\",\"tls\",\"quic\",\"fakedns\"],\"metadataOnly\":false,\"routeOnly\":true}",
  "allocate": "{\"strategy\":\"always\",\"refresh\":5,\"concurrency\":3}"
}'"'"''
```

**Key points in this JSON:**
- `"flow": ""` — empty, XHTTP does not use xtls-rprx-vision
- `"network": "xhttp"` — SplitHTTP transport
- `"xhttpSettings": {"path": "/{XHTTP_PATH}"}` — unique path, not `/`
- `"routeOnly": true` in sniffing — Xray reads domain names for routing decisions only, does not interfere with traffic (prevents broken sites)
- `"fallbacks": []` — XHTTP does not support fallback

**If API fails** — access panel via SSH tunnel and create inbound manually:

```bash
ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}
```

Open: `https://127.0.0.1:{panel_port}/{web_base_path}`

Manual settings:
- Protocol: VLESS
- Port: 443
- Network: xhttp
- Path: `/{XHTTP_PATH}`
- Security: Reality
- Dest: `{BEST_SNI}:443`
- Server Names: `{BEST_SNI}`
- Click "Get New Keys"
- Sniffing: ON → http, tls, quic → Route Only: ON

## Step 4: Why routeOnly Matters

Without `routeOnly`, Xray rewrites destination addresses from IP to domain names inside the tunnel. This breaks some sites (HSTS, certificate pinning, CDN backends).

With `routeOnly: true`: Xray only "reads" the domain for routing rules (e.g. block torrents, route Russian sites directly) — it never touches the traffic itself.

**Always use routeOnly: true** with XHTTP.

## Step 5: Get Connection Link

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -b /tmp/3x-cookie "https://127.0.0.1:${PANEL_PORT}/{web_base_path}/panel/api/inbounds/list" | python3 -c "
import json,sys
data = json.load(sys.stdin)
for inb in data.get(\"obj\", []):
    if inb.get(\"protocol\") == \"vless\" and \"xhttp\" in inb.get(\"streamSettings\", \"\"):
        settings = json.loads(inb[\"settings\"])
        stream = json.loads(inb[\"streamSettings\"])
        client = settings[\"clients\"][0]
        uuid = client[\"id\"]
        port = inb[\"port\"]
        rs = stream[\"realitySettings\"]
        sni = rs[\"serverNames\"][0]
        pbk = rs[\"settings\"][\"publicKey\"]
        sid = rs[\"shortIds\"][0]
        fp = rs[\"settings\"].get(\"fingerprint\", \"chrome\")
        path = stream[\"xhttpSettings\"][\"path\"]
        import urllib.parse
        encoded_path = urllib.parse.quote(path, safe=\"\")
        link = f\"vless://{uuid}@\$(curl -4 -s ifconfig.me):{port}?type=xhttp&security=reality&pbk={pbk}&fp={fp}&sni={sni}&sid={sid}&path={encoded_path}#vless-xhttp-reality\"
        print(link)
        break
"'
```

**Show link to user in two formats** (same as TCP+Reality — terminal line-wrap fix):

~~~
Скопируй и вставь в любой LLM чтобы получить чистую ссылку:

Убери все переносы строк и лишние пробелы из этой ссылки, выдай одной строкой:

{VLESS_LINK}
~~~

Save link to file:

```bash
ssh {nickname} "echo '{VLESS_LINK}' > ~/vpn-link.txt"
```

Cleanup:

```bash
ssh {nickname} "rm -f /tmp/3x-cookie"
```

## Step 6: Verify Xray Core Version

XHTTP requires Xray core v1.8.16+. Check:

```bash
ssh {nickname} "sudo /usr/local/x-ui/bin/xray-linux-* version | head -1"
```

If version is below v1.8.16, update via panel: Panel Settings → Xray Settings → Update Xray Core.

Or from CLI:

```bash
ssh {nickname} "sudo x-ui update && sudo x-ui restart"
```

## Completion

After getting the link, return to main SKILL.md Step 20 (Install Hiddify).

**Note on client compatibility:** Hiddify supports XHTTP. Make sure Hiddify is updated to the latest version — older versions (pre-2024) may not recognize `type=xhttp` in the link.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Client shows "unknown network type xhttp" | Update Hiddify/client to latest version |
| Connection refused on port 443 | Check `ss -tlnp \| grep 443` — another service may be using 443 |
| Reality handshake fails | Wrong SNI — re-run scanner, pick different domain |
| Some sites broken via VPN | Check `routeOnly: true` is set in sniffing settings |
| Inbound not created (API error) | Check API response for JSON parse errors, use panel UI as fallback |
