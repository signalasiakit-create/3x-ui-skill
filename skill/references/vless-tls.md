# VLESS TLS Setup (with Domain)

Use this when user has a domain and wants VLESS TLS instead of Reality.

## Prerequisites

- Domain registered and A-record pointing to server IP
- DNS propagated (verify: `nslookup {domain}` returns server IP)
- Port 443 open in UFW (already done in Step 8)
- **Port 80 is NOT open by default** — it will be opened temporarily only for certificate issuance and renewal

## Step 1: Verify DNS

```bash
nslookup {domain}
```

Must return the server IP. If not — wait 5-10 minutes for DNS propagation.

Can also check from server:
```bash
ssh {nickname} "sudo apt install -y dnsutils > /dev/null 2>&1; nslookup {domain}"
```

## Step 2: Get SSL Certificate

Temporarily open port 80, issue certificate via acme.sh, then close port 80:

```bash
ssh {nickname} "sudo ufw allow 80/tcp"
```

Install acme.sh and issue certificate:

```bash
ssh {nickname} "sudo apt install -y socat curl && curl https://get.acme.sh | sh -s email=admin@{domain} && sudo ~/.acme.sh/acme.sh --issue -d {domain} --standalone --httpport 80"
```

Install certificate to the target path:

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

Certificate files will be at:
```
/root/cert/{domain}/fullchain.pem   # certificate
/root/cert/{domain}/privkey.pem     # private key
```

## Step 3: Configure Panel with SSL and Open Panel Port

Apply certificate to panel:

```bash
ssh {nickname} "sudo /usr/local/x-ui/x-ui cert -webCert /root/cert/{domain}/fullchain.pem -webCertKey /root/cert/{domain}/privkey.pem"
ssh {nickname} "sudo x-ui restart"
```

Open panel port in UFW so it's accessible via domain (not only via SSH tunnel):

```bash
ssh {nickname} "sudo ufw allow {panel_port}/tcp"
ssh {nickname} "sudo ufw status"
```

Panel now serves HTTPS with a valid certificate. Access directly via domain:

```
https://{domain}:{panel_port}/{web_base_path}
```

No browser warning — the certificate matches the domain.

**Note:** Panel port is exposed to the internet. This is intentional for domain-based access. Make sure panel credentials are strong and 2FA is enabled (Step 5).

## Step 4: Change Panel Credentials

```bash
ssh {nickname} "sudo x-ui setting -username {new_username} -password {new_password}"
ssh {nickname} "sudo x-ui restart"
```

Open panel in browser: `https://{domain}:{panel_port}/{web_base_path}`

## Step 5: Enable 2FA in Panel (Recommended)

Since panel is accessible from the internet, 2FA is strongly recommended:

1. Open panel: `https://{domain}:{panel_port}/{web_base_path}`
2. Go to Settings → Account
3. Enable "Two-Factor Authentication"
4. Scan QR with authenticator app (Google Authenticator, Microsoft Authenticator)
5. Enter 6-digit code to confirm

## Step 6: Create VLESS TLS Inbound

Login to API (now via domain, no SSH tunnel needed):

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

**Note:** `h2` is removed from ALPN (only `http/1.1`) — required for fallback to Nginx to work correctly. Fallback to `127.0.0.1:8081` is included — regular HTTPS visitors will see the stub site.

## Step 7: Get Connection Link

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

## Step 8: Certificate Auto-Renewal via Cron (with Firewall)

Since port 80 is closed by UFW, automatic renewal requires a script that temporarily opens port 80, renews the certificate, then closes it again.

Create the renewal script:

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

Remove any existing acme.sh cron entry and set up a new one that runs at 3:00 AM daily:

```bash
ssh {nickname} '(sudo crontab -l 2>/dev/null | grep -v acme | grep -v cert-renew; echo "0 3 * * * /root/cert-renew.sh") | sudo crontab -'
```

Verify cron is set:

```bash
ssh {nickname} "sudo crontab -l"
```

Expected output should include:
```
0 3 * * * /root/cert-renew.sh
```

Test the script manually to confirm it works:

```bash
ssh {nickname} "sudo /root/cert-renew.sh && echo 'Renewal script OK' && tail -20 /var/log/cert-renew.log"
```

## Step 9: Move SSH to Custom Port

**Ask the user for a custom SSH port** (e.g., 2222, 2345, 4822 — any unused port above 1024).

**IMPORTANT:** Open the new port in UFW BEFORE changing sshd_config to avoid being locked out.

```bash
ssh {nickname} "sudo ufw allow {ssh_port}/tcp"
```

Update sshd_config to listen on the new port:

```bash
ssh {nickname} "sudo sed -i 's/^#\?Port .*/Port {ssh_port}/' /etc/ssh/sshd_config"
```

Verify the change:

```bash
ssh {nickname} "grep '^Port' /etc/ssh/sshd_config"
```

Restart SSH daemon:

```bash
ssh {nickname} "sudo systemctl restart sshd"
```

**CRITICAL — test new SSH connection BEFORE closing port 22.** Open a new terminal window and test:

```bash
ssh -p {ssh_port} -i ~/.ssh/{nickname}_key {username}@{SERVER_IP}
```

If connection works, close port 22:

```bash
ssh -p {ssh_port} {nickname} "sudo ufw deny 22/tcp && sudo ufw status"
```

Update `~/.ssh/config` on the local machine to use the new port:

```bash
cat >> ~/.ssh/config << 'EOF'

Host {nickname}
    HostName {SERVER_IP}
    User {username}
    IdentityFile ~/.ssh/{nickname}_key
    IdentitiesOnly yes
    Port {ssh_port}
EOF
```

(Or edit the existing entry if `{nickname}` is already in config.)

Verify the shortcut works:

```bash
ssh {nickname} "echo 'SSH on port {ssh_port} works'"
```

## Step 10: Install Nginx + Stub Website

Install Nginx and set up the stub site that visitors see when browsing to the domain.

See `references/fallback-nginx.md` for the full setup — it covers:
- Nginx installation
- Localhost configuration on port 8081 (for Xray fallback)
- NebulaDrive-style stub HTML page
- Verification

After completing fallback-nginx.md, return here.

## Completion

After getting the connection link and completing Steps 8–10, return to main SKILL.md Step 20 (Install Hiddify).

**Panel URL (TLS path):** `https://{domain}:{panel_port}/{web_base_path}` — direct access, no SSH tunnel needed.
