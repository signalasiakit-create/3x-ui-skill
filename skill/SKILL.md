---
name: 3x-ui-setup
description: >
  VPN server deployment assistant for 3x-ui panel on a fresh Linux VPS.
  Use when user provides a server IP/password and asks to set up a VPN, install 3x-ui,
  configure VLESS Reality or VLESS TLS, harden a new server, or set up Hiddify client.
  Russian triggers: "настрой VPN", "поставь 3x-ui", "установи впн на сервер", "настрой сервер с нуля".
  Do NOT use for troubleshooting an existing VPN setup, client-only questions, or non-VPN server tasks.
allowed-tools: Bash,Read,Write,Edit
---

# ⚠️ HOW TO USE THIS SKILL CORRECTLY

**IMPORTANT:** This skill requires **strict step-by-step adherence**. Skipping or combining steps can cause configuration issues, lockouts, or security problems. Claude Code tends to skip steps — use these **magic phrases** to keep the process on track.

## Magic Phrases for Users

### Starting fresh:
```
Настрой VPN-сервер строго по всем шагам скила.
Перед каждым шагом назови его номер и название.
Не переходи к следующему шагу без моего подтверждения.
На шагах с выбором или вопросами — обязательно спрашивай меня.
```

### Resuming after interruption:
```
Сессия прервалась. Покажи текущий статус установки:
- Какие шаги уже выполнены?
- Какой шаг выполняется сейчас?
- Какой будет следующий?
```

### Unsticking a stuck installation:
```
Ты пропустил несколько шагов. Вернёмся к {STEP_NUMBER}.
Выполни его полностью, затем мы продолжим по порядку.
```

## Why Strict Step-by-Step Matters

1. **Server lockout risk** — Step 6 must be tested before Step 7 disables root
2. **Guide completeness** — SSH port migration (Step 22R-0) must happen BEFORE guide generation (Step 22R-1), so the guide captures the correct port
3. **Panel credentials** — must be saved in Step 14 before Step 18
4. **SSH key verification** — must work in Step 21 before Step 22 locks SSH
5. **WARP configuration** — optional in Step 21a, but must follow VPN verification

## Session Progress Template

When resuming, show the user this progress:

```
📋 Текущий статус установки VPN-сервера {nickname}

✅ COMPLETED:
  Step 0: Собраны данные ({mode} mode)
  Step 1: SSH-ключ сгенерирован
  Step 2-13: Сервер защищен (firewall, hardening, etc.)
  Step 14: Панель 3x-ui установлена
  Step 14b: BBR включен

⏳ IN PROGRESS:
  Step 14c: Конфигурация домена (SSL сертификат)

❓ NEXT:
  Step 15: Disable ICMP
  Step 16: Выбор протокола (Path A/B/C)
  Step 17A: Reality сканер
  ... и далее

Продолжим с Step 14c?
```

---

# VPN Server Setup (3x-ui)

Complete setup: fresh VPS from provider → secured server → working VPN with Hiddify client.

## Workflow Overview

```
ЧАСТЬ 1: Настройка сервера
  Fresh VPS (IP + root + password)
    → Determine execution mode (remote or local)
    → Generate SSH key / setup access
    → Connect as root
    → Update system
    → Create non-root user + sudo
    → Install SSH key
    → TEST new user login (critical!)
    → Firewall (ufw)
    → Kernel hardening
    → Time sync + packages
    → Configure local ~/.ssh/config
    → ✅ Server secured

ЧАСТЬ 2: Установка VPN (3x-ui)
    → Install 3x-ui panel
    → Enable BBR (TCP optimization)
    → Disable ICMP (stealth)
    → Reality: scanner → create inbound → get link
    → Install Hiddify client
    → Verify connection
    → Generate guide file (credentials + instructions)
    → Install fail2ban + lock SSH (after key verified)
    → ✅ VPN working
```

---

# PART 1: Server Hardening

**Full commands in `references/part1-server-hardening.md`** — open it now and follow each step.

| Step | Name | Mode note |
|------|------|-----------|
| **Step 0** | Collect Info | Determine Remote vs Local; ask for IP, user, domain |
| **Step 1** | Generate SSH Key | LOCAL machine only — skip in Local mode |
| **Step 2** | First Root Login | Handle forced password change prompt |
| **Step 3** | System Update | `apt upgrade` non-interactive |
| **Step 4** | Create Non-Root User | sudo-capable, generate + save strong password |
| **Step 5** | Install SSH Key | `authorized_keys` for new user |
| **Step 6** | **TEST New Login** | ⚠️ CRITICAL — DO NOT SKIP — test before disabling root |
| **Step 7** | SSH Lockdown | DEFERRED → Step 22 |
| **Step 8** | Firewall (UFW) | SSH + 443 only, port 80 closed |
| **Step 9** | fail2ban | DEFERRED → Step 22 |
| **Step 10** | Kernel Hardening | sysctl security settings |
| **Step 11** | Time Sync + Packages | chrony, curl, wget, unzip |
| **Step 12** | Local SSH Config | `~/.ssh/config` shortcut (Remote mode) |
| **Step 13** | Final Verification | `ufw status`, `rp_filter` check |

**Part 1 complete when:** `ssh {nickname}` connects without password.

---

# PART 2: VPN Installation (3x-ui)

**Full commands in `references/part2-vpn-setup.md`** — open it and follow each step.

| Step | Name | Notes |
|------|------|-------|
| **Step 14** | Install 3x-ui Panel | Save credentials shown in output — ⚠️ critical |
| **Step 14b** | Enable BBR | TCP throughput optimization |
| **Step 14c** | Panel Domain Access | **Only if user has domain** — SSL cert + UFW + panel URL |
| **Step 15** | Disable ICMP | Server becomes invisible to ping |
| **Step 16** | Choose Protocol | Path A (Reality) / Path B (TLS) / Path C (XHTTP) |
| **Step 17A** | Reality Scanner | Run for Path A and C — find best SNI from /24 subnet |
| **Step 18A** | Create VLESS Inbound | Via API (or SSH tunnel to panel as fallback) |
| **Step 19** | Get Connection Link | Extract from API, show in two formats (raw + LLM-cleanup) |
| **Step 20** | Install Hiddify Client | Guide user through install + profile add |
| **Step 21** | Verify Connection | Confirm VPN works before finalizing |
| **Step 21a** | WARP Outbound | Optional — route Google/YouTube via Cloudflare |

**Protocol branches:**
- **Path A** → Steps 17A → 18A → 19 (in `references/part2-vpn-setup.md`)
- **Path B** → `references/vless-tls.md`
- **Path C** → Step 17A scanner (SNI only), then `references/vless-xhttp-reality.md`
- **WARP** → `references/warp-outbound.md` (after Step 21)

**Part 2 complete when:** User connects via Hiddify and sees VPN IP.

---
## Step 22: Generate Guide File & Finalize SSH Access

**Order in this step:** SSH port migration → guide file → user verifies guide → fail2ban + lockdown.

> ⚠️ SSH port migration is done HERE (not in Step 14c) so the guide captures the correct port.

### Remote Mode

**22R-0: Move SSH to Custom Port (if domain configured in Step 14c)**

**Only if the user has a domain.** Skip this sub-step if no domain.

**IMPORTANT:** UFW opens the new port BEFORE changing sshd_config — no lockout risk.

```bash
ssh {nickname} "sudo ufw allow {ssh_port}/tcp"
```

Update sshd_config:

```bash
ssh {nickname} "sudo sed -i 's/^#\?Port .*/Port {ssh_port}/' /etc/ssh/sshd_config"
```

Verify and restart:

```bash
ssh {nickname} "grep '^Port' /etc/ssh/sshd_config"
ssh {nickname} "sudo systemctl restart sshd"
```

**CRITICAL — test new SSH connection BEFORE closing port 22.** Open a new terminal and test:

```bash
ssh -p {ssh_port} -i ~/.ssh/{nickname}_key {username}@{SERVER_IP}
```

If connection works, close port 22:

```bash
ssh -p {ssh_port} {nickname} "sudo ufw deny 22/tcp && sudo ufw status"
```

Update `~/.ssh/config` on local machine to use the new port:

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

(Or edit the existing `{nickname}` entry if already present.)

Verify:

```bash
ssh {nickname} "echo 'SSH on port {ssh_port} works'"
```

---

**22R-1: Generate guide file locally**

Use the **Write tool** to create `~/vpn-{nickname}-guide.md` on the user's local machine. Use the **Guide File Template** below, substituting all `{variables}` with actual values.

Tell user: **Методичка сохранена в ~/vpn-{nickname}-guide.md — там все пароли, доступы и инструкции.**

---

**22R-1a: ⚠️ VERIFICATION CHECKPOINT — ОБЯЗАТЕЛЬНО ПЕРЕД ПРОДОЛЖЕНИЕМ**

**Do NOT proceed to fail2ban until user confirms the guide is correct.**

Tell the user:

```
⚠️ Открой файл ~/vpn-{nickname}-guide.md и проверь каждый пункт:

☐  IP сервера:       {SERVER_IP}
☐  Пользователь:     {username}
☐  Пароль sudo:      заполнен (не пустой, не "{sudo_password}")
☐  SSH ключ:         ~/.ssh/{nickname}_key
☐  SSH порт:         {ssh_port} — указан в разделе "Подключение к серверу"
                     (если домена нет — порт 22)
☐  Панель — логин:   {panel_username}
☐  Панель — пароль:  заполнен (не пустой)
☐  Панель — URL:     правильный (SSH-туннель или домен)
☐  VLESS ссылка:     присутствует, одной строкой, без переносов

Если что-то пустое или неверное — скажи, исправлю прямо сейчас.

**ДВОЙНАЯ ПРОВЕРКА (оба обязательны!):**
1. ✅ Проверь все 8 пунктов выше и убедись что всё заполнено
2. ✅ После проверки скажи ровно: "Методичка ОК"

Только ПОСЛЕ ОБЕИХ проверок продолжу финальную блокировку сервера (fail2ban + lockdown).
```

**Wait for:**
1. User confirms all 8 items are correct
2. User says exactly "Методичка ОК" (or "Методичка OK", "Методичка хорошо")
3. ONLY THEN proceed to Step 22R-2**

---

**22R-2: Final lockdown — fail2ban + SSH**

Verify SSH key access works:
```bash
ssh {nickname} "echo 'SSH key access OK'"
```

If successful, install fail2ban and lock SSH:
```bash
ssh {nickname} 'sudo apt install -y fail2ban && sudo tee /etc/fail2ban/jail.local << JAILEOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
JAILEOF
sudo systemctl enable fail2ban && sudo systemctl restart fail2ban'
```

```bash
ssh {nickname} 'sudo sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config && sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config && sudo systemctl restart sshd'
```

**Verify lockdown + SSH still works:**
```bash
ssh {nickname} "grep -E 'PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config && sudo systemctl status fail2ban --no-pager -l && echo 'Lockdown OK'"
```

### Local Mode — Step 22

For Local mode (Claude Code running on the VPS), follow `references/step22-local-mode.md`.
Steps: generate guide → SCP download → SSH key setup → fail2ban + lockdown.

---

### Guide File Template

Use the **Write tool** to create the guide file. Full template in `references/guide-template.md`.
Substitute ALL `{variables}` with actual collected values before writing.

---

## Critical Rules

### Part 1 (Server)
1. **NEVER skip Step 6** (test login) -- user can be locked out permanently
2. **NEVER disable root before confirming new user works**
3. **NEVER store passwords in files** -- only display once to user
4. **If connection drops** after password change -- reconnect, this is normal
5. **If Step 6 fails** -- fix it before proceeding, keep root session open
6. **Generate SSH key BEFORE first connection** -- more efficient workflow
7. **All operations after Step 6 use sudo** -- not root
8. **Steps 7 and 9 are DEFERRED** -- SSH lockdown and fail2ban are installed at the very end (Step 22)

### Part 2 (VPN)
9. **No domain: NEVER expose panel port to internet** -- access only via SSH tunnel; **Domain configured (Step 14c): panel accessible via domain for ALL paths** (A, B, C) — UFW open, valid SSL cert, 2FA required
10. **NEVER skip firewall configuration** -- only open needed ports
11. **ALWAYS save panel credentials** -- show them once, clearly
12. **ALWAYS verify connection works** before declaring success
13. **Ask before every destructive or irreversible action**
14. **ALWAYS generate guide file** (Step 22) -- the user's single source of truth
15. **SSH port migration happens in Step 22 (22R-0), NOT in Step 14c** — this ensures the guide captures the correct port
16. **ALWAYS show verification checklist after guide is generated** (Step 22R-1a) — wait for user confirmation before fail2ban
17. **Lock SSH + install fail2ban LAST** (Step 22R-2) -- only after guide verified and SSH key confirmed working
18. **NEVER leave password auth enabled** after setup is complete

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Connection drops after password change | Normal -- reconnect with new password |
| Permission denied (publickey) | Check key path and permissions (700/600) |
| Host key verification failed | `ssh-keygen -R {SERVER_IP}` then reconnect |
| x-ui install fails | `sudo apt update && sudo apt install -y curl tar` |
| Panel not accessible | Use SSH tunnel: `ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}` |
| Reality not connecting | Wrong SNI -- re-run scanner, try different domain |
| Hiddify shows error | Update Hiddify to latest version, re-add link |
| "connection refused" | Check x-ui is running: `sudo x-ui status` |
| Forgot panel password | `sudo x-ui setting -reset` |
| SCP fails (Windows) | Install OpenSSH: Settings → Apps → Optional Features → OpenSSH Client |
| SCP fails (connection refused) | Check UFW allows SSH: `sudo ufw status`, verify sshd running |
| BBR not active after reboot | Re-check: `sysctl net.ipv4.tcp_congestion_control` -- re-apply if needed |

## x-ui CLI Reference

```bash
x-ui start          # start panel
x-ui stop           # stop panel
x-ui restart        # restart panel
x-ui status         # check status
x-ui setting -reset # reset username/password
x-ui log            # view logs
x-ui cert           # manage SSL certificates
x-ui update         # update to latest version
```
