
import re

CRON_PREFIX = "cron:"
WHITELIST = {"ping", "test", "instagram", "summary", "backup", "memory"}


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
