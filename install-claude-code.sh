#!/bin/bash
# ============================================================
#  Claude Code — Автоматичний інсталятор для macOS / Linux
#  Версія: 1.0
# ============================================================
#
#  ЯК ЗАПУСТИТИ:
#  1. Відкрийте Terminal
#  2. Перейдіть в папку з файлом:  cd ~/Downloads
#  3. Дайте права на виконання:    chmod +x install-claude-code.sh
#  4. Запустіть:                   ./install-claude-code.sh
#
# ============================================================

set -e

# --- Кольори ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

step() {
    echo ""
    echo -e "  ${CYAN}[$1]${NC} ${WHITE}$2${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────────${NC}"
}

ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
}

info() {
    echo -e "  ${GRAY}→${NC} $1"
}

# --- Визначення ОС ---
detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

OS=$(detect_os)

# ============================================================
#  СТАРТ
# ============================================================
clear
echo ""
echo -e "  ${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "  ${CYAN}║                                              ║${NC}"
echo -e "  ${CYAN}║   Claude Code — Автоматичне встановлення     ║${NC}"
echo -e "  ${CYAN}║                                              ║${NC}"
echo -e "  ${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

if [ "$OS" = "macos" ]; then
    info "Виявлено: macOS"
elif [ "$OS" = "linux" ]; then
    info "Виявлено: Linux"
else
    warn "Невідома ОС. Скрипт може працювати некоректно."
fi

# ============================================================
#  КРОК 1: Перевірка / встановлення Node.js
# ============================================================
step "1/4" "Перевірка Node.js..."

NODE_INSTALLED=false

if command -v node &> /dev/null; then
    NODE_VER=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')

    if [ "$NODE_MAJOR" -ge 18 ]; then
        ok "Node.js вже встановлено: $NODE_VER"
        NODE_INSTALLED=true
    else
        warn "Node.js застарілий ($NODE_VER). Потрібна версія 18+."
    fi
fi

if [ "$NODE_INSTALLED" = false ]; then
    info "Встановлюємо Node.js..."

    if [ "$OS" = "macos" ]; then
        # macOS: через Homebrew
        if command -v brew &> /dev/null; then
            info "Homebrew знайдено. Встановлюємо Node.js..."
            brew install node
        else
            info "Homebrew не знайдено. Встановлюємо Homebrew спочатку..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Додаємо Homebrew до PATH (для Apple Silicon)
            if [ -f /opt/homebrew/bin/brew ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi

            info "Тепер встановлюємо Node.js..."
            brew install node
        fi

    elif [ "$OS" = "linux" ]; then
        # Linux: через NodeSource
        if command -v apt-get &> /dev/null; then
            info "Встановлюємо через apt (Ubuntu/Debian)..."
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command -v dnf &> /dev/null; then
            info "Встановлюємо через dnf (Fedora/RHEL)..."
            curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
            sudo dnf install -y nodejs
        elif command -v yum &> /dev/null; then
            info "Встановлюємо через yum (CentOS)..."
            curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
            sudo yum install -y nodejs
        else
            fail "Не вдалось визначити пакетний менеджер."
            info "Встановіть Node.js вручну: https://nodejs.org/"
            exit 1
        fi
    fi

    # Перевіряємо
    if command -v node &> /dev/null; then
        NODE_VER=$(node --version)
        ok "Node.js встановлено: $NODE_VER"
        NODE_INSTALLED=true
    else
        fail "Не вдалось встановити Node.js."
        info "Встановіть вручну: https://nodejs.org/"
        exit 1
    fi
fi

# ============================================================
#  КРОК 2: Встановлення Claude Code
# ============================================================
step "2/4" "Встановлення Claude Code..."

CLAUDE_INSTALLED=false

if command -v claude &> /dev/null; then
    CLAUDE_VER=$(claude --version 2>/dev/null || echo "")
    if [ -n "$CLAUDE_VER" ]; then
        ok "Claude Code вже встановлено: $CLAUDE_VER"
        CLAUDE_INSTALLED=true
    fi
fi

if [ "$CLAUDE_INSTALLED" = false ]; then
    info "Встановлюємо Claude Code через npm..."

    # Спробуємо без sudo спочатку
    if npm install -g @anthropic-ai/claude-code 2>/dev/null; then
        ok "Claude Code встановлено"
    else
        info "Потрібні права адміністратора (sudo)..."
        sudo npm install -g @anthropic-ai/claude-code
        ok "Claude Code встановлено"
    fi

    # Перевіряємо
    if command -v claude &> /dev/null; then
        CLAUDE_VER=$(claude --version 2>/dev/null || echo "встановлено")
        ok "Claude Code: $CLAUDE_VER"
        CLAUDE_INSTALLED=true
    else
        fail "Команда 'claude' не знайдена після встановлення."
        warn "Спробуйте закрити та відкрити термінал заново."
    fi
fi

# ============================================================
#  КРОК 3: Створення робочих папок
# ============================================================
step "3/4" "Створення робочих папок..."

PROJECTS_DIR="$HOME/claude-projects"
SANDBOX_DIR="$PROJECTS_DIR/sandbox"

if [ -d "$PROJECTS_DIR" ]; then
    ok "Папка claude-projects вже існує: $PROJECTS_DIR"
else
    mkdir -p "$PROJECTS_DIR"
    ok "Створено: $PROJECTS_DIR"
fi

if [ -d "$SANDBOX_DIR" ]; then
    ok "Папка sandbox вже існує: $SANDBOX_DIR"
else
    mkdir -p "$SANDBOX_DIR"
    ok "Створено: $SANDBOX_DIR"
fi

# ============================================================
#  КРОК 4: Підсумок
# ============================================================
step "4/4" "Перевірка результатів..."

echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "  ${GREEN}║           РЕЗУЛЬТАТИ ВСТАНОВЛЕННЯ            ║${NC}"
echo -e "  ${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Node.js
NODE_CHECK=$(node --version 2>/dev/null || echo "")
if [ -n "$NODE_CHECK" ]; then
    ok "Node.js:      $NODE_CHECK"
else
    fail "Node.js:      не знайдено"
fi

# npm
NPM_CHECK=$(npm --version 2>/dev/null || echo "")
if [ -n "$NPM_CHECK" ]; then
    ok "npm:          v$NPM_CHECK"
else
    fail "npm:          не знайдено"
fi

# Claude Code
CLAUDE_CHECK=$(claude --version 2>/dev/null || echo "")
if [ -n "$CLAUDE_CHECK" ]; then
    ok "Claude Code:  $CLAUDE_CHECK"
else
    fail "Claude Code:  не знайдено"
fi

# Папки
if [ -d "$PROJECTS_DIR" ]; then
    ok "Папки:        $PROJECTS_DIR"
else
    fail "Папки:        не створено"
fi

echo ""
echo -e "  ${GRAY}─────────────────────────────────────────────${NC}"

if [ "$CLAUDE_INSTALLED" = true ]; then
    echo ""
    echo -e "  ${YELLOW}ЩО ДАЛІ:${NC}"
    echo ""
    echo -e "  ${WHITE}1. Переконайтесь, що у вас є підписка Pro на claude.ai${NC}"
    echo -e "  ${GRAY}   (якщо немає — оформіть за \$20/міс)${NC}"
    echo ""
    echo -e "  ${WHITE}2. Запустіть Claude Code:${NC}"
    echo -e "  ${CYAN}   cd $SANDBOX_DIR${NC}"
    echo -e "  ${CYAN}   claude${NC}"
    echo ""
    echo -e "  ${WHITE}3. У браузері увійдіть в акаунт та натисніть 'Allow'${NC}"
    echo ""
else
    echo ""
    warn "Встановлення не завершено повністю."
    warn "Закрийте термінал, відкрийте заново і запустіть скрипт ще раз."
    echo ""
fi

echo -e "  ${GRAY}Натисніть Enter для виходу...${NC}"
read -r
