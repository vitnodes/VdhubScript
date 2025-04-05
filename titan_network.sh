#!/bin/bash

# Кольори тексту
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Скидання кольору

# Перевірка наявності curl та встановлення, якщо відсутній
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi

# Логотип VDHUB
curl -s https://raw.githubusercontent.com/vitnodes/VdhubScript/main/logo.sh | bash

# Меню
echo -e "${YELLOW}🔍 Оберіть дію:${NC}"
echo -e "${CYAN}1) 🚀 Встановити ноду${NC}"
echo -e "${CYAN}2) 🔄 Оновити ноду${NC}"
echo -e "${CYAN}3) 📋 Переглянути логи${NC}"
echo -e "${CYAN}4) 🔄 Перезапустити ноду${NC}"
echo -e "${CYAN}5) 🗑️ Видалити ноду${NC}"

echo -e "${YELLOW}⌨️  Введіть номер опції:${NC} "
read choice

case $choice in
    1)
        echo -e "${BLUE}🚀 Розпочинаємо встановлення Titan ноди...${NC}"

        # Docker
        if command -v docker &> /dev/null; then
            echo -e "${GREEN}✅ Docker вже встановлено. Пропускаємо.${NC}"
        else
            echo -e "${BLUE}🔧 Встановлюємо Docker...${NC}"
            sudo apt remove -y docker docker-engine docker.io containerd runc
            sudo apt install -y apt-transport-https ca-certificates curl software-properties-common lsb-release gnupg2
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io
            echo -e "${GREEN}✅ Docker успішно встановлено!${NC}"
        fi

        # Docker Compose
        if command -v docker-compose &> /dev/null; then
            echo -e "${GREEN}✅ Docker Compose вже встановлено. Пропускаємо.${NC}"
        else
            echo -e "${BLUE}🔧 Встановлюємо Docker Compose...${NC}"
            VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
            sudo curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            echo -e "${GREEN}✅ Docker Compose успішно встановлено!${NC}"
        fi

        # Додаємо користувача до групи docker
        if ! groups $USER | grep -q '\bdocker\b'; then
            echo -e "${BLUE}👤 Додаємо користувача до групи Docker...${NC}"
            sudo groupadd docker
            sudo usermod -aG docker $USER
        else
            echo -e "${GREEN}✅ Користувач вже в групі Docker.${NC}"
        fi

        # Docker-образ
        echo -e "${BLUE}📥 Завантажуємо Docker-образ Titan...${NC}"
        docker pull nezha123/titan-edge

        # Каталог
        mkdir -p ~/.titanedge

        # Запуск
        docker run --name titan --network=host -d -v ~/.titanedge:/root/.titanedge nezha123/titan-edge

        # Прив'язка identity
        echo -e "${YELLOW}🔑 Введіть ваш Titan identity code:${NC}"
        read identity_code
        docker run --rm -it -v ~/.titanedge:/root/.titanedge nezha123/titan-edge bind --hash="$identity_code" https://api-test1.container1.titannet.io/api/v2/device/binding

        # Повідомлення
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${YELLOW}📋 Команда для перегляду логів:${NC}"
        echo "docker logs -f titan"
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${GREEN}✨ Установка завершена успішно!${NC}"
        sleep 2
        
        # Провірка логів
        docker logs -f titan
        ;;
    2)
        echo -e "${BLUE}🔄 Перевіряємо оновлення...${NC}"
        echo -e "${GREEN}✅ У вас актуальна версія ноди.${NC}"
        ;;
    3)
        echo -e "${BLUE}📋 Перегляд логів...${NC}"
        docker logs -f titan
        ;;
    4)
        echo -e "${BLUE}🔄 Перезапускаємо ноду...${NC}"
        docker restart titan
        echo -e "${GREEN}✅ Ноду успішно перезапущено!${NC}"
        sleep 2

        # Провірка логів
        docker logs -f titan
        ;;
    5)
        echo -e "${RED}🗑️ Видаляємо ноду Titan...${NC}"
        docker stop titan
        docker rm titan
        docker rmi nezha123/titan-edge
        rm -rf ~/.titanedge
        echo -e "${GREEN}✨ Titan ноду успішно видалено!${NC}"
        sleep 2
        ;;
    *)
        echo -e "${RED}❌ Невірний вибір! Введіть число від 1 до 5.${NC}"
        ;;
esac
