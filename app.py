"""
NMIACM TODO Tracker — Flask Backend
Серверное приложение с REST API для управления задачами.

Запуск:
    pip install flask flask-cors python-dotenv
    python app.py

Авторизация:
    POST-запросы требуют заголовок: X-API-Key: <ключ из .env>
    GET-запросы (чтение) — открытые, без ключа.

API Endpoints:
    GET  /                     — Главная страница (HTML трекер)
    GET  /api/tasks            — Получить все задачи и состояние
    POST /api/tasks/toggle     — Переключить статус задачи        [API KEY]
    POST /api/tasks/reset      — Сбросить весь прогресс            [API KEY]
    POST /api/reload-tasks     — Перезагрузить задачи              [API KEY]
    GET  /api/stats            — Статистика прогресса
    POST /api/tasks/bulk-update — Массовое обновление задач        [API KEY]
"""

import json
import os
from datetime import datetime
from functools import wraps
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

app = Flask(__name__, static_folder="static")
CORS(app)

# ─── API Key ──────────────────────────────────────────────

# Load from .env file or environment variable
_env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
if os.path.exists(_env_path):
    with open(_env_path) as _f:
        for _line in _f:
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _k, _v = _line.split("=", 1)
                os.environ.setdefault(_k.strip(), _v.strip())

API_KEY = os.environ.get("NMIACM_API_KEY", "")

if not API_KEY:
    print("WARNING: NMIACM_API_KEY not set! POST endpoints will reject all requests.")
    print("Create a .env file with: NMIACM_API_KEY=your-secret-key")


def require_api_key(f):
    """Decorator: require valid API key for POST endpoints."""
    @wraps(f)
    def decorated(*args, **kwargs):
        key = request.headers.get("X-API-Key", "")
        if not API_KEY:
            return jsonify({"error": "Server API key not configured"}), 500
        if not key or key != API_KEY:
            return jsonify({"error": "Invalid or missing API key", "hint": "Send header X-API-Key"}), 403
        return f(*args, **kwargs)
    return decorated


STATE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "todo_state.json")


def load_state():
    """Загрузить состояние из JSON файла."""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return default_state()


def save_state(state):
    """Сохранить состояние в JSON файл."""
    state["last_updated"] = datetime.now().isoformat()
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def default_state():
    """Состояние по умолчанию со всеми фазами и задачами."""
    return {
        "last_updated": datetime.now().isoformat(),
        "checked": {},
        "open_phases": {},
        "phases": [
            {
                "id": "phase1",
                "title": "Фаза 1 — Подготовка и анализ",
                "icon": "🔍",
                "color": "purple",
                "stages": [
                    {
                        "name": "Анализ текущего состояния",
                        "tasks": [
                            "Провести аудит существующих процессов",
                            "Составить карту текущих workflow",
                            "Определить болевые точки и узкие места",
                            "Провести интервью с командой (5+ человек)",
                            "Собрать метрики текущей производительности",
                            "Документировать существующие инструменты и стек",
                        ],
                    },
                    {
                        "name": "Планирование внедрения",
                        "tasks": [
                            "Определить цели и KPI для внедрения",
                            "Составить дорожную карту на 3 месяца",
                            "Выделить бюджет и ресурсы",
                            "Назначить ответственных за каждый этап",
                            "Подготовить план коммуникации с командой",
                        ],
                    },
                ],
            },
            {
                "id": "phase2",
                "title": "Фаза 2 — Настройка инфраструктуры",
                "icon": "⚙️",
                "color": "pink",
                "stages": [
                    {
                        "name": "Техническая подготовка",
                        "tasks": [
                            "Настроить систему контроля версий (Git)",
                            "Развернуть CI/CD пайплайн",
                            "Настроить автоматическое тестирование",
                            "Подготовить staging-окружение",
                            "Настроить мониторинг и алертинг",
                            "Внедрить линтеры и форматтеры кода",
                        ],
                    },
                    {
                        "name": "Инструменты коммуникации",
                        "tasks": [
                            "Настроить каналы в мессенджере для команды",
                            "Внедрить систему управления задачами",
                            "Настроить базу знаний / wiki",
                            "Создать шаблоны для задач и багов",
                        ],
                    },
                ],
            },
            {
                "id": "phase3",
                "title": "Фаза 3 — Процессы и стандарты",
                "icon": "📋",
                "color": "green",
                "stages": [
                    {
                        "name": "Стандарты разработки",
                        "tasks": [
                            "Написать coding guidelines",
                            "Определить стратегию ветвления (branching strategy)",
                            "Стандартизировать формат коммитов",
                            "Создать шаблоны для code review",
                            "Определить Definition of Done",
                            "Внедрить парное программирование (pair programming)",
                        ],
                    },
                    {
                        "name": "Процессы управления",
                        "tasks": [
                            "Внедрить ежедневные стендапы",
                            "Настроить спринт-планирование",
                            "Ввести ретроспективы каждые 2 недели",
                            "Создать процесс приоритизации задач",
                            "Определить SLA для разных типов задач",
                        ],
                    },
                ],
            },
            {
                "id": "phase4",
                "title": "Фаза 4 — Обучение команды",
                "icon": "🎓",
                "color": "orange",
                "stages": [
                    {
                        "name": "Подготовка материалов",
                        "tasks": [
                            "Создать обучающие материалы по методологии",
                            "Записать видео-туториалы (3+ штуки)",
                            "Подготовить практические задания",
                            "Составить FAQ по частым вопросам",
                        ],
                    },
                    {
                        "name": "Проведение обучения",
                        "tasks": [
                            "Провести вводный воркшоп для всей команды",
                            "Провести практические сессии по группам",
                            "Назначить менторов для новичков",
                            "Организовать Q&A сессии",
                            "Оценить уровень усвоения материала",
                        ],
                    },
                ],
            },
            {
                "id": "phase5",
                "title": "Фаза 5 — Пилотный запуск",
                "icon": "🚀",
                "color": "cyan",
                "stages": [
                    {
                        "name": "Пилотный проект",
                        "tasks": [
                            "Выбрать пилотный проект для внедрения",
                            "Сформировать пилотную команду (3-5 человек)",
                            "Применить все процессы на пилотном проекте",
                            "Собирать обратную связь ежедневно",
                            "Фиксировать проблемы и блокеры",
                            "Адаптировать процессы на основе фидбека",
                        ],
                    },
                    {
                        "name": "Оценка результатов пилота",
                        "tasks": [
                            "Сравнить метрики до/после внедрения",
                            "Провести ретроспективу пилотного проекта",
                            "Подготовить отчёт с выводами",
                            "Определить необходимые корректировки",
                        ],
                    },
                ],
            },
            {
                "id": "phase6",
                "title": "Фаза 6 — Масштабирование",
                "icon": "📈",
                "color": "red",
                "stages": [
                    {
                        "name": "Расширение на всю команду",
                        "tasks": [
                            "Разработать план поэтапного масштабирования",
                            "Внедрить процессы в следующую команду/проект",
                            "Настроить кросс-командную синхронизацию",
                            "Автоматизировать повторяющиеся процессы",
                            "Обновить документацию по результатам пилота",
                        ],
                    }
                ],
            },
            {
                "id": "phase7",
                "title": "Фаза 7 — Мониторинг и улучшение",
                "icon": "🔄",
                "color": "teal",
                "stages": [
                    {
                        "name": "Непрерывное улучшение",
                        "tasks": [
                            "Настроить дашборд с метриками эффективности",
                            "Проводить ежемесячные обзоры процессов",
                            "Собирать и анализировать обратную связь",
                            "Внедрять улучшения итеративно",
                            "Документировать извлечённые уроки (lessons learned)",
                            "Отмечать успехи и достижения команды",
                        ],
                    }
                ],
            },
        ],
    }


# ─── Routes ───────────────────────────────────────────────


@app.route("/")
def index():
    """Отдать главную HTML страницу."""
    return send_from_directory(".", "TODO_NMIACM_TRACKER.html")


@app.route("/api/tasks", methods=["GET"])
def get_tasks():
    """Получить полное состояние трекера."""
    state = load_state()
    return jsonify(state)


@app.route("/api/tasks/toggle", methods=["POST"])
@require_api_key
def toggle_task():
    """Переключить статус задачи.

    Body JSON: {"task_id": "phase1_Анализ текущего состояния_0"}
    """
    data = request.get_json()
    task_id = data.get("task_id")
    if not task_id:
        return jsonify({"error": "task_id is required"}), 400

    state = load_state()
    current = state.get("checked", {}).get(task_id, False)
    state.setdefault("checked", {})[task_id] = not current
    save_state(state)
    return jsonify({"task_id": task_id, "checked": not current})


@app.route("/api/tasks/reset", methods=["POST"])
@require_api_key
def reset_tasks():
    """Сбросить весь прогресс (галочки)."""
    state = load_state()
    state["checked"] = {}
    save_state(state)
    return jsonify({"status": "reset", "message": "Прогресс сброшен"})


@app.route("/api/reload-tasks", methods=["POST"])
@require_api_key
def reload_tasks():
    """Перезагрузить задачи — сбрасывает к дефолтному состоянию
    или загружает из переданного JSON body.

    Без body: сбросить к дефолту (все 67 задач, прогресс обнулён).
    С body JSON: загрузить переданное состояние целиком.
    """
    if request.content_length and request.content_length > 0:
        try:
            new_state = request.get_json()
            if new_state and isinstance(new_state, dict) and "phases" in new_state:
                save_state(new_state)
                return jsonify({"status": "reloaded", "message": "Задачи обновлены из запроса"})
        except Exception:
            pass

    state = default_state()
    save_state(state)
    return jsonify({"status": "reloaded", "message": "Задачи сброшены к дефолту"})


@app.route("/api/stats", methods=["GET"])
def get_stats():
    """Получить статистику прогресса."""
    state = load_state()
    checked = state.get("checked", {})
    phases = state.get("phases", [])

    total = 0
    done = 0
    current_phase = None
    phase_stats = []

    for phase in phases:
        pt, pd = 0, 0
        for stage in phase.get("stages", []):
            for ti, _task in enumerate(stage.get("tasks", [])):
                task_id = f"{phase['id']}_{stage['name']}_{ti}"
                pt += 1
                total += 1
                if checked.get(task_id, False):
                    pd += 1
                    done += 1
        pct = round(pd / pt * 100) if pt else 0
        phase_stats.append({
            "id": phase["id"],
            "title": phase["title"],
            "total": pt,
            "done": pd,
            "percent": pct,
        })
        if pct < 100 and current_phase is None:
            current_phase = phase["title"]

    pct_global = round(done / total * 100) if total else 0

    return jsonify({
        "total": total,
        "done": done,
        "percent": pct_global,
        "current_phase": current_phase or "Все выполнено!",
        "phases": phase_stats,
        "last_updated": state.get("last_updated"),
    })


@app.route("/api/tasks/bulk-update", methods=["POST"])
@require_api_key
def bulk_update():
    """Массовое обновление задач — для удалённого управления.

    Body JSON: {"checked": {"phase1_Анализ текущего состояния_0": true, ...}}
    Можно передавать частичное обновление — только изменённые задачи.
    """
    data = request.get_json()
    updates = data.get("checked", {})
    if not isinstance(updates, dict):
        return jsonify({"error": "checked must be a dict"}), 400

    state = load_state()
    state.setdefault("checked", {}).update(updates)
    save_state(state)

    return jsonify({
        "status": "updated",
        "updated_count": len(updates),
        "message": f"Обновлено {len(updates)} задач",
    })


# ─── Init ─────────────────────────────────────────────────

if not os.path.exists(STATE_FILE):
    save_state(default_state())

if __name__ == "__main__":
    print("=" * 50)
    print("  NMIACM TODO Tracker")
    print("  http://0.0.0.0:5000")
    print("  API Key: " + ("configured" if API_KEY else "NOT SET!"))
    print("=" * 50)
    app.run(host="0.0.0.0", port=5000, debug=True)
