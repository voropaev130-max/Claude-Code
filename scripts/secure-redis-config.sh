#!/usr/bin/env bash
# secure-redis-config.sh
# Правильно конфигурирует САМ Redis: bind на localhost, пароль, protected mode.
# Запускать ВНУТРИ той VM/LXC/контейнера, где работает Redis (не на хосте Proxmox).
#
# Использование:
#   sudo bash secure-redis-config.sh                       # автогенерация пароля
#   sudo REDIS_PASS='мой_пароль' bash secure-redis-config.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Запускать под root (sudo)" >&2; exit 1
fi

CONF=""
for f in /etc/redis/redis.conf /etc/redis.conf /usr/local/etc/redis.conf; do
  [ -f "$f" ] && CONF="$f" && break
done
if [ -z "$CONF" ]; then
  echo "redis.conf не найден" >&2; exit 1
fi
echo "[i] Конфиг: $CONF"

# Бэкап один раз
BAK="${CONF}.bak.$(date +%s)"
cp -n "$CONF" "$BAK"
echo "[i] Бэкап: $BAK"

# Генерация пароля если не передан
if [ -z "${REDIS_PASS:-}" ]; then
  REDIS_PASS="$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 40)"
  echo "[i] Сгенерирован пароль (сохраните!): $REDIS_PASS"
fi

# bind на локалхост
sed -i -E 's/^[# ]*bind .*/bind 127.0.0.1 ::1/' "$CONF"
grep -qE '^bind ' "$CONF" || echo 'bind 127.0.0.1 ::1' >> "$CONF"

# protected-mode yes
sed -i -E 's/^[# ]*protected-mode .*/protected-mode yes/' "$CONF"
grep -qE '^protected-mode ' "$CONF" || echo 'protected-mode yes' >> "$CONF"

# requirepass
if grep -qE '^[# ]*requirepass ' "$CONF"; then
  sed -i -E "s|^[# ]*requirepass .*|requirepass ${REDIS_PASS}|" "$CONF"
else
  echo "requirepass ${REDIS_PASS}" >> "$CONF"
fi

# Отключаем опасные команды (защита от RCE через CONFIG SET dir)
for cmd in CONFIG FLUSHALL FLUSHDB DEBUG SHUTDOWN EVAL; do
  grep -qE "^rename-command ${cmd} " "$CONF" || echo "rename-command ${cmd} \"\"" >> "$CONF"
done

echo "[i] Перезапускаем Redis..."
if systemctl list-units --type=service | grep -qE 'redis-server\.service'; then
  systemctl restart redis-server
elif systemctl list-units --type=service | grep -qE 'redis\.service'; then
  systemctl restart redis
else
  echo "[!] Не найден systemd-юнит Redis. Перезапустите вручную."
fi

echo
echo "=== Проверка ==="
echo "Bind должен быть только локальный:"
ss -tlnp 2>/dev/null | grep -E ':(6379|6380)\s' || echo "(порт не слушается)"
echo
echo "Пинг с паролем должен работать:"
redis-cli -a "$REDIS_PASS" --no-auth-warning ping 2>&1 || echo "(не отвечает)"
echo
echo "Готово. Пароль: $REDIS_PASS"
echo "Сохраните его в безопасном месте (1Password / pass / vault)."
