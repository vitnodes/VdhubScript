#!/bin/bash

# Скрипт для перенаправлення всього трафіку через proxychains на Ubuntu 22.04

# Перевірка на root права
if [ "$EUID" -ne 0 ]; then
  echo "Цей скрипт вимагає прав суперкористувача (root)."
  echo "Будь ласка, запустіть з sudo: sudo $0"
  exit 1
fi

# Перевірка, чи встановлений proxychains
if ! command -v proxychains4 &> /dev/null; then
    echo "Proxychains не встановлено. Встановлюємо..."
    apt update
    apt install -y proxychains4
    if [ $? -ne 0 ]; then
        echo "Помилка встановлення proxychains. Перевірте підключення до інтернету та права доступу."
        exit 1
    fi
    echo "Proxychains Успішно встановлено."
else
    echo "Proxychains Вже встановлено."
fi

# Функція для налаштування iptables для перенаправлення всього трафіку через proxychains
setup_traffic_forwarding() {
    local proxy_type=$1
    local proxy_ip=$2
    local proxy_port=$3
    local proxy_user=$4
    local proxy_pass=$5
    local local_port=$6
    local excluded_ips=$7
    
    # Створюємо резервну копію оригінального конфігу
    cp /etc/proxychains4.conf /etc/proxychains4.conf.backup
    
    # Налаштовуємо proxychains без використання 'cat <<EOF'
    echo '# proxychains.conf VER 4.x' > /etc/proxychains4.conf
    echo '#' >> /etc/proxychains4.conf
    echo '# Проксіфікація всього трафіку через заданий проксі' >> /etc/proxychains4.conf
    echo '' >> /etc/proxychains4.conf
    echo '# Строгий режим — якщо проксі не працює, зєднання переривається' >> /etc/proxychains4.conf
    echo 'strict_chain' >> /etc/proxychains4.conf
    echo '' >> /etc/proxychains4.conf
    echo '# Проксіфікація DNS запитів' >> /etc/proxychains4.conf
    echo 'proxy_dns' >> /etc/proxychains4.conf
    echo '' >> /etc/proxychains4.conf
    echo '# Таймаути для TCP зєднань' >> /etc/proxychains4.conf
    echo 'tcp_read_time_out 15000' >> /etc/proxychains4.conf
    echo 'tcp_connect_time_out 8000' >> /etc/proxychains4.conf
    echo '' >> /etc/proxychains4.conf
    echo '# Локальні підмережі не проксіюються' >> /etc/proxychains4.conf
    echo 'localnet 127.0.0.0/255.0.0.0' >> /etc/proxychains4.conf
    echo 'localnet 10.0.0.0/255.0.0.0' >> /etc/proxychains4.conf
    echo 'localnet 172.16.0.0/255.240.0.0' >> /etc/proxychains4.conf
    echo 'localnet 192.168.0.0/255.255.0.0' >> /etc/proxychains4.conf
    echo '' >> /etc/proxychains4.conf
    echo '# Список проксі-серверів:' >> /etc/proxychains4.conf
    echo '[ProxyList]' >> /etc/proxychains4.conf

    # Додаємо проксі з урахуванням логіна та пароля, якщо вони вказані
    if [ -n "$proxy_user" ] && [ -n "$proxy_pass" ]; then
        echo "$proxy_type $proxy_ip $proxy_port $proxy_user $proxy_pass" >> /etc/proxychains4.conf
    else
        echo "$proxy_type $proxy_ip $proxy_port" >> /etc/proxychains4.conf
    fi

    echo "Конфігурація proxychains оновлена."
    
    # Тестуємо проксі перед налаштуванням iptables
    echo "Тестування проксі-зєднання..."
    if proxychains4 curl -s --connect-timeout 10 https://ifconfig.me > /dev/null; then
        echo "Проксі-зєднання працює."
    else
        echo "ПОМИЛКА: Проксі-з'єднання не працює. Перевірте налаштування проксі та повторіть спробу."
        echo "Відновлюємо оригінальну конфігурацію..."
        cp /etc/proxychains4.conf.backup /etc/proxychains4.conf
        exit 1
    fi
    
    # Скидаємо правила iptables
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    
    # Дозволяємо локальний трафік
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Дозволяємо встановлені зєднання
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Обов'язково дозволяємо SSH зєднання, щоб не втратити доступ
    iptables -t nat -A OUTPUT -p tcp --dport 22 -j ACCEPT
    
    # Виключаємо певні IP із проксіювання
    if [ -n "$excluded_ips" ]; then
        IFS=',' read -ra IPS <<< "$excluded_ips"
        for ip in "${IPS[@]}"; do
            iptables -t nat -A OUTPUT -d $ip -j RETURN
        done
    fi
    
    # Направляємо весь TCP трафік через проксі
    iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-port $local_port
    
    # Зберігаємо правила iptables
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    else
        echo "Встановлення netfilter-persistent для збереження правил iptables..."
        apt install -y iptables-persistent
        netfilter-persistent save
    fi
    
    # Створюємо скрипт для відновлення зєднання після перезавантаження
    echo '#!/bin/bash' > /usr/local/bin/restore-proxy-connection.sh
    echo '# Скрипт відновлення правил iptables для проксіювання' >> /usr/local/bin/restore-proxy-connection.sh
    echo 'sleep 10' >> /usr/local/bin/restore-proxy-connection.sh
    echo "iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-port $local_port" >> /usr/local/bin/restore-proxy-connection.sh
    chmod +x /usr/local/bin/restore-proxy-connection.sh
    
    # Створюємо сервіс для відновлення зєднання
    echo '[Unit]' > /etc/systemd/system/restore-proxy-connection.service
    echo 'Description=Restore Proxy Connection Rules' >> /etc/systemd/system/restore-proxy-connection.service
    echo 'After=network.target' >> /etc/systemd/system/restore-proxy-connection.service
    echo '' >> /etc/systemd/system/restore-proxy-connection.service
    echo '[Service]' >> /etc/systemd/system/restore-proxy-connection.service
    echo 'Type=oneshot' >> /etc/systemd/system/restore-proxy-connection.service
    echo 'ExecStart=/usr/local/bin/restore-proxy-connection.sh' >> /etc/systemd/system/restore-proxy-connection.service
    echo 'RemainAfterExit=true' >> /etc/systemd/system/restore-proxy-connection.service
    echo '' >> /etc/systemd/system/restore-proxy-connection.service
    echo '[Install]' >> /etc/systemd/system/restore-proxy-connection.service
    echo 'WantedBy=multi-user.target' >> /etc/systemd/system/restore-proxy-connection.service

    systemctl daemon-reload
    systemctl enable restore-proxy-connection.service
    
    # Встановлюємо socat якщо він не встановлений
    if ! command -v socat &> /dev/null; then
        echo "Встановлюємо socat..."
        apt install -y socat
    fi
    
    # Створюємо сервіс для перенаправлення
    echo '[Unit]' > /etc/systemd/system/proxychains-redirect.service
    echo 'Description=Proxychains Traffic Redirector' >> /etc/systemd/system/proxychains-redirect.service
    echo 'After=network.target' >> /etc/systemd/system/proxychains-redirect.service
    echo '' >> /etc/systemd/system/proxychains-redirect.service
    echo '[Service]' >> /etc/systemd/system/proxychains-redirect.service
    echo 'Type=simple' >> /etc/systemd/system/proxychains-redirect.service
    echo "ExecStart=/usr/bin/proxychains4 -f /etc/proxychains4.conf /usr/bin/socat TCP4-LISTEN:$local_port,fork,reuseaddr TCP4:$proxy_ip:$proxy_port" >> /etc/systemd/system/proxychains-redirect.service
    echo 'Restart=always' >> /etc/systemd/system/proxychains-redirect.service
    echo 'RestartSec=10' >> /etc/systemd/system/proxychains-redirect.service
    echo '' >> /etc/systemd/system/proxychains-redirect.service
    echo '[Install]' >> /etc/systemd/system/proxychains-redirect.service
    echo 'WantedBy=multi-user.target' >> /etc/systemd/system/proxychains-redirect.service
    
    # Активуємо і запускаємо сервіс
    systemctl daemon-reload
    systemctl enable proxychains-redirect.service
    systemctl start proxychains-redirect.service
    
    echo "Весь трафік сервера тепер проходить через $proxy_type проксі $proxy_ip:$proxy_port"
    echo "Локальний порт перенаправлення: $local_port"
    echo "Виключені IP: $excluded_ips"
    echo ""
    echo "Поточна конфігурація:"
    cat /etc/proxychains4.conf
    echo ""
    echo "Статус служби перенаправлення:"
    systemctl status proxychains-redirect.service
}

# Запит параметрів
read -p "Тип проксі (http, socks4, socks5): " proxy_type
read -p "IP Адреса проксі: " proxy_ip
read -p "Порт проксі: " proxy_port
read -p "Імя користувача проксі (залиште порожнім, якщо не потрібно): " proxy_user
read -p "Пароль для проксі (залиште порожнім, якщо не потрібно): " proxy_pass
read -p "Локальний порт для перенаправлення (наприклад, 9050): " local_port
read -p "Виключені IP (через кому, наприклад 8.8.8.8,1.1.1.1): " excluded_ips

# Запускаємо налаштування перенаправлення трафіку
setup_traffic_forwarding "$proxy_type" "$proxy_ip" "$proxy_port" "$proxy_user" "$proxy_pass" "$local_port" "$excluded_ips"

echo ""
echo "Для перевірки роботи проксі виконайте в іншій сесії:"
echo "curl -s https://ifconfig.me"
echo ""
echo "Для відновлення налаштувань виконайте:"
echo "systemctl stop proxychains-redirect.service"
echo "systemctl disable proxychains-redirect.service"
echo "systemctl disable restore-proxy-connection.service"
echo "iptables -F && iptables -t nat -F"
echo "cp /etc/proxychains4.conf.backup /etc/proxychains4.conf"
echo ""
echo "ВАЖЛИВО: Переконайтеся, що ви можете підключитися до сервера після налаштування."
echo "Якщо зєднання зникає, можливо, потрібно перевірити налаштування проксі або додати IP SSH-зєднання у виключення."
