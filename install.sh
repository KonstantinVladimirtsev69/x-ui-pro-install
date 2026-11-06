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
apt-get install -y curl wget jq sudo bash psmisc sqlite3 ufw cron
systemctl enable --now cron 2>/dev/null || true

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

IP4=$(ip route get 8.8.8.8 2>&1 | grep -Po -- 'src \K\S*' || true)
if [[ -z "$IP4" ]]; then
    IP4=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || curl -s --max-time 3 https://ifconfig.me 2>/dev/null || echo "127.0.0.1")
fi
IP_LAST="${IP4##*.}"
[[ -z "$IP_LAST" || "$IP_LAST" == "$IP4" ]] && IP_LAST="vpn"

HOST_SHORT=$(hostname -s 2>/dev/null | cut -d. -f1 | tr -dc 'a-zA-Z0-9_-' | tr '[:upper:]' '[:lower:]' || echo "srv")
[[ -z "$HOST_SHORT" ]] && HOST_SHORT="srv"
DEFAULT_CLIENT="${HOST_SHORT}-${IP_LAST}"

echo ""
read -rp "Введите имя первого клиента [по умолчанию: ${DEFAULT_CLIENT}]: " INPUT_CLIENT
INPUT_CLIENT=$(echo "$INPUT_CLIENT" | tr -dc 'a-zA-Z0-9_-' | tr '[:upper:]' '[:lower:]')

if [[ -z "$INPUT_CLIENT" ]]; then
    CLIENT_NAME="$DEFAULT_CLIENT"
else
    if [[ "$INPUT_CLIENT" =~ -${IP_LAST}$ ]]; then
        CLIENT_NAME="$INPUT_CLIENT"
    else
        CLIENT_NAME="${INPUT_CLIENT}-${IP_LAST}"
    fi
fi
echo -e "Имя первого клиента: ${BLUE}${CLIENT_NAME}${NC}"

echo -e "\n${GREEN}[3/3] Запуск установки X-UI PRO...${NC}"
bash <(curl -sSL https://raw.githubusercontent.com/KonstantinVladimirtsev69/x-ui-pro-install/main/x-ui-pro.sh) \
    -install yes \
    -panel 1 \
    -ONLY_CF_IP_ALLOW no \
    -subdomain "$DOMAIN_PANEL" \
    -reality_domain "$DOMAIN_REALITY" \
    -client_name "$CLIENT_NAME"

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}      Установка успешно завершена! Сохраните данные выше.   ${NC}"
echo -e "${GREEN}======================================================${NC}"
