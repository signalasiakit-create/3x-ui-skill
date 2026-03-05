# Guide File Template & Completion Summary

Use the **Write tool** to generate the guide file substituting all `{variables}`.

---

### Guide File Template

Generate this file using the **Write tool**, substituting all `{variables}` with actual values collected during setup.

~~~markdown
# Методичка VPN-сервера — {nickname}

Дата создания: {current_date}

## 1. Подключение к серверу

| Параметр | Значение |
|----------|----------|
| IP | `{SERVER_IP}` |
| Пользователь | `{username}` |
| Пароль sudo | `{sudo_password}` |
| SSH-ключ | `~/.ssh/{nickname}_key` |
| SSH-порт | `{ssh_port}` (если TLS путь, иначе 22) |
| Быстрое подключение | `ssh {nickname}` |

## 2. Панель 3x-ui

| Параметр | Значение |
|----------|----------|
| Логин | `{panel_username}` |
| Пароль | `{panel_password}` |

**Reality путь (без домена)** — доступ через SSH-туннель:
```
ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}
```
Затем открой: `https://127.0.0.1:{panel_port}/{web_base_path}`

**TLS путь (с доменом)** — прямой доступ:
```
https://{domain}:{panel_port}/{web_base_path}
```

## 3. VPN-подключение

**Reality путь:**

| Параметр | Значение |
|----------|----------|
| Протокол | VLESS Reality |
| Порт | 443 |
| SNI | `{best_sni}` |
| Клиент | Hiddify |

**TLS путь:**

| Параметр | Значение |
|----------|----------|
| Протокол | VLESS TLS |
| Порт | 443 |
| Домен | `{domain}` |
| Клиент | Hiddify |

Ссылка VLESS:
```
{VLESS_LINK}
```

## 4. Настройка SSH-ключа

Если у тебя ещё нет SSH-ключа, следуй инструкциям для своей ОС:

### macOS / Linux

```bash
# Создать ключ
ssh-keygen -t ed25519 -C "{username}@{nickname}" -f ~/.ssh/{nickname}_key -N ""

# Отправить публичный ключ на сервер
scp ~/.ssh/{nickname}_key.pub {username}@{SERVER_IP}:~/

# Установить права
chmod 600 ~/.ssh/{nickname}_key

# Добавить в SSH-конфиг
cat >> ~/.ssh/config << 'SSHEOF'

Host {nickname}
    HostName {SERVER_IP}
    User {username}
    IdentityFile ~/.ssh/{nickname}_key
    IdentitiesOnly yes
SSHEOF

# Проверить подключение
ssh {nickname}
```

### Windows (PowerShell)

```powershell
# Создать ключ
ssh-keygen -t ed25519 -C "{username}@{nickname}" -f $HOME\.ssh\{nickname}_key -N '""'

# Отправить публичный ключ на сервер
scp $HOME\.ssh\{nickname}_key.pub {username}@{SERVER_IP}:~/

# Добавить в SSH-конфиг
Add-Content $HOME\.ssh\config @"

Host {nickname}
    HostName {SERVER_IP}
    User {username}
    IdentityFile ~/.ssh/{nickname}_key
    IdentitiesOnly yes
"@

# Проверить подключение
ssh {nickname}
```

Примечание: `chmod` не нужен на Windows. SSH использует ACL автоматически.

## 5. Частые команды

```bash
ssh {nickname}                           # подключиться к серверу
ssh {nickname} "sudo x-ui status"        # статус панели
ssh {nickname} "sudo x-ui restart"       # перезапустить панель
ssh {nickname} "sudo x-ui log"           # логи
ssh {nickname} "sudo x-ui setting -reset" # сбросить пароль панели
```

Добавить нового VPN-клиента:
Открой панель через SSH-туннель → Inbounds → ... → Add Client → отправь ссылку/QR.

## 6. Статус безопасности

| Параметр | Статус |
|----------|--------|
| Вход под root | Отключён |
| Вход по паролю | Отключён |
| Файрвол UFW | Включён (SSH, 443) |
| fail2ban | Включён (3 попытки → бан 24ч) |
| Усиление ядра | Включено (sysctl) |
| BBR | Включён |
| ICMP (ping) | Отключён |
| SSH порт | {ssh_port} (если TLS путь, порт 22 закрыт) |
| Обновление сертификата | Cron 0 3 * * * /root/cert-renew.sh (если TLS путь) |

## 7. Решение проблем

| Проблема | Решение |
|----------|---------|
| Connection refused | `ssh {nickname} "sudo x-ui status"` — перезапусти если остановлен |
| Permission denied (publickey) | Проверь путь и права ключа: `ls -la ~/.ssh/{nickname}_key` |
| Host key verification failed | `ssh-keygen -R {SERVER_IP}` и переподключись |
| Панель недоступна (Reality) | Используй SSH-туннель (см. раздел 2) |
| Панель недоступна (TLS) | Проверь UFW: `sudo ufw status`, убедись порт {panel_port} открыт |
| VPN не подключается | Неверный SNI/домен или сервер лежит — проверь `sudo x-ui log` |
| Забыл пароль панели | `ssh {nickname} "sudo x-ui setting -reset"` |
| Сертификат не обновился | `ssh {nickname} "sudo /root/cert-renew.sh"` и проверь `/var/log/cert-renew.log` |

## 8. Инструкции для Claude Code

Этот раздел для автоматической настройки через Claude Code на твоём ноутбуке.
Скопируй всё ниже и вставь в Claude Code на ноутбуке.

---

**ЗАДАЧА: Настроить SSH-ключ и завершить настройку безопасности VPN-сервера**

Данные сервера:
- SERVER_IP: {SERVER_IP}
- USERNAME: {username}
- PASSWORD: {sudo_password}
- NICKNAME: {nickname}

Шаги:

**Часть А: Установка sshpass (нужен для автоматической передачи пароля)**
1. Определи ОС и установи sshpass:
   - macOS: `brew install hudochenkov/sshpass/sshpass`
   - Linux (Debian/Ubuntu): `sudo apt install -y sshpass`

**Часть Б: Создание и установка SSH-ключа**
2. Создай SSH-ключ: `ssh-keygen -t ed25519 -C "{username}@{nickname}" -f ~/.ssh/{nickname}_key -N ""`
3. Установи ключ на сервере одной командой:
   ```
   sshpass -p '{sudo_password}' ssh-copy-id -i ~/.ssh/{nickname}_key.pub -o StrictHostKeyChecking=accept-new {username}@{SERVER_IP}
   ```
4. Проверь вход по ключу (должен работать БЕЗ пароля):
   ```
   ssh -i ~/.ssh/{nickname}_key {username}@{SERVER_IP} "echo 'SSH key OK'"
   ```
5. Добавь SSH-конфиг:
   ```
   cat >> ~/.ssh/config << 'EOF'

   Host {nickname}
       HostName {SERVER_IP}
       User {username}
       IdentityFile ~/.ssh/{nickname}_key
       IdentitiesOnly yes
   EOF
   ```
6. Проверь подключение через конфиг: `ssh {nickname} "echo 'Config OK'"`

**Часть В: Финальная защита сервера (fail2ban + блокировка пароля)**
7. Установи fail2ban:
   ```
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
8. Заблокируй парольный вход и root:
   ```
   ssh {nickname} 'sudo sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config && sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config && sudo systemctl restart sshd'
   ```
9. Проверь что SSH-ключ всё ещё работает после блокировки:
   ```
   ssh {nickname} "grep -E 'PermitRootLogin|PasswordAuthentication' /etc/ssh/sshd_config && sudo systemctl status fail2ban --no-pager && echo 'Сервер полностью защищён!'"
   ```
10. Скажи пользователю: "Готово! SSH-ключ настроен, fail2ban установлен, парольный вход отключён. Подключайся: ssh {nickname}"
~~~

---

## Completion Summary

Print this summary for the user:

```
VPN-сервер полностью настроен и работает!

Подключение к серверу:
   Команда:     ssh {nickname}
   IP:          {SERVER_IP}
   Пользователь: {username}
   SSH-ключ:    ~/.ssh/{nickname}_key
   Пароль sudo: {sudo_password}

Безопасность сервера:
   Root-вход отключён
   Парольный вход отключён
   Файрвол включён (порты: SSH, 443)
   fail2ban защищает от брутфорса
   Ядро усилено (sysctl)
   BBR включён (TCP-оптимизация)
   ICMP отключён (сервер не пингуется)
   [Domain] SSH переведён на порт {ssh_port}, порт 22 закрыт
   [Domain] Сертификат обновляется автоматически каждый день в 3:00

Панель 3x-ui:
   [Без домена] URL: https://127.0.0.1:{panel_port}/{web_base_path} (через SSH-туннель)
                Туннель: ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}
   [С доменом]  URL: https://{domain}:{panel_port}/{web_base_path} (прямой доступ, все протоколы)
   Login:    {panel_username}
   Password: {panel_password}

VPN-подключение:
   [Path A] Протокол: VLESS TCP+Reality   | Порт: 443 | SNI: {best_sni}
   [Path B] Протокол: VLESS TCP+TLS       | Порт: 443 | Домен: {domain}
   [Path C] Протокол: VLESS XHTTP+Reality | Порт: 443 | SNI: {best_sni} | Path: /{xhttp_path}

Клиент:
   Hiddify -- ссылка добавлена

Управление (через SSH):
   ssh {nickname}                           # подключиться к серверу
   ssh {nickname} "sudo x-ui status"        # статус панели
   ssh {nickname} "sudo x-ui restart"       # перезапустить панель
   ssh {nickname} "sudo x-ui log"           # логи
   [Domain] ssh {nickname} "sudo /root/cert-renew.sh"  # обновить сертификат вручную

[Без домена] SSH-туннель к панели:
   ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}
   Затем открыть: https://127.0.0.1:{panel_port}/{web_base_path}

Добавить нового клиента:
   Открой админку -> Inbounds -> ... -> Add Client
   Скинь ссылку или QR-код другому человеку

Методичка: ~/vpn-{nickname}-guide.md
   Все пароли, инструкции и команды в одном файле
```
