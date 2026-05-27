#!/usr/bin/env bash
# diagnose-redis.sh
# Найти, где именно крутится открытый наружу Redis (хост / VM / LXC / Docker).
# Запускать на хосте Proxmox под root (через Web Shell или ssh).
# Никаких изменений не делает — только читает.

set -u
RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'; BLU=$'\033[0;34m'; NC=$'\033[0m'

hr() { printf '%s\n' "------------------------------------------------------------"; }
h() { printf "\n${BLU}== %s ==${NC}\n" "$1"; }
ok() { printf "${GRN}[OK]${NC} %s\n" "$*"; }
warn() { printf "${YLW}[WARN]${NC} %s\n" "$*"; }
bad() { printf "${RED}[FAIL]${NC} %s\n" "$*"; }

h "1. Кто слушает 6379/6380 на хосте Proxmox"
if command -v ss >/dev/null; then
  out=$(ss -tlnp 2>/dev/null | awk '$4 ~ /:(6379|6380)$/ {print}')
  if [ -n "$out" ]; then
    echo "$out"
    if echo "$out" | grep -qE '0\.0\.0\.0:(6379|6380)|\[::\]:(6379|6380)'; then
      bad "Redis на хосте слушает ВСЕ интерфейсы — открыт наружу"
    else
      ok "Redis на хосте слушает только локально"
    fi
  else
    ok "На хосте Proxmox процесс на 6379/6380 не найден"
  fi
else
  warn "ss не установлен, ставим: apt install -y iproute2"
fi

h "2. LXC контейнеры (pct)"
if command -v pct >/dev/null; then
  pct list 2>/dev/null | tee /tmp/_pct.list
  while read -r vmid status _; do
    [[ "$vmid" =~ ^[0-9]+$ ]] || continue
    [ "$status" = "running" ] || continue
    if pct exec "$vmid" -- ss -tlnp 2>/dev/null | grep -qE ':(6379|6380)\s'; then
      bad "LXC $vmid: внутри есть Redis"
      pct exec "$vmid" -- ss -tlnp 2>/dev/null | grep -E ':(6379|6380)\s'
    fi
  done < <(tail -n +2 /tmp/_pct.list 2>/dev/null)
else
  warn "pct не найден (LXC не используется?)"
fi

h "3. VM (qm) — список"
if command -v qm >/dev/null; then
  qm list 2>/dev/null
  warn "Внутрь VM заглянуть отсюда нельзя — нужно зайти по ssh в каждую и проверить ss -tlnp | grep 6379"
else
  warn "qm не найден"
fi

h "4. Docker контейнеры"
if command -v docker >/dev/null; then
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null | tee /tmp/_dock.ps
  if grep -qiE 'redis|6379' /tmp/_dock.ps; then
    bad "Найдены Docker-контейнеры, связанные с Redis"
    if grep -qE '0\.0\.0\.0:(6379|6380)' /tmp/_dock.ps; then
      bad "Один из них пробросил 6379 на 0.0.0.0 — это и есть открытый Redis"
    fi
  fi
else
  warn "Docker не установлен на хосте"
fi

h "5. Внешние подключения к Redis (если процесс есть)"
if command -v ss >/dev/null; then
  ext=$(ss -tnp 2>/dev/null | awk '$4 ~ /:(6379|6380)$/ && $5 !~ /^(127\.|::1|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/ {print}')
  if [ -n "$ext" ]; then
    bad "Активные внешние подключения к Redis:"
    echo "$ext"
  else
    ok "Внешних подключений к Redis сейчас не вижу"
  fi
fi

h "6. Firewall хоста"
echo "--- iptables INPUT (top 20) ---"
iptables -L INPUT -n -v --line-numbers 2>/dev/null | head -20
echo
echo "--- nftables (если используется) ---"
nft list ruleset 2>/dev/null | grep -E '(chain input|6379|6380)' | head -20 || true
echo
echo "--- UFW ---"
ufw status 2>/dev/null || echo "UFW не установлен"
echo
echo "--- Proxmox cluster firewall ---"
cat /etc/pve/firewall/cluster.fw 2>/dev/null || echo "(не настроен)"

h "7. Что слушает на внешнем IP — общий обзор"
ip -4 addr show | awk '/inet / && $NF != "lo" {print "  Интерфейс:", $NF, "IP:", $2}'
echo
echo "Все TCP-сокеты на 0.0.0.0 (открыты наружу):"
ss -tlnp 2>/dev/null | awk '$4 ~ /^(0\.0\.0\.0|\[::\]):/ {print}'

hr
echo "Готово. Скопируйте вывод и пришлите мне — я скажу, что закрывать."
