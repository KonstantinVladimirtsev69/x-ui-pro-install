# X-UI Pro Install

## Overview
Автоматизированный скрипт развертывания 3X-UI VPN сервера с поддержкой Nginx SNI-мультиплексирования на 443 порту, VLESS Reality, VLESS WebSocket, Trojan-gRPC и автоматического выпуска SSL через Let's Encrypt для Ubuntu 20.04/22.04/24.04.

## Core Components
- `install.sh`: Интерактивная обертка для установки обновлений, зависимостей и запуска инсталлятора.
- `x-ui-pro.sh`: Основной скрипт установки 3X-UI, Nginx stream routing, Certbot и генерации конфигурации.
