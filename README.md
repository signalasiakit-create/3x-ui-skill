# 3x-ui Skill — Extended

**Claude Code skill for automated VPN server deployment**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) ![Platform](https://img.shields.io/badge/Platform-Linux%20VPS-orange) ![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)

> **Русская версия**: [README.ru.md](README.ru.md)

---

> ### Based on the original skill by [AndyShaman](https://github.com/AndyShaman/3x-ui-skill)
> This repository is a fork of [AndyShaman/3x-ui-skill](https://github.com/AndyShaman/3x-ui-skill) — the complete foundation this work is built on. All credit for the original design, workflow, and implementation goes to the original author. This fork adds extended configuration options on top of that work.

---

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/signalasiakit-create/3x-ui-skill/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/signalasiakit-create/3x-ui-skill.git
cp -r 3x-ui-skill/skill ~/.claude/skills/3x-ui-setup
rm -rf 3x-ui-skill
```

## Overview

A Claude Code skill that fully automates VPN server deployment on a fresh VPS. Hand it your server IP and root password — it handles everything from OS hardening to a working VLESS proxy with client setup instructions.

Built for beginners who want a secure, censorship-resistant connection without learning sysadmin or proxy protocols. The skill walks through each step, verifies critical checkpoints, and leaves you with a hardened server and a ready-to-use VPN.

## Features

- 🔒 **Full server hardening** — SSH keys, firewall (UFW), fail2ban, kernel tweaks
- 📦 **3x-ui panel** — installed with randomized credentials and secure defaults
- ⚡ **VLESS TCP + Reality** — recommended path, no domain needed
- 🌐 **VLESS TCP + TLS** — domain path with auto SSL, panel accessible via domain directly
- 🕸️ **VLESS XHTTP + Reality** — SplitHTTP transport, maximum DPI resistance
- 🎭 **NebulaDrive stub site** — realistic cloud storage page as Nginx camouflage
- 🔑 **SSH on custom port** — port 22 closed, SSH moved to user-chosen port
- ♻️ **Certificate auto-renewal** — cron script opens port 80, renews, closes — daily at 03:00
- ☁️ **WARP outbound** — route Google/YouTube through Cloudflare to fix geo-detection and CAPTCHAs
- 📱 **Hiddify client guidance** — step-by-step connection on any device
- 🖥️ **Remote or local mode** — works over SSH from your machine or directly on the server
- ✅ **Checkpoint-driven workflow** — every critical step is verified before moving on
- 👻 **ICMP disabled** — server does not respond to ping for stealth
- 🚪 **Intelligent firewall management** — only necessary ports open (443 for VPN, custom SSH port, panel port if domain configured)

## Protocol Options

| | Path A | Path B | Path C |
|--|--------|--------|--------|
| **Transport** | TCP | TCP | XHTTP (SplitHTTP) |
| **Security** | Reality | TLS | Reality |
| **Domain for VPN** | No | Yes (required) | No |
| **Difficulty** | Easy | Medium | Easy |
| **Fallback site** | No | Yes (Nginx stub) | No |
| **DPI resistance** | High | High | Very high |
| **Panel access** | SSH tunnel (or domain if configured) | Direct via domain | SSH tunnel (or domain if configured) |
| **Recommended for** | Beginners | Users with domain | Max stealth |

> **Path A** is recommended for most users. **Path C** (XHTTP) is the hardest to detect and block but requires an up-to-date client.
>
> **Domain is optional for Path A and C** — if you have a domain, panel access via domain is configured independently of the VPN protocol choice.

## What's New in This Fork

### Panel via Domain (optional for Path A/C, mandatory for Path B)
- **Path B (TLS):** Domain is REQUIRED for VPN protocol. Panel accessible via domain: `https://yourdomain.com:{panel_port}/{web_base_path}`
- **Path A (Reality) / Path C (XHTTP):** Domain is OPTIONAL. If domain is provided, panel is accessible directly via domain instead of SSH tunnel.

SSL cert, UFW access, and cert renewal are set up in a dedicated step AFTER protocol selection.

### Certificate Auto-Renewal (only if domain configured)
Port 80 is closed by default. A `/root/cert-renew.sh` script handles the firewall automatically. Runs daily at **03:00** via cron. Log: `/var/log/cert-renew.log`.

### SSH on Custom Port (optional for all paths)
Optional: Move SSH from port 22 to a user-chosen port for extra security. UFW opens the new port first, then closes 22 — no lockout risk. Works independently of VPN protocol or domain choice.

### NebulaDrive Stub Site
Nginx serves a realistic dark-themed cloud storage page. Regular browser visitors see a legitimate site, not a connection error. Built with JetBrains Mono + Russo One fonts, animated gradients.

### WARP Outbound (Google Geo-Detection Fix)
After the VPN is working, an optional step offers to route Google, YouTube, and Google AI services (Gemini, AI Studio) through Cloudflare WARP. This replaces the datacenter exit IP with a Cloudflare IP that Google trusts — eliminating CAPTCHAs and geo-blocks without slowing down non-Google traffic.

### XHTTP + Reality (Path C)
New protocol: SplitHTTP transport with Reality security. Splits VPN traffic into many small HTTP requests — one of the hardest configurations for DPI to detect.
- No domain required
- No `xtls-rprx-vision` flow (not supported with XHTTP)
- Sniffing with `routeOnly: true` to prevent broken sites
- Requires Xray core v1.8.16+

## Workflow

```
Fresh VPS (IP + root + password)
  |
  +-- Part 1: Server Hardening
  |   +-- SSH key generation
  |   +-- System update
  |   +-- Non-root user + sudo
  |   +-- UFW firewall (SSH + 443 only)
  |   +-- Kernel hardening (sysctl)
  |   +-- BBR TCP optimization
  |   +-- ICMP disabled (stealth)
  |   +-- SSH config shortcut
  |
  +-- Part 2: VPN Installation (choose path)
  |   +-- 3x-ui panel install
  |   |
  |   +-- [Path A] TCP + Reality
  |   |     +-- Reality SNI scanner
  |   |     +-- Create inbound via API
  |   |     +-- Panel via SSH tunnel
  |   |
  |   +-- [Path B] TCP + TLS (domain)
  |   |     +-- SSL certificate (acme.sh)
  |   |     +-- Panel via domain (direct)
  |   |     +-- Cert renewal cron (03:00)
  |   |     +-- SSH moved to custom port
  |   |     +-- NebulaDrive stub site
  |   |
  |   +-- [Path C] XHTTP + Reality
  |         +-- Reality SNI scanner
  |         +-- Create XHTTP inbound via API
  |         +-- Panel via SSH tunnel
  |
  +-- Connection link + Hiddify setup
  +-- Step 21a (Optional): WARP Outbound
  |     +-- Install warp-cli
  |     +-- Configure proxy mode
  |     +-- Add Xray outbound + routing rule
  |     +-- Test via SOCKS5
  |
  +-- fail2ban + SSH lockdown
  +-- Done: Secured server + Working VPN
```

## File Structure

| File | Description |
|------|-------------|
| `skill/SKILL.md` | Main skill — complete setup workflow |
| `skill/references/vless-tls.md` | Path B: TCP + TLS with domain |
| `skill/references/vless-xhttp-reality.md` | Path C: XHTTP + Reality (this fork) |
| `skill/references/fallback-nginx.md` | Nginx NebulaDrive stub site |
| `skill/references/warp-outbound.md` | Optional: WARP outbound for Google geo-detection fix |
| `skill/references/warp-auto.sh` | Automation script for one-command WARP installation and verification |
| `install.sh` | One-line installer script |

## Usage

After installation, open Claude Code and say:

- *"Set up a VPN on my VPS"*
- *"I have a new server, help me configure VLESS"*
- *"Harden my server and install 3x-ui"*

The skill activates automatically when Claude detects a relevant request.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI)
- Fresh VPS (Ubuntu 20.04+ / Debian 11+) with root access
- SSH access from your machine
- *(Path B only)* Domain name with A-record pointing to VPS IP

## Clients

| Platform | App |
|----------|-----|
| Android | [Hiddify](https://github.com/hiddify/hiddify-app/releases) |
| iOS | [Hiddify](https://apps.apple.com/app/hiddify/id6596777532) |
| Windows | [Hiddify](https://github.com/hiddify/hiddify/releases) |
| macOS | [Hiddify](https://github.com/hiddify/hiddify-app/releases) |
| Linux | [Hiddify](https://github.com/hiddify/hiddify-app/releases) |

Path C (XHTTP) also works with Nekobox, v2rayN — latest versions required.

## Firewall & Port Management

The skill implements **minimal firewall exposure** — only necessary ports are open:

| Port | Status | Purpose | When Used |
|------|--------|---------|-----------|
| 22 | Varies | SSH | Closed if custom port configured (Step 22); closed by default for security |
| 443 | ✅ Always open | VLESS VPN (all paths) | Required for all protocol paths (A, B, C) |
| 80 | ❌ Closed (auto-open) | ACME certificate renewal | Opens automatically via cron daily at 03:00 for 5 minutes, then closes (Step 14c only) |
| {panel_port} | Varies | 3x-ui admin panel | Closed by default; opens only if domain configured (Step 14c); protected by SSL + credentials |
| 40000 | Localhost only | WARP SOCKS5 | **NOT exposed to internet** — runs only on 127.0.0.1 (optional Step 21a) |
| {ssh_port} | ✅ Open (custom SSH) | SSH access | Created if you move SSH from port 22 (Step 22) |

### Key security points:

- **Port 80** is normally CLOSED. Opens automatically only during daily cert renewal (03:00) via `/root/cert-renew.sh` cron, then closes.
- **Port 40000** (WARP) is **never exposed to the internet** — only bound to localhost (127.0.0.1). If you see it bound to 0.0.0.0:40000, something is misconfigured.
- **Panel port** is protected by SSL certificate (if domain configured) and requires login with credentials. Enable 2FA for extra security.
- **Fail2ban** protects SSH from brute-force after setup completes (installed in Step 22).

### Verify ports after setup:

```bash
# Check UFW firewall rules
ssh {nickname} "sudo ufw status numbered"

# Check what ports are actually listening
ssh {nickname} "sudo ss -tlnp | grep -E ':443|:80|:40000|:{panel_port}'"

# Verify port 80 is NOT permanently open
ssh {nickname} "sudo ufw status | grep 80"  # Should show nothing or "deny"

# Verify WARP only on localhost (if installed)
ssh {nickname} "sudo ss -tlnp | grep 40000"  # Should show 127.0.0.1:40000
```

## Troubleshooting

### SSH & Connection Issues

| Problem | Solution |
|---------|----------|
| `Permission denied (publickey)` | Check SSH key permissions: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/*` |
| `Host key verification failed` | Remove old key: `ssh-keygen -R <server-ip>` |
| SSH timeout or refuses connection | If using custom SSH port (Step 22): `ssh -p {custom_port} {username}@{server-ip}` |

### Panel Access Issues

| Problem | Solution |
|---------|----------|
| Panel not accessible (Path A/C, no domain) | Use SSH tunnel: `ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}` → then open `https://127.0.0.1:{panel_port}/{web_base_path}` |
| Panel not accessible (with domain) | Check: 1) Domain points to server IP (`nslookup {domain}`), 2) UFW allows port ({panel_port}): `sudo ufw status`, 3) Certificate exists: `sudo ls /root/cert/{domain}/`, 4) Xray running: `sudo x-ui status` |
| Forgot panel password | Reset: `ssh {nickname} "sudo x-ui setting -reset"` |

### VPN Connection Issues

| Problem | Solution |
|---------|----------|
| Reality not connecting | Re-run the SNI scanner to find a working target; verify domain is NOT your own domain as SNI |
| XHTTP client error | Update Hiddify/Nekobox/v2rayN to latest version (XHTTP requires recent clients) |
| No internet after VPN connects | Check panel logs: `ssh {nickname} "sudo x-ui log"` — look for TLS errors or binding issues |

### Certificate Issues

| Problem | Solution |
|---------|----------|
| Certificate not renewed | Check cron: `ssh {nickname} "sudo crontab -l \| grep cert"` — should show `0 3 * * * /root/cert-renew.sh`. Run manually: `ssh {nickname} "sudo /root/cert-renew.sh"` and check `/var/log/cert-renew.log` |
| Port 80 not closing after renewal | Check script output: `ssh {nickname} "tail /var/log/cert-renew.log"`. If stuck, manually close: `ssh {nickname} "sudo ufw deny 80/tcp"` |

### Firewall & Port Issues

| Problem | Solution |
|---------|----------|
| **Port 80 permanently open (CRITICAL)** | This should NOT happen. Port 80 must be closed except during cert renewal. Check: `sudo ufw status \| grep 80` (should show nothing or "deny"). If open, close it: `sudo ufw deny 80/tcp` |
| **Port 40000 exposed to internet (CRITICAL)** | WARP SOCKS5 should ONLY listen on localhost. Check: `sudo ss -tlnp \| grep 40000`. If shows `0.0.0.0:40000` or non-127.0.0.1 address, WARP is misconfigured. Reinstall: `sudo apt remove cloudflare-warp && sudo apt install cloudflare-warp` |
| UFW shows unexpected open ports | Run: `sudo ufw status numbered` and compare with expected list (SSH, 443, and {panel_port} if domain) |

### WARP Specific Issues

| Problem | Solution |
|---------|----------|
| `warp-cli` not found | Install: `ssh {nickname} "sudo apt update && sudo apt install -y cloudflare-warp"` |
| Port 40000 not listening | Check mode: `ssh {nickname} "warp-cli mode"` — must be `Proxy`. Reconfigure: `ssh {nickname} "warp-cli --accept-tos mode proxy && warp-cli --accept-tos connect"` |
| `warp=off` in trace | WARP connected but not routing traffic. Set mode again: `warp-cli --accept-tos mode proxy` and reconnect in panel |
| Google still shows datacenter IP | Verify routing rule in panel: inbound=`inbound-443`, outbound=`warp-cli`, domains include `geosite:google`, `geosite:youtube`. Restart: `sudo x-ui restart` |

## License

MIT — see [LICENSE](LICENSE) for details.

## Credits

- **Original skill:** [AndyShaman/3x-ui-skill](https://github.com/AndyShaman/3x-ui-skill) — the complete foundation this work is built on
- **3x-ui panel:** [mhsanaei/3x-ui](https://github.com/mhsanaei/3x-ui)
- **Xray core:** [XTLS/Xray-core](https://github.com/XTLS/Xray-core)
- **Hiddify client:** [hiddify/hiddify-app](https://github.com/hiddify/hiddify-app)
