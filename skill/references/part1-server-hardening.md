# Part 1: Server Hardening (Steps 0–13)

Complete server setup from fresh VPS to production-ready state.

---

# PART 1: Server Hardening

Secure a fresh server from provider credentials to production-ready state.

## Step 0: Collect Information

First, determine **execution mode**:

**Где запущен Claude Code?**
- **На локальном компьютере** (Remote mode) -- настраиваем удалённый сервер через SSH
- **На самом сервере** (Local mode) -- настраиваем этот же сервер напрямую

### Remote Mode -- ASK the user for:

1. **Server IP** -- from provider email
2. **Root password** -- from provider email
3. **Desired username** -- for the new non-root account
4. **Server nickname** -- for SSH config (e.g., `myserver`, `vpn1`)
5. **Has domain?** -- if unsure, recommend "no" (Reality path, simpler)
6. **Domain name** (if yes to #5) -- must already point to server IP
7. **SSH port** (if domain configured) -- custom port for SSH access (any unused port above 1024, e.g., 2222 or 2345); port 22 will be closed after switching

### Local Mode -- ASK the user for:

1. **Desired username** -- for the new non-root account
2. **Server nickname** -- for future SSH access from user's computer (e.g., `myserver`, `vpn1`)
3. **Has domain?** -- if unsure, recommend "no" (Reality path, simpler)
4. **Domain name** (if yes to #3) -- must already point to server IP
5. **SSH port** (if domain configured) -- custom port for SSH access (any unused port above 1024, e.g., 2222 or 2345); port 22 will be closed after switching

In Local mode, get server IP automatically:
```bash
curl -4 -s ifconfig.me
```

If user pastes the full provider email, extract the data from it.

**Recommend Reality (no domain) for beginners.** Explain:
- Reality: works without domain, free, simpler setup, great performance
- TLS: needs domain purchase (~$10/year), more traditional, allows fallback site

## Execution Modes

All commands in this skill are written for **Remote mode** (via SSH).
For **Local mode**, adapt as follows:

| Step | Remote Mode (default) | Local Mode |
|------|----------------------|------------|
| Step 1 | Generate SSH key on LOCAL machine | **SKIP** -- user creates key on laptop later (Step 22) |
| Step 2 | `ssh root@{SERVER_IP}` | Already on server. If not root: `sudo su -` |
| Steps 3-4 | Run on server via root SSH | Run directly (already on server) |
| Step 5 | Install local public key on server | **SKIP** -- user sends .pub via SCP later (Step 22) |
| Step 6 | SSH test from LOCAL: `ssh -i ... user@IP` | Switch user: `su - {username}`, then `sudo whoami` |
| Step 7 | **SKIP** -- lockdown deferred to Step 22 | **SKIP** -- lockdown deferred to Step 22 |
| Steps 8-11 | `sudo` on server via SSH | `sudo` directly (no SSH prefix) |
| Step 12 | Write `~/.ssh/config` on LOCAL | **SKIP** -- user does this from guide file (Step 22) |
| Step 13 | Verify via `ssh {nickname}` | Run audit directly, **skip SSH lockdown checks** |
| Part 2 | `ssh {nickname} "sudo ..."` | `sudo ...` directly (no SSH prefix) |
| Step 17A | Scanner via `ssh {nickname} '...'` | Scanner runs directly (no SSH wrapper) -- see Step 17A for both commands |
| Panel access | Via SSH tunnel | Direct: `https://127.0.0.1:{panel_port}/{web_base_path}` |
| Step 22 | Generate guide + fail2ban + lock SSH | Generate guide → SCP download → SSH key setup → fail2ban + lock SSH |

**IMPORTANT:** In both modes, the end result is the same -- user has SSH key access to the server from their local computer via `ssh {nickname}`, password auth disabled, root login disabled.

## Step 1: Generate SSH Key (LOCAL)

Run on the user's LOCAL machine BEFORE connecting to the server:

```bash
ssh-keygen -t ed25519 -C "{username}@{nickname}" -f ~/.ssh/{nickname}_key -N ""
```

Save the public key content for later:
```bash
cat ~/.ssh/{nickname}_key.pub
```

## Step 2: First Connection as Root

```bash
ssh root@{SERVER_IP}
```

### Handling forced password change

Many providers force a password change on first login. Signs:
- Prompt: "You are required to change your password immediately"
- Prompt: "Current password:" followed by "New password:"
- Prompt: "WARNING: Your password has expired"

If this happens:
1. Enter the current (provider) password
2. Enter a new strong temporary password (this is temporary -- SSH keys will replace it)
3. You may be disconnected -- reconnect with the new password

**If connection drops after password change -- this is normal.** Reconnect:
```bash
ssh root@{SERVER_IP}
```

## Step 3: System Update (as root on server)

```bash
apt update && DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt upgrade -y
```

## Step 4: Create Non-Root User

```bash
useradd -m -s /bin/bash {username}
echo "{username}:{GENERATE_STRONG_PASSWORD}" | chpasswd
usermod -aG sudo {username}
```

Generate a strong random password. Tell the user to save it (needed for sudo). Then:

```bash
# Verify
groups {username}
```

## Step 5: Install SSH Key for New User

```bash
mkdir -p /home/{username}/.ssh
echo "{PUBLIC_KEY_CONTENT}" > /home/{username}/.ssh/authorized_keys
chmod 700 /home/{username}/.ssh
chmod 600 /home/{username}/.ssh/authorized_keys
chown -R {username}:{username} /home/{username}/.ssh
```

## Step 6: TEST New User Login -- CRITICAL CHECKPOINT

**DO NOT proceed without successful test!**

Open a NEW connection (keep root session alive):
```bash
ssh -i ~/.ssh/{nickname}_key {username}@{SERVER_IP}
```

Verify sudo works:
```bash
sudo whoami
# Must output: root
```

**If this fails** -- debug permissions, do NOT disable root login:
```bash
# Check on server as root:
ls -la /home/{username}/.ssh/
cat /home/{username}/.ssh/authorized_keys
# Fix ownership:
chown -R {username}:{username} /home/{username}/.ssh
```

## Step 7: Lock Down SSH — DEFERRED

**Оба режима: ПРОПУСКАЕМ.** Блокировка SSH и установка fail2ban выполняются в самом конце (Step 22), после того как SSH-ключ проверен. Это предотвращает случайную блокировку доступа во время настройки.

## Step 8: Firewall

```bash
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status
```

**Note:** Port 80 is NOT opened here. For TLS path it is opened temporarily during certificate issuance (vless-tls.md Step 2) and for renewal (via `/root/cert-renew.sh`), then closed again. For Reality path port 80 is never needed.

## Step 9: fail2ban — DEFERRED

**Пропущен.** fail2ban устанавливается в конце настройки (Step 22) вместе с блокировкой SSH, чтобы не заблокировать пользователя во время настройки.

## Step 10: Kernel Hardening

```bash
sudo tee /etc/sysctl.d/99-security.conf << 'EOF'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF
sudo sysctl -p /etc/sysctl.d/99-security.conf
```

## Step 11: Time Sync + Base Packages

```bash
sudo apt install -y chrony curl wget unzip net-tools
sudo systemctl enable chrony
```

## Step 12: Configure Local SSH Config

On the user's LOCAL machine:

```bash
cat >> ~/.ssh/config << 'EOF'

Host {nickname}
    HostName {SERVER_IP}
    User {username}
    IdentityFile ~/.ssh/{nickname}_key
    IdentitiesOnly yes
EOF
```

Tell user: **Теперь подключайся командой `ssh {nickname}` -- без пароля и IP.**

## Step 13: Final Verification

Connect as new user and run quick audit:
```bash
ssh {nickname}
# Then on server:
sudo ufw status
sudo sysctl net.ipv4.conf.all.rp_filter
```

Expected: ufw active, rp_filter = 1.

**Note:** SSH lockdown и fail2ban проверяются в конце (Step 22) после подтверждения работы SSH-ключа.

**Часть 1 завершена. Базовая настройка сервера готова. Переходим к установке VPN.**

---
