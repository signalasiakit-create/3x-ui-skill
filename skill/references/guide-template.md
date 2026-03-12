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
| SSH-порт | `{ssh_port}` ({ssh_port_custom}: yes/no) |
| Быстрое подключение | `ssh {nickname}` |

## 2. Панель 3x-ui

| Параметр | Значение |
|----------|----------|
| Логин | `{panel_username}` |
| Пароль | `{panel_password}` |

**Path A (Reality) / Path C (XHTTP) — без домена панели** — доступ через SSH-туннель:
```
ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}
```
Затем открой: `https://127.0.0.1:{panel_port}/{web_base_path}`

**Path A (Reality) / Path C (XHTTP) — с доменом панели** (если выбрано {panel_via_domain}) — прямой доступ:
```
https://{domain}:{panel_port}/{web_base_path}
```

**Path B (TLS) — с доменом** — прямой доступ:
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

**XHTTP+Reality путь:**

| Параметр | Значение |
|----------|----------|
| Протокол | VLESS XHTTP+Reality |
| Порт | 443 |
| SNI | `{best_sni}` |
| Path | `/{xhttp_path}` |
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
| Файрвол UFW | Включён |
| fail2ban | Включён (3 попытки → бан 24ч) |
| Усиление ядра | Включено (sysctl) |
| BBR | Включён |
| ICMP (ping) | Отключён |

## 6a. Статус портов и firewall

### Всегда открытые в UFW:
| Порт | Протокол | Назначение | Кто может подключиться |
|------|----------|-----------|---------------------------|
| {ssh_port} | TCP | SSH доступ | Только по SSH-ключу (парольный вход отключен) |
| 443 | TCP | VLESS VPN (Reality или TLS) | Любой (VPN) |

### Условно открытые:
| Порт | Когда | Назначение | Действие |
|------|--------|-----------|----------|
| 80 | {panel_via_domain}: yes | Обновление SSL сертификата (ACME) | Открывается автоматически в 03:00 на 5 минут, потом закрывается |
| {panel_port} | {panel_via_domain}: yes | Доступ к панели через домен | Открыт постоянно (защищен SSL и 2FA) |

### Всегда закрытые:
| Порт | Почему |
|------|---------|
| 22 | SSH перемещен на {ssh_port} ({ssh_port_custom}: yes/no) |
| 80 (основное время) | HTTPS и fallback на 443, ACME открывается по расписанию |

### Специальные (локальные, НЕ открыты в UFW):
| Порт | Адрес | Назначение | Доступность |
|------|-------|-----------|----------|
| 40000 | 127.0.0.1 | WARP SOCKS5 прокси ({warp_enabled}) | Только локальный, НЕ открыт в интернет |

**Важно:** Порт 40000 — это локальный SOCKS5 прокси WARP. Он НЕ открыт в UFW и НЕ доступен из интернета. Маршрутизация идет внутри Xray.

### Чеклист проверки портов:

Для проверки что все порты скфигурированы правильно, выполни на своем компьютере:

**Проверка SSH:**
```bash
ssh {nickname} "echo 'SSH OK'"  # Должен работать без пароля
```

**Проверка VPN порта:**
```bash
ssh {nickname} "ss -tlnp | grep 443"  # Должно быть: LISTEN ... :443
```

**Проверка UFW:**
```bash
ssh {nickname} "sudo ufw status numbered"
```

**Ожидается (для Path A/C без домена):**
```
1  Allow       22/tcp (SSH на его исходном порту если ssh_port_custom == no)
   Allow       {ssh_port}/tcp (SSH если ssh_port_custom == yes)
2  Allow       443/tcp
```

**Ожидается (для Path A/C с доменом или Path B):**
```
1  Allow       {ssh_port}/tcp (SSH на кастомном порту)
2  Allow       443/tcp
3  Allow       {panel_port}/tcp
```

**Проверка что 80 закрыт (основное время):**
```bash
ssh {nickname} "sudo ufw status | grep 80"
# НЕ должно быть никакого 80 в списке (кроме как "deny")
```

**Проверка WARP (если включен):**
```bash
ssh {nickname} "ss -tlnp | grep 40000"
# Должно быть: LISTEN 127.0.0.1:40000 (только локальный адрес)
```

| SSH порт | {ssh_port} ({ssh_port_custom}: yes/no — если yes, порт 22 закрыт) |
| Обновление сертификата | Cron 0 3 * * * /root/cert-renew.sh ({panel_via_domain}: yes/no — если yes) |

## 7. Решение проблем

### Проблемы с подключением

| Проблема | Решение |
|----------|---------|
| Connection refused | `ssh {nickname} "sudo x-ui status"` — перезапусти если остановлен |
| Permission denied (publickey) | Проверь путь и права ключа: `ls -la ~/.ssh/{nickname}_key` |
| Host key verification failed | `ssh-keygen -R {SERVER_IP}` и переподключись |
| VPN не подключается | Неверный SNI/домен или сервер лежит — проверь `sudo x-ui log` |

### Проблемы с панелью

| Проблема | Решение |
|----------|---------|
| Панель недоступна (без домена) | Используй SSH-туннель: `ssh -L {panel_port}:127.0.0.1:{panel_port} {nickname}` |
| Панель недоступна (с доменом) | Проверь UFW: `ssh {nickname} "sudo ufw status"`, убедись порт {panel_port} открыт |
| Забыл пароль панели | `ssh {nickname} "sudo x-ui setting -reset"` |
| Панель медленная/лагует | Проверь сертификат TLS: `ssh {nickname} "sudo x-ui log"` |

### Проблемы с сертификатом

| Проблема | Решение |
|----------|---------|
| Сертификат не обновился | `ssh {nickname} "sudo /root/cert-renew.sh"` и проверь `/var/log/cert-renew.log` |
| Port 80 не закрывается после обновления | Проверь что скрипт `/root/cert-renew.sh` работает: `ssh {nickname} "sudo tail -20 /var/log/cert-renew.log"` |
| ACME ошибка "address already in use" | Порт 80 занят чем-то ещё. Проверь: `ssh {nickname} "sudo lsof -i :80"` |

### Проблемы с firewall и портами

| Проблема | Решение |
|----------|---------|
| VPN работает но панель "не видна" | Проверь UFW: `ssh {nickname} "sudo ufw status numbered"`. Должны быть открыты SSH и 443. Если с доменом — нужен и {panel_port} |
| Заблокирован доступ к SSH | SSH должен быть на порту {ssh_port}. Используй: `ssh -p {ssh_port} {username}@{SERVER_IP}` или конфиг (см. раздел 4) |
| WARP не работает (если включен) | Проверь что 40000 слушает ТОЛЬКО на localhost: `ssh {nickname} "ss -tlnp \| grep 40000"`. Должно быть `127.0.0.1:40000`, НЕ `0.0.0.0:40000` |
| Порт 80 должен быть закрыт | `ssh {nickname} "sudo ufw status \| grep 80"`. НЕ должно показывать разрешение на 80 (только deny). Проверь что крон скрипт работает каждый день в 03:00 |

### Проверка всех портов за раз

Выполни эту команду для полной диагностики:

```bash
ssh {nickname} 'echo "=== SSH/UFW ==="; sudo ufw status numbered; \
echo ""; echo "=== VPN (443) ==="; sudo ss -tlnp | grep 443; \
echo ""; echo "=== Panel ({panel_port}) ==="; sudo ss -tlnp | grep {panel_port}; \
echo ""; echo "=== Port 80 ==="; sudo ufw status | grep 80 || echo "Port 80 не открыт (OK)"; \
echo ""; echo "=== WARP (40000) ==="; sudo ss -tlnp | grep 40000 || echo "WARP не установлен или не запущен"; \
echo ""; echo "=== Cert renewal cron ==="; sudo crontab -l | grep cert'
```

**Ожидаемый результат:**
- UFW активен с SSH и 443 открытыми
- 443 слушает (Xray VPN)
- {panel_port} слушит если {panel_via_domain}: yes
- 80 НЕ открыт в UFW (или отмечен как deny)
- 40000 слушит ТОЛЬКО на 127.0.0.1 (если WARP включен)
- Cron задача настроена для cert-renew.sh

## 8. WARP Outbound (Опционально)

**Статус:** {warp_enabled}

Если WARP включен, трафик Google/YouTube маршрутизируется через Cloudflare для обхода геоблокировок.

| Параметр | Значение |
|----------|----------|
| Статус | {warp_enabled} |
| Адрес прокси | `127.0.0.1` |
| Порт прокси | `40000` |
| Домены через WARP | `Google, YouTube, Gemini, NotebookLM` |
| Остальной трафик | Напрямую через VPN (полная скорость) |

### Проверка WARP

```bash
ssh {nickname} "warp-cli --accept-tos status"
# Должно быть: Connected

ssh {nickname} "ss -tlnp | grep 40000"
# Должно быть: LISTEN 127.0.0.1:40000
```

### Если WARP включен — тест

Подключись через VPN и открой: https://www.cloudflare.com/cdn-cgi/trace

Ожидается:
- `warp=on` — WARP активен
- `ip=104.x.x.x` — IP Cloudflare (не твоего сервера)

### Отключение WARP

Если WARP работает медленно или не нужен:

```bash
ssh {nickname} "warp-cli --accept-tos disconnect"
```

Затем в панели удали:
1. **Outbound** с tag `warp-cli`
2. **Routing Rule** для Google/YouTube доменов
3. Перезапусти: `ssh {nickname} "sudo x-ui restart"`

---

## 9. Инструкции для Claude Code

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

WARP Outbound (опционально):
   {warp_enabled}
   [Если включен] Адрес: 127.0.0.1:40000
   Домены через WARP: Google, YouTube, Gemini, NotebookLM
   Проверка: ssh {nickname} "warp-cli --accept-tos status"
   [Если отключить] ssh {nickname} "warp-cli --accept-tos disconnect"

Методичка: ~/vpn-{nickname}-guide.md
   Все пароли, инструкции и команды в одном файле
```
