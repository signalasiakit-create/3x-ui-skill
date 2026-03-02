# 3x-ui Skill — Extended

**Скилл Claude Code для автоматического развёртывания VPN-сервера**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) ![Platform](https://img.shields.io/badge/Platform-Linux%20VPS-orange) ![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)

> **English version**: [README.md](README.md)

---

> ### Основан на оригинальном скилле [AndyShaman](https://github.com/AndyShaman/3x-ui-skill)
> Этот репозиторий является форком [AndyShaman/3x-ui-skill](https://github.com/AndyShaman/3x-ui-skill) — полного фундамента, на котором построена вся эта работа. Всё авторство за оригинальный дизайн, структуру и реализацию принадлежит автору оригинала. Данный форк добавляет расширенные возможности поверх этой базы.

---

## Быстрая установка

```bash
curl -fsSL https://raw.githubusercontent.com/signalasiakit-create/3x-ui-skill/main/install.sh | bash
```

Или вручную:

```bash
git clone https://github.com/signalasiakit-create/3x-ui-skill.git
cp -r 3x-ui-skill/skill ~/.claude/skills/3x-ui-setup
rm -rf 3x-ui-skill
```

## Обзор

Скилл для Claude Code, который полностью автоматизирует развёртывание VPN-сервера на базе 3x-ui. Вы даёте свежий VPS (IP-адрес и root-пароль от провайдера) — скилл делает всё остальное: защищает сервер, устанавливает панель управления, настраивает прокси и помогает подключиться через клиент Hiddify.

Создан специально для новичков. Не нужно разбираться в Linux, SSH или сетевых протоколах — достаточно запустить Claude Code и описать задачу.

## Возможности

- 🔒 **Полная защита сервера** — SSH-ключи, файрвол UFW, fail2ban, hardening ядра
- 📦 **Установка панели 3x-ui** — со случайно сгенерированными учётными данными
- ⚡ **VLESS TCP + Reality** — домен не нужен, рекомендуется для большинства
- 🌐 **VLESS TCP + TLS** — с доменом, панель доступна напрямую без SSH-туннеля
- 🕸️ **VLESS XHTTP + Reality** — SplitHTTP транспорт, максимальная защита от DPI
- 🎭 **Сайт-заглушка NebulaDrive** — реалистичная страница облачного хранилища на Nginx
- 🔑 **SSH на кастомном порту** — порт 22 закрывается, SSH переносится на выбранный порт
- ♻️ **Автообновление сертификата** — cron-скрипт открывает порт 80, обновляет, закрывает — ежедневно в 03:00
- 📱 **Инструкции по Hiddify** — пошаговое руководство для клиента
- 🖥️ **Удалённый и локальный режим** — через SSH или прямо на сервере
- ✅ **Пошаговые проверки** — критические точки верифицируются на каждом этапе
- 👻 **ICMP отключён** — сервер не отвечает на ping

## Варианты протоколов

| | Path A | Path B | Path C |
|--|--------|--------|--------|
| **Транспорт** | TCP | TCP | XHTTP (SplitHTTP) |
| **Безопасность** | Reality | TLS | Reality |
| **Домен для VPN** | Нет | Да (обязателен) | Нет |
| **Сложность** | Простой | Средний | Простой |
| **Сайт-заглушка** | Нет | Да (Nginx) | Нет |
| **Защита от DPI** | Высокая | Высокая | Очень высокая |
| **Доступ к панели** | SSH-туннель (или домен, если настроен) | Напрямую через домен | SSH-туннель (или домен, если настроен) |
| **Рекомендуется** | Новичкам | При наличии домена | Максимальная скрытность |

> **Path A** рекомендуется большинству пользователей. **Path C** (XHTTP) труднее всего обнаружить и заблокировать, но требует актуальной версии клиента.
>
> **Домен необязателен для Path A и C** — если домен есть, доступ к панели через домен настраивается независимо от выбранного протокола VPN.

## Что нового в этом форке

### Панель через домен (все протоколы)
При наличии домена панель 3x-ui доступна напрямую — независимо от выбранного протокола VPN (Path A, B или C). SSL-сертификат, UFW и автообновление настраиваются в отдельном шаге до выбора протокола:
```
https://ваш-домен:{panel_port}/{web_base_path}
```

### Автообновление сертификата
Порт 80 по умолчанию закрыт. Скрипт `/root/cert-renew.sh` управляет файрволом автоматически: открывает порт 80 → обновляет сертификат → закрывает порт 80 → перезапускает x-ui. Запускается ежедневно в **03:00** через cron. Лог: `/var/log/cert-renew.log`.

### SSH на кастомном порту
Порт 22 заменяется на выбранный пользователем. UFW сначала открывает новый порт — только потом закрывает 22, исключая риск блокировки доступа.

### Сайт-заглушка NebulaDrive
Nginx отдаёт реалистичную страницу облачного хранилища с тёмной темой. Обычный посетитель видит настоящий сайт, а не ошибку подключения. Шрифты JetBrains Mono + Russo One, анимированные градиенты.

### XHTTP + Reality (Path C)
Новый вариант протокола: SplitHTTP транспорт с безопасностью Reality. Разбивает трафик VPN на множество мелких HTTP-запросов — одна из самых сложных для обнаружения конфигураций.
- Домен не нужен
- Без `xtls-rprx-vision` flow (не поддерживается с XHTTP)
- Sniffing с `routeOnly: true` — браузеры работают без сбоев
- Требует Xray core v1.8.16+

## Файловая структура

| Файл | Описание |
|------|----------|
| `skill/SKILL.md` | Основной скилл — полный процесс установки |
| `skill/references/vless-tls.md` | Path B: TCP + TLS с доменом |
| `skill/references/vless-xhttp-reality.md` | Path C: XHTTP + Reality (этот форк) |
| `skill/references/fallback-nginx.md` | Сайт-заглушка NebulaDrive на Nginx |
| `install.sh` | Установка одной командой |

## Использование

Установите скилл любым из способов выше, откройте Claude Code и скажите:

- *«Настрой VPN на моём VPS»*
- *«У меня новый сервер, помоги настроить VLESS»*
- *«Подними 3x-ui на моём сервере»*

Скилл активируется автоматически, когда Claude Code определит, что задача связана с настройкой VPN или 3x-ui.

## Требования

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI)
- Свежий VPS (Ubuntu 20.04+ / Debian 11+) с root-доступом
- SSH-доступ с вашего компьютера
- *(Только Path B)* Доменное имя с A-записью на IP сервера

## Клиенты

| Платформа | Приложение |
|-----------|------------|
| Android | [Hiddify](https://github.com/hiddify/hiddify-app/releases) |
| iOS | [Hiddify](https://apps.apple.com/app/hiddify/id6596777532) |
| Windows | [Hiddify](https://github.com/hiddify/hiddify/releases) |
| macOS | [Hiddify](https://github.com/hiddify/hiddify-app/releases) |
| Linux | [Hiddify](https://github.com/hiddify/hiddify-app/releases) |

Path C (XHTTP) также работает с Nekobox, v2rayN — нужны актуальные версии.

## Решение проблем

| Проблема | Решение |
|----------|---------|
| Permission denied (publickey) | Проверьте права ключа: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/*` |
| Host key verification failed | Удалите старый ключ: `ssh-keygen -R <IP>` |
| Панель недоступна (Path A/C) | SSH-туннель: `ssh -L {port}:127.0.0.1:{port} {nickname}` |
| Панель недоступна (Path B) | Проверьте UFW: `sudo ufw status` — порт панели должен быть открыт |
| Reality не подключается | Перезапустите сканер SNI, выберите другой домен |
| Сертификат не обновился | Запустите вручную: `sudo /root/cert-renew.sh`, проверьте `/var/log/cert-renew.log` |
| Забыли пароль от панели | Сбросьте: `sudo x-ui setting -reset` |
| Ошибка клиента с XHTTP | Обновите Hiddify/Nekobox/v2rayN до последней версии |

## Лицензия

MIT — подробности в файле [LICENSE](LICENSE).

## Благодарности

- **Оригинальный скилл:** [AndyShaman/3x-ui-skill](https://github.com/AndyShaman/3x-ui-skill) — полный фундамент, на котором построена эта работа
- **Панель 3x-ui:** [mhsanaei/3x-ui](https://github.com/mhsanaei/3x-ui)
- **Ядро Xray:** [XTLS/Xray-core](https://github.com/XTLS/Xray-core)
- **Клиент Hiddify:** [hiddify/hiddify-app](https://github.com/hiddify/hiddify-app)
