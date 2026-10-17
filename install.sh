#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}      Автоматическая установка и настройка 3X-UI VPN   ${NC}"
echo -e "${BLUE}======================================================${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ошибка: Запустите скрипт из-под root (sudo su -)${NC}"
    exit 1
fi

echo -e "\n${GREEN}[1/3] Обновление системы и установка зависимостей...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget jq sudo bash psmisc sqlite3 ufw

echo -e "\n${GREEN}[2/3] Ввод доменов${NC}"
while true; do
    read -rp "Введите домен для панели управления (например, panel.domain.com): " DOMAIN_PANEL
    DOMAIN_PANEL=$(echo "$DOMAIN_PANEL" | tr -d '[:space:]')
    [[ -n "$DOMAIN_PANEL" ]] && break
    echo -e "${RED}Домен не может быть пустым!${NC}"
done

while true; do
    read -rp "Введите домен для подключения / REALITY (например, vpn.domain.com): " DOMAIN_REALITY
    DOMAIN_REALITY=$(echo "$DOMAIN_REALITY" | tr -d '[:space:]')
    [[ -n "$DOMAIN_REALITY" ]] && break
    echo -e "${RED}Домен не может быть пустым!${NC}"
done

echo -e "\n${GREEN}[3/3] Запуск установки X-UI PRO...${NC}"
bash <(curl -sSL https://raw.githubusercontent.com/KonstantinVladimirtsev69/x-ui-pro-install/main/x-ui-pro.sh) \
    -install yes \
    -panel 1 \
    -ONLY_CF_IP_ALLOW no \
    -subdomain "$DOMAIN_PANEL" \
    -reality_domain "$DOMAIN_REALITY"

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}      Установка успешно завершена! Сохраните данные выше.   ${NC}"
echo -e "${GREEN}======================================================${NC}"
