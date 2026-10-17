# X-UI PRO Auto-Installer (Ubuntu 20.04 / 22.04 / 24.04 Fixed)

Автоматический скрипт установки и настройки 3X-UI панели и VPN (VLESS Reality, WS, gRPC Trojan, Sing-box).

## Быстрый запуск (одна команда):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/KonstantinVladimirtsev69/x-ui-pro-install/main/install.sh)
```

Скрипт автоматически:
1. Выполняет `apt-get update && apt-get upgrade -y` и ставит все системные утилиты.
2. Запрашивает два домена (для панели управления и для подключения REALITY).
3. Получает бесплатные SSL-сертификаты Let's Encrypt для обоих доменов.
4. Устанавливает и настраивает 3X-UI + Nginx с SNI-роутингом (Stream preread).
5. Настраивает BBR, UFW и выводит все реквизиты доступа и ссылки на подписки.
