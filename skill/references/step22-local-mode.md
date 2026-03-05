# Step 22: Local Mode — Guide Generation & SSH Lockdown

Use when Claude Code runs directly on the VPS (Local mode).

---

### Local Mode

In Local mode, Claude Code runs on the server. SSH lockdown was skipped (Step 7), so password auth still works. The flow:

#### 22L-1: Generate guide file on server

Use the **Write tool** to create `/home/{username}/vpn-guide.md` on the server. Use the **Guide File Template** below, substituting all `{variables}` with actual values.

#### 22L-2: User downloads guide via SCP

Tell the user:

```
Методичка готова! Скачай её на свой компьютер.
Открой НОВЫЙ терминал на своём ноутбуке и выполни:

scp {username}@{SERVER_IP}:~/vpn-guide.md ./

Пароль: {sudo_password}

Файл сохранится в текущую папку. Открой его -- там все пароли и инструкции.
```

**Fallback:** If SCP doesn't work (Windows without OpenSSH, network issues), show the full guide content directly in chat.

#### 22L-2a: ⚠️ VERIFICATION CHECKPOINT — ОБЯЗАТЕЛЬНО ПЕРЕД ПРОДОЛЖЕНИЕМ

Tell the user:

```
⚠️ Открой скачанный файл vpn-guide.md и проверь каждый пункт:

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
Только после "Методичка ОК" продолжим настройку SSH-ключа.
```

**Wait for user to say "Методичка ОК" (or equivalent) before proceeding!**

#### 22L-3: User creates SSH key on their laptop

Tell the user:

```
Теперь создай SSH-ключ на своём компьютере.
Есть два варианта:

Вариант А: Следуй инструкциям из раздела "SSH Key Setup" в методичке.

Вариант Б (автоматический): Установи Claude Code на ноутбуке
  (https://claude.ai/download) и скинь ему файл vpn-guide.md --
  он сам всё настроит по инструкциям из раздела "Instructions for Claude Code".

После создания ключа отправь публичный ключ на сервер (следующий шаг).
```

#### 22L-4: User sends public key to server via SCP

Tell the user:

```
Отправь публичный ключ на сервер (из терминала на ноутбуке):

scp ~/.ssh/{nickname}_key.pub {username}@{SERVER_IP}:~/

Пароль: {sudo_password}
```

Wait for user confirmation before proceeding.

#### 22L-5: Install key + verify

```bash
mkdir -p /home/{username}/.ssh
cat /home/{username}/{nickname}_key.pub >> /home/{username}/.ssh/authorized_keys
chmod 700 /home/{username}/.ssh
chmod 600 /home/{username}/.ssh/authorized_keys
chown -R {username}:{username} /home/{username}/.ssh
rm -f /home/{username}/{nickname}_key.pub
```

Tell user to test from their laptop:
```
Проверь подключение с ноутбука:
ssh -i ~/.ssh/{nickname}_key {username}@{SERVER_IP}

Должно подключиться без пароля.
```

**Wait for user confirmation that SSH key works before proceeding!**

#### 22L-6: Final lockdown — fail2ban + SSH

**Only after user confirms key-based login works!**

Install fail2ban:
```bash
sudo apt install -y fail2ban
sudo tee /etc/fail2ban/jail.local << 'EOF'
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
EOF
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```

Lock SSH:
```bash
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

Verify:
```bash
grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config
sudo systemctl status fail2ban --no-pager
```

Expected: `PermitRootLogin no`, `PasswordAuthentication no`, fail2ban active.

Tell user to verify SSH still works from laptop:
```
Проверь, что SSH-ключ всё ещё работает:
ssh {nickname}
Если подключился — всё настроено!
```

#### 22L-7: User configures SSH config

Tell the user:

```
Последний шаг! Добавь на ноутбуке в файл ~/.ssh/config:

Host {nickname}
    HostName {SERVER_IP}
    User {username}
    IdentityFile ~/.ssh/{nickname}_key
    IdentitiesOnly yes

Теперь подключайся просто: ssh {nickname}
```

#### 22L-8: Delete guide file from server

```bash
rm -f /home/{username}/vpn-guide.md
```

Tell user: **Методичка удалена с сервера. Убедись, что она сохранена на твоём компьютере.**

---
