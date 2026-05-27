#!/usr/bin/env bash
# fix-redis-firewall.sh
# Закрывает порты Redis (6379, 6380) на внешнем интерфейсе хоста Proxmox.
# Безопасно: НЕ трогает сам Redis, НЕ удаляет данные, только режет внешний трафик.
# Внутри VM/LXC Redis продолжит работать как был.
#
# Запускать на хосте Proxmox под root.
# Откатить можно: iptables -D INPUT <правило> или скрипт unfix-redis-firewall.sh

set -euo pipefail

PORTS=(6379 6380)
EXT_IF="${EXT_IF:-vmbr0}"   # внешний бридж Proxmox по умолчанию
DRY="${DRY_RUN:-0}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Запускать под root" >&2; exit 1
fi

run() {
  echo "+ $*"
  [ "$DRY" = "1" ] || "$@"
}

echo "=== Текущие правила (до) ==="
iptables -L INPUT -n -v --line-numbers | head -20

for p in "${PORTS[@]}"; do
  if iptables -C INPUT -i "$EXT_IF" -p tcp --dport "$p" -j DROP 2>/dev/null; then
    echo "[skip] DROP для порта $p уже есть"
  else
    run iptables -I INPUT 1 -i "$EXT_IF" -p tcp --dport "$p" -j DROP
  fi
done

# Разрешаем доступ изнутри хоста и из приватных сетей
for p in "${PORTS[@]}"; do
  run iptables -I INPUT 1 -s 127.0.0.0/8 -p tcp --dport "$p" -j ACCEPT
  run iptables -I INPUT 1 -s 10.0.0.0/8 -p tcp --dport "$p" -j ACCEPT
  run iptables -I INPUT 1 -s 172.16.0.0/12 -p tcp --dport "$p" -j ACCEPT
  run iptables -I INPUT 1 -s 192.168.0.0/16 -p tcp --dport "$p" -j ACCEPT
done

echo
echo "=== Текущие правила (после) ==="
iptables -L INPUT -n -v --line-numbers | head -30

echo
echo "=== Сохраняем правила ==="
if ! command -v iptables-save >/dev/null; then
  run apt-get update
  run apt-get install -y iptables-persistent
fi
mkdir -p /etc/iptables
run sh -c 'iptables-save > /etc/iptables/rules.v4'
echo "Сохранено в /etc/iptables/rules.v4"

echo
echo "Готово. Теперь снаружи 6379/6380 должны быть закрыты, изнутри — работают."
echo "Проверка снаружи: nc -zv 95.216.76.51 6379  → connection refused/timed out"
