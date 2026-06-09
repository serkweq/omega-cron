
import json
import os
import re
import time

CRON_PREFIX = "cron:"
WHITELIST = {"ping", "test", "instagram", "summary", "backup", "memory"}
CRON_STATE_FILE = "/tmp/cron-last-fired.json"
DEFAULT_COOLDOWN = 60  # seconds


def is_cron_message(text):
    return text.strip().lower().startswith(CRON_PREFIX)


def parse_cron_message(text):
    text = text.strip()
    if not text.lower().startswith(CRON_PREFIX):
        return {
            "valid": False,
            "skill": None,
            "task": None,
            "payload": None,
            "error": f"Not a cron message (missing \'{CRON_PREFIX}\' prefix)"
        }

    body = text[len(CRON_PREFIX):].strip()
    parts = body.split(":")

    if len(parts) < 2:
        return {
            "valid": False,
            "skill": None,
            "task": None,
            "payload": None,
            "error": f"Invalid cron format. Expected \'cron:<skill>:<task>\' got \'{body}\'"
        }

    skill = parts[0].strip().lower()
    task = parts[1].strip().lower()
    payload = ":".join(parts[2:]).strip() or None

    if skill not in WHITELIST:
        return {
            "valid": False,
            "skill": skill,
            "task": task,
            "payload": payload,
            "error": f"Unknown skill \'{skill}\'. Whitelist: {', '.join(sorted(WHITELIST))}"
        }

    return {
        "valid": True,
        "skill": skill,
        "task": task,
        "payload": payload,
        "error": None
    }


def get_field(obj, field):
    if hasattr(obj, field):
        return getattr(obj, field)
    if isinstance(obj, dict):
        return obj.get(field)
    return None


def _load_state():
    """Load last-fired timestamps from state file."""
    if not os.path.exists(CRON_STATE_FILE):
        return {}
    try:
        with open(CRON_STATE_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return {}


def _save_state(state):
    """Persist last-fired timestamps to state file."""
    try:
        with open(CRON_STATE_FILE, "w") as f:
            json.dump(state, f)
    except IOError:
        pass  # non-fatal — proceed without state


def check_idempotency(skill, task, cooldown=None):
    """
    Returns (blocked, elapsed) where blocked=True means this job fired
    recently and should be skipped. elapsed is seconds since last fire.
    """
    cooldown = cooldown if cooldown is not None else DEFAULT_COOLDOWN
    state = _load_state()
    key = f"{skill}:{task}"
    last = state.get(key, 0)
    now = time.time()
    elapsed = now - last
    if elapsed < cooldown:
        return (True, elapsed)
    return (False, elapsed)


def update_last_fired(skill, task):
    """Record that skill:task just fired."""
    state = _load_state()
    key = f"{skill}:{task}"
    state[key] = time.time()
    _save_state(state)
