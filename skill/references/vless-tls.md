# VLESS TLS Setup (with Domain)

Use this when user has a domain and wants VLESS TLS instead of Reality.

**Prerequisites:** SSL certificate, panel SSL config, panel port UFW access, cert renewal cron, and SSH custom port are all configured in **SKILL.md Step 14c** before reaching this file. Steps here cover only the VLESS TLS inbound creation and Nginx stub site.

## Prerequisites

- Domain registered and A-record pointing to server IP
- DNS propagated (verify: `nslookup {domain}` returns server IP)
- **Step 14c completed** — SSL cert at `/root/cert/{domain}/`, panel accessible via `https://{domain}:{panel_port}/{web_base_path}`, cert renewal cron active
- Port 443 open in UFW (already done in Step 8)

## Step 1: Verify DNS

```bash
nslookup {domain}
```

Must return the server IP. If not — wait 5-10 minutes for DNS propagation.

Can also check from server:
```bash
ssh {nickname} "sudo apt install -y dnsutils > /dev/null 2>&1; nslookup {domain}"
```

## Step 2: Verify Certificate Files

Certificate was issued in Step 14c. Confirm files exist:

```bash
ssh {nickname} "sudo ls -la /root/cert/{domain}/"
```

Expected output:
```
/root/cert/{domain}/fullchain.pem   # certificate
/root/cert/{domain}/privkey.pem     # private key
```

If files are missing — return to SKILL.md Step 14c and issue the certificate first.

## Step 3: Change Panel Credentials

Since panel is now publicly accessible via domain, update the auto-generated credentials:

```bash
ssh {nickname} "sudo x-ui setting -username {new_username} -password {new_password}"
ssh {nickname} "sudo x-ui restart"
```

Verify panel access: `https://{domain}:{panel_port}/{web_base_path}`

## Step 4: Enable 2FA in Panel (Strongly Recommended)

Panel is accessible from the internet — 2FA is strongly recommended:

1. Open panel: `https://{domain}:{panel_port}/{web_base_path}`
2. Go to Settings → Account
3. Enable "Two-Factor Authentication"
4. Scan QR with authenticator app (Google Authenticator, Microsoft Authenticator)
5. Enter 6-digit code to confirm

## Step 5: Create VLESS TLS Inbound

Login to API via domain:

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -c /tmp/3x-cookie -b /tmp/3x-cookie -X POST "https://{domain}:${PANEL_PORT}/{web_base_path}/login" -H "Content-Type: application/x-www-form-urlencoded" -d "username={panel_username}&password={panel_password}"'
```

Generate UUID:

```bash
ssh {nickname} "sudo /usr/local/x-ui/bin/xray-linux-* uuid"
```

Create VLESS TLS inbound on port 443:

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -c /tmp/3x-cookie -b /tmp/3x-cookie -X POST "https://{domain}:${PANEL_PORT}/{web_base_path}/panel/api/inbounds/add" -H "Content-Type: application/json" -d '"'"'{
  "up": 0,
  "down": 0,
  "total": 0,
  "remark": "vless-tls",
  "enable": true,
  "expiryTime": 0,
  "listen": "",
  "port": 443,
  "protocol": "vless",
  "settings": "{\"clients\":[{\"id\":\"{CLIENT_UUID}\",\"flow\":\"xtls-rprx-vision\",\"email\":\"user1\",\"limitIp\":0,\"totalGB\":0,\"expiryTime\":0,\"enable\":true}],\"decryption\":\"none\",\"fallbacks\":[{\"dest\":\"127.0.0.1:8081\"}]}",
  "streamSettings": "{\"network\":\"tcp\",\"security\":\"tls\",\"externalProxy\":[],\"tlsSettings\":{\"serverName\":\"{domain}\",\"minVersion\":\"1.2\",\"maxVersion\":\"1.3\",\"cipherSuites\":\"\",\"rejectUnknownSni\":false,\"disableSystemRoot\":false,\"enableSessionResumption\":false,\"certificates\":[{\"certificateFile\":\"/root/cert/{domain}/fullchain.pem\",\"keyFile\":\"/root/cert/{domain}/privkey.pem\",\"ocspStapling\":3600,\"oneTimeLoading\":false,\"usage\":\"encipherment\",\"buildChain\":false}],\"alpn\":[\"http/1.1\"]},\"tcpSettings\":{\"acceptProxyProtocol\":false,\"header\":{\"type\":\"none\"}}}",
  "sniffing": "{\"enabled\":true,\"destOverride\":[\"http\",\"tls\",\"quic\",\"fakedns\"],\"metadataOnly\":false,\"routeOnly\":false}",
  "allocate": "{\"strategy\":\"always\",\"refresh\":5,\"concurrency\":3}"
}'"'"''
```

**Key points:**
- `"fallbacks":[{"dest":"127.0.0.1:8081"}]` — regular HTTPS visitors will see the Nginx stub site
- `"alpn":["http/1.1"]` only (no `h2`) — required for Xray fallback to work correctly
- `"flow":"xtls-rprx-vision"` — XTLS Vision for performance

## Step 6: Get Connection Link

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -b /tmp/3x-cookie "https://{domain}:${PANEL_PORT}/{web_base_path}/panel/api/inbounds/list" | python3 -c "
import json,sys
data = json.load(sys.stdin)
for inb in data.get(\"obj\", []):
    if inb.get(\"protocol\") == \"vless\" and \"tls\" in inb.get(\"streamSettings\", \"\"):
        settings = json.loads(inb[\"settings\"])
        stream = json.loads(inb[\"streamSettings\"])
        client = settings[\"clients\"][0]
        uuid = client[\"id\"]
        port = inb[\"port\"]
        sni = stream.get(\"tlsSettings\", {}).get(\"serverName\", \"\")
        flow = client.get(\"flow\", \"\")
        link = f\"vless://{uuid}@{sni}:{port}?type=tcp&security=tls&sni={sni}&fp=chrome&flow={flow}#vless-tls\"
        print(link)
        break
"'
```

**Show link to user in two formats** (terminal line-wrap fix):

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

## Step 7: Install Nginx + Stub Website

Install Nginx and set up the stub site that visitors see when browsing to the domain.

See `references/fallback-nginx.md` for the full setup — it covers:
- Nginx installation
- Localhost configuration on port 8081 (for Xray fallback)
- NebulaDrive-style stub HTML page
- Verification

After completing fallback-nginx.md, return here.

## Completion

After getting the connection link and completing Step 7, return to main SKILL.md Step 20 (Install Hiddify).

**Panel URL (TLS path):** `https://{domain}:{panel_port}/{web_base_path}` — direct access, no SSH tunnel needed.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Certificate files missing | Return to SKILL.md Step 14c, run cert issuance commands |
| Panel not accessible | Check UFW: `sudo ufw status` — panel port must be open (done in Step 14c) |
| API login fails | Verify panel URL and credentials |
| Inbound not created (API error) | Use panel UI as fallback: open panel in browser, add inbound manually |
| Some sites broken via VPN | Check sniffing settings — `routeOnly` should be `false` for TLS path |
| Fallback not working | Check ALPN is `http/1.1` only (not h2), Nginx is on port 8081 |
