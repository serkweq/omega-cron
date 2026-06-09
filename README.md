omega-cron - External Cron Trigger Pipeline for OmegaClaw
==========================================================

WHAT THIS DOES
--------------
Schedules work to run against OmegaClaw at precise times.
Scheduling intent originates externally; OmegaClaw is the
executor, not the scheduler.

  cron.org -> curl -> Telegram Bot API -> OmegaClaw polling -> MeTTa -> action

No new bot, no daemon, no separate infrastructure.
Same TG_BOT_TOKEN OmegaClaw already uses.

FILES
-----
  trigger.sh              curl wrapper - the only external dependency
  src/cron-helper.py      Python: whitelist + parse logic
  src/cron-handler.metta  MeTTa: parse, dispatch, skill handlers
  example-crontab         Ready-to-paste cron expressions
  README.md               This file

INSTALLATION INTO OMEGACLAW
---------------------------
1. Copy the cron helper Python module into OmegaClaw:

   cp src/cron-helper.py /path/to/OmegaClaw-Core/src/cron-helper.py

2. Add cron-handler.metta to the load chain.
   In lib_omegaclaw.metta, add after other imports:

   !(import! &self (library OmegaClaw-Core ./src/cron-handler))

3. Register the crontab skill in src/skills.metta.
   Add to getSkills:

     "- Invoke scheduled task dispatcher: crontab string"

4. Add get_field helper to src/helper.py:

   def get_field(obj, field):
       if hasattr(obj, field):
           return getattr(obj, field)
       if isinstance(obj, dict):
           return obj.get(field)
       return None

5. Restart OmegaClaw.

TESTING
-------
  # Test trigger script (no OmegaClaw needed)
  TG_BOT_TOKEN=... TG_CHAT_ID=... ./trigger.sh ping health-check

  # With OmegaClaw running
  TG_BOT_TOKEN=... TG_CHAT_ID=... ./trigger.sh test ping
  docker logs -f omegaclaw | grep CRON

ADDING NEW CRON SKILLS
----------------------
1. Whitelist in src/cron-helper.py WHITELIST dict
2. Add handler case in src/cron-handler.metta crontab-dispatch
3. Implement the handler function
4. Add crontab entry

SECURITY MODEL
--------------
- Skill whitelist enforced in cron-helper.py before any handler runs
- TG_BOT_TOKEN grants send-only access to your bound Telegram chat
- Auth binding: only your account can trigger OmegaClaw
- cron: prefix distinguishes scheduled triggers in logs

LIMITATIONS
-----------
- Max 20s delay (TG_POLL_TIMEOUT) between cron fire and agent response
- If OmegaClaw offline when cron fires, Telegram queues up to 24h
- No native Telegram message scheduling - this is external scheduling

ENVIRONMENT VARIABLES
---------------------
  TG_BOT_TOKEN   Bot token from OmegaClaw config
  TG_CHAT_ID     Your Telegram chat ID (bound after auth)
