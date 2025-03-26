#!/bin/bash

# Кольорові коди для виводу в термінал
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
NC='\033[0m'

# Функція для друку кольорового тексту
print_color() {
    local color=$1
    local text=$2
    echo -e "${color}${text}${NC}"
}

# Функція для відображення логотипа
display_logo() {
    curl -s https://raw.githubusercontent.com/vitnodes/VdhubScript/main/logo.sh | bash
}

# Функція для зміни Chain ID у конфігураційному файлі mainnet
update_mainnet_chain_ids() {
    local config_path="$HOME/abstract-node/external-node/mainnet-external-node.yml"
    print_color "$COLOR_BLUE" "🔧 Оновлюємо Chain ID у конфігурації mainnet..."
    
    # Перевіряємо існування файлу
    if [ ! -f "$config_path" ]; then
        print_color "$COLOR_RED" "❌ Файл конфігурації не знайдено: $config_path"
        return 1
    fi
    
    # Створюємо тимчасовий файл
    local temp_file="${config_path}.tmp"
    
    # Замінюємо значення Chain ID
    sed -e 's/EN_L1_CHAIN_ID: .*/EN_L1_CHAIN_ID: 1/' \
        -e 's/EN_L2_CHAIN_ID: .*/EN_L2_CHAIN_ID: 2741/' \
        "$config_path" > "$temp_file"
    
    # Перевіряємо успішність операції
    if [ $? -eq 0 ]; then
        mv "$temp_file" "$config_path"
        print_color "$COLOR_GREEN" "✅ Chain ID Успішно оновлено в конфігурації mainnet"
    else
        print_color "$COLOR_RED" "❌ Помилка при оновленні Chain ID"
        rm -f "$temp_file"
        return 1
    fi
}

# Функція перевірки встановлення Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_color "$COLOR_RED" "🔍 Docker не встановлено. Встановлюємо Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo systemctl enable docker
        sudo systemctl start docker
    else
        print_color "$COLOR_GREEN" "✅ Docker вже встановлено"
    fi
}

# Функція перевірки встановлення Docker Compose
check_docker_compose() {
    if ! command -v docker compose &> /dev/null; then
        print_color "$COLOR_RED" "🔍 Docker Compose не встановлено. Встановлюємо Docker Compose..."
        sudo apt update
        sudo apt install -y docker-compose-plugin
    else
        print_color "$COLOR_GREEN" "✅ Вже встановлено"
    fi
}

# Функція встановлення ноди Abstract
install_node() {
    local network=$1
    
    print_color "$COLOR_BLUE" "📥 Клонуємо репозиторій..."
    git clone https://github.com/Abstract-Foundation/abstract-node
    cd abstract-node/external-node
    
    if [ "$network" == "testnet" ]; then
        print_color "$COLOR_BLUE" "🚀 Запускаємо testnet ноду..."
        docker compose -f testnet-external-node.yml up -d
    else
        update_mainnet_chain_ids
        print_color "$COLOR_BLUE" "🚀 Запускаємо mainnet ноду..."
        docker compose -f mainnet-external-node.yml up -d
    fi
    
    print_color "$COLOR_GREEN" "✅ Встановлення ноди завершено!"
}

# Функція перегляду логів контейнера
check_logs() {
    echo "📋 Доступні контейнери:"
    docker ps --format "{{.Names}}"
    echo
    read -p "Введіть ім'я контейнера для перегляду логів: " container_name
    
    if [ -n "$container_name" ]; then
        docker logs -f --tail=100 "$container_name"
    else
        print_color "$COLOR_RED" "❌ Імя контейнера не вказано"
    fi
}

# Функція скидання стану ноди
reset_node() {
    local network=$1
    
    print_color "$COLOR_YELLOW" "🔄 Скидаємо стан ноди..."
    cd ~/abstract-node/external-node
    if [ "$network" == "testnet" ]; then
        docker compose -f testnet-external-node.yml down --volumes
    else
        docker compose -f mainnet-external-node.yml down --volumes
    fi
    
    print_color "$COLOR_GREEN" "✅ Скидання ноди завершено!"
}

# Функція перезапуску контейнера
restart_container() {
    echo "📋 Доступні контейнери:"
    docker ps --format "{{.Names}}"
    echo
    read -p "Введіть імя контейнера для перезапуску: " container_name
    
    if [ -n "$container_name" ]; then
        print_color "$COLOR_YELLOW" "🔄 Перезапускаємо контейнер $container_name..."
        docker restart "$container_name"
        print_color "$COLOR_GREEN" "✅ Контейнер успішно перезапущено!"
    else
        print_color "$COLOR_RED" "❌ Імя контейнера не вказано"
    fi
}

# Функція повного видалення ноди
remove_node() {
    print_color "$COLOR_YELLOW" "⚠️ Увага! Це дія видалить всі контейнери та дані ноди!"
    read -p "Ви впевнені, що хочете продовжити? (y/n): " confirm
    
    if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
        print_color "$COLOR_BLUE" "🗑️ Видаляємо контейнери..."
        cd ~/abstract-node/external-node
        docker compose -f testnet-external-node.yml down --volumes
        docker compose -f mainnet-external-node.yml down --volumes
        
        print_color "$COLOR_BLUE" "🗑️ Видаляємо файли ноди..."
        cd ~/
        rm -rf abstract-node
        
        print_color "$COLOR_GREEN" "✅ Ноду успішно видалено!"
    else
        print_color "$COLOR_YELLOW" "🛑 Операцію скасовано"
    fi
}

# Головне меню скрипта
main_menu() {
    while true; do
        clear
        display_logo
        echo
        print_color "$COLOR_BLUE" "=== 🌟 Меню встановлення ноди Abstract === "
        echo "1. 🛠️  Встановити необхідні компоненти (Docker и Docker Compose)"
        echo "2. 🌐 Встановити Testnet ноду"
        echo "3. 🌍 Встановити Mainnet ноду"
        echo "4. 📋 Перегляд логів контейнера"
        echo "5. 🔄 Скинути Testnet ноду"
        echo "6. 🔄 Скинути Mainnet ноду"
        echo "7. 🔃 Перезапустити контейнер"
        echo "8. 🗑️  Видалити ноду"
        echo "9. 🚪 Вихід"
        echo
        read -p "Виберіть опцію (1-9): " choice
        
        case $choice in
            1)
                check_docker
                check_docker_compose
                read -p "Натисніть Enter для продовження..."
                ;;
            2)
                install_node "testnet"
                read -p "Натисніть Enter для продовження..."
                ;;
            3)
                install_node "mainnet"
                read -p "Натисніть Enter для продовження..."
                ;;
            4)
                check_logs
                read -p "Натисніть Enter для продовження..."
                ;;
            5)
                reset_node "testnet"
                read -p "Натисніть Enter для продовження..."
                ;;
            6)
                reset_node "mainnet"
                read -p "Натисніть Enter для продовження..."
                ;;
            7)
                restart_container
                read -p "Натисніть Enter для продовження..."
                ;;
            8)
                remove_node
                read -p "Натисніть Enter для продовження..."
                ;;
            9)
                print_color "$COLOR_GREEN" "👋 Дякуємо за використання встановлювача Abstract Node!"
                exit 0
                ;;
            *)
                print_color "$COLOR_RED" "❌ Невірна опція. Спробуйте ще раз."
                read -p "Натисніть Enter для продовження..."
                ;;
        esac
    done
}

# Запуск головного меню
main_menu
