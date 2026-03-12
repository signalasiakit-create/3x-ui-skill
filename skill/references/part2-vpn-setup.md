# Part 2: VPN Installation — Steps 14–21a

All commands use `ssh {nickname}` configured in Part 1.

---

# PART 2: VPN Installation (3x-ui)

All commands from here use `ssh {nickname}` -- the shortcut configured in Part 1.

## Step 14: Install 3x-ui

3x-ui install script requires root. Run with sudo:

```bash
ssh {nickname} "curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh -o /tmp/3x-ui-install.sh && echo 'n' | sudo bash /tmp/3x-ui-install.sh"
```

The `echo 'n'` answers "no" to port customization prompt -- a random port and credentials will be generated.

**Note:** Do NOT use `sudo bash <(curl ...)` -- process substitution does not work with sudo (file descriptors are not inherited).

**IMPORTANT:** Capture the output! It contains:
- Generated **username**
- Generated **password**
- Panel **port**
- Panel **web base path**

Extract and save these values. Show them to the user:

```
Данные панели 3x-ui (СОХРАНИ!):
  Username: {panel_username}
  Password: {panel_password}
  Port:     {panel_port}
  Path:     {web_base_path}

  Без домена:
    URL:  https://127.0.0.1:{panel_port}/{web_base_path} (через SSH-туннель)
    Туннель: ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}

  С доменом — настраивается в Step 14c (для всех протоколов VPN):
    URL:  https://{domain}:{panel_port}/{web_base_path} (прямой доступ)
```

Verify 3x-ui is running:

```bash
ssh {nickname} "sudo x-ui status"
```

If not running: `ssh {nickname} "sudo x-ui start"`

**Без домена:** Panel port is NOT opened in firewall — access only via SSH tunnel for security.
**С доменом:** SSL cert and UFW access configured in Step 14c — direct domain access works for ALL VPN protocol paths (A, B, C).

## Step 14b: Enable BBR

BBR (Bottleneck Bandwidth and RTT) dramatically improves TCP throughput, especially on lossy links -- critical for VPN performance.

```bash
ssh {nickname} 'current=$(sysctl -n net.ipv4.tcp_congestion_control); echo "Current: $current"; if [ "$current" != "bbr" ]; then echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf && echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf && sudo sysctl -p && echo "BBR enabled"; else echo "BBR already active"; fi'
```

Verify:
```bash
ssh {nickname} "sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc"
```

Expected: `net.ipv4.tcp_congestion_control = bbr`, `net.core.default_qdisc = fq`.

## Step 14c: Configure Panel Domain Access

**When to execute:**
- **Path B (TLS):** MANDATORY if domain is available — domain is required for VPN protocol (VLESS TLS inbound on 443)
- **Path A (Reality) or Path C (XHTTP):** OPTIONAL — ask user "Do you want to use domain for panel access?"
  - YES → execute this step (panel access via domain, Xray NOT on 443)
  - NO → skip this step (panel accessible only via SSH tunnel)

**About NebulaDrive stub site:**
- **Path B:** NebulaDrive is REQUIRED (Xray listens on 443 for VLESS TLS → needs fallback for browser visitors)
- **Path A/C:** NebulaDrive is NOT needed (Xray does NOT listen on 443 → panel on separate {panel_port})
  - If domain is used for panel only (Path A/C) → skip Nginx setup, no fallback needed

**Important:** This step is executed AFTER protocol selection (Step 16). The domain can be used for panel access independently of the VPN protocol choice.

### Verify DNS

```bash
nslookup {domain}
```

Must return the server IP. If not — wait 5-10 minutes for DNS propagation.

### Issue SSL Certificate

Temporarily open port 80, issue certificate via acme.sh, then close it:

```bash
ssh {nickname} "sudo ufw allow 80/tcp"
```

```bash
ssh {nickname} "sudo apt install -y socat curl && curl https://get.acme.sh | sh -s email=admin@{domain} && sudo ~/.acme.sh/acme.sh --issue -d {domain} --standalone --httpport 80"
```

Install certificate to target path:

```bash
ssh {nickname} "sudo mkdir -p /root/cert/{domain} && sudo ~/.acme.sh/acme.sh --install-cert -d {domain} \
  --key-file /root/cert/{domain}/privkey.pem \
  --fullchain-file /root/cert/{domain}/fullchain.pem \
  --reloadcmd 'x-ui restart'"
```

Close port 80:

```bash
ssh {nickname} "sudo ufw deny 80/tcp"
```

Verify certificate files exist:

```bash
ssh {nickname} "sudo ls -la /root/cert/{domain}/"
```

### Configure Panel with SSL

```bash
ssh {nickname} "sudo /usr/local/x-ui/x-ui cert -webCert /root/cert/{domain}/fullchain.pem -webCertKey /root/cert/{domain}/privkey.pem"
ssh {nickname} "sudo x-ui restart"
```

Open panel port in UFW so it's accessible via domain from anywhere:

```bash
ssh {nickname} "sudo ufw allow {panel_port}/tcp && sudo ufw status"
```

Panel is now accessible at:

```
https://{domain}:{panel_port}/{web_base_path}
```

No browser warning — the certificate matches the domain. Works for **all VPN paths (A, B, C)**.

**Note:** Panel port is now exposed to the internet. Change default credentials and enable 2FA (Panel Settings → Account → Two-Factor Authentication) after first login.

### Certificate Auto-Renewal

Port 80 is closed by default. Create a script that temporarily opens it for ACME challenge:

```bash
ssh {nickname} 'sudo tee /root/cert-renew.sh << '"'"'EOF'"'"'
#!/bin/bash
LOG=/var/log/cert-renew.log
echo "=== $(date) ===" >> $LOG

# Open port 80 for ACME challenge
ufw allow 80/tcp >> $LOG 2>&1

# Renew certificate (acme.sh checks expiry automatically)
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" >> $LOG 2>&1

# Restart x-ui to apply renewed certificate
x-ui restart >> $LOG 2>&1

# Close port 80
ufw deny 80/tcp >> $LOG 2>&1

echo "=== Done ===" >> $LOG
EOF
sudo chmod +x /root/cert-renew.sh'
```

Set up cron to run daily at 03:00:

```bash
ssh {nickname} '(sudo crontab -l 2>/dev/null | grep -v acme | grep -v cert-renew; echo "0 3 * * * /root/cert-renew.sh") | sudo crontab -'
```

Verify:

```bash
ssh {nickname} "sudo crontab -l"
```

Expected output includes: `0 3 * * * /root/cert-renew.sh`

Test the script manually:

```bash
ssh {nickname} "sudo /root/cert-renew.sh && echo 'Renewal script OK' && tail -10 /var/log/cert-renew.log"
```

## Step 15: Disable ICMP (Stealth)

Makes server invisible to ping scans:

```bash
ssh {nickname} "sudo sed -i 's/-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT/-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/' /etc/ufw/before.rules && sudo sed -i 's/-A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT/-A ufw-before-forward -p icmp --icmp-type echo-request -j DROP/' /etc/ufw/before.rules && sudo ufw reload"
```

Verify:
```bash
ping -c 2 -W 2 {SERVER_IP}
```

Expected: no response (timeout).

## Step 16: Branch -- Choose Protocol

Ask the user which setup they want:

| | Path A | Path B | Path C |
|--|--------|--------|--------|
| **Transport** | TCP | TCP | XHTTP (SplitHTTP) |
| **Security** | Reality | TLS | Reality |
| **Domain for VPN** | No | Yes (required) | No |
| **Difficulty** | Easy | Medium | Easy |
| **Fallback site** | No | Yes (Nginx stub) | No |
| **DPI resistance** | High | High | Very high |
| **Flow** | xtls-rprx-vision | xtls-rprx-vision | None (not used) |
| **Panel access** | SSH tunnel (or domain if Step 14c) | Via domain | SSH tunnel (or domain if Step 14c) |

**Recommend Path A for beginners.** Path C (XHTTP) is slightly harder to block but requires an up-to-date client (Hiddify, Nekobox, v2rayN — latest versions).

### ⚠️ CRITICAL: Own domain CANNOT be used as Reality SNI/dest

Having a domain does **not** force you to use Path B. You can configure panel access via domain (Step 14c) and still choose Path A or C for VPN. The restriction below applies only to the Reality SNI/dest setting, not to panel access.

Reality works by physically connecting to the dest server and borrowing its real TLS handshake. Xray literally opens a TCP connection to `dest:443` on every client connect. If the domain points to the same server, Xray connects to itself — creating a loop that breaks the connection entirely.

```
Path A/C — Reality dest MUST be an external server (different IP, from scanner):
  Client → Xray → connects to neighbor-site.com:443 (real external server) → borrows TLS ✅

Path A/C — Using own domain as Reality dest is IMPOSSIBLE:
  Client → Xray → connects to yourdomain.com:443 → same IP → loop → broken ❌
```

**If user says "I have a domain, can I use it for Reality SNI?"** — answer:
> No. Reality requires an external server at a different IP. Your domain creates a loop as the SNI/dest. Use the scanner to find a neighbor server. Your domain can still be used for panel access (Step 14c), and if you want TLS-based VPN as well, choose Path B.

**The only exception** would be if the domain is behind Cloudflare proxy (orange cloud enabled) — then `yourdomain.com` resolves to Cloudflare's IP, not your server. In that case it technically works as a dest, but this is an advanced edge case and not recommended.

### Path A: VLESS TCP + Reality -- RECOMMENDED

No domain required for VPN. Domain optional — only affects panel access (Step 14c).

Go to Step 17A.

### Path B: VLESS TCP + TLS (domain required for VPN)

Go to `references/vless-tls.md`.

> **If user has a domain and wants TLS VPN** (Nginx stub site, direct Xray TLS inbound) — use Path B.
> **If user has a domain and wants Reality VPN** — use Path A or C; domain only affects panel access (Step 14c).

### Path C: VLESS XHTTP + Reality (max stealth, domain optional for panel only)

No domain required for VPN. Domain optional — only affects panel access (Step 14c).

Run the Reality scanner first (Step 17A — scanner only, stop after choosing SNI), then go to `references/vless-xhttp-reality.md`.

> Same rule applies: own domain cannot be SNI/dest. Scanner result required.

## Step 17A: Find Best SNI with Reality Scanner

Scan the server's **/24 subnet** to find real websites on neighboring IPs that support **TLS 1.3, H2 (HTTP/2), and X25519** -- the exact stack Reality needs to mimic a genuine TLS handshake. The found domain becomes the masquerade target (SNI/dest), making VPN traffic indistinguishable from regular HTTPS to a neighboring site on the same hosting.

**Why subnet scanning matters:**
- Reality reproduces a real TLS 1.3 handshake with the dest server -- the dest **must** support TLS 1.3 + H2 + X25519, or Reality won't work
- RealiTLScanner (from the XTLS project) checks exactly this -- it only outputs servers compatible with Reality
- DPI sees the SNI in TLS ClientHello and can probe the IP to verify the domain actually lives there
- Popular domains (microsoft.com, google.com) are often on CDN IPs far from the VPS -- active probing catches this
- A small unknown site on a neighboring IP (e.g., `shop.finn-auto.fi`) is ideal -- nobody filters it, and it's in the same subnet
- **Do NOT manually pick an SNI** without the scanner -- a random domain may not support TLS 1.3 or may be on a different IP range

Download and run Reality Scanner against the /24 subnet:

**Remote mode** (Claude Code on user's laptop):
```bash
ssh {nickname} 'ARCH=$(dpkg --print-architecture); case "$ARCH" in amd64) SA="64";; arm64|aarch64) SA="arm64-v8a";; *) SA="$ARCH";; esac && curl -sL "https://github.com/XTLS/RealiTLScanner/releases/latest/download/RealiTLScanner-linux-${SA}" -o /tmp/scanner && chmod +x /tmp/scanner && file /tmp/scanner | grep -q ELF || { echo "ERROR: scanner binary not valid for this architecture"; exit 1; }; MY_IP=$(curl -4 -s ifconfig.me); SUBNET=$(echo $MY_IP | sed "s/\.[0-9]*$/.0\/24/"); echo "Scanning subnet: $SUBNET"; timeout 120 /tmp/scanner --addr "$SUBNET" 2>&1 | head -80'
```

**Local mode** (Claude Code on the VPS itself):
```bash
ARCH=$(dpkg --print-architecture); case "$ARCH" in amd64) SA="64";; arm64|aarch64) SA="arm64-v8a";; *) SA="$ARCH";; esac && curl -sL "https://github.com/XTLS/RealiTLScanner/releases/latest/download/RealiTLScanner-linux-${SA}" -o /tmp/scanner && chmod +x /tmp/scanner && file /tmp/scanner | grep -q ELF || { echo "ERROR: scanner binary not valid for this architecture"; exit 1; }; MY_IP=$(curl -4 -s ifconfig.me); SUBNET=$(echo $MY_IP | sed "s/\.[0-9]*$/.0\/24/"); echo "Scanning subnet: $SUBNET"; timeout 120 /tmp/scanner --addr "$SUBNET" 2>&1 | head -80
```

**Note:** The commands are identical — Local mode simply runs without the `ssh {nickname}` wrapper since Claude Code is already on the VPS. GitHub releases use non-standard arch names (`64` instead of `amd64`, `arm64-v8a` instead of `arm64`). The `case` block maps them. The `file | grep ELF` check ensures the download is a real binary, not a 404 HTML page. Timeout is 120s because scanning 254 IPs takes longer than a single IP.

### Choosing the best SNI from scan results

Every domain in the scanner output already supports TLS 1.3 + H2 + X25519 (the scanner filters for this). From those results, **prefer** domains in this order:

1. **Small unknown sites on neighboring IPs** (e.g., `shop.finn-auto.fi`, `portal.company.de`) -- ideal, not filtered by DPI
2. **Regional/niche services** (e.g., local hosting panels, small business sites) -- low profile
3. **Well-known tech sites** (e.g., `github.com`, `twitch.tv`) -- acceptable but less ideal

**AVOID** these as SNI:
- `www.google.com`, `www.microsoft.com`, `googletagmanager.com` -- commonly blacklisted by DPI, people in Amnezia chats report these stop working
- Any domain behind a CDN (Cloudflare, Akamai, Fastly) -- the IP won't match the CDN edge, active probing detects this
- Domains that resolve to a completely different IP range than the VPS

**How to verify a candidate SNI:** The scanner output shows which IP responded with which domain. Pick a domain where the responding IP is in the same /24 as the VPS.

**If scanner finds nothing or times out** -- some providers (e.g., OVH) have sparse subnets. Try scanning a wider range `/23` (512 IPs):

**Remote mode:**
```bash
ssh {nickname} 'MY_IP=$(curl -4 -s ifconfig.me); SUBNET=$(echo $MY_IP | sed "s/\.[0-9]*$/.0\/23/"); timeout 180 /tmp/scanner --addr "$SUBNET" 2>&1 | head -80'
```

**Local mode:**
```bash
MY_IP=$(curl -4 -s ifconfig.me); SUBNET=$(echo $MY_IP | sed "s/\.[0-9]*$/.0\/23/"); timeout 180 /tmp/scanner --addr "$SUBNET" 2>&1 | head -80
```

If still nothing, use `www.yahoo.com` as a last-resort fallback -- it supports TLS 1.3 and resolves to many IPs globally, and is less commonly filtered than google/microsoft. But **always prefer a real neighbor from the scan** -- a neighbor is guaranteed to be in the same subnet and verified by the scanner for TLS 1.3 + H2 + X25519 compatibility.

Save the best SNI for the next step.

## Step 18A: Create VLESS Reality Inbound via API

**Pre-check:** Verify port 443 is not occupied by another service (some providers pre-install apache2/nginx):

```bash
ssh {nickname} "ss -tlnp | grep ':443 '"
```

If something is listening on 443, stop and disable it first (e.g., `sudo systemctl stop apache2 && sudo systemctl disable apache2`). Otherwise the VLESS inbound will silently fail to bind.

3x-ui has an API. Since v2.8+, the installer auto-configures SSL, so the panel runs on HTTPS. Use `-k` to skip certificate verification (self-signed cert on localhost).

First, get session cookie:

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -c /tmp/3x-cookie -b /tmp/3x-cookie -X POST "https://127.0.0.1:${PANEL_PORT}/{web_base_path}/login" -H "Content-Type: application/x-www-form-urlencoded" -d "username={panel_username}&password={panel_password}"'
```

Generate keys for Reality:

```bash
ssh {nickname} "sudo /usr/local/x-ui/bin/xray-linux-* x25519"
```

This outputs two lines: `PrivateKey` = private key, `Password` = **public key** (confusing naming by xray). Save both.

Generate UUID for the client:

```bash
ssh {nickname} "sudo /usr/local/x-ui/bin/xray-linux-* uuid"
```

Generate random Short ID:

```bash
ssh {nickname} "openssl rand -hex 8"
```

Create the inbound:

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -c /tmp/3x-cookie -b /tmp/3x-cookie -X POST "https://127.0.0.1:${PANEL_PORT}/{web_base_path}/panel/api/inbounds/add" -H "Content-Type: application/json" -d '"'"'{
  "up": 0,
  "down": 0,
  "total": 0,
  "remark": "vless-reality",
  "enable": true,
  "expiryTime": 0,
  "listen": "",
  "port": 443,
  "protocol": "vless",
  "settings": "{\"clients\":[{\"id\":\"{CLIENT_UUID}\",\"flow\":\"xtls-rprx-vision\",\"email\":\"user1\",\"limitIp\":0,\"totalGB\":0,\"expiryTime\":0,\"enable\":true}],\"decryption\":\"none\",\"fallbacks\":[]}",
  "streamSettings": "{\"network\":\"tcp\",\"security\":\"reality\",\"externalProxy\":[],\"realitySettings\":{\"show\":false,\"xver\":0,\"dest\":\"{BEST_SNI}:443\",\"serverNames\":[\"{BEST_SNI}\"],\"privateKey\":\"{PRIVATE_KEY}\",\"minClient\":\"\",\"maxClient\":\"\",\"maxTimediff\":0,\"shortIds\":[\"{SHORT_ID}\"],\"settings\":{\"publicKey\":\"{PUBLIC_KEY}\",\"fingerprint\":\"chrome\",\"serverName\":\"\",\"spiderX\":\"/\"}},\"tcpSettings\":{\"acceptProxyProtocol\":false,\"header\":{\"type\":\"none\"}}}",
  "sniffing": "{\"enabled\":true,\"destOverride\":[\"http\",\"tls\",\"quic\",\"fakedns\"],\"metadataOnly\":false,\"routeOnly\":false}",
  "allocate": "{\"strategy\":\"always\",\"refresh\":5,\"concurrency\":3}"
}'"'"''
```

**If API approach fails** -- tell user to access panel via SSH tunnel (Step 18A-alt).

### Step 18A-alt: SSH Tunnel to Panel (manual fallback)

If API fails, user can access panel in browser:

```bash
ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}
```

Then open in browser: `https://127.0.0.1:{panel_port}/{web_base_path}` (browser will warn about self-signed cert -- accept it)

Guide user through the UI:
1. Login with generated credentials
2. Inbounds -> Add Inbound
3. Protocol: VLESS
4. Port: 443
5. Security: Reality
6. Client Flow: xtls-rprx-vision
7. Target & SNI: paste the best SNI from scanner
8. Click "Get New Cert" for keys
9. Create

## Step 19: Get Connection Link

Get the client connection link from 3x-ui API:

```bash
ssh {nickname} 'PANEL_PORT={panel_port}; curl -sk -b /tmp/3x-cookie "https://127.0.0.1:${PANEL_PORT}/{web_base_path}/panel/api/inbounds/list" | python3 -c "
import json,sys
data = json.load(sys.stdin)
for inb in data.get(\"obj\", []):
    if inb.get(\"protocol\") == \"vless\":
        settings = json.loads(inb[\"settings\"])
        stream = json.loads(inb[\"streamSettings\"])
        client = settings[\"clients\"][0]
        uuid = client[\"id\"]
        port = inb[\"port\"]
        security = stream.get(\"security\", \"none\")
        if security == \"reality\":
            rs = stream[\"realitySettings\"]
            sni = rs[\"serverNames\"][0]
            pbk = rs[\"settings\"][\"publicKey\"]
            sid = rs[\"shortIds\"][0]
            fp = rs[\"settings\"].get(\"fingerprint\", \"chrome\")
            flow = client.get(\"flow\", \"\")
            link = f\"vless://{uuid}@$(curl -4 -s ifconfig.me):{port}?type=tcp&security=reality&pbk={pbk}&fp={fp}&sni={sni}&sid={sid}&spx=%2F&flow={flow}#vless-reality\"
            print(link)
            break
"'
```

**Show the link to the user.** This is what they'll paste into Hiddify.

**IMPORTANT: Terminal line-wrap fix.** Long VLESS links break when copied from terminal. ALWAYS provide the link in TWO formats:

1. The raw link (for reference)
2. A ready-to-copy block with LLM cleanup prompt:

~~~
Скопируй всё ниже и вставь в любой LLM (ChatGPT, Claude) чтобы получить чистую ссылку:

Убери все переносы строк и лишние пробелы из этой ссылки, выдай одной строкой:

{VLESS_LINK}
~~~

Also save the link to a file for easy access:

```bash
ssh {nickname} "echo '{VLESS_LINK}' > ~/vpn-link.txt"
```

Tell the user: **Ссылка также сохранена в файл ~/vpn-link.txt**

Cleanup session cookie:
```bash
ssh {nickname} "rm -f /tmp/3x-cookie"
```

## Step 20: Guide User -- Install Hiddify Client

Tell the user:

```
Теперь установи клиент Hiddify на своё устройство:

Android:  Google Play -> "Hiddify" или https://github.com/hiddify/hiddify-app/releases
iOS:      App Store -> "Hiddify"
Windows:  https://github.com/hiddify/hiddify-app/releases (скачай .exe)
macOS:    https://github.com/hiddify/hiddify-app/releases (скачай .dmg)
Linux:    https://github.com/hiddify/hiddify-app/releases (.deb или .AppImage)

После установки:
1. Открой Hiddify
2. Нажми "+" или "Add Profile"
3. Выбери "Add from clipboard" (ссылка уже скопирована)
4. Или отсканируй QR-код (я могу его показать)
5. Нажми кнопку подключения (большая кнопка в центре)
6. Готово! Проверь IP на сайте: https://2ip.ru
```

## Step 21: Verify Connection Works

After user connects via Hiddify, verify:

```bash
ssh {nickname} "sudo x-ui status && ss -tlnp | grep -E '443|{panel_port}'"
```

## Step 21a: Optional — WARP Outbound (Fix Google Geo-Detection)

**Offer this after VPN is verified working (Step 21).**

Tell the user:

```
Хочешь настроить WARP? Это маршрутизирует Google/YouTube через сеть Cloudflare:
- Google будет видеть IP Cloudflare вместо датацентра (Hetzner/Vultr)
- Уберёт капчи Google и проблемы с гео-детектом
- Остальной трафик идёт напрямую — скорость не падает

Займёт ~5 минут.
```

If yes → follow `references/warp-outbound.md`, then return here.
If no → proceed to Step 22.

---
