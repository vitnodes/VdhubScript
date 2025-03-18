#!/bin/bash

# Визначення кольорів
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функція для логування
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Функція для перевірки помилок
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Помилка: $1${NC}"
        exit 1
    fi
}

# Функція для перевірки залежностей
check_dependencies() {
    local deps=("curl" "wget")
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            echo -e "${YELLOW}Установка $dep...${NC}"
            sudo apt update
            sudo apt install $dep -y
            check_error "Не вдалося встановити $dep"
        fi
    done
}

# Банер
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Встановлення Node Exporter            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# Перевірка залежностей
log "Перевірка залежностей..."
check_dependencies

# Завантаження логотипа
log "Завантаження логотипа..."
curl -s https://raw.githubusercontent.com/vitnodes/VdhubScript/main/logo.sh | bash

# Отримання останньої версії node_exporter
log "Отримання останньої версії node_exporter..."
VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep 'tag_name' | cut -d\" -f4 | cut -c2-)
check_error "Не вдалося отримати версію node_exporter"

# Визначення операційної системи
log "Визначення системи..."
if [[ "$(uname -s)" == "Linux" ]]; then
    OS="linux"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    OS="darwin"
else
    echo -e "${RED}Непідтримувана операційна система!${NC}"
    exit 1
fi

# Визначення архітектури
if [[ "$(uname -m)" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$(uname -m)" == "aarch64" ]]; then
    ARCH="arm64"
else
    echo -e "${RED}Непідтримувана архітектура!${NC}"
    exit 1
fi

# Завантаження та встановлення node_exporter
log "Завантаження node_exporter v${VERSION}..."
wget -q --show-progress https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.${OS}-${ARCH}.tar.gz
check_error "Не вдалося завантажити node_exporter"

log "Розпакування..."
tar xf node_exporter-${VERSION}.${OS}-${ARCH}.tar.gz
check_error "Не вдалося розпакувати архів"

rm node_exporter-${VERSION}.${OS}-${ARCH}.tar.gz
sudo mv node_exporter-${VERSION}.${OS}-${ARCH} node_exporter
chmod +x $HOME/node_exporter/node_exporter
sudo mv $HOME/node_exporter/node_exporter /usr/bin
rm -Rf $HOME/node_exporter/

# Створення systemd сервісу
log "Створення systemd сервісу..."
sudo tee /etc/systemd/system/exporterd.service > /dev/null <<EOF
[Unit]
Description=Node Exporter Service
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
ExecStart=/usr/bin/node_exporter
Restart=always
RestartSec=3
LimitNOFILE=65535
NoNewPrivileges=true
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Запуск сервісу
log "Налаштування та запуск сервісу..."
sudo systemctl daemon-reload
sudo systemctl enable exporterd
sudo systemctl start exporterd
check_error "Не вдалося запустити сервіс"

# Перевірка статусу
log "Перевірка статусу сервісу..."
if systemctl is-active --quiet exporterd; then
    echo -e "${GREEN}Node Exporter Успішно встановлено та запущено!${NC}"
    echo -e "${YELLOW}Версія:${NC} ${VERSION}"
    echo -e "${YELLOW}Порт:${NC} 9100"
    echo -e "${YELLOW}Метрики доступні за адресою:${NC} http://localhost:9100/metrics"
else
    echo -e "${RED}Помилка під час запуску сервісу!${NC}"
    exit 1
fi
