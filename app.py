"""
NMIACM TODO Tracker — Flask Backend
Серверное приложение с REST API для управления задачами.

Запуск:
    pip install flask flask-cors
    python app.py

API Endpoints:
    GET  /                     — Главная страница (HTML трекер)
    GET  /api/tasks            — Получить все задачи и состояние
    POST /api/tasks/toggle     — Переключить статус задачи
    POST /api/tasks/reset      — Сбросить весь прогресс
    POST /api/reload-tasks     — Перезагрузить задачи из todo_state.json
    GET  /api/stats            — Статистика прогресса
    POST /api/tasks/bulk-update — Массовое обновление задач (для удалённого управления)
    GET  /api/audio/status     — Проверить доступность аудио транскрипции
    POST /api/audio/transcribe — Транскрибировать аудиофайл в текст
"""

import json
import os
import shutil
import tempfile
from datetime import datetime
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

# Audio transcription imports (optional — graceful degradation if missing)
_audio_available = False
_audio_missing_reason = ""
try:
    import speech_recognition as sr
    from pydub import AudioSegment

    if not shutil.which("flac"):
        _audio_missing_reason = (
            "FLAC codec not found. Install it: sudo apt-get install flac"
        )
    else:
        _audio_available = True
except ImportError as e:
    _audio_missing_reason = (
        f"Missing Python package: {e.name}. "
        "Install with: pip install SpeechRecognition pydub"
    )

app = Flask(__name__, static_folder="static")
CORS(app)

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
def reset_tasks():
    """Сбросить весь прогресс (галочки)."""
    state = load_state()
    state["checked"] = {}
    save_state(state)
    return jsonify({"status": "reset", "message": "Прогресс сброшен"})


@app.route("/api/reload-tasks", methods=["POST"])
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


# ─── Audio Transcription ─────────────────────────────────


@app.route("/api/audio/status", methods=["GET"])
def audio_status():
    """Check if audio transcription is available."""
    return jsonify({
        "available": _audio_available,
        "reason": _audio_missing_reason if not _audio_available else "ok",
    })


@app.route("/api/audio/transcribe", methods=["POST"])
def transcribe_audio():
    """Transcribe an uploaded audio file to text.

    Accepts multipart/form-data with field 'audio' containing the file.
    Supported formats: wav, mp3, ogg, flac, webm, m4a.
    Optional query param: lang (default "ru-RU").
    """
    if not _audio_available:
        return jsonify({
            "error": "Audio transcription is not available",
            "reason": _audio_missing_reason,
            "fix": "pip install SpeechRecognition pydub && sudo apt-get install flac",
        }), 503

    if "audio" not in request.files:
        return jsonify({"error": "No 'audio' file in request"}), 400

    audio_file = request.files["audio"]
    if audio_file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    lang = request.args.get("lang", "ru-RU")

    tmp_wav = None
    try:
        # Save uploaded file to a temp location
        suffix = os.path.splitext(audio_file.filename)[1].lower() or ".wav"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            audio_file.save(tmp)
            tmp_path = tmp.name

        # Convert to WAV if necessary (pydub handles format detection)
        if suffix != ".wav":
            audio = AudioSegment.from_file(tmp_path)
            tmp_wav = tmp_path + ".wav"
            audio.export(tmp_wav, format="wav")
        else:
            tmp_wav = tmp_path
            tmp_path = None  # don't double-delete

        # Transcribe using Google Speech Recognition (free, no API key)
        recognizer = sr.Recognizer()
        with sr.AudioFile(tmp_wav) as source:
            audio_data = recognizer.record(source)

        text = recognizer.recognize_google(audio_data, language=lang)

        return jsonify({
            "text": text,
            "lang": lang,
            "status": "ok",
        })

    except sr.UnknownValueError:
        return jsonify({
            "error": "Could not understand audio",
            "hint": "Try speaking more clearly or check microphone quality",
        }), 422
    except sr.RequestError as e:
        return jsonify({
            "error": "Speech recognition service error",
            "details": str(e),
        }), 502
    except Exception as e:
        return jsonify({
            "error": "Transcription failed",
            "details": str(e),
        }), 500
    finally:
        # Clean up temp files
        for path in (tmp_path, tmp_wav):
            if path and os.path.exists(path):
                try:
                    os.unlink(path)
                except OSError:
                    pass


# ─── Init ─────────────────────────────────────────────────

if not os.path.exists(STATE_FILE):
    save_state(default_state())

if __name__ == "__main__":
    print("=" * 50)
    print("  NMIACM TODO Tracker")
    print("  http://0.0.0.0:5000")
    print("=" * 50)
    app.run(host="0.0.0.0", port=5000, debug=True)
