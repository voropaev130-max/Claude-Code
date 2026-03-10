# ============================================================
#  Claude Code — Автоматичний інсталятор для Windows
#  Версія: 1.0
# ============================================================
#
#  ЯК ЗАПУСТИТИ:
#  1. Натисніть правою кнопкою на цей файл
#  2. Оберіть "Запустити з PowerShell" (Run with PowerShell)
#  -- АБО --
#  1. Відкрийте PowerShell від імені адміністратора
#  2. Виконайте: Set-ExecutionPolicy Bypass -Scope Process -Force
#  3. Виконайте: .\install-claude-code.ps1
#
# ============================================================

# --- Кольоровий вивід ---
function Write-Step {
    param([string]$Step, [string]$Message)
    Write-Host ""
    Write-Host "  [$Step] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message -ForegroundColor White
    Write-Host "  $('─' * 50)" -ForegroundColor DarkGray
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  ⚠ $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  → $Message" -ForegroundColor Gray
}

# --- Перевірка прав адміністратора ---
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================
#  СТАРТ
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║                                              ║" -ForegroundColor Cyan
Write-Host "  ║   Claude Code — Автоматичне встановлення     ║" -ForegroundColor Cyan
Write-Host "  ║                                              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# --- Перевірка прав ---
if (-not (Test-Administrator)) {
    Write-Warn "Скрипт запущено БЕЗ прав адміністратора."
    Write-Warn "Деякі дії можуть не працювати."
    Write-Host ""
    $response = Read-Host "  Продовжити все одно? (y/n)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Info "Перезапустіть PowerShell від імені адміністратора."
        Write-Info "Win + X → Terminal (Admin)"
        Read-Host "  Натисніть Enter для виходу"
        exit 1
    }
}

# ============================================================
#  КРОК 1: Перевірка / встановлення Node.js
# ============================================================
Write-Step "1/4" "Перевірка Node.js..."

$nodeInstalled = $false
$nodeVersion = $null

try {
    $nodeVersion = & node --version 2>$null
    if ($nodeVersion) {
        $versionNumber = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
        if ($versionNumber -ge 18) {
            Write-Ok "Node.js вже встановлено: $nodeVersion"
            $nodeInstalled = $true
        } else {
            Write-Warn "Node.js застарілий ($nodeVersion). Потрібна версія 18+."
        }
    }
} catch {
    # Node.js не знайдено
}

if (-not $nodeInstalled) {
    Write-Info "Завантажуємо Node.js LTS..."

    $nodeInstallerUrl = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
    $nodeInstallerPath = "$env:TEMP\nodejs-installer.msi"

    try {
        # Завантаження
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($nodeInstallerUrl, $nodeInstallerPath)
        Write-Ok "Node.js завантажено"

        # Встановлення
        Write-Info "Встановлюємо Node.js (це може зайняти 1-2 хвилини)..."
        $process = Start-Process msiexec.exe -ArgumentList "/i `"$nodeInstallerPath`" /qn /norestart" -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            # Оновлюємо PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            $nodeVersion = & node --version 2>$null
            if ($nodeVersion) {
                Write-Ok "Node.js встановлено: $nodeVersion"
                $nodeInstalled = $true
            } else {
                Write-Warn "Node.js встановлено, але потрібно перезавантажити комп'ютер."
                Write-Warn "Після перезавантаження запустіть цей скрипт ще раз."
            }
        } else {
            Write-Fail "Помилка встановлення Node.js (код: $($process.ExitCode))"
            Write-Info "Спробуйте встановити вручну: https://nodejs.org/"
        }

        # Видаляємо інсталятор
        Remove-Item $nodeInstallerPath -Force -ErrorAction SilentlyContinue

    } catch {
        Write-Fail "Не вдалось завантажити Node.js: $_"
        Write-Info "Встановіть вручну: https://nodejs.org/"
        Write-Info "Після встановлення запустіть цей скрипт ще раз."
        Read-Host "  Натисніть Enter для виходу"
        exit 1
    }
}

if (-not $nodeInstalled) {
    Write-Fail "Node.js не встановлено. Перезавантажте комп'ютер і запустіть скрипт ще раз."
    Read-Host "  Натисніть Enter для виходу"
    exit 1
}

# ============================================================
#  КРОК 2: Встановлення Claude Code
# ============================================================
Write-Step "2/4" "Встановлення Claude Code..."

$claudeInstalled = $false

try {
    $claudeVersion = & claude --version 2>$null
    if ($claudeVersion) {
        Write-Ok "Claude Code вже встановлено: $claudeVersion"
        $claudeInstalled = $true
    }
} catch {
    # Claude Code не знайдено
}

if (-not $claudeInstalled) {
    Write-Info "Встановлюємо Claude Code через npm..."

    try {
        $npmOutput = & npm install -g @anthropic-ai/claude-code 2>&1

        # Перевіряємо
        $claudeVersion = & claude --version 2>$null
        if ($claudeVersion) {
            Write-Ok "Claude Code встановлено: $claudeVersion"
            $claudeInstalled = $true
        } else {
            # Можливо потрібно оновити PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $npmGlobalPath = & npm config get prefix 2>$null
            if ($npmGlobalPath) {
                $env:Path += ";$npmGlobalPath"
            }

            $claudeVersion = & claude --version 2>$null
            if ($claudeVersion) {
                Write-Ok "Claude Code встановлено: $claudeVersion"
                $claudeInstalled = $true
            } else {
                Write-Fail "Claude Code встановлено, але команда 'claude' не знайдена."
                Write-Warn "Перезавантажте комп'ютер і спробуйте: claude --version"
            }
        }
    } catch {
        Write-Fail "Помилка встановлення: $_"
        Write-Info "Спробуйте вручну: npm install -g @anthropic-ai/claude-code"
    }
}

# ============================================================
#  КРОК 3: Створення робочих папок
# ============================================================
Write-Step "3/4" "Створення робочих папок..."

$projectsDir = Join-Path $HOME "claude-projects"
$sandboxDir = Join-Path $projectsDir "sandbox"

if (Test-Path $projectsDir) {
    Write-Ok "Папка claude-projects вже існує: $projectsDir"
} else {
    New-Item -ItemType Directory -Path $projectsDir -Force | Out-Null
    Write-Ok "Створено: $projectsDir"
}

if (Test-Path $sandboxDir) {
    Write-Ok "Папка sandbox вже існує: $sandboxDir"
} else {
    New-Item -ItemType Directory -Path $sandboxDir -Force | Out-Null
    Write-Ok "Створено: $sandboxDir"
}

# ============================================================
#  КРОК 4: Підсумок
# ============================================================
Write-Step "4/4" "Перевірка результатів..."

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║           РЕЗУЛЬТАТИ ВСТАНОВЛЕННЯ            ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Node.js
$nodeCheck = & node --version 2>$null
if ($nodeCheck) {
    Write-Ok "Node.js:      $nodeCheck"
} else {
    Write-Fail "Node.js:      не знайдено"
}

# npm
$npmCheck = & npm --version 2>$null
if ($npmCheck) {
    Write-Ok "npm:          v$npmCheck"
} else {
    Write-Fail "npm:          не знайдено"
}

# Claude Code
$claudeCheck = & claude --version 2>$null
if ($claudeCheck) {
    Write-Ok "Claude Code:  $claudeCheck"
} else {
    Write-Fail "Claude Code:  не знайдено"
}

# Папки
if (Test-Path $projectsDir) {
    Write-Ok "Папки:        $projectsDir"
} else {
    Write-Fail "Папки:        не створено"
}

Write-Host ""
Write-Host "  ─────────────────────────────────────────────" -ForegroundColor DarkGray

if ($claudeInstalled) {
    Write-Host ""
    Write-Host "  ЩО ДАЛІ:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Переконайтесь, що у вас є підписка Pro на claude.ai" -ForegroundColor White
    Write-Host "     (якщо немає — оформіть за \$20/міс)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Запустіть Claude Code:" -ForegroundColor White
    Write-Host "     cd $sandboxDir" -ForegroundColor Cyan
    Write-Host "     claude" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. У браузері увійдіть в акаунт та натисніть 'Allow'" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Warn "Встановлення не завершено повністю."
    Write-Warn "Перезавантажте комп'ютер і запустіть скрипт ще раз."
    Write-Host ""
}

Read-Host "  Натисніть Enter для виходу"
